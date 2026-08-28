-- =====================================================================
-- 0149 - startparti og margin paa produksjonsplanen
--
-- PRODUKTBESLUTNING, tatt 2026-08-28 (Robert):
--
--   STARTPARTI SOM PROSENT. En nattaapen stasjon vil ha en fast andel
--   ferdig naar doera aapner. I dag settes `start_antall` med en
--   pluss-knapp per produkt - tretti produkter er tretti klatringer,
--   hver dag. Prosenten setter utgangspunktet; + og - virker som foer.
--
--   MARGIN OVER FORSLAGET. `foreslatt` treffer forventet SALG, og
--   halvparten av dagene ligger over. Utsolgt koster ingenting i noe
--   tall vi maaler, saa motoren har en innebygd skjevhet mot aa lage
--   for lite. Marginen er motvekten.
--
-- NIVAA: stasjonen setter standarden, varegruppa kan avvike.
-- `null` paa varegruppa betyr ARV, ikke null prosent. Skal varmmat
-- faktisk ha null start, settes den til 0 - og da vinner den.
--
-- ---------------------------------------------------------------------
-- DET VIKTIGSTE FORBEHOLDET
--
-- MARGINEN LEGGES PAA `planlagt`, ALDRI PAA `foreslatt`.
--
-- Backtesten regner `foreslatt` paa nytt fra historikk og maaler mot
-- `v_butikksalg`; den leser aldri `planlagt`. Blandes de to, ser
-- modellen ut til aa overvurdere salget systematisk - og den selvlaerte
-- kalibreringen ville «rettet» den feilen ved aa foreslaa mindre.
--
-- OG: MARGINEN SKAL ALDRI UTLEDES AV MAALT SVINN. Regelen fra
-- 2026-08-24 staar: planen justerer seg mot salg, aldri mot svinn,
-- fordi svinn bare har ett fortegn. Blir marginen satt automatisk fra
-- svinntallet, lukker sloeyfa seg likevel - bare gjennom en annen doer:
-- mindre margin -> mindre svinn -> «marginen kan settes ned».
-- Derfor er dette to tall et MENNESKE setter.
-- `src/lib/produksjonsplan.grense.test.ts` vokter det.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1) En tabell, to nivaaer
--
-- `varegruppe_kode = '*'` ER STASJONENS STANDARD. Samme konvensjon som
-- `prognose_treff.kategori`, der '*' betyr total.
--
-- FORSTE UTKAST LA STANDARDEN SOM TO KOLONNER PAA `stasjoner`. Det gikk
-- ikke: `stasjoner_admin_skriv` (0001) gir bare `retailer_admin`
-- skriverett, saa BUTIKKSJEFEN KUNNE IKKE SATT SIN EGEN STASJONS
-- STANDARD - og det var nettopp det hun skulle kunne. Med begge nivaaer
-- her gjelder én policy for begge, og hun naar begge.
--
-- Egen tabell framfor kolonner er dessuten riktig for gruppene uansett:
-- varegruppene er data, ikke et fast sett. En kolonne per gruppe ville
-- betydd en migrasjon hver gang St1 oppretter en.
-- ---------------------------------------------------------------------
create table if not exists public.stasjon_produksjon_innstilling (
  id              uuid primary key default gen_random_uuid(),
  retailer_id     uuid not null references public.retailers(id) on delete restrict,
  stasjon_id      uuid not null references public.stasjoner(id) on delete cascade,
  -- '*' = stasjonens standard. Ellers en varegruppekode.
  varegruppe_kode text not null,
  -- null = arv fra standarden. 0 = faktisk null prosent, og vinner.
  start_prosent   int,
  margin_prosent  int,
  oppdatert_tid   timestamptz not null default now(),
  unique (stasjon_id, varegruppe_kode),
  check (start_prosent  is null or start_prosent  between 0 and 99),
  check (margin_prosent is null or margin_prosent between 0 and 100)
);

create index if not exists stasjon_produksjon_innstilling_stasjon_idx
  on public.stasjon_produksjon_innstilling (stasjon_id);

comment on table public.stasjon_produksjon_innstilling is
  'Start- og marginprosent for produksjonsplanen. varegruppe_kode = ''*'' '
  'er stasjonens standard; en varegruppekode er et avvik fra den. null i '
  'en kolonne betyr ARV fra standarden, 0 betyr null prosent og vinner. '
  'Begge nivaaer ligger her fordi stasjoner bare kan skrives av '
  'retailer_admin - butikksjefen ville ikke naadd sin egen standard. '
  'Se 0149.';


