-- Run before deploying the application that calls malekort_salgsdekning.
-- Rerun safe; preserves the old RPC for older deployed clients.
-- Count shop sales dates PER station, never the union of retailer dates.
create or replace function public.malekort_salgsdekning(
  p_malekort uuid, p_fra date, p_til date
)
returns table(stasjon_id uuid, dager bigint)
language sql stable security definer set search_path = public as $$
  select ds.stasjon_id, count(distinct ds.dato)
  from public.v_butikksalg ds
  join public.stasjoner s on s.id = ds.stasjon_id
    and s.retailer_id = ds.retailer_id and s.slettet_tid is null
  where ds.dato between p_fra and p_til
    and ds.retailer_id = (select public.gjeldende_retailer_id())
    and exists (
      select 1 from public.malekort m
      where m.id = p_malekort and m.retailer_id = ds.retailer_id
        and m.slettet_tid is null
        and (
          (select public.gjeldende_rolle()) = 'retailer_admin'
          or ((select public.gjeldende_rolle()) = 'butikksjef' and m.vis_butikksjef)
          or ((select public.gjeldende_rolle()) = 'butikkbruker_tablet' and m.vis_tablet)
        )
    )
  group by ds.stasjon_id
$$;
revoke all on function public.malekort_salgsdekning(uuid, date, date) from public, anon;
grant execute on function public.malekort_salgsdekning(uuid, date, date) to authenticated;
