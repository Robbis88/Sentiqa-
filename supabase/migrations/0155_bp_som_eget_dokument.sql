-- =====================================================================
-- BP-EN SOM SITT EGET DOKUMENT
--
-- BP-en lagres allerede: `lagreBp` skriver `bp_omsetning`,
-- `bp_bruttofortjeneste` og `bp_kostnad` til `regnskapslinjer`. Men den
-- hopper over maaneder som er avlagt:
--
--     if (erLaast) continue // regnskapet baerer allerede budsjettet
--
-- Det er RIKTIG for driftsmaalingen. En avlagt maaned baerer sitt eget
-- budsjett, og en senere BP-revisjon skal ikke kunne endre den - Dale ble
-- replanlagt ned uten at januar og februar flyttet seg.
--
-- FOELGEN ER AT ET AVSLUTTET AAR IKKE FINNES SOM BP.
-- BP25 ligger ingen steder som BP25 - bare som det regnskapet endte opp
-- med aa maale mot. En BP-mot-BP-analyse kan derfor ikke lese basen for
-- det eldste aaret.
--
-- Disse to tabellene svarer paa et ANNET spoersmaal enn `bp_*`-linjene:
--
--   regnskapslinjer bp_*   hva maales denne maaneden mot?
--   bp_aar / bp_linje      hva lovet St1 oss for aaret?
--
-- De erstatter ikke hverandre, og maanedslaasen roeres ikke.
--
-- ---------------------------------------------------------------------
-- UROERT AV ALT ETTERPAA
--
-- Ingenting her skal endres av en senere regnskapsimport, en replan
-- eller en maanedslaas. Det er hele poenget: dette er hva fila sa den
-- dagen den kom. Skulle St1 sende en revidert BP for samme aar,
-- overskrives raden - og det er riktig, for da er DET den nye avtalen.
--
-- ---------------------------------------------------------------------
-- INGEN MYK SLETTING
--
-- `slettet_tid` er med vilje utelatt. `0154` maatte rydde 31 tabeller der
-- en SELECT-policy krevde `slettet_tid is null` og dermed blokkerte sin
-- egen myke sletting. Et budsjettdokument har ingen bruksverdi som
-- slettet - det skal enten staa eller erstattes - saa kolonnen ville
-- baaret en felle uten aa loese noe.
--
-- Idempotent: `if not exists` / `drop policy if exists` / vaktet innsett.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. TABELLENE
-- ---------------------------------------------------------------------

create table if not exists public.bp_aar (
  id            uuid primary key default gen_random_uuid(),
  -- `retailer_id` staar her selv om den kan utledes av stasjonen.
  -- RLS trenger et sargbart predikat: `stasjon_id in (mine_stasjoner())`
  -- kan aldri bli initplan, og tabellen leses av hver analysevisning.
  retailer_id   uuid not null references public.retailers(id)  on delete cascade,
  stasjon_id    uuid not null references public.stasjoner(id)  on delete cascade,
  -- Vinduet er vidt med vilje. Sjekken skal fange villskap - 0, negative
  -- tall, 9999 fra en parser paa avveie - ikke gjette hvilke aar en kjede
  -- kan ha BP for. Et smalere vindu ga dessuten tenantmatrisen for faa
  -- verdier aa variere over, og en fixture som kolliderer med seg selv
  -- gir 23505: en domenefeil forkledd som en sikkerhetsavvisning.
  ar            int  not null check (ar between 2000 and 2999),
  -- null = formatet har ikke timebudsjett (St1-malen til og med BP25).
  -- 0 ville betydd "ingen timer", og det er noe helt annet.
  timer_aar     numeric check (timer_aar >= 0),
  format        text not null check (format in ('st1_bp25', 'st1_bp26')),
  kilde_jobb_id uuid references public.import_jobber(id) on delete set null,
  opprettet_tid timestamptz not null default now(),
  oppdatert_tid timestamptz not null default now(),
  unique (stasjon_id, ar),
  -- Baerer den sammensatte fremmednoekkelen fra `bp_linje`. Se der.
  unique (id, retailer_id)
);

