-- =====================================================================
-- Sentiqa — Personlig sjekkliste (PROSJEKT.md §16.5)
-- Lederens egen, private sjekkliste — adskilt fra stasjonens delte rutiner.
-- Daglige (gjentakende) + engangs-punkter. RLS: hver bruker ser KUN sine egne.
-- =====================================================================
create table if not exists public.personlig_punkt (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  retailer_id   uuid references public.retailers(id) on delete cascade,
  tittel        text not null,
  gjentakende   boolean not null default true,   -- true = daglig, false = engangs
  fullfort_tid  timestamptz,                       -- for engangs-punkter
  opprettet_tid timestamptz not null default now(),
  slettet_tid   timestamptz
);
create index if not exists personlig_punkt_user_idx on public.personlig_punkt (user_id);

create table if not exists public.personlig_kryss (
  id            uuid primary key default gen_random_uuid(),
  punkt_id      uuid not null references public.personlig_punkt(id) on delete cascade,
  user_id       uuid not null references auth.users(id) on delete cascade,
  dato          date not null,
  opprettet_tid timestamptz not null default now(),
  unique (punkt_id, dato)
);

alter table public.personlig_punkt enable row level security;
alter table public.personlig_kryss enable row level security;

drop policy if exists personlig_punkt_egne on public.personlig_punkt;
create policy personlig_punkt_egne on public.personlig_punkt for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists personlig_kryss_egne on public.personlig_kryss;
create policy personlig_kryss_egne on public.personlig_kryss for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

grant select, insert, update, delete on public.personlig_punkt to authenticated;
grant select, insert, update, delete on public.personlig_kryss to authenticated;
