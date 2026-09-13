-- =====================================================================
-- LAASEN PAA MAANEDSPLANEN, FELT FOR FELT
-- =====================================================================
-- Kjoeres med `psql -v ON_ERROR_STOP=1`. Alt skjer i én transaksjon som
-- rulles tilbake til slutt - basen staar uroert.
--
-- Fire ting maales:
--
--   1  TRIGGEREN, ETT FELT OM GANGEN. En vakt som bare proever `punkter`
--      beviser ikke at `merknad` eller snapshotet er laast. Hvert
--      enkelt felt skal felle den.
--   2  DET SOM FORTSATT MAA GAA. `sluppet -> sendt`, og fri endring av
--      et utkast. Uten disse ville testene over bestaatt i en trigger
--      som avviser alt.
--   3  JOBBVALIDERINGEN i `skriv_maanedsplan_utkast`, som skal feile
--      LUKKET: ingen plan skrevet naar kildejobben ikke holder.
--   4  DIGESTEN: +100/-100 i samme maaned. Antall og sum staar stille,
--      digesten skal flytte seg.
-- =====================================================================

begin;

create or replace function pg_temp.kast(p_melding text)
returns void language plpgsql as $$
begin raise exception 'FUNN: %', p_melding using errcode = 'assert_failure'; end $$;

-- Feller en update som SKULLE vaert blokkert.
create or replace function pg_temp.maa_blokkere(p_id uuid, p_sql text)
returns void language plpgsql as $$
begin
  begin
    execute format(p_sql, p_id);
  exception when check_violation then
    return;                                -- riktig: triggeren felte den
  end;
  perform pg_temp.kast('Updaten gikk gjennom, men skulle vaert blokkert: ' || p_sql);
end $$;

-- Feller en update som SKULLE gaatt gjennom.
create or replace function pg_temp.maa_gaa(p_id uuid, p_sql text)
returns void language plpgsql as $$
begin
  execute format(p_sql, p_id);
exception when others then
  perform pg_temp.kast('Updaten ble blokkert, men skulle gaatt: ' || p_sql
                       || ' (' || sqlerrm || ')');
end $$;

-- ---------------------------------------------------------------------
-- FIKSTUR. Egen kjede og stasjon, saa ingenting kolliderer med seeden.
-- ---------------------------------------------------------------------
do $$
declare
  v_ret uuid := '99999999-9999-4999-8999-999999999901';
  v_st  uuid := '99999999-9999-4999-8999-999999999902';
  v_pro uuid := '99999999-9999-4999-8999-999999999903';
begin
  insert into public.retailers (id, navn) values (v_ret, 'Laasetest')
    on conflict (id) do nothing;
  insert into public.stasjoner (id, retailer_id, butikknummer, navn, stasjonstype)
    values (v_st, v_ret, '9801', 'Laasestasjon', 'bydel')
    on conflict (id) do nothing;
  insert into public.profiler (id, retailer_id, rolle, fullt_navn)
    values (v_pro, v_ret, 'retailer_admin', 'Laasetest Eier')
    on conflict (id) do nothing;
end $$;

-- ---------------------------------------------------------------------
-- 1  TRIGGEREN, FELT FOR FELT
-- ---------------------------------------------------------------------
do $$
declare
  v_ret  uuid := '99999999-9999-4999-8999-999999999901';
  v_st   uuid := '99999999-9999-4999-8999-999999999902';
  v_pro  uuid := '99999999-9999-4999-8999-999999999903';
  v_id   uuid;
  v_felt text;
  -- HVERT FELT EIEREN FAKTISK GODKJENNER. `merknad` sto ikke i
  -- triggeren foer `0217`, og snapshotkolonnene fra `0216` heller ikke.
  v_innhold text[] := array[
    'dom = ''flat''',
    'ingress = ''noe helt annet''',
    'punkter = ''[{"x":1}]''::jsonb',
    'merknad = ''endret''',
    'matkast = ''{"a":1}''::jsonb',
    'usynlig = ''{"b":2}''::jsonb',
    'rangering = ''{"mulig":false}''::jsonb'
  ];
