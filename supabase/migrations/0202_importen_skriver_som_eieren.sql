-- =====================================================================
-- 0202  IMPORTEN SKRIVER SOM EIEREN, IKKE SOM TJENESTEN
-- =====================================================================
-- 0198, 0199 og 0200 sier alle tre den samme setningen:
--
--   «Ingen insert/update/delete-policy. Radene kommer fra importen
--    gjennom tjenestenoekkelen.»
--
-- Den er sann for EN av to importveier, og usann for den Robert bruker.
--
--   src/app/api/epost-inntak/route.ts   lagSupabaseAdminKlient()   tjenestenoekkel
--   src/lib/import/behandle.ts          lagSupabaseServerKlient()  brukerens sesjon
--
-- «Behandle»-knappen kjoerer kjernen med brukerens egen sesjon. Da
-- gjelder RLS, og en tabell uten skrivepolicy avviser. Resultatet 2026-09-12:
--
--   BP26 KELSAR BIL AS.xlsx - Feilet
--   Lagring feilet (batch 1 av 1): new row violates row-level security
--   policy for table "royaltysats"
--
-- Feilen kom paa den FOERSTE av de tre. `bilagssum` og `maanedsplan`
-- ville stoppet de sju regnskapsfilene rett etterpaa, av samme grunn.
--
-- ---------------------------------------------------------------------
-- HVORFOR `retailer_admin` OG IKKE `authenticated`
--
-- Importruta er allerede eierens alene - `behandle.ts` returnerer uten
-- aa gjoere noe for enhver annen rolle. Policyen skal beskrive den
-- doera som finnes, ikke en videre en.
--
-- En `for insert to authenticated` uten rollekrav ville latt en
-- butikksjef POSTe en royaltysats rett paa PostgREST, forbi hele
-- importen. Satsen avgjoer hva hver forbedring er verdt i kroner i hele
-- systemet.
--
-- ---------------------------------------------------------------------
-- DETTE AAPNER IKKE DET 0198 LUKKET
--
-- 0198 argumenterte mot «en sats som kan redigeres i en visning». Den
-- innvendingen staar - og den rammer ikke denne policyen, for eieren kan
-- allerede sette satsen til hva som helst ved aa endre tallet i
-- BP-arket foer opplasting. Doera har vaert der hele tiden.
--
-- Det som holder satsen aerlig er ikke policyen, men `skalLagres()` i
-- `parsere/bp-royalty.ts`: satsene avstemmes mot BP-ens egen «Sum
-- Royalty», og en sats som ikke gaar opp lagres ikke. Den kontrollen
-- kjoerer uansett hvilken noekkel som skriver.
--
-- Policyen holder ALLE ANDRE ute. Det er det en policy kan.
--
-- ---------------------------------------------------------------------
-- FORMEN
--
-- Ingen `for all` - `USING` i en slik policy gjelder ogsaa SELECT og
-- drar skrivepolicyen inn i hver leseplan. Hjelpefunksjonene er pakket i
-- `(select ...)` saa de blir initplan. Hver arm paa oeverste nivaa i
-- `with check` nevner `retailer_id`. Se AGENTS.md.
--
-- Ingen delete-policy noe sted: importen sletter ikke i disse tre. Den
-- skriver over med upsert, og det er `update` som daekker det.
--
-- GRANT VED SIDEN AV POLICY. En policy uten grant avviser fortsatt - de
-- tre tabellene fikk bare `grant select`. `revoke ... from anon` staar
-- med i hver blokk, siden Supabase-standarden
-- `alter default privileges ... grant all on tables to anon` treffer
-- hver ny tabell og kan ha truffet disse paa nytt.
-- =====================================================================

-- ---------------------------------------------------------------------
-- royaltysats - insert + update (importen gjoer upsert paa retailer_id,aar)
-- ---------------------------------------------------------------------
drop policy if exists royaltysats_ny on public.royaltysats;
create policy royaltysats_ny on public.royaltysats
  for insert to authenticated
  with check (retailer_id = (select public.gjeldende_retailer_id())
              and (select public.gjeldende_rolle())::text = 'retailer_admin');

drop policy if exists royaltysats_endre on public.royaltysats;
create policy royaltysats_endre on public.royaltysats
  for update to authenticated
  using (retailer_id = (select public.gjeldende_retailer_id())
         and (select public.gjeldende_rolle())::text = 'retailer_admin')
  with check (retailer_id = (select public.gjeldende_retailer_id())
              and (select public.gjeldende_rolle())::text = 'retailer_admin');

grant insert, update on public.royaltysats to authenticated;
revoke all on public.royaltysats from anon;

-- ---------------------------------------------------------------------
-- bilagssum - insert + update
--
-- Hver maanedsfil baerer tolv maaneder bakover, saa sju filer overlapper
-- med elleve. Upsert paa (retailer_id, butikknummer, periode, konto,
-- tekst) er hele grunnen til at en ny opplasting ikke legger fjoraaret
-- oppaa seg selv - og upserten trenger begge policyene.
-- ---------------------------------------------------------------------
drop policy if exists bilagssum_ny on public.bilagssum;
create policy bilagssum_ny on public.bilagssum
  for insert to authenticated
  with check (retailer_id = (select public.gjeldende_retailer_id())
              and (select public.gjeldende_rolle())::text = 'retailer_admin');

drop policy if exists bilagssum_endre on public.bilagssum;
create policy bilagssum_endre on public.bilagssum
  for update to authenticated
  using (retailer_id = (select public.gjeldende_retailer_id())
         and (select public.gjeldende_rolle())::text = 'retailer_admin')
  with check (retailer_id = (select public.gjeldende_retailer_id())
              and (select public.gjeldende_rolle())::text = 'retailer_admin');

grant insert, update on public.bilagssum to authenticated;
revoke all on public.bilagssum from anon;

-- ---------------------------------------------------------------------
-- maanedsplan - bare insert
--
-- `maanedsplan_slipp` (0200) gir allerede eieren update, og den daekker
-- upsertens oppdateringsarm. Det som manglet var innsettingen av
-- utkastet.
--
-- Selve innholdet er fortsatt laast av triggeren fra 0200, ikke av
-- policyen: er planen sluppet eller sendt, kan den ikke skrives om -
-- uansett hvem som skriver, ogsaa tjenestenoekkelen, som aldri ser en
-- policy.
-- ---------------------------------------------------------------------
drop policy if exists maanedsplan_ny on public.maanedsplan;
create policy maanedsplan_ny on public.maanedsplan
  for insert to authenticated
  with check (retailer_id = (select public.gjeldende_retailer_id())
              and (select public.gjeldende_rolle())::text = 'retailer_admin');

grant insert on public.maanedsplan to authenticated;
revoke all on public.maanedsplan from anon;
