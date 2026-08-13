-- =====================================================================
-- Sentiqa - 0083_signal_lukket.sql
-- Lukking av funn i oppmerksomhetsfeeden.
--
-- Uten dette blir feeden en soppelbotte etter noen uker: den samme
-- kategorien som falt i mars ligger der fortsatt i mai, og sjefen slutter
-- aa lese den. Med lukking blir listen igjen et sted man handler.
--
-- To regler:
--   1) Et funn lukkes AUTOMATISK naar signalet forsvinner - lukkingen
--      lagres ikke, den bare uteblir ved neste beregning.
--   2) Manuell lukking varer i et begrenset antall dager (gjelder_til).
--      Er problemet fortsatt der etterpaa, skal det opp igjen. Et funn som
--      kan skjules for alltid er et funn ingen fikser.
--
-- signal_id er den stabile n0kkelen motoren gir hvert funn ('avd-190',
-- 'stasjon-<uuid>', 'oppgaver-forsinket' ...). Den er ikke en fremmedn0kkel
-- mot noe - funnene finnes bare i minnet mens siden bygges.
-- =====================================================================

create table if not exists public.signal_lukket (
  id            uuid primary key default gen_random_uuid(),
  retailer_id   uuid not null references public.retailers(id) on delete restrict,
  stasjon_id    uuid references public.stasjoner(id) on delete cascade,
  signal_id     text not null,
  gjelder_til   date not null,
  notat         text,
  lukket_av     uuid references auth.users(id) on delete set null,
  opprettet_tid timestamptz not null default now()
);

-- Ett aktivt skjul per (stasjon, signal). Upsert forlenger i stedet for aa
-- hope opp rader. stasjon_id kan vaere null (kjede-brede funn), og da tar
-- coalesce seg av det saa noekkelen fortsatt er entydig.
create unique index if not exists signal_lukket_unik
  on public.signal_lukket (retailer_id, coalesce(stasjon_id, '00000000-0000-0000-0000-000000000000'::uuid), signal_id);

create index if not exists signal_lukket_oppslag
  on public.signal_lukket (retailer_id, gjelder_til);

comment on table public.signal_lukket is
  'Midlertidig skjulte funn i oppmerksomhetsfeeden. Utloper paa gjelder_til - '
  'et funn som kan skjules for alltid er et funn ingen fikser.';

alter table public.signal_lukket enable row level security;

-- Samme moenster som resten: aldri "for all", gjeldende_rolle() pakket i
-- (select ...), stasjonstilgang via mine_stasjoner(). Kjede-brede rader
-- (stasjon_id null) leses av alle i kjeden.
drop policy if exists signal_lukket_les on public.signal_lukket;
create policy signal_lukket_les on public.signal_lukket for select to authenticated
  using (
    retailer_id = (select public.gjeldende_retailer_id())
    and (stasjon_id is null or stasjon_id in (select public.mine_stasjoner()))
  );

drop policy if exists signal_lukket_ins on public.signal_lukket;
create policy signal_lukket_ins on public.signal_lukket for insert to authenticated
  with check (
    retailer_id = (select public.gjeldende_retailer_id())
    and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef')
    and (stasjon_id is null or stasjon_id in (select public.mine_stasjoner()))
  );

drop policy if exists signal_lukket_upd on public.signal_lukket;
create policy signal_lukket_upd on public.signal_lukket for update to authenticated
  using (
    retailer_id = (select public.gjeldende_retailer_id())
    and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef')
    and (stasjon_id is null or stasjon_id in (select public.mine_stasjoner()))
  )
  with check (
    retailer_id = (select public.gjeldende_retailer_id())
    and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef')
    and (stasjon_id is null or stasjon_id in (select public.mine_stasjoner()))
  );

drop policy if exists signal_lukket_del on public.signal_lukket;
create policy signal_lukket_del on public.signal_lukket for delete to authenticated
  using (
    retailer_id = (select public.gjeldende_retailer_id())
    and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef')
    and (stasjon_id is null or stasjon_id in (select public.mine_stasjoner()))
  );

grant select, insert, update, delete on public.signal_lukket to authenticated;
