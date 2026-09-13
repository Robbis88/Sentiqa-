-- =====================================================================
-- 0212  ÉN SETNING VAR FEIL SVAR PAA ET RIKTIG SPOERSMAAL
-- =====================================================================
-- `aktiver_import()` byttet aktiv jobb med ÉN update:
--
--   update public.import_jobber
--      set aktiv = (id = p_jobb)
--    where … and (aktiv or id = p_jobb);
--
-- Begrunnelsen sto i `0209`: «ÉN setning, saa det aldri finnes et
-- oeyeblikk med to aktive eller ingen aktive.» Spoersmaalet var riktig.
-- Svaret var det ikke.
--
-- Foerste ekte kall, 2026-09-13:
--
--   ERROR: 23505 duplicate key value violates unique constraint
--          "import_jobber_aktiv_unik"
--   DETAIL: Key (retailer_id, rapporttype, gjelder_dato)=(…, 2026-01-01)
--           already exists.
--
-- **En partiell unik indeks kan ikke utsettes.** `deferrable` finnes
-- bare paa unike SKRANKER, og Postgres stoetter ikke partielle unike
-- skranker - bare partielle unike indekser. Da sjekkes den per rad mens
-- setningen gaar, og den nye raden blir aktiv foer den gamle er
-- deaktivert. Sluttilstanden ville vaert gyldig; veien dit er det ikke.
--
-- Atomisiteten jeg var ute etter kommer uansett fra TRANSAKSJONEN.
-- Funksjonen kjoerer i én, og ingen annen sesjon ser mellomtilstanden.
-- To setninger i riktig rekkefoelge er derfor bade lovlig og trygt:
--
--   1  deaktiver den gamle
--   2  aktiver den nye
--
-- Motsatt rekkefoelge ville feilet paa nytt.
--
-- ---------------------------------------------------------------------
-- FUNKSJONEN HAR ALDRI VIRKET
--
-- Ingenting kaller den ennaa, saa ingen data er skadet. Men den sto som
-- «mekanismen er paa plass» i P1-rapporten, og det var den ikke. Den ble
-- funnet fordi Robert kalte den for haand for aa rette januars
-- proveniens - ikke av en test.
--
-- `supabase/tests/aktiver_import_probe.sql` kjoerer den naa mot ekte
-- jobber i en transaksjon som rulles tilbake. Den ville fanget dette.
--
-- Idempotent: `or replace`. Ingen rad endres av selve migrasjonen.
-- =====================================================================

create or replace function public.aktiver_import(
  p_retailer uuid,
  p_jobb     uuid
) returns table (forrige uuid, ny uuid)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_type    public.rapporttype;
  v_dato    date;
  v_versjon text;
  v_avstemt timestamptz;
  v_avvik   integer;
  v_gammel  uuid;
  v_grupper integer;
  v_ukontrollert integer;
