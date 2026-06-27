-- =====================================================================
-- Sentiqa — Databehandleravtale-aksept (PROSJEKT.md §15)
-- Sporer hvilken versjon av DPA-en hver kunde har inngått, når, og hvem
-- som bekreftet. Settes av registreringsflyten. Nullbar for eksisterende
-- tenants opprettet før akseptflyten (følges opp manuelt/ved neste innlogging).
-- =====================================================================
alter table public.retailers add column if not exists dpa_akseptert_tid timestamptz;
alter table public.retailers add column if not exists dpa_versjon       text;
alter table public.retailers add column if not exists dpa_akseptert_av  text;

comment on column public.retailers.dpa_akseptert_tid is 'Tidspunkt kunden inngikk databehandleravtalen.';
comment on column public.retailers.dpa_versjon is 'Versjonsstreng for DPA-en kunden inngikk (jf. src/lib/juss.ts DPA_VERSJON).';
comment on column public.retailers.dpa_akseptert_av is 'Navnet på personen som bekreftet avtalen ved registrering.';
