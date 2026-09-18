-- Varig forventningshistorikk for rutineoversikten.
-- Rader er snapshots av konfigurasjonen og skal aldri oppdateres eller slettes.
create table if not exists public.rutine_forventninger (
  id uuid primary key default gen_random_uuid(),
  retailer_id uuid not null references public.retailers(id) on delete restrict,
  stasjon_id uuid not null references public.stasjoner(id) on delete cascade,
  rutine_id uuid not null,
  skjema_id uuid not null,
  dato date not null,
  vakttype text not null,
  skjema_navn text,
  rutine_tittel text not null,
  forventet_start text not null,
  forventet_slutt text not null,
  paakrevd_bilde boolean not null default false,
  materialisert_tid timestamptz not null default now(),
  unique (rutine_id, dato)
);
create index if not exists rutine_forventninger_stasjon_dato_idx on public.rutine_forventninger (stasjon_id, dato);
create index if not exists rutine_forventninger_retailer_dato_idx on public.rutine_forventninger (retailer_id, dato);

alter table public.rutine_forventninger enable row level security;
revoke all on public.rutine_forventninger from anon;
grant select on public.rutine_forventninger to authenticated;
grant all on public.rutine_forventninger to service_role;

drop policy if exists rutine_forventninger_les on public.rutine_forventninger;
create policy rutine_forventninger_les on public.rutine_forventninger
  for select to authenticated
  using (
    stasjon_id in (select public.mine_stasjoner())
    and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef')
  );

-- Fyller bare hull. Å kjøre funksjonen flere ganger er derfor trygt.
create or replace function public.materialiser_rutine_forventninger(
  p_fra date default ((now() at time zone 'Europe/Oslo')::date),
  p_til date default (((now() at time zone 'Europe/Oslo')::date) + 30)
) returns integer
language plpgsql security definer set search_path = public
as $$
declare antall integer;
begin
  insert into public.rutine_forventninger
    (retailer_id, stasjon_id, rutine_id, skjema_id, dato, vakttype, skjema_navn,
     rutine_tittel, forventet_start, forventet_slutt, paakrevd_bilde)
  select r.retailer_id, r.stasjon_id, r.id, s.id, d.dato, s.vakttype, s.navn,
         r.tittel, s.tid_start, s.tid_slutt, r.paakrevd_bilde
  from public.rutiner r
  join public.rutineskjemaer s on s.id = r.skjema_id
  cross join lateral generate_series(p_fra, p_til, interval '1 day') as d(dato)
  where r.slettet_tid is null and s.slettet_tid is null and s.aktiv
    and (coalesce(cardinality(s.ukedager), 0) = 0 or extract(dow from d.dato)::int = any(s.ukedager))
    and (coalesce(cardinality(r.ukedager), 0) = 0 or extract(dow from d.dato)::int = any(r.ukedager))
    and r.opprettet_dato <= d.dato
  on conflict (rutine_id, dato) do nothing;
  get diagnostics antall = row_count;
  return antall;
end;
$$;
revoke all on function public.materialiser_rutine_forventninger(date, date) from public, anon, authenticated;
grant execute on function public.materialiser_rutine_forventninger(date, date) to service_role;

comment on table public.rutine_forventninger is
  'Uforanderlig snapshot av hva som var forventet per rutine og vaktdato. '
  'Brukes av lederoversikten; nettbrettet bruker fortsatt aktive rutiner.';

-- Backfyller rapportperioden og horisonten ved første utrulling. Senere kjøringer
-- setter bare inn hull på grunn av ON CONFLICT over.
select public.materialiser_rutine_forventninger(
  ((now() at time zone 'Europe/Oslo')::date - 30),
  ((now() at time zone 'Europe/Oslo')::date + 30)
);