begin
  select rapporttype, gjelder_dato, parserversjon, avstemt_tid, avviksantall
    into v_type, v_dato, v_versjon, v_avstemt, v_avvik
    from public.import_jobber
   where id = p_jobb and retailer_id = p_retailer and status = 'parset';

  if v_type is null then
    raise exception
      'aktiver_import: jobb % finnes ikke for retailer %, eller er ikke «parset». '
      'En jobb som ikke er ferdig avstemt skal ikke kunne aktiveres.',
      p_jobb, p_retailer;
  end if;
  if v_dato is null then
    raise exception
      'aktiver_import: jobb % mangler gjelder_dato. Uten periode kan ingen '
      'vite hva den skulle erstatte.', p_jobb;
  end if;

  -- PORT 1: hvilken parser laget radene?
  if v_versjon is null or btrim(v_versjon) = '' then
    raise exception
      'aktiver_import: jobb % mangler parserversjon. Samme fil med ulik '
      'parser gir ulikt radantall, og uten navnet ser to versjoner like '
      'ut. Gamle jobber har null med rette - de kan ikke AKTIVERES paa '
      'nytt, bare staa.', p_jobb;
  end if;

  -- PORT 2: er avstemmingen kjoert i det hele tatt?
  if v_avstemt is null then
    raise exception
      'aktiver_import: jobb % er ikke avstemt (avstemt_tid er null). '
      '«Parset» betyr at koden ikke kastet, ikke at radene stemmer.', p_jobb;
  end if;

  -- PORT 3: fant avstemmingen noe?
  if coalesce(v_avvik, -1) <> 0 then
    raise exception
      'aktiver_import: jobb % har avviksantall = % (kravet er 0). Et avvik '
      'skal forklares foer tallet blir synlig.', p_jobb, coalesce(v_avvik, -1);
  end if;

  -- PORT 4 og 5 gjelder bare regnskapet, som er det eneste som baerer
  -- svinnrader.
  if v_type = 'regnskap_resultat' then
    select count(*) filter (where nivaa = 'gruppe'),
           count(*) filter (where avviksstatus = 'avvik')
      into v_grupper, v_ukontrollert
      from public.regnskap_usynlig_svinn
     where kilde_jobb_id = p_jobb and slettet_tid is null;

    if coalesce(v_grupper, 0) = 0 then
      raise exception
        'aktiver_import: jobb % har ingen grupperader. Uten dem eier ingen '
        'totalen, og hver analyse maa falle tilbake paa produktnivaa.', p_jobb;
    end if;

    if coalesce(v_ukontrollert, 0) > 0 then
      raise exception
        'aktiver_import: jobb % har % rader der kontrollen av usynlig svinn '
        'ikke stemmer (teoretisk − faktisk − kast = usynlig). Tallene er '
        'ikke til aa bygge en konklusjon paa.', p_jobb, v_ukontrollert;
    end if;
  end if;

  select id into v_gammel
    from public.import_jobber
   where retailer_id = p_retailer and rapporttype = v_type
     and gjelder_dato = v_dato and aktiv and id <> p_jobb;

  -- -------------------------------------------------------------------
  -- TO SETNINGER, OG REKKEFOELGEN ER HELE POENGET.
  --
  -- Deaktiver foerst. Den partielle unike indeksen sjekkes per rad, saa
  -- motsatt rekkefoelge gir 23505 selv om sluttilstanden er gyldig.
  -- Transaksjonen gjoer mellomtilstanden usynlig for alle andre.
  -- -------------------------------------------------------------------
  update public.import_jobber
     set aktiv = false, oppdatert_tid = now()
   where retailer_id = p_retailer
     and rapporttype = v_type
     and gjelder_dato = v_dato
     and aktiv
     and id <> p_jobb;

  update public.import_jobber
     set aktiv = true, oppdatert_tid = now()
   where id = p_jobb
     and not aktiv;

  return query select v_gammel, p_jobb;
end $$;

revoke all on function public.aktiver_import(uuid, uuid) from public;
grant execute on function public.aktiver_import(uuid, uuid) to authenticated;

comment on function public.aktiver_import(uuid, uuid) is
  'Bytter aktiv import for én periode. Fem porter: «parset», '
  'parserversjon, avstemt_tid, avviksantall = 0, og for regnskapet '
  'grupperader + bestaatt kontroll av usynlig svinn. Byttet skjer i TO '
  'setninger - deaktiver foer aktiver - fordi en partiell unik indeks '
  'ikke kan utsettes og sjekkes per rad. Transaksjonen gjoer '
  'mellomtilstanden usynlig.';

-- ---------------------------------------------------------------------
-- Kvittering: hvor mange perioder har en aktiv jobb som IKKE skrev
-- radene som ligger der?
-- ---------------------------------------------------------------------
with kilde as (
  select s.periode,
         count(distinct s.kilde_jobb_id) as kilder,
         min(s.kilde_jobb_id)            as hovedkilde
    from public.regnskap_usynlig_svinn s
   where s.slettet_tid is null
   group by s.periode
)
select k.periode,
       k.kilder,
       ij.parserversjon                       as skrivende_versjon,
       a.parserversjon                        as aktiv_versjon,
       case when a.id = k.hovedkilde then 'samme' else 'ULIK' end as proveniens
  from kilde k
  left join public.import_jobber ij on ij.id = k.hovedkilde
  left join public.import_jobber a
    on a.gjelder_dato = k.periode and a.rapporttype = 'regnskap_resultat' and a.aktiv
 order by k.periode;
