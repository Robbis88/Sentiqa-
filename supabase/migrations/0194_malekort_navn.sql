-- =====================================================================
-- 0194 - ANONYMISERINGEN SKJER DER NAVNET HENTES
--
-- `malekort.anonymiser` byttet butikknavnet til «Butikk #4» i VISNINGEN.
-- Rangeringen bygges av to `security definer`-funksjoner som enhver
-- `authenticated` kan kalle rett over PostgREST:
--
--   malekort_stasjoner()      (0075) navnet paa HVER stasjon i kjeden
--   beregn_malekort_salg()    (0074/0085) tallet per stasjon_id
--
-- Join dem selv, og den navngitte rangeringen er tilbake - uansett hva
-- admin har huket av. Samme form som `malekort.vis_tablet` foer `0134`:
-- et flagg som bare bodde i spoerringen.
--
-- ---------------------------------------------------------------------
-- HVA SOM ER HEMMELIG, OG HVA SOM IKKE ER DET
--
-- Butikksjefen SKAL se rangeringen - det er hele poenget med kortet.
-- Tallene er ikke hemmelige. Det flagget lover aa skjule er KOBLINGEN
-- navn-til-tall.
--
-- Derfor flyttes anonymiseringen hit, til der navnet hentes, i staden
-- for aa stramme tallfunksjonen. `beregn_malekort_salg` faar staa: uten
-- et navn er `stasjon_id -> 4711 kr` ikke en opplysning om noen.
--
-- ---------------------------------------------------------------------
-- PER KORT, IKKE PER KJEDE
--
-- `malekort_stasjoner()` visste ikke hvilket kort den svarte for, og
-- kunne derfor ikke anonymisere - anonymiseringen er en egenskap ved
-- KORTET. Denne tar kortet som argument.
--
-- Tenantbindingen ligger i `where m.retailer_id = gjeldende_retailer_id()`:
-- funksjonen er definer, saa uten den kunne hvem som helst sendt inn en
-- annen kjedes kort-id. Finnes ikke kortet i din kjede, kommer det null
-- rader ut - fail-closed.
--
-- ---------------------------------------------------------------------
-- REKKEFOELGE
--
-- Denne er ADDITIV og trygg i hvilken som helst rekkefoelge: den legger
-- til en funksjon, ingen flate mister noe.
--
-- `0195` tar granten paa `malekort_stasjoner()` og MAA kjores ETTER at
-- koden er ute - motsatt av husregelen, fordi den fjerner noe den gamle
-- koden bruker. Det staar ogsaa i 0195.
--
-- Idempotent: kun `create or replace`.
-- =====================================================================

create or replace function public.malekort_navn(p_malekort uuid)
returns table(id uuid, navn text, butikknummer text, anonym boolean)
language sql stable security definer set search_path = public as $$
  with kort as (
    select m.retailer_id, m.anonymiser
    from public.malekort m
    where m.id = p_malekort
      and m.slettet_tid is null
      -- TENANTBINDINGEN. Uten den kunne en annen kjedes kort-id sendes
      -- inn, og funksjonen ville svart med den kjedens stasjonsnavn.
      and m.retailer_id = public.gjeldende_retailer_id()
  ),
  skjul as (
    -- Eieren ser alltid navnene. Det er hen som huket av.
    select coalesce((select anonymiser from kort), false)
           and public.gjeldende_rolle() is distinct from 'retailer_admin' as ja
  )
  select s.id,
         case when (select ja from skjul)
                   and s.id not in (select public.mine_stasjoner())
              then null else s.navn end                              as navn,
         case when (select ja from skjul)
                   and s.id not in (select public.mine_stasjoner())
              then null else s.butikknummer end                      as butikknummer,
         ((select ja from skjul)
           and s.id not in (select public.mine_stasjoner()))          as anonym
  from public.stasjoner s
  where s.slettet_tid is null
    and s.retailer_id = (select retailer_id from kort)
  order by s.butikknummer
$$;

comment on function public.malekort_navn(uuid) is
  'Stasjonsnavnene for ETT maalekort, allerede anonymisert etter kortets '
  'anonymiser-flagg og kallerens rolle. Erstatter malekort_stasjoner() paa '
  '/maaling og /vaar-stasjon: den gamle ga navnet paa hver stasjon til hvem '
  'som helst, saa flagget kunne omgaas ved aa joine den med '
  'beregn_malekort_salg over PostgREST.';

grant execute on function public.malekort_navn(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- KVITTERING
-- ---------------------------------------------------------------------
-- `anonyme_rader` teller hva et anonymt kort ville skjult for en
-- butikksjef. Er den 0 mens `anonyme_kort` er over 0, virker ikke
-- anonymiseringen - da skal ikke koden merges.
--
-- Kjores som eier, altsaa som `retailer_admin`-grenen, saa selve
-- funksjonen returnerer navn her. Tallene under leser tabellene direkte.
select
  'kvittering'                                                        as hva,
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'malekort_navn')       as funksjonen_finnes,
  (select count(*) from public.malekort
    where anonymiser and slettet_tid is null)                         as anonyme_kort,
  (select count(*) from public.malekort m
    join public.stasjoner s on s.retailer_id = m.retailer_id
   where m.anonymiser and m.slettet_tid is null and s.slettet_tid is null)
                                                                      as anonyme_rader;
