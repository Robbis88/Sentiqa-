-- ---------------------------------------------------------------------
-- 0098: arbeidsavtaler
-- ---------------------------------------------------------------------
-- Malene er Virkes, juridisk gjennomgatt. De lagres som de er i Storage
-- og fylles ut ved generering - vi skriver dem ikke om. Ordlyden er
-- poenget med aa bruke dem.
--
-- Tre valg avgjor hvilken mal som gjelder:
--   ansettelsesform  fast | midlertidig | tilkalling
--   rolle            ansatt | ass_butikksjef | butikksjef
--   mindreaarig      folger av fodselsdato, ikke av et sporsmaal
--
-- Tariffbundet er en egenskap ved kjeden, ikke ved personen, saa den
-- ligger paa retailers og velges ikke per kontrakt.

alter table public.retailers
  add column if not exists tariffbundet boolean not null default true,
  -- Feltene som er like i hver eneste kontrakt: firmanavn, orgnr,
  -- forretningsadresse, lonningsdato, provetid. Jsonb fordi malene kan
  -- ha ulike felt, og en kolonne per felt ville blitt en migrasjon hver
  -- gang Virke endrer en setning.
  add column if not exists kontrakt_standardfelt jsonb not null default '{}'::jsonb;

-- Feltene malene trenger og som ikke fantes noe sted fra for.
alter table public.stasjoner
  add column if not exists adresse text;

alter table public.ansatt_avtale
  add column if not exists fodselsdato date,
  add column if not exists stillingstittel text;

comment on column public.stasjoner.adresse is
  'Arbeidsstedets adresse. Staar i arbeidsavtalen.';
comment on column public.ansatt_avtale.fodselsdato is
  'Full fodselsdato - arbeidsavtalen krever den. Avgjor ogsaa om '
  'u18-reglene gjelder i vaktplanen.';

comment on column public.retailers.kontrakt_standardfelt is
  'Felt som er like i alle kontrakter: arbeidsgivernavn, orgnr, adresse, '
  'lonningsdato, provetid. Fylles inn en gang.';

-- ---------------------------------------------------------------------
create table if not exists public.kontraktmal (
  id               uuid primary key default gen_random_uuid(),
  retailer_id      uuid not null references public.retailers(id) on delete cascade,
  ansettelsesform  text not null check (ansettelsesform in ('fast', 'midlertidig', 'tilkalling')),
  rolle            text not null default 'ansatt'
                   check (rolle in ('ansatt', 'ass_butikksjef', 'butikksjef')),
  mindreaarig      boolean not null default false,
  tariffbundet     boolean not null default true,
  filnavn          text not null,
  storage_sti      text not null,
  -- Versjonen er poenget med hele tabellen. Du maa kunne vise noeyaktig
  -- hvilken tekst hun signerte, ikke bare at hun signerte noe.
  versjon          int  not null default 1,
  aktiv            boolean not null default true,
  opprettet_tid    timestamptz not null default now(),
  unique (retailer_id, ansettelsesform, rolle, mindreaarig, tariffbundet, versjon)
);

create index if not exists kontraktmal_retailer_idx
  on public.kontraktmal (retailer_id, aktiv);

comment on table public.kontraktmal is
  'Virkes .docx-maler. Lagres urort; felt fylles ut ved generering.';

-- ---------------------------------------------------------------------
create table if not exists public.ansatt_kontrakt (
  id             uuid primary key default gen_random_uuid(),
  stasjon_id     uuid not null references public.stasjoner(id) on delete cascade,
  ansatt_nr      text not null,
  ansatt_navn    text not null,
  mal_id         uuid references public.kontraktmal(id) on delete set null,
  mal_versjon    int,
  -- Verdiene som ble fylt inn. Uten dem kan ikke dokumentet gjenskapes,
  -- og da er versjonsnummeret alene verdilost.
  verdier        jsonb not null default '{}'::jsonb,
  storage_sti    text,
  gjelder_fra    date,
  gjelder_til    date,
  status         text not null default 'utkast'
                 check (status in ('utkast', 'sendt', 'signert', 'erstattet')),
  signert_tid    timestamptz,
  signert_metode text check (signert_metode in ('bekreftelse', 'bankid')),
  opprettet_av   uuid references auth.users(id) on delete set null,
  opprettet_tid  timestamptz not null default now()
);

