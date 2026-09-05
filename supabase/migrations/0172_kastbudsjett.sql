-- =====================================================================
-- KASTBUDSJETTET FRA DELINGSFILA
--
-- St1 setter et kastbudsjett per UNDERGRUPPE, og undergruppene er
-- vareomraadene under avdeling 120 MAT. Tallene har ligget i delingsfila
-- hele tiden - parseren leste bare «Timer»-arket og sa det rett ut:
-- «Fila har elleve ark til ... De leses ikke her.»
--
-- Maalt mot Kelsars fil 2026-09-05, Laguneparken:
--
--     10 BAKERI      12,19 %    119 577
--     11 POELSE       5,77 %     83 663
--     12 HAMBURGER    6,12 %     38 857
--     13 PIZZA        8,56 %      2 433
--     14 OPPVARMET    7,22 %     12 256
--     15 PAASMURT    10,14 %    119 290
--                              --------
--                               376 076
--
-- Det er paa krona det Mat-arket oppgir som total. Undergruppene ER
-- totalen.
--
-- ---------------------------------------------------------------------
-- TO NIVAAER, FORDI ST1 SENDER TO VARIANTER
--
-- Maalt paa Kelsars egne filer 2026-09-05:
--
--   2025-fila   Timer + 10 undergruppeark   TRE stasjoner   ingen usynlig
--   2026-fila   Mat + Vask, ingen Timer     FEM stasjoner   MED usynlig
--
-- Innevaerende aar har altsaa BARE totalen. Et skjema som krevde
-- undergrupper ville avvist aaret vi faktisk driver i.
--
-- Derfor `nivaa`: `avdeling` for Mat-totalen (kode 120), `vareomrade`
-- for de seks delene. **De summeres ALDRI paa tvers.** Finnes begge for
-- samme aar, er vareomraadene de gjeldende - de er finere, og de
-- summerer til totalen uansett.
--
-- ---------------------------------------------------------------------
-- PROSENTEN ER KOST DELT PAA OMSETNING
--
-- St1 regner kastede kroner (kostpris) delt paa SALG. Sentiqas
-- `/svinn` regner kost mot kost, innfoert fordi den gamle blandingen ga
-- et tall som ikke betydde noe.
--
-- DE TO PROSENTENE ER ULIKE TALL og vil aldri stemme overens. Kolonnen
-- heter derfor `kast_pst_av_salg`, ikke `kast_pst`. Et navn som ikke
-- sier hvilken broek det er, ville invitert til nettopp den
-- sammenligningen.
--
-- ---------------------------------------------------------------------
-- ET AAR, EN STASJON, ETT NIVAA, EN KODE
--
-- `unique (stasjon_id, ar, nivaa, kode)`. Kommer en ny delingsfil
-- for samme aar, er det en RETTELSE - St1 sender reviderte filer - og da
-- skal raden overskrives, ikke legges ved siden av. Upserten i importen
-- gjoer det.
--
-- Idempotent: `if not exists` / `drop policy if exists`.
-- =====================================================================

create table if not exists public.kastbudsjett (
  id              uuid primary key default gen_random_uuid(),
  -- `retailer_id` staar her selv om den kan utledes av stasjonen: RLS
  -- trenger et sargbart predikat, og `stasjon_id in (mine_stasjoner())`
  -- kan aldri bli initplan.
  retailer_id     uuid not null references public.retailers(id) on delete cascade,
  stasjon_id      uuid not null references public.stasjoner(id) on delete cascade,
  ar              int  not null check (ar between 2000 and 2999),
  -- `avdeling` = Mat-totalen (kode 120). `vareomrade` = en av de seks
  -- delene under den. Aldri summert paa tvers - se toppen.
  nivaa           text not null check (nivaa in ('avdeling', 'vareomrade')),
  -- `120` for totalen, ellers vareomraadet slik det staar i salgsdataene:
  -- `10` = BAKERI, `11` = POELSE, `15` = PAASMURT.
  kode            text not null,
  navn            text,
  -- Andel av OMSETNING, ikke av varekost. Se toppen.
  kast_pst_av_salg numeric not null check (kast_pst_av_salg > 0 and kast_pst_av_salg < 1),
  -- St1s egen utregning. Lagres selv om den kan regnes ut, fordi det er
  -- TALLET DE SATTE - og en avrunding hos oss ville gjort budsjettet til
  -- noe annet enn det som staar i fila.
  kast_budsjett_kr numeric not null check (kast_budsjett_kr > 0),
  -- Salget prosenten er regnet av. Uten den kan ingen ettergaa tallet.
  historisk_salg_kr numeric,
  -- USYNLIG SVINN har sitt EGET budsjett, og bare den nyeste filvarianten
  -- oppgir det. Null betyr «ikke oppgitt», ikke «null kroner» - forskjellen
  -- er hele grunnen til at kolonnen er nullbar og ikke default 0.
  --
  -- Det staar bare paa avdelingsnivaa: usynlig svinn kan per definisjon
  -- ikke fordeles paa undergruppe, siden ingen vet hvor det ble av.
  usynlig_budsjett_kr numeric check (usynlig_budsjett_kr >= 0),
  kilde_jobb_id   uuid references public.import_jobber(id) on delete set null,
  opprettet_tid   timestamptz not null default now(),
  oppdatert_tid   timestamptz not null default now(),
  unique (stasjon_id, ar, nivaa, kode)
);

