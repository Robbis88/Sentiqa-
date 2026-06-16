-- =====================================================================
-- Sentiqa - RLS-YTELSE: policyene kalte gjeldende_rolle()/gjeldende_retailer_id()
-- (hver et subquery mot profiler) + har_stasjonstilgang() PER RAD. Med 1000
-- testrader gikk det fort, men etter onboarding (daglig_salg ~400k rader) ga det
-- "statement timeout" -> 0 rader (sa ut som datatap, men dataene var trygge).
-- Fix (Supabase-anbefaling): pakk funksjonene i (select ...) sa de evalueres EN
-- gang (initplan), filtrer pa retailer_id forst (PK-ledende kolonne), og bruk
-- stasjon_id IN (...) som initplan for butikksjef/tablet i stedet for per-rad-kall.
-- =====================================================================

-- daglig_salg (partisjonert — policy pa forelder gjelder alle partisjoner)
drop policy if exists daglig_salg_les on public.daglig_salg;
create policy daglig_salg_les on public.daglig_salg for select to authenticated
  using (
    slettet_tid is null
    and retailer_id = (select public.gjeldende_retailer_id())
    and (
      (select public.gjeldende_rolle()) = 'retailer_admin'
      or stasjon_id in (select bs.stasjon_id from public.butikksjef_stasjoner bs where bs.profil_id = (select auth.uid()))
    )
  );

-- timesalg, kassererstatistikk, synlig_svinn (samme struktur)
do $$
declare t text;
begin
  foreach t in array array['timesalg', 'kassererstatistikk', 'synlig_svinn'] loop
    execute format('drop policy if exists %I on public.%I', t || '_les', t);
    execute format($f$
      create policy %I on public.%I for select to authenticated
      using (
        slettet_tid is null
        and retailer_id = (select public.gjeldende_retailer_id())
        and (
          (select public.gjeldende_rolle()) = 'retailer_admin'
          or stasjon_id in (select bs.stasjon_id from public.butikksjef_stasjoner bs where bs.profil_id = (select auth.uid()))
        )
      )$f$, t || '_les', t);
  end loop;
end $$;

-- regnskapslinjer (cluster-linjer har stasjon_id null -> kun admin ser dem)
drop policy if exists regnskapslinjer_les on public.regnskapslinjer;
create policy regnskapslinjer_les on public.regnskapslinjer for select to authenticated
  using (
    slettet_tid is null
    and retailer_id = (select public.gjeldende_retailer_id())
    and (
      (select public.gjeldende_rolle()) = 'retailer_admin'
      or (stasjon_id is not null and stasjon_id in (select bs.stasjon_id from public.butikksjef_stasjoner bs where bs.profil_id = (select auth.uid())))
    )
  );

-- regnskap_usynlig_svinn (kun admin)
drop policy if exists usynlig_svinn_les on public.regnskap_usynlig_svinn;
create policy usynlig_svinn_les on public.regnskap_usynlig_svinn for select to authenticated
  using (
    slettet_tid is null
    and retailer_id = (select public.gjeldende_retailer_id())
    and (select public.gjeldende_rolle()) = 'retailer_admin'
  );
