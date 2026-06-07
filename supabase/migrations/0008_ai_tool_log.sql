-- =====================================================================
-- Sentiqa — ai_tool_log (PROSJEKT.md §8, §15)
-- Logger hvert verktøykall AI-assistenten gjør (tenant, bruker, verktøy,
-- argumenter). Grunnlag for token-/bruks-måling og «vis kildene». PII holdes
-- ute av argument-feltet i app-laget. retailer_id + RLS.
-- =====================================================================
create table if not exists public.ai_tool_log (
  id            uuid primary key default gen_random_uuid(),
  retailer_id   uuid not null references public.retailers(id) on delete restrict,
  bruker_id     uuid references auth.users(id) on delete set null,
  verktoy       text not null,
  argument      jsonb,
  opprettet_tid timestamptz not null default now()
);
create index if not exists ai_tool_log_retailer_idx
  on public.ai_tool_log (retailer_id, opprettet_tid desc);

alter table public.ai_tool_log enable row level security;

-- Admin ser egen tenants logg. Innloggede skriver kun for egen tenant.
drop policy if exists ai_tool_log_les on public.ai_tool_log;
create policy ai_tool_log_les on public.ai_tool_log for select to authenticated
  using (public.gjeldende_rolle() = 'retailer_admin'
         and retailer_id = public.gjeldende_retailer_id());

drop policy if exists ai_tool_log_skriv on public.ai_tool_log;
create policy ai_tool_log_skriv on public.ai_tool_log for insert to authenticated
  with check (retailer_id = public.gjeldende_retailer_id());

grant select, insert on public.ai_tool_log to authenticated;