create table if not exists public.bp_linje (
  id          uuid primary key default gen_random_uuid(),
  bp_aar_id   uuid not null,
  -- DENORMALISERT, MEN IKKE FRI. `retailer_id` maa staa her for at RLS
  -- skal ha et sargbart predikat - en join til `bp_aar` i hver policy
  -- ville kostet en oppslagsplan per rad.
  --
  -- Men en denormalisert tenantkolonne som kan drive er verre enn ingen:
  -- settes den til en ANNEN kjede enn aargangen tilhoerer, blir raden
  -- synlig for feil tenant. Derfor gaar fremmednoekkelen mot BEGGE
  -- kolonnene, og basen haandhever at de hoerer sammen. Ingen skrivevei
  -- kan skille dem.
  retailer_id uuid not null,
  maned       int  not null check (maned between 1 and 12),
  -- `omsetning` og `varekost` er per varegruppe, `kostnad` per konto.
  -- De tre holdes fra hverandre fordi de har hver sin kodeverden:
  -- "120" er en varegruppe, "5010" er en konto, og de kan kollidere.
  seksjon     text not null check (seksjon in ('omsetning', 'varekost', 'kostnad')),
  kode        text not null,
  post        text not null,
  belop_kr    numeric not null,
  foreign key (bp_aar_id, retailer_id)
    references public.bp_aar (id, retailer_id) on delete cascade,
  unique (bp_aar_id, maned, seksjon, kode)
);

create index if not exists bp_aar_oppslag
  on public.bp_aar (retailer_id, ar);
create index if not exists bp_linje_oppslag
  on public.bp_linje (retailer_id, seksjon);
create index if not exists bp_linje_aargang
  on public.bp_linje (bp_aar_id);

comment on table public.bp_aar is
  'St1s BP slik fila kom, per stasjon og aar. IKKE det samme som '
  'regnskapslinjer bp_* - de hopper over avlagte maaneder med vilje, saa '
  'et avsluttet aar finnes ikke der. Uroert av senere regnskapsimport.';
comment on column public.bp_aar.timer_aar is
  'null = formatet har ikke timebudsjett (St1-malen t.o.m. BP25). '
  'Ikke 0 - det ville betydd ingen timer.';
comment on table public.bp_linje is
  'Budsjettlinjene i BP-en: omsetning og varekost per varegruppe, '
  'kostnad per konto, per maaned. Aar og stasjon staar paa bp_aar - '
  'retailer_id er den eneste denormaliseringen, og den er bundet av '
  'fremmednoekkelen slik at den ikke kan drive.';

-- ---------------------------------------------------------------------
-- 2. RETTIGHETER OG RLS
-- ---------------------------------------------------------------------
-- `anon` er rollen bak den offentlige noekkelen i hver sidelast.

revoke all on public.bp_aar   from anon, authenticated;
revoke all on public.bp_linje from anon, authenticated;

grant select, insert, update, delete on public.bp_aar   to authenticated;
grant select, insert, update, delete on public.bp_linje to authenticated;
grant all on public.bp_aar   to service_role;
grant all on public.bp_linje to service_role;

alter table public.bp_aar   enable row level security;
alter table public.bp_linje enable row level security;

-- EIERENS DATA, som `bemanning_aar`. BP-en baerer royaltysats, fastloenn
-- og kjedens kostnadsramme - det er kjedens oekonomi, ikke stasjonens
-- drift. Butikksjefen ser sin maanedsramme i `bemanning_maned`.
--
-- ALDRI `for all`: `using` i en `for all`-policy gjelder ogsaa SELECT, og
-- permissive policyer OR-es sammen. En skrivepolicy ville da blitt
-- trukket inn i hver leseplan og gjort `retailer_id` ikke-sargbar.
--
-- Hvert funksjonskall er pakket i `(select ...)` saa det evalueres en
-- gang som initplan, ikke per rad.

drop policy if exists bp_aar_les on public.bp_aar;
create policy bp_aar_les on public.bp_aar
  for select to authenticated
  using (retailer_id = (select public.gjeldende_retailer_id())
         and (select public.gjeldende_rolle())::text = 'retailer_admin');

drop policy if exists bp_aar_ny on public.bp_aar;
create policy bp_aar_ny on public.bp_aar
  for insert to authenticated
  with check (retailer_id = (select public.gjeldende_retailer_id())
              and (select public.gjeldende_rolle())::text = 'retailer_admin');

