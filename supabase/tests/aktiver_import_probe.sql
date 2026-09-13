-- =====================================================================
-- PROBE: aktiver_import() — byttet, og de fem portene
-- =====================================================================
-- DENNE VILLE FANGET FEILEN I `0209`.
--
-- Funksjonen byttet aktiv jobb med ÉN update, «saa det aldri finnes et
-- oeyeblikk med to aktive». Foerste ekte kall 2026-09-13 ga:
--
--   ERROR: 23505 duplicate key ... "import_jobber_aktiv_unik"
--
-- En partiell unik indeks kan ikke utsettes og sjekkes per rad, saa den
-- nye raden ble aktiv foer den gamle var deaktivert. `0212` deler den i
-- to setninger i riktig rekkefoelge.
--
-- Funksjonen hadde staatt i produksjon i et doegn og aldri virket. Ingen
-- data ble skadet - ingenting kaller den ennaa - men den sto som
-- «mekanismen er paa plass» i rapporten, og det var den ikke.
--
-- ---------------------------------------------------------------------
-- TRYGG I PRODUKSJON
--
-- Alt skjer i én transaksjon som avsluttes med `rollback`. Fiksturene
-- bruker perioden 1999-03-01, som ikke finnes i ekte data, og de ryddes
-- av tilbakerullingen uansett.
--
-- Kvittering: siste `select` skal gi NULL rader.
-- =====================================================================

begin;

create temp table aktiveringsavvik (
  tilfelle  text,
  forventet text,
  faktisk   text
) on commit drop;

do $probe$
declare
  v_ret   uuid;
  v_fil   uuid;
  v_a     uuid;   -- jobb A: komplett, skal kunne aktiveres
  v_b     uuid;   -- jobb B: komplett, skal kunne overta
  v_c     uuid;   -- jobb C: mangler parserversjon
  v_ny    uuid;
  v_forrige uuid;
  v_antall  integer;
