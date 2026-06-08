-- =====================================================================
-- Sentiqa — Web-push-abonnementer (PROSJEKT.md §2 varsler)
-- Lagrer nettleser/mobil-push-abonnement per bruker. Varsler sendes via
-- web-push (VAPID) i tillegg til in-app. Bruker styrer kun sine egne.
-- =====================================================================
create table if not exists public.push_abonnementer (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  retailer_id   uuid references public.retailers(id) on delete cascade,
  endpoint      text not null unique,
  p256dh        text not null,
  auth          text not null,
  opprettet_tid timestamptz not null default now()
);
create index if not exists push_abonnementer_user_idx on public.push_abonnementer (user_id);

alter table public.push_abonnementer enable row level security;

drop policy if exists push_egne on public.push_abonnementer;
create policy push_egne on public.push_abonnementer for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

grant select, insert, update, delete on public.push_abonnementer to authenticated;
