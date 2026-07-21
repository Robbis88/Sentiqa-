-- =====================================================================
-- Sentiqa - 0080_storage_og_lopenr.sql
-- Siste runde av SQL-helsesjekken. Ren ASCII, idempotent.
--
--  1) Unik indeks paa avvik-lopenummer (verifisert 0 duplikater for).
--  2) Storage-policyene: trygg uuid-konvertering + initplan-innpakking.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1) Lopenummer garantert unikt per kjede.
-- Triggeren i 0079 laser allerede per retailer, saa dette er et belte i
-- tillegg til selen: det fanger opp skriving som gaar utenom appen
-- (service-rolle, import, manuell SQL).
--
-- Partiell paa slettet_tid is null: et soft-slettet avvik beholder sitt
-- nummer, men blokkerer ikke. Triggeren bruker max() over ALLE rader, saa
-- nummer gjenbrukes uansett ikke.
--
-- Ikke "concurrently": SQL Editor kjorer fila i en transaksjon, og
-- concurrently er ulovlig der. avvik er en liten tabell, saa den korte
-- laasen er uproblematisk.
-- ---------------------------------------------------------------------
create unique index if not exists avvik_retailer_lopenr_unik
  on public.avvik (retailer_id, lopenr)
  where slettet_tid is null;


-- ---------------------------------------------------------------------
-- 2a) Trygg tekst -> uuid.
-- Storage-policyene caster et fritt sti-segment til uuid. Ligger det et
-- objekt i botten med et segment som ikke er en uuid, feiler castet -
-- og en feil i en policy-kval avbryter HELE spoerringen. Da ville ingen
-- kunne liste botten, ikke bare den ene fila.
--
-- Appen lager alltid gyldige stier, saa dette er ikke en kjent feil i
-- dag. Men en fil lastet opp med service-rolle eller via dashboardet
-- gaar utenom policyen, og da er skaden gjort for alle.
-- ---------------------------------------------------------------------
create or replace function public.som_uuid(p_tekst text)
returns uuid
language plpgsql
immutable
parallel safe
as $$
begin
  return p_tekst::uuid;
exception when others then
  return null;   -- ugyldig segment => ingen tilgang, ikke krasj
end
$$;

grant execute on function public.som_uuid(text) to authenticated;


-- ---------------------------------------------------------------------
-- 2b) rutinebilder: {retailer}/{stasjon}/fil
-- Tilgang folger stasjonen. har_stasjonstilgang() scoper allerede til
-- egen kjede, saa segment [2] alene er nok til tenant-isolasjon - men
-- kallet skjedde per rad. mine_stasjoner() (0077) gir initplan.
-- ---------------------------------------------------------------------
drop policy if exists rutinebilder_storage on storage.objects;
create policy rutinebilder_storage on storage.objects for all to authenticated
  using (
    bucket_id = 'rutinebilder'
    and public.som_uuid((storage.foldername(name))[2]) in (select public.mine_stasjoner())
  )
  with check (
    bucket_id = 'rutinebilder'
    and public.som_uuid((storage.foldername(name))[2]) in (select public.mine_stasjoner())
  );


-- ---------------------------------------------------------------------
-- 2c) raa-filer: {retailer_id}/...  (kun eier)
-- ---------------------------------------------------------------------
drop policy if exists raa_filer_storage_admin on storage.objects;
create policy raa_filer_storage_admin on storage.objects for all to authenticated
  using (
    bucket_id = 'raa-filer'
    and (select public.gjeldende_rolle()) = 'retailer_admin'
    and (storage.foldername(name))[1] = (select public.gjeldende_retailer_id())::text
  )
  with check (
    bucket_id = 'raa-filer'
    and (select public.gjeldende_rolle()) = 'retailer_admin'
    and (storage.foldername(name))[1] = (select public.gjeldende_retailer_id())::text
  );


-- ---------------------------------------------------------------------
-- 2d) fakturaer: {retailer_id}/...  (kun eier)
-- ---------------------------------------------------------------------
drop policy if exists fakturaer_storage_eier on storage.objects;
create policy fakturaer_storage_eier on storage.objects for all to authenticated
  using (
    bucket_id = 'fakturaer'
    and (select public.gjeldende_rolle()) = 'retailer_admin'
    and (storage.foldername(name))[1] = (select public.gjeldende_retailer_id())::text
  )
  with check (
    bucket_id = 'fakturaer'
    and (select public.gjeldende_rolle()) = 'retailer_admin'
    and (storage.foldername(name))[1] = (select public.gjeldende_retailer_id())::text
  );


-- =====================================================================
-- MERK - bevisst IKKE gjort:
--
-- A) rutinebilder_storage er fortsatt "for all", saa en tablet-bruker med
--    stasjonstilgang kan slette bildebevis. For IK-mat/HACCP kan det
--    argumenteres for at bevis ikke skal kunne slettes av den som utforer
--    kontrollen. Det er en driftsbeslutning, ikke en teknisk feil, saa
--    den tas ikke her.
--
-- B) De ~26 gjenstaaende "for all"-policyene paa definisjonstabeller
--    (vaer, merker, lenker, sjekkpunkter, puls_sporsmal ...) er urort.
--    Noen hundre rader hver - per-rad-kall koster ingenting der, og hver
--    policy vi rorer er en sjanse til aa brekke tenant-isolasjonen.
-- =====================================================================