create index if not exists ansatt_kontrakt_ansatt_idx
  on public.ansatt_kontrakt (stasjon_id, ansatt_nr);

comment on table public.ansatt_kontrakt is
  'Genererte arbeidsavtaler. verdier + mal_versjon gjor at dokumentet '
  'kan gjenskapes noeyaktig slik det var da det ble signert.';

-- ---------------------------------------------------------------------
-- RLS - samme monster som ellers: aldri "for all", funksjonskall pakket
-- i (select ...), stasjonstilgang via mine_stasjoner().
-- ---------------------------------------------------------------------
alter table public.kontraktmal      enable row level security;
alter table public.ansatt_kontrakt  enable row level security;

drop policy if exists kontraktmal_les on public.kontraktmal;
drop policy if exists kontraktmal_ins on public.kontraktmal;
drop policy if exists kontraktmal_upd on public.kontraktmal;
drop policy if exists kontraktmal_del on public.kontraktmal;

-- Malene er felles for kjeden, ikke per stasjon.
create policy kontraktmal_les on public.kontraktmal
  for select to authenticated
  using (retailer_id = (select public.gjeldende_retailer_id()));
create policy kontraktmal_ins on public.kontraktmal
  for insert to authenticated
  with check (retailer_id = (select public.gjeldende_retailer_id())
              and (select public.gjeldende_rolle()) = 'retailer_admin');
create policy kontraktmal_upd on public.kontraktmal
  for update to authenticated
  using (retailer_id = (select public.gjeldende_retailer_id())
         and (select public.gjeldende_rolle()) = 'retailer_admin')
  with check (retailer_id = (select public.gjeldende_retailer_id())
              and (select public.gjeldende_rolle()) = 'retailer_admin');
create policy kontraktmal_del on public.kontraktmal
  for delete to authenticated
  using (retailer_id = (select public.gjeldende_retailer_id())
         and (select public.gjeldende_rolle()) = 'retailer_admin');

drop policy if exists ansatt_kontrakt_les on public.ansatt_kontrakt;
drop policy if exists ansatt_kontrakt_ins on public.ansatt_kontrakt;
drop policy if exists ansatt_kontrakt_upd on public.ansatt_kontrakt;
drop policy if exists ansatt_kontrakt_del on public.ansatt_kontrakt;

create policy ansatt_kontrakt_les on public.ansatt_kontrakt
  for select to authenticated
  using (stasjon_id in (select public.mine_stasjoner()));
create policy ansatt_kontrakt_ins on public.ansatt_kontrakt
  for insert to authenticated
  with check (stasjon_id in (select public.mine_stasjoner())
              and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));
create policy ansatt_kontrakt_upd on public.ansatt_kontrakt
  for update to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'))
  with check (stasjon_id in (select public.mine_stasjoner())
              and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));
-- En signert kontrakt slettes ikke. Den erstattes, og da staar begge.
create policy ansatt_kontrakt_del on public.ansatt_kontrakt
  for delete to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) = 'retailer_admin'
         and signert_tid is null);

grant select, insert, update, delete on public.kontraktmal     to authenticated;
grant select, insert, update, delete on public.ansatt_kontrakt to authenticated;

-- ---------------------------------------------------------------------
-- Storage: butikksjefen maa faa LESE malfila
-- ---------------------------------------------------------------------
-- raa-filer er eiers bucket (0080), og det skal den fortsatt vaere - der
-- ligger salgsrapporter og lonnsgrunnlag. Men malen er ikke data, den er
-- et skjema, og butikksjefen er nettopp den som skriver kontraktene.
-- Uten leserett faar hun «Fant ikke malfila» og ingen forklaring.
--
-- Derfor en smal SELECT-policy, ikke en utvidelse av eierpolicyen:
-- bare kontraktmal-mappa, bare i egen kjede. Permissive policyer OR-es
-- sammen, saa dette apner kun det ene prefikset.
--
-- Segmentene sammenlignes som tekst, aldri ved aa caste stien til uuid -
-- en fil med et ikke-uuid forste segment ville da felt HELE spoerringen
-- for alle (se 0080).
drop policy if exists kontraktmal_storage_les on storage.objects;
create policy kontraktmal_storage_les on storage.objects
  for select to authenticated
  using (
    bucket_id = 'raa-filer'
    and (storage.foldername(name))[1] = (select public.gjeldende_retailer_id())::text
    and (storage.foldername(name))[2] = 'kontraktmal'
    and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef')
  );