begin
  select id into v_ret from public.retailers order by opprettet_tid limit 1;
  if v_ret is null then
    raise exception 'probe: fant ingen retailer';
  end if;

  insert into public.raa_filer (retailer_id, filnavn, storage_sti, mottakskanal)
  values (v_ret, 'probe-aktivering.xlsx', 'probe/aktivering', 'drop_zone')
  returning id into v_fil;

  -- Tre jobber paa samme periode. A og B er komplette; C mangler
  -- parserversjonen og skal avvises av port 1.
  insert into public.import_jobber
    (raa_fil_id, retailer_id, rapporttype, status, gjelder_dato,
     parserversjon, avstemt_tid, avviksantall, antall_rader)
  values (v_fil, v_ret, 'st1_salgsstatistikk', 'parset', date '1999-03-01',
          'probe-1', now(), 0, 1)
  returning id into v_a;

  insert into public.import_jobber
    (raa_fil_id, retailer_id, rapporttype, status, gjelder_dato,
     parserversjon, avstemt_tid, avviksantall, antall_rader)
  values (v_fil, v_ret, 'st1_salgsstatistikk', 'parset', date '1999-03-01',
          'probe-2', now(), 0, 1)
  returning id into v_b;

  insert into public.import_jobber
    (raa_fil_id, retailer_id, rapporttype, status, gjelder_dato,
     parserversjon, avstemt_tid, avviksantall, antall_rader)
  values (v_fil, v_ret, 'st1_salgsstatistikk', 'parset', date '1999-03-01',
          null, now(), 0, 1)
  returning id into v_c;

  -- -------------------------------------------------------------------
  -- 1) FOERSTE AKTIVERING. Ingen er aktiv fra foer.
  -- -------------------------------------------------------------------
  select ny, forrige into v_ny, v_forrige
    from public.aktiver_import(v_ret, v_a);

  if v_ny is distinct from v_a then
    insert into aktiveringsavvik values ('foerste aktivering: ny', v_a::text, v_ny::text);
  end if;
  if v_forrige is not null then
    insert into aktiveringsavvik values ('foerste aktivering: forrige', 'null', v_forrige::text);
  end if;

  -- -------------------------------------------------------------------
  -- 2) BYTTET. DETTE ER TILFELLET SOM FEILET MED ÉN SETNING.
  -- -------------------------------------------------------------------
  begin
    select ny, forrige into v_ny, v_forrige
      from public.aktiver_import(v_ret, v_b);
  exception when unique_violation then
    insert into aktiveringsavvik values (
      'BYTTE: partiell unik indeks slo til',
      'byttet uten feil',
      '23505 - funksjonen bytter i én setning igjen, se 0212');
  end;

  if v_forrige is distinct from v_a then
    insert into aktiveringsavvik values ('bytte: forrige', v_a::text, coalesce(v_forrige::text, 'null'));
  end if;

  select count(*) into v_antall
    from public.import_jobber
   where gjelder_dato = date '1999-03-01' and retailer_id = v_ret and aktiv;
  if v_antall <> 1 then
    insert into aktiveringsavvik values ('etter bytte: antall aktive', '1', v_antall::text);
  end if;

  select count(*) into v_antall
    from public.import_jobber
   where id = v_b and aktiv;
  if v_antall <> 1 then
    insert into aktiveringsavvik values ('etter bytte: B er aktiv', '1', v_antall::text);
  end if;

  -- -------------------------------------------------------------------
  -- 3) TILBAKE IGJEN. Rollback er aa kalle den med den gamle iden.
  -- -------------------------------------------------------------------
  select ny into v_ny from public.aktiver_import(v_ret, v_a);
  select count(*) into v_antall
    from public.import_jobber
   where id = v_a and aktiv;
  if v_antall <> 1 then
    insert into aktiveringsavvik values ('tilbakerulling: A er aktiv igjen', '1', v_antall::text);
  end if;

  -- -------------------------------------------------------------------
  -- 4) PORT 1: en jobb uten parserversjon skal AVVISES.
  -- -------------------------------------------------------------------
  begin
    perform public.aktiver_import(v_ret, v_c);
    insert into aktiveringsavvik values (
      'port 1: parserversjon', 'avvist', 'slapp gjennom');
  exception when others then
    if sqlerrm not like '%parserversjon%' then
      insert into aktiveringsavvik values (
        'port 1: feil grunn', 'melding om parserversjon', sqlerrm);
    end if;
  end;

  -- -------------------------------------------------------------------
  -- 5) PORT 2: uten avstemming skal den avvises.
  -- -------------------------------------------------------------------
  update public.import_jobber set avstemt_tid = null where id = v_b;
  begin
    perform public.aktiver_import(v_ret, v_b);
    insert into aktiveringsavvik values (
      'port 2: avstemt_tid', 'avvist', 'slapp gjennom');
  exception when others then
    if sqlerrm not like '%ikke avstemt%' then
      insert into aktiveringsavvik values (
        'port 2: feil grunn', 'melding om avstemming', sqlerrm);
    end if;
  end;

  -- -------------------------------------------------------------------
  -- 6) PORT 3: avvik <> 0 skal avvises.
  -- -------------------------------------------------------------------
  update public.import_jobber set avstemt_tid = now(), avviksantall = 3 where id = v_b;
  begin
    perform public.aktiver_import(v_ret, v_b);
    insert into aktiveringsavvik values (
      'port 3: avviksantall', 'avvist', 'slapp gjennom');
  exception when others then
    if sqlerrm not like '%avviksantall%' then
      insert into aktiveringsavvik values (
        'port 3: feil grunn', 'melding om avviksantall', sqlerrm);
    end if;
  end;
end $probe$;

-- KVITTERING. Null rader = funksjonen bytter riktig og portene holder.
select * from aktiveringsavvik order by tilfelle;

select count(*) as avvik,
       case when count(*) = 0 then 'AKTIVERINGEN VIRKER'
            else 'SE RADENE OVER' end as dom
  from aktiveringsavvik;

rollback;