begin
  -- --- SLUPPET: innhold laast, status kan gaa videre ---------------
  for i in 1 .. array_length(v_innhold, 1) loop
    v_felt := v_innhold[i];
    delete from public.maanedsplan where stasjon_id = v_st;
    insert into public.maanedsplan
      (id, retailer_id, stasjon_id, maaned, dom, ingress, punkter, status,
       sluppet_av, sluppet_tid)
    values (gen_random_uuid(), v_ret, v_st, date '2026-07-01', 'motvind',
            'x', '[]'::jsonb, 'sluppet', v_pro, now())
    returning id into v_id;

    perform pg_temp.maa_blokkere(v_id,
      'update public.maanedsplan set ' || v_felt || ' where id = %L');
  end loop;

  -- --- AVVIST: ALT laast, ogsaa status og proveniens ---------------
  foreach v_felt in array v_innhold || array[
    'status = ''utkast''',
    'kilde_jobb_id = null'
  ] loop
    delete from public.maanedsplan where stasjon_id = v_st;
    insert into public.maanedsplan
      (id, retailer_id, stasjon_id, maaned, dom, ingress, punkter, status,
       kilde_jobb_id)
    values (gen_random_uuid(), v_ret, v_st, date '2026-07-01', 'motvind',
            'x', '[]'::jsonb, 'avvist', null)
    returning id into v_id;
    -- `kilde_jobb_id = null` paa en rad som alt er null endrer ingenting,
    -- saa den raden faar en verdi foerst.
    if v_felt = 'kilde_jobb_id = null' then
      update public.maanedsplan set status = 'utkast' where id = v_id;
      update public.maanedsplan set kilde_jobb_id = gen_random_uuid() where id = v_id;
      update public.maanedsplan set status = 'avvist' where id = v_id;
    end if;

    perform pg_temp.maa_blokkere(v_id,
      'update public.maanedsplan set ' || v_felt || ' where id = %L');
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 2  KANARIFUGL: det som fortsatt MAA gaa
-- ---------------------------------------------------------------------
do $$
declare
  v_ret uuid := '99999999-9999-4999-8999-999999999901';
  v_st  uuid := '99999999-9999-4999-8999-999999999902';
  v_pro uuid := '99999999-9999-4999-8999-999999999903';
  v_id  uuid;
begin
  -- Et UTKAST kan endres fritt. Uten denne ville testene over bestaatt
  -- i en trigger som blokkerer alt.
  delete from public.maanedsplan where stasjon_id = v_st;
  insert into public.maanedsplan
    (id, retailer_id, stasjon_id, maaned, dom, ingress, punkter, status)
  values (gen_random_uuid(), v_ret, v_st, date '2026-07-01', 'motvind',
          'x', '[]'::jsonb, 'utkast')
  returning id into v_id;
  perform pg_temp.maa_gaa(v_id,
    'update public.maanedsplan set ingress = ''ny'', merknad = ''m'', '
    || 'matkast = ''{"c":3}''::jsonb where id = %L');

  -- SLUPPET -> SENDT maa fortsatt gaa. Laa `status` i sluppet-armen,
  -- ville laasen blokkert sin egen neste tilstand.
  delete from public.maanedsplan where stasjon_id = v_st;
  insert into public.maanedsplan
    (id, retailer_id, stasjon_id, maaned, dom, ingress, punkter, status,
     sluppet_av, sluppet_tid)
  values (gen_random_uuid(), v_ret, v_st, date '2026-07-01', 'motvind',
          'x', '[]'::jsonb, 'sluppet', v_pro, now())
  returning id into v_id;
  perform pg_temp.maa_gaa(v_id,
    'update public.maanedsplan set status = ''sendt'' where id = %L');
end $$;

