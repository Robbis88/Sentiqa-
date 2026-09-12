-- =====================================================================
-- 0211  EN JOBB SKAL IKKE KUNNE BLI SYNLIG UTEN AA VAERE AVSTEMT
-- =====================================================================
-- `0209` ga `aktiver_import()` én port: jobben maa vaere `parset`. Det
-- er for lite. «Parset» betyr bare at koden ikke kastet - ikke at
-- radene stemmer.
--
-- Fire porter til, og hver av dem svarer paa et sposermaal noen har
-- stilt etter en feil:
--
--   parserversjon    hvilken parser laget radene? Sto `null` paa hver
--                    jobb, fordi ingen skrev den. Samme fil med ulik
--                    parser gir ulikt radantall - januarfila ga 324
--                    rader i juni og 384 i september.
--   avstemt_tid      ER avstemmingen kjoert? Ikke «gikk importen».
--   avviksantall     fant avstemmingen noe? 0 er kravet.
--   radnivaa         finnes grupperadene i det hele tatt? En jobb uten
--                    dem gir en maaned som ser komplett ut og som hver
--                    analyse maa falle tilbake fra.
--   usynlig-kontroll holder `teoretisk − faktisk − kast = usynlig` paa
--                    hver rad? Feiler den, er tallene ikke til aa
--                    bygge en konklusjon paa.
--
-- ---------------------------------------------------------------------
-- GAMLE JOBBER BEHOLDER `null` OG BLIR STAAENDE
--
-- Etterfyllingen i `0209` merket siste vellykkede jobb per periode som
-- aktiv. De jobbene har ingen parserversjon og ingen avstemming, og de
-- SKAL ikke miste flagget - da ville hver maaned blitt usynlig i det
-- oeyeblikket dette kjoerte.
--
-- Portene gjelder derfor NY aktivering. En gammel aktiv jobb staar til
-- en ny tar plassen, og den nye maa bevise seg. `parsergrunnlag()` i
-- `src/lib/import/parserversjon.ts` kaller `null` for «eldre
-- parsergrunnlag», og det er sant.
--
-- ---------------------------------------------------------------------
-- IKKE KJOERT. Skrevet og testet lokalt.
--
-- Idempotent: `add column if not exists`, `or replace` paa funksjonen.
-- Ingen policy roeres, ingen view roeres, ingen rad endres.
-- =====================================================================

alter table public.import_jobber
  add column if not exists avstemt_tid   timestamptz,
  add column if not exists avviksantall  integer;

comment on column public.import_jobber.avstemt_tid is
  'Naar avstemmingen ble kjoert for denne jobben. `null` = ikke avstemt, '
  'og da kan jobben ikke aktiveres. «Parset» betyr bare at koden ikke '
  'kastet.';
comment on column public.import_jobber.avviksantall is
  'Antall rader der kontrollen av usynlig svinn ikke stemte. Kravet for '
  'aktivering er 0.';

-- ---------------------------------------------------------------------
-- AKTIVERINGEN, MED FEM PORTER
--
-- `or replace` beholder signaturen fra `0209`, saa ingen kallsted
-- endres. Funksjonen er fortsatt `security definer` og baerer
-- tenantpredikatet selv.
-- ---------------------------------------------------------------------
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

  -- ÉN setning, saa det aldri finnes et oeyeblikk med to aktive eller
  -- ingen aktive.
  update public.import_jobber
     set aktiv = (id = p_jobb),
         oppdatert_tid = now()
   where retailer_id = p_retailer
     and rapporttype = v_type
     and gjelder_dato = v_dato
     and (aktiv or id = p_jobb);

  return query select v_gammel, p_jobb;
end $$;

revoke all on function public.aktiver_import(uuid, uuid) from public;
grant execute on function public.aktiver_import(uuid, uuid) to authenticated;

comment on function public.aktiver_import(uuid, uuid) is
  'Bytter aktiv import for én periode i ÉN setning. Fem porter: jobben '
  'maa vaere «parset», ha parserversjon, vaere avstemt, ha 0 avvik, og '
  'for regnskapet ha grupperader og bestaatt kontroll av usynlig svinn. '
  'Rollback er aa kalle den med den gamle jobb-iden - men den gamle maa '
  'da ogsaa passere portene, saa en tilbakerulling til en jobb fra eldre '
  'parsergrunnlag maa gjoeres med et manuelt update.';

-- ---------------------------------------------------------------------
-- Kvittering SOM SELECT.
--
-- Forventet i dag: hver aktiv jobb har `parserversjon = null` og
-- `avstemt = null` - de er fra eldre parsergrunnlag, og de staar.
-- ---------------------------------------------------------------------
select rapporttype,
       count(*)                                          as aktive,
       count(*) filter (where parserversjon is not null) as med_versjon,
       count(*) filter (where avstemt_tid is not null)   as avstemte,
       count(*) filter (where parserversjon is null)     as eldre_grunnlag
  from public.import_jobber
 where aktiv
 group by rapporttype
 order by rapporttype;