drop policy if exists bp_aar_endre on public.bp_aar;
create policy bp_aar_endre on public.bp_aar
  for update to authenticated
  using (retailer_id = (select public.gjeldende_retailer_id())
         and (select public.gjeldende_rolle())::text = 'retailer_admin')
  -- `retailer_id` staar i BEGGE armer fordi det ikke finnes noen `or` her.
  -- Vakthundens punkt 11 krever at hver arm paa oeverste nivaa nevner
  -- den - en fri stasjonsarm ville latt raden flyttes til en annen kjede
  -- med stasjonen i behold.
  with check (retailer_id = (select public.gjeldende_retailer_id()));

drop policy if exists bp_aar_slett on public.bp_aar;
create policy bp_aar_slett on public.bp_aar
  for delete to authenticated
  using (retailer_id = (select public.gjeldende_retailer_id())
         and (select public.gjeldende_rolle())::text = 'retailer_admin');

drop policy if exists bp_linje_les on public.bp_linje;
create policy bp_linje_les on public.bp_linje
  for select to authenticated
  using (retailer_id = (select public.gjeldende_retailer_id())
         and (select public.gjeldende_rolle())::text = 'retailer_admin');

drop policy if exists bp_linje_ny on public.bp_linje;
create policy bp_linje_ny on public.bp_linje
  for insert to authenticated
  with check (retailer_id = (select public.gjeldende_retailer_id())
              and (select public.gjeldende_rolle())::text = 'retailer_admin');

drop policy if exists bp_linje_endre on public.bp_linje;
create policy bp_linje_endre on public.bp_linje
  for update to authenticated
  using (retailer_id = (select public.gjeldende_retailer_id())
         and (select public.gjeldende_rolle())::text = 'retailer_admin')
  with check (retailer_id = (select public.gjeldende_retailer_id()));

drop policy if exists bp_linje_slett on public.bp_linje;
create policy bp_linje_slett on public.bp_linje
  for delete to authenticated
  using (retailer_id = (select public.gjeldende_retailer_id())
         and (select public.gjeldende_rolle())::text = 'retailer_admin');

-- ---------------------------------------------------------------------
-- 3. HVILKE AARGANGER FINNES?
-- ---------------------------------------------------------------------
-- Sida trenger aa vite hva den kan sammenligne FOER den lover noe. En
-- kjede med bare ett aar skal se ett aar, ikke en tom sammenligning.
--
-- `security_invoker = true` staar i samme setning. Uten den leses viewet
-- som eier, forbi RLS - og `create or replace` uten klausulen nullstiller
-- flagget i stillhet. Vakthundens punkt 9 kaster paa begge deler.

create or replace view public.v_bp_aarganger
with (security_invoker = true) as
select b.retailer_id,
       b.ar,
       min(b.format)                                as format,
       count(*)                                     as stasjoner,
       count(b.timer_aar)                           as stasjoner_med_timer,
       coalesce(sum(b.timer_aar), 0)                as timer_aar,
       max(b.oppdatert_tid)                         as sist_oppdatert
from public.bp_aar b
group by b.retailer_id, b.ar;

comment on view public.v_bp_aarganger is
  'Hvilke BP-aarganger en kjede faktisk har. `stasjoner_med_timer` < '
  '`stasjoner` betyr at formatet mangler timebudsjett - da kan kr/time '
  'ikke leses, og analysen skal la vaere aa love det.';

grant select on public.v_bp_aarganger to authenticated;
revoke all on public.v_bp_aarganger from anon;

-- ---------------------------------------------------------------------
-- 4. KVITTERING
-- ---------------------------------------------------------------------
-- SQL Editor viser ikke `raise notice`, saa svaret maa komme som en rad.
-- `anon_kan_lese` skal vaere 0 paa begge; alt annet er en lekkasje.

select (select count(*) from public.bp_aar)                        as bp_aar_rader,
       (select count(*) from public.bp_linje)                      as bp_linje_rader,
       (select count(*) from pg_policies
        where schemaname = 'public'
          and tablename in ('bp_aar', 'bp_linje'))                 as policyer,
       (select count(*) from information_schema.role_table_grants
        where table_schema = 'public'
          and table_name in ('bp_aar', 'bp_linje', 'v_bp_aarganger')
          and grantee = 'anon')                                    as anon_kan_lese;
