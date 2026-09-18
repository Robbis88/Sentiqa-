-- Run manually before deploying the application. Re-runnable; no data changes.
begin;
drop policy if exists varsler_insert on public.varsler;
create policy varsler_insert on public.varsler for insert to authenticated
with check (
  retailer_id = (select public.gjeldende_retailer_id())
  and (select public.gjeldende_rolle())::text in ('retailer_admin','butikksjef','butikkbruker_tablet')
  and (
    (stasjon_id is null and (select public.gjeldende_rolle())::text = 'retailer_admin')
    or (stasjon_id in (select public.mine_stasjoner())
      and exists (select 1 from public.stasjoner s where s.id = stasjon_id and s.retailer_id = varsler.retailer_id))
  )
  and (mottaker_id is null or exists (
    select 1 from public.profiler p where p.id = mottaker_id and p.retailer_id = varsler.retailer_id
  ))
  and ((select public.gjeldende_rolle())::text <> 'butikkbruker_tablet' or mottaker_id is null)
);

drop policy if exists uke_rapport_del on public.uke_rapport;
create policy uke_rapport_del on public.uke_rapport for delete to authenticated
using (
  retailer_id = (select public.gjeldende_retailer_id())
  and (select public.gjeldende_rolle())::text in ('retailer_admin','butikksjef')
  and stasjon_id in (select public.mine_stasjoner())
);
commit;
