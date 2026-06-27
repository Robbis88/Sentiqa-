-- =====================================================================
-- Sentiqa — Målekort-motor (fase 2). Aggregerings-RPC-er som leaderboardet
-- bruker. SECURITY DEFINER + eksplisitt retailer-filter (gjeldende_retailer_id):
-- gir butikksjef innsyn i ANDRE stasjoners aggregat (nødvendig for rangering)
-- UTEN å åpne rå rad-tilgang — og kan aldri lekke en annen kjedes tall.
-- =====================================================================

-- Scoped salgssum per stasjon for et datointervall. Scope fra malekort_scope
-- (0 rader = alt salg). Vakt: målekortet må tilhøre kallerens cluster.
create or replace function public.beregn_malekort_salg(p_malekort uuid, p_fra date, p_til date)
returns table(stasjon_id uuid, omsetning numeric, antall numeric, brutto numeric)
language sql stable security definer set search_path = public as $$
  select ds.stasjon_id,
         coalesce(sum(ds.omsetning_eks_mva), 0) as omsetning,
         coalesce(sum(ds.antall), 0)            as antall,
         coalesce(sum(ds.bto_fortjeneste_kr), 0) as brutto
  from public.daglig_salg ds
  where ds.dato between p_fra and p_til
    and ds.slettet_tid is null
    and ds.retailer_id = public.gjeldende_retailer_id()
    and exists (
      select 1 from public.malekort m
      where m.id = p_malekort and m.retailer_id = ds.retailer_id and m.slettet_tid is null
    )
    and (
      not exists (select 1 from public.malekort_scope s where s.malekort_id = p_malekort)
      or exists (
        select 1 from public.malekort_scope s
        where s.malekort_id = p_malekort
          and ((s.nivaa = 'avdeling'   and s.kode = ds.avdeling_kode)
            or (s.nivaa = 'vareomrade' and s.kode = ds.vareomrade_kode)
            or (s.nivaa = 'varegruppe' and s.kode = ds.varegruppe_kode)
            or (s.nivaa = 'ean'        and s.kode = ds.ean))
      )
    )
  group by ds.stasjon_id
$$;
grant execute on function public.beregn_malekort_salg(uuid, date, date) to authenticated;

-- Kunder (timesalg) + bonger (kassererstatistikk) per stasjon for intervallet.
-- Brukes til snittpris-per-kunde / snittbong / kunder-metrikkene.
create or replace function public.beregn_stasjon_kunder(p_fra date, p_til date)
returns table(stasjon_id uuid, kunder numeric, bonger numeric)
language sql stable security definer set search_path = public as $$
  select s.id as stasjon_id,
         coalesce(t.kunder, 0) as kunder,
         coalesce(k.bonger, 0) as bonger
  from public.stasjoner s
  left join (
    select stasjon_id, sum(antall_kunder) as kunder
    from public.timesalg where dato between p_fra and p_til and slettet_tid is null
    group by stasjon_id
  ) t on t.stasjon_id = s.id
  left join (
    select stasjon_id, sum(bonger) as bonger
    from public.kassererstatistikk where dato between p_fra and p_til and slettet_tid is null
    group by stasjon_id
  ) k on k.stasjon_id = s.id
  where s.slettet_tid is null and s.retailer_id = public.gjeldende_retailer_id()
$$;
grant execute on function public.beregn_stasjon_kunder(date, date) to authenticated;

-- Distinkte salgsdatoer i et intervall (for komletthetssjekken — «aldri halv
-- uke»). Liten retur (≤ ~31 datoer) → trygt under 1000-radgrensen.
create or replace function public.malekort_salgsdatoer(p_fra date, p_til date)
returns table(dato date)
language sql stable security definer set search_path = public as $$
  select distinct dato
  from public.daglig_salg
  where dato between p_fra and p_til and slettet_tid is null
    and retailer_id = public.gjeldende_retailer_id()
$$;
grant execute on function public.malekort_salgsdatoer(date, date) to authenticated;