-- ---------------------------------------------------------------------
-- 2) RLS
--
-- Splittet per operasjon, aldri `for all`: USING i en for all-policy
-- gjelder ogsaa SELECT, og permissive policyer OR-es sammen - saa en
-- skrivepolicy trekkes inn i hver leseplan og gjoer retailer_id
-- ikke-sargbar.
--
-- `stasjon_id in (select public.mine_stasjoner())` og ikke
-- `har_stasjonstilgang(stasjon_id)`: den siste tar en kolonne som
-- argument og kan derfor aldri bli initplan - den evalueres per rad.
--
-- Hver arm i `with check` nevner retailer_id. Aa nevne tenantkolonnen i
-- bare den ene armen av et `or` er ikke aa binde den (se 0141), og
-- punkt 11 i vakthunden kaster paa det.
--
-- SKRIVING ER LEDERENS. Nettbrettet har ingen grunn til aa endre
-- driftsregler - det utfoerer planen, det administrerer den ikke.
-- Samme skille som 0136 satte paa hode og linjer.
-- ---------------------------------------------------------------------
alter table public.stasjon_produksjon_innstilling enable row level security;

drop policy if exists stasjon_produksjon_innstilling_les on public.stasjon_produksjon_innstilling;
create policy stasjon_produksjon_innstilling_les on public.stasjon_produksjon_innstilling
  for select to authenticated
  using (stasjon_id in (select public.mine_stasjoner()));

drop policy if exists stasjon_produksjon_innstilling_ins on public.stasjon_produksjon_innstilling;
create policy stasjon_produksjon_innstilling_ins on public.stasjon_produksjon_innstilling
  for insert to authenticated
  with check (stasjon_id in (select public.mine_stasjoner())
              and retailer_id = (select public.gjeldende_retailer_id())
              and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));

drop policy if exists stasjon_produksjon_innstilling_upd on public.stasjon_produksjon_innstilling;
create policy stasjon_produksjon_innstilling_upd on public.stasjon_produksjon_innstilling
  for update to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'))
  with check (stasjon_id in (select public.mine_stasjoner())
              and retailer_id = (select public.gjeldende_retailer_id())
              and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));

drop policy if exists stasjon_produksjon_innstilling_del on public.stasjon_produksjon_innstilling;
create policy stasjon_produksjon_innstilling_del on public.stasjon_produksjon_innstilling
  for delete to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));

comment on policy stasjon_produksjon_innstilling_les on public.stasjon_produksjon_innstilling is
  'Nettbrettet leser dem ikke selv - prosentene er alt regnet inn i '
  'planlagt og start_antall naar linja lages. Lesetilgangen foelger '
  'stasjonen fordi lederflaten trenger den. Se 0149.';


-- ---------------------------------------------------------------------
-- 3) Rettigheter
--
-- `anon` er rollen bak den offentlige noekkelen i hver sidelast, og
-- Supabase-standarden `alter default privileges ... grant all on tables
-- to anon` treffer hver ny tabell. Uten dette revoke-et ville RLS vaert
-- eneste lag. Se 0134 og punkt 10 i vakthunden.
-- ---------------------------------------------------------------------
revoke all on public.stasjon_produksjon_innstilling from anon;
grant select, insert, update, delete on public.stasjon_produksjon_innstilling to authenticated;


-- ---------------------------------------------------------------------
-- ETTER DENNE: kjor supabase/tests/rls_vakthund.sql.
-- Tabellen er lagt inn i `kalde`-arrayet der - den skrives noen faa
-- ganger i aaret, ikke per transaksjon.
--
-- BEVISET SOM SKAL FORELIGGE (matrisen dekker det):
--
--   butikksjef leser/skriver egen stasjons innstilling      ok
--   eier det samme paa hele kjeden                          ok
--   tablet INSERT / UPDATE / DELETE                         42501
--   tablet SELECT egen stasjon                              ok (ufarlig)
--   annen kjede naar den ikke                               42501 / 0 rader
--   raden kan ikke flyttes til annen kjede                  42501
-- ---------------------------------------------------------------------
