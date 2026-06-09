-- =====================================================================
-- Sentiqa — Rutine-bildebevis (PROSJEKT.md §16.5, etappe 3)
-- Privat bucket for bildebevis, stasjons-scoped sti {retailer}/{stasjon}/fil.
-- bilde_sti på utføringen. Signerte URL-er hentes batchet i app-laget.
-- =====================================================================
alter table public.rutine_utforinger add column if not exists bilde_sti text;

insert into storage.buckets (id, name, public)
values ('rutinebilder', 'rutinebilder', false)
on conflict (id) do nothing;

-- Tilgang følger stasjonen (sti-segment 2 = stasjon_id).
drop policy if exists rutinebilder_storage on storage.objects;
create policy rutinebilder_storage on storage.objects for all to authenticated
  using (
    bucket_id = 'rutinebilder'
    and public.har_stasjonstilgang(((storage.foldername(name))[2])::uuid)
  )
  with check (
    bucket_id = 'rutinebilder'
    and public.har_stasjonstilgang(((storage.foldername(name))[2])::uuid)
  );
