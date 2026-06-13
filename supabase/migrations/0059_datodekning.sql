-- =====================================================================
-- Sentiqa - Datodekning: distinkte datoer pr datasett, så /dekning kan vise
-- 13–14 mnd bakover (nødvendig for år-mot-år-analyser) uten å treffe 1000-rad-
-- grensen på rådata. security_invoker → RLS på underliggende tabeller gjelder.
-- =====================================================================
create or replace view public.v_datodekning with (security_invoker = true) as
  select 'daglig_salg'::text       as datasett, retailer_id, dato from public.daglig_salg        where slettet_tid is null and dato is not null group by retailer_id, dato
  union all
  select 'kassererstatistikk'::text, retailer_id, dato from public.kassererstatistikk where slettet_tid is null and dato is not null group by retailer_id, dato
  union all
  select 'timesalg'::text,           retailer_id, dato from public.timesalg           where slettet_tid is null and dato is not null group by retailer_id, dato
  union all
  select 'synlig_svinn'::text,       retailer_id, dato from public.synlig_svinn        where slettet_tid is null and dato is not null group by retailer_id, dato;

grant select on public.v_datodekning to authenticated;