create index if not exists kastbudsjett_oppslag
  on public.kastbudsjett (retailer_id, ar);

comment on table public.kastbudsjett is
  'St1s kastbudsjett per stasjon, aar og vareomraade, fra delingsfila. '
  'kast_pst_av_salg er KOST DELT PAA OMSETNING - en annen broek enn '
  'svinnprosenten paa /svinn, som er kost mot kost. De skal ikke '
  'sammenlignes.';

-- ---------------------------------------------------------------------
-- RETTIGHETER
--
-- `revoke ... from anon` er ikke overfloedig: Supabase-standarden gir
-- hver ny tabell et anon-grant av seg selv. Se `0134`.
-- ---------------------------------------------------------------------
revoke all on public.kastbudsjett from anon, authenticated;
grant select on public.kastbudsjett to authenticated;
grant all    on public.kastbudsjett to service_role;

alter table public.kastbudsjett enable row level security;

-- BUTIKKSJEFEN SKAL SE SITT EGET KRAV. Det er hele poenget: et budsjett
-- ingen kjenner styrer ingenting. Derfor stasjonsscope og ikke eier-bare,
-- til forskjell fra `bp_aar`, som baerer royalty og kjedens oekonomi.
--
-- Ingen skrivepolicy. Budsjettet kommer fra fila; en rad noen kan endre
-- i etterkant er ikke lenger St1s krav. Importen skriver som service_role.
--
-- ALDRI `for all`: `using` i en `for all`-policy gjelder ogsaa SELECT.
drop policy if exists kastbudsjett_les on public.kastbudsjett;
create policy kastbudsjett_les on public.kastbudsjett
  for select to authenticated
  using (stasjon_id in (select public.mine_stasjoner()));

-- ---------------------------------------------------------------------
-- DEKNINGEN MAA KJENNE DEN
--
-- `onboarding.test.ts` krever at hver kilde i `KILDER` kan MAALES av
-- `v_datadekning`. En kilde uten arm her ville staatt evig som «ikke
-- lastet opp», ogsaa etter at fila var inne - og en liste som lyver om
-- hva som mangler er verre enn ingen liste.
--
-- Hele viewet gjentas fordi `create or replace` ikke kan legge til en
-- arm. Armene er identiske med `0163`, pluss den siste.
--
-- `security_invoker` staar her selv om viewet alt hadde den:
-- `create or replace view` uten klausulen NULLSTILLER flagget i
-- stillhet, og da leser viewet som eieren, forbi RLS. Punkt 9 i
-- vakthunden kaster paa nettopp det.
-- ---------------------------------------------------------------------
create or replace view public.v_datadekning
with (security_invoker = true) as
  select 'st1_salgsstatistikk'::text as kilde,
         stasjon_id,
         count(distinct dato)        as dager,
         max(dato)::text             as siste_dato
  from public.v_butikksalg
  where dato is not null
  group by stasjon_id

  union all
  select 'timesalg', stasjon_id, count(distinct dato), max(dato)::text
  from public.timesalg
  where slettet_tid is null and dato is not null
  group by stasjon_id

  union all
  select 'stempling', stasjon_id, count(distinct dato), max(dato)::text
  from public.stempling
  where dato is not null
  group by stasjon_id

  union all
  select 'bemanning_maned', stasjon_id, count(*), max(ar)::text
  from public.bemanning_maned
  group by stasjon_id

  union all
  select 'regnskapslinjer', stasjon_id, count(distinct periode), max(periode)::text
  from public.regnskapslinjer
  where stasjon_id is not null and periode is not null
  group by stasjon_id

  union all
  select 'kassererstatistikk', stasjon_id, count(distinct dato), max(dato)::text
  from public.kassererstatistikk
  where slettet_tid is null and dato is not null
  group by stasjon_id

  union all
  select 'svinn', stasjon_id, count(distinct dato), max(dato)::text
  from public.synlig_svinn
  where slettet_tid is null and dato is not null
  group by stasjon_id

  -- NY I 0163: baerer aargangen timer, uansett hvilken fil de kom med.
  union all
  select 'bp_timer',
         stasjon_id,
         count(*) filter (where timer_aar is not null),
         max(ar) filter (where timer_aar is not null)::text
  from public.bp_aar
  group by stasjon_id
  having count(*) filter (where timer_aar is not null) > 0

  -- NY I 0172: kastbudsjettet fra delingsfila.
  union all
  select 'kastbudsjett',
         stasjon_id,
         count(*),
         max(ar)::text
  from public.kastbudsjett
  group by stasjon_id;

comment on view public.v_datadekning is
  'Hvor mye data hver kilde har, per stasjon. Mater "hva mangler"-listen '
  'paa importsiden. Skal kjenne hver rapporttype systemet tar imot - se '
  'TYPE_TIL_KILDE i src/lib/onboarding.ts.';

grant select on public.v_datadekning to authenticated;
revoke all on public.v_datadekning from anon;