-- ---------------------------------------------------------------------
-- 3  JOBBVALIDERINGEN FEILER LUKKET
-- ---------------------------------------------------------------------
do $$
declare
  v_ret   uuid := '99999999-9999-4999-8999-999999999901';
  v_st    uuid := '99999999-9999-4999-8999-999999999902';
  v_annen uuid := '99999999-9999-4999-8999-999999999911';
  v_fil   uuid;
  v_ok    uuid;
  v_feil_mnd uuid;
  v_fremmed  uuid;
  v_rader jsonb;
  v_antall int;
begin
  insert into public.retailers (id, navn) values (v_annen, 'Annen kjede')
    on conflict (id) do nothing;

  insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal)
    values (gen_random_uuid(), v_ret, 'test.xlsx', 'x/test.xlsx', 'drop_zone')
    returning id into v_fil;

  insert into public.import_jobber (retailer_id, raa_fil_id, rapporttype, status, gjelder_dato)
    values (v_ret, v_fil, 'regnskap_resultat', 'parset', date '2026-07-01')
    returning id into v_ok;
  insert into public.import_jobber (retailer_id, raa_fil_id, rapporttype, status, gjelder_dato)
    values (v_ret, v_fil, 'regnskap_resultat', 'parset', date '2026-06-01')
    returning id into v_feil_mnd;
  insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal)
    values (gen_random_uuid(), v_annen, 'annen.xlsx', 'x/annen.xlsx', 'drop_zone')
    returning id into v_fil;
  insert into public.import_jobber (retailer_id, raa_fil_id, rapporttype, status, gjelder_dato)
    values (v_annen, v_fil, 'regnskap_resultat', 'parset', date '2026-07-01')
    returning id into v_fremmed;

  v_rader := jsonb_build_array(jsonb_build_object(
    'stasjon_id', v_st, 'maaned', '2026-07-01', 'dom', 'motvind',
    'ingress', 'x', 'punkter', '[]'::jsonb, 'merknad', null,
    'matkast', null, 'usynlig', null, 'rangering', null));

  -- De tre som skal feile LUKKET.
  for v_fil in select unnest(array[v_fremmed, v_feil_mnd,
                                   '00000000-0000-4000-8000-000000000000'::uuid]) loop
    delete from public.maanedsplan where stasjon_id = v_st;
    begin
      perform * from public.skriv_maanedsplan_utkast(v_rader, v_ret, v_fil);
      perform pg_temp.kast('Ugyldig kildejobb ble godtatt: ' || v_fil);
    exception when check_violation then
      null;                                -- riktig
    end;
    select count(*) into v_antall from public.maanedsplan where stasjon_id = v_st;
    if v_antall <> 0 then
      perform pg_temp.kast('Plan ble skrevet tross ugyldig kildejobb: ' || v_fil);
    end if;
  end loop;

  -- KANARIFUGL: den GYLDIGE jobben skal gaa gjennom.
  delete from public.maanedsplan where stasjon_id = v_st;
  perform * from public.skriv_maanedsplan_utkast(v_rader, v_ret, v_ok);
  select count(*) into v_antall from public.maanedsplan
   where stasjon_id = v_st and kilde_jobb_id = v_ok;
  if v_antall <> 1 then
    perform pg_temp.kast('Gyldig kildejobb skrev ingen plan - vakten maaler ingenting');
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 4  LAASEN I `on conflict ... where`
-- ---------------------------------------------------------------------
do $$
declare
  v_ret uuid := '99999999-9999-4999-8999-999999999901';
  v_st  uuid := '99999999-9999-4999-8999-999999999902';
  v_pro uuid := '99999999-9999-4999-8999-999999999903';
  v_rader jsonb;
  v_skrevet boolean;
  v_ingress text;
  v_status text;
