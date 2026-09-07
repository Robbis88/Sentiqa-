-- ---------------------------------------------------------------------
-- 0179: loennsarter fra easy@work
-- ---------------------------------------------------------------------
-- `stempling` (0088) sier naar noen var paa jobb. Denne sier hva timen
-- KOSTET. Det er to forskjellige sporsmaal, og fram til naa kunne bare
-- det forste besvares uten aa vente paa regnskapet.
--
-- Regnskapsrapporten er fortsatt fasiten, og den skal den vaere. Men den
-- kommer midt i neste maaned. Denne eksporten finnes dagen etter at
-- maaneden er over, og for en stasjon uten fastloennede treffer den
-- regnskapet naer nok til aa vaere verdt aa se paa.
--
-- EN RAD PER LOENNSART PER ANSATT PER DAG. Det er formen eksporten har,
-- og den skal ikke summeres for den lagres: `2 Timeloenn` hoerer til
-- konto 503, `1429`-`1435` til 502, `12 Sykeloenn` til 505. Summerer vi
-- ved innlesing, mister vi nettopp koblingen som gjor tallet
-- sammenlignbart med regnskapet.
create table if not exists public.lonnsart_linje (
  id             uuid primary key default gen_random_uuid(),
  stasjon_id     uuid not null references public.stasjoner(id) on delete cascade,
  ansatt_nr      text not null,
  ansatt_navn    text not null,
  dato           date not null,
  -- Koden alene: '2', '12', '96', '97', '1429' ... Den er det regnskapet
  -- kan kobles paa.
  lonnsart       text not null,
  -- Hele etiketten slik easy@work skrev den, kode og alt:
  -- '97 O.tidstillegg uke 100% son'.
  --
  -- DEN ER NOEKKELEN, IKKE KODEN. Loennsart 97 finnes i fire varianter,
  -- og to av dem kan treffe samme person samme dag - malt paa Dale
  -- august 2026 skjedde det to ganger. En noekkel paa koden alene hadde
  -- gjort 400 rader til 398 og spist 5 273 kroner sondagsovertid i
  -- stillhet. En slik kollisjon gir 23505 og ser ut som en avvisning.
  lonnsart_tekst text not null,
  timer          numeric(10,2) not null check (timer >= 0),
  belop_kr       numeric(12,2) not null,
  kilde_jobb_id  uuid references public.import_jobber(id) on delete set null,
  opprettet_tid  timestamptz not null default now(),
  unique (stasjon_id, ansatt_nr, dato, lonnsart_tekst)
);

create index if not exists lonnsart_linje_stasjon_dato_idx
  on public.lonnsart_linje (stasjon_id, dato);
create index if not exists lonnsart_linje_ansatt_idx
  on public.lonnsart_linje (stasjon_id, ansatt_nr, dato);

comment on table public.lonnsart_linje is
  'Loennsarter med timer og kroner fra easy@work. En rad per loennsart per ansatt per dag.';
comment on column public.lonnsart_linje.lonnsart is
  'Koden alene. 2=timeloenn, 12=sykeloenn, 96=50% overtid, 97=100% overtid, 14xx=tillegg.';
comment on column public.lonnsart_linje.lonnsart_tekst is
  'Hele etiketten. Noekkelen - koden alene kolliderer innen samme dag.';
comment on column public.lonnsart_linje.belop_kr is
  'Kontantloenn for linja. Feriepenger og aga er IKKE med - de paaloper av summen.';

alter table public.lonnsart_linje enable row level security;

-- Samme monster som 0088: aldri "for all", funksjonskall pakket i
-- (select ...) saa de blir initplan, stasjonstilgang via mine_stasjoner().
drop policy if exists lonnsart_linje_les on public.lonnsart_linje;
drop policy if exists lonnsart_linje_ins on public.lonnsart_linje;
drop policy if exists lonnsart_linje_upd on public.lonnsart_linje;
drop policy if exists lonnsart_linje_del on public.lonnsart_linje;

-- LEDERFLATE, IKKE NETTBRETT. Rader med navn, dato og kroner per person
-- er loennsopplysninger. Den delte nettbrettkontoen er ikke en person,
-- og 0101 stengte den ute fra stemplingene av mindre enn dette.
create policy lonnsart_linje_les on public.lonnsart_linje
  for select to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));

create policy lonnsart_linje_ins on public.lonnsart_linje
  for insert to authenticated
  with check (stasjon_id in (select public.mine_stasjoner())
              and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));

create policy lonnsart_linje_upd on public.lonnsart_linje
  for update to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'))
  with check (stasjon_id in (select public.mine_stasjoner())
              and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));

create policy lonnsart_linje_del on public.lonnsart_linje
  for delete to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) = 'retailer_admin');

grant select, insert, update, delete on public.lonnsart_linje to authenticated;
-- Standardrettighetene i schema public treffer hver ny tabell, og anon er
-- rollen bak den offentlige noekkelen i hver sidelast (0134).
revoke all on public.lonnsart_linje from anon;

-- Rapporttypen maa finnes for at importjobben skal kunne merkes.
alter type public.rapporttype add value if not exists 'easyatwork_lonnsart';

-- Kvittering.
select
  (select count(*) from pg_policies
    where schemaname = 'public' and tablename = 'lonnsart_linje')            as policyer,
  (select count(*) from information_schema.role_table_grants
    where table_schema = 'public' and table_name = 'lonnsart_linje'
      and grantee = 'anon')                                                  as anon,
  (select count(*) from pg_enum e join pg_type t on t.oid = e.enumtypid
    where t.typname = 'rapporttype' and e.enumlabel = 'easyatwork_lonnsart') as rapporttype;
