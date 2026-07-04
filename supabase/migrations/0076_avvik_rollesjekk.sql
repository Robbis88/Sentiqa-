-- =====================================================================
-- Avvik: krev rolle for skriv (ikke bare stasjonstilgang)
-- Uten rollesjekk kunne en delt tablet-konto (butikkbruker_tablet) endre
-- eller slette avvik. Søsterpolicyer (ik_punkter_skriv, pengepremie_skriv)
-- har allerede samme rollebegrensning.
-- =====================================================================
drop policy if exists avvik_skriv on public.avvik;
create policy avvik_skriv on public.avvik for all to authenticated
  using (
    public.har_stasjonstilgang(stasjon_id)
    and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef')
  )
  with check (
    public.har_stasjonstilgang(stasjon_id)
    and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef')
  );
