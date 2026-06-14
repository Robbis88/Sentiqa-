-- =====================================================================
-- Sentiqa - Trafikk (Vegvesen): doegnvolum per stasjon for kampanje-fangstrate.
-- Koblingen stasjon -> tellepunkt settes/bekreftes av plattform-eier (kun der
-- telleren faktisk staar paa veien forbi stasjonen). Nattjobben henter
-- doegntrafikk for stasjoner der maaling er skrudd PAA.
-- =====================================================================

alter table public.stasjoner
  add column if not exists trafikk_punkt_id   text,
  add column if not exists trafikk_punkt_navn text,
  add column if not exists trafikk_punkt_vei  text,
  add column if not exists trafikk_aktiv      boolean not null default false;

create table if not exists public.trafikk (
  stasjon_id      uuid not null references public.stasjoner(id) on delete cascade,
  dato            date not null,
  antall_kjoretoy numeric,
  dekning_pst     numeric,
  hentet_tid      timestamptz not null default now(),
  primary key (stasjon_id, dato)
);

alter table public.trafikk enable row level security;

-- Les: brukere med tilgang til stasjonen (plattform-eier leser via service-role).
drop policy if exists trafikk_les on public.trafikk;
create policy trafikk_les on public.trafikk for select to authenticated
  using (public.har_stasjonstilgang(stasjon_id));

grant select on public.trafikk to authenticated;