begin
  v_rader := jsonb_build_array(jsonb_build_object(
    'stasjon_id', v_st, 'maaned', '2026-07-01', 'dom', 'medvind',
    'ingress', 'NY TEKST', 'punkter', '[]'::jsonb, 'merknad', null,
    'matkast', null, 'usynlig', null, 'rangering', null));

  foreach v_status in array array['sluppet', 'sendt', 'avvist'] loop
    delete from public.maanedsplan where stasjon_id = v_st;
    insert into public.maanedsplan
      (retailer_id, stasjon_id, maaned, dom, ingress, punkter, status,
       sluppet_av, sluppet_tid)
    values (v_ret, v_st, date '2026-07-01', 'motvind', 'GAMMEL', '[]'::jsonb,
            v_status,
            case when v_status in ('sluppet', 'sendt') then v_pro end,
            case when v_status in ('sluppet', 'sendt') then now() end);

    select skrevet into v_skrevet
      from public.skriv_maanedsplan_utkast(v_rader, v_ret, null);
    select ingress into v_ingress from public.maanedsplan where stasjon_id = v_st;

    if v_skrevet then perform pg_temp.kast(v_status || ': skrevet = true'); end if;
    if v_ingress <> 'GAMMEL' then
      perform pg_temp.kast(v_status || ': innholdet ble endret');
    end if;
  end loop;

  -- KANARIFUGL: et utkast SKRIVES.
  delete from public.maanedsplan where stasjon_id = v_st;
  insert into public.maanedsplan
    (retailer_id, stasjon_id, maaned, dom, ingress, punkter, status)
  values (v_ret, v_st, date '2026-07-01', 'motvind', 'GAMMEL', '[]'::jsonb, 'utkast');
  select skrevet into v_skrevet
    from public.skriv_maanedsplan_utkast(v_rader, v_ret, null);
  select ingress into v_ingress from public.maanedsplan where stasjon_id = v_st;
  if not v_skrevet or v_ingress <> 'NY TEKST' then
    perform pg_temp.kast('Et utkast ble IKKE skrevet - vakten maaler ingenting');
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 5  DIGESTEN SER +100/-100
-- ---------------------------------------------------------------------
do $$
declare
  v_ret uuid := '99999999-9999-4999-8999-999999999901';
  v_st  uuid := '99999999-9999-4999-8999-999999999902';
  a_ant bigint; b_ant bigint;
  a_sum numeric; b_sum numeric;
  a_dig text;   b_dig text;
  v_a uuid; v_b uuid;
begin
  insert into public.regnskapslinjer (id, retailer_id, stasjon_id, periode, seksjon, post, regnskap)
    values (gen_random_uuid(), v_ret, v_st, date '2026-07-01', 'omsetning', 'A', 1000)
    returning id into v_a;
  insert into public.regnskapslinjer (id, retailer_id, stasjon_id, periode, seksjon, post, regnskap)
    values (gen_random_uuid(), v_ret, v_st, date '2026-07-01', 'omsetning', 'B', 2000)
    returning id into v_b;

  select count(*), coalesce(sum(regnskap), 0),
         coalesce(md5(string_agg(md5(x::text), '' order by x.id)), 'TOM')
    into a_ant, a_sum, a_dig
    from public.regnskapslinjer x where x.stasjon_id = v_st;

  update public.regnskapslinjer set regnskap = regnskap + 100 where id = v_a;
  update public.regnskapslinjer set regnskap = regnskap - 100 where id = v_b;

  select count(*), coalesce(sum(regnskap), 0),
         coalesce(md5(string_agg(md5(x::text), '' order by x.id)), 'TOM')
    into b_ant, b_sum, b_dig
    from public.regnskapslinjer x where x.stasjon_id = v_st;

  if a_ant <> b_ant then perform pg_temp.kast('antallet endret seg - feil fikstur'); end if;
  if a_sum <> b_sum then perform pg_temp.kast('summen endret seg - feil fikstur'); end if;
  if a_dig = b_dig then
    perform pg_temp.kast('DIGESTEN SAA IKKE +100/-100. Da beviser den ingenting.');
  end if;
end $$;

select 'maanedsplan_laas: ingen funn' as dom;

rollback;
