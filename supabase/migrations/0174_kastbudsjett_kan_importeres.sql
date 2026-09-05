-- =====================================================================
-- IMPORTEN SKRIVER SOM BRUKEREN, IKKE SOM service_role
--
-- `0172` ga `kastbudsjett` bare `grant select ... to authenticated` og
-- ingen skrivepolicy, med denne begrunnelsen:
--
--     «Ingen skrivepolicy. Budsjettet kommer fra fila; en rad noen kan
--      endre er ikke lenger St1s krav. Importen skriver som service_role.»
--
-- Den siste setningen er FEIL, og den sto ogsaa i tenant-kontrakten.
-- `behandleJobb` i `src/lib/import/behandle.ts` kjoerer
-- `lagSupabaseServerKlient()` - brukerens egen sesjon, altsaa rollen
-- `authenticated` - og begrenser seg selv til `retailer_admin` i koden.
-- Ingen importvei i systemet bruker service_role.
--
-- Resultatet var at delingsfila stoppet med
--
--     Delingsfil: kunne ikke skrive kastbudsjett:
--     permission denied for table kastbudsjett
--
-- ---------------------------------------------------------------------
-- SPEILBILDET AV `0146`
--
-- `0146` handlet om et GRANT UTEN POLICY - en doer som staar paa gloett
-- fordi Supabase' default privileges ga rettigheten av seg selv.
--
-- Dette er den motsatte: en POLICY UTEN GRANT, en doer som er laast fra
-- innsiden. Begge kommer av at rettighet og policy er to lag, og at det
-- ene laget alene verken aapner eller stenger.
--
-- Feilen de gir er dessuten ulik, og det er verdt aa kjenne igjen:
-- mangler GRANTET, sier Postgres `permission denied for table` (42501)
-- foer policyen i det hele tatt vurderes. Mangler POLICYEN, kommer
-- `new row violates row-level security policy`. Den foerste peker paa
-- grants, den andre paa predikatet.
--
-- ---------------------------------------------------------------------
-- HVA SOM FAKTISK TRENGS, OG IKKE MER
--
-- `lagreKastbudsjett` gjoer ÉN ting: `upsert` med `onConflict` paa
-- (stasjon_id, ar, nivaa, kode). Det krever `insert` og `update`.
--
-- INGEN `delete`. Ingen kodevei sletter en kastbudsjettrad - en revidert
-- fil fra St1 er en RETTELSE og treffer samme rad gjennom upserten.
-- Et delete-grant ville vaert en evne uten en bruker.
--
-- Og fortsatt ingen skriverett for butikksjefen. Begrunnelsen i `0172`
-- staar: en rad noen kan endre i etterkant er ikke lenger St1s krav.
-- Butikksjefen SER sitt eget krav (`0173`), og det er hele poenget.
--
-- ---------------------------------------------------------------------
-- Idempotent: `grant` er additivt og taaler gjentakelse,
-- `drop policy if exists` foer `create policy`.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. RETTIGHETEN
-- ---------------------------------------------------------------------
--
-- `revoke ... from anon` gjentas her med vilje. Supabase' default
-- privileges treffer hver ny tabell, og en re-kjoering av settet fra
-- `0001` kan komme til aa gi anon rettigheter paa nytt. Se `0134`.
revoke all on public.kastbudsjett from anon;
grant insert, update on public.kastbudsjett to authenticated;

-- ---------------------------------------------------------------------
-- 2. POLICYENE
-- ---------------------------------------------------------------------
--
-- ALDRI `for all`: `using` i en `for all`-policy gjelder ogsaa SELECT,
-- og permissive policyer OR-es sammen - da ville skrivepolicyen blitt
-- trukket inn i hver leseplan og gjort `retailer_id` ikke-sargbar.
--
-- Alle funksjonskall er pakket i `(select ...)` saa de evalueres én gang
-- som initplan. `gjeldende_rolle()` og `gjeldende_retailer_id()` er
-- security definer og kan ikke inlines; uten pakkingen kjoeres de per
-- rad, og tabellen vokser med hver aargang og hver stasjon.

drop policy if exists kastbudsjett_ny on public.kastbudsjett;
create policy kastbudsjett_ny on public.kastbudsjett
  for insert to authenticated
  -- HVER ARM PAA OEVERSTE NIVAA NEVNER `retailer_id`, og her finnes det
  -- ingen `or` - kravet fra vakthundens punkt 11 er dermed trivielt
  -- oppfylt. Stasjonsleddet staar likevel: uten det kunne en eier skrevet
  -- en rad paa en stasjon i egen kjede som ikke er hens.
  with check (
    retailer_id = (select public.gjeldende_retailer_id())
    and stasjon_id in (select public.mine_stasjoner())
    and (select public.gjeldende_rolle())::text = 'retailer_admin'
  );

drop policy if exists kastbudsjett_endre on public.kastbudsjett;
create policy kastbudsjett_endre on public.kastbudsjett
  for update to authenticated
  using (
    retailer_id = (select public.gjeldende_retailer_id())
    and stasjon_id in (select public.mine_stasjoner())
    and (select public.gjeldende_rolle())::text = 'retailer_admin'
  )
  -- `with check` maa gjentas: `using` avgjoer hvilke rader som kan
  -- endres, `with check` hva de kan endres TIL. Uten den kunne raden
  -- flyttes til en annen kjede med stasjonen i behold - formen `0141`
  -- fant paa `uke_rapport`.
  with check (
    retailer_id = (select public.gjeldende_retailer_id())
    and stasjon_id in (select public.mine_stasjoner())
  );

-- ---------------------------------------------------------------------
-- 3. KVITTERING
-- ---------------------------------------------------------------------
--
-- `raise notice` vises ikke i Supabase SQL Editor - se `0145`. Derfor en
-- vanlig `select` som svarer paa begge lagene: rettigheten OG policyen.
select
  (select count(*) from information_schema.role_table_grants
    where table_schema = 'public' and table_name = 'kastbudsjett'
      and grantee = 'authenticated'
      and privilege_type in ('INSERT', 'UPDATE'))            as skrivegrants,
  (select count(*) from pg_policies
    where schemaname = 'public' and tablename = 'kastbudsjett'
      and policyname in ('kastbudsjett_ny', 'kastbudsjett_endre')) as skrivepolicyer,
  (select count(*) from information_schema.role_table_grants
    where table_schema = 'public' and table_name = 'kastbudsjett'
      and grantee = 'anon')                                  as anon_skal_vaere_0;
