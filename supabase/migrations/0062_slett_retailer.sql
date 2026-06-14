-- =====================================================================
-- Sentiqa - Permanent sletting av en kjede (GDPR). Sletter ALLE rader i alle
-- public-tabeller som har en retailer_id, i flere pass slik at FK-rekkefoelge
-- loeser seg selv, og til slutt selve retailers-raden. Auth-brukere slettes
-- separat fra appen (service-role). Kun service_role kan kjoere funksjonen --
-- ingen vanlig innlogget bruker naar den (kalles bak rolle-gate i app-laget).
-- =====================================================================
create or replace function public.slett_retailer_permanent(p_retailer uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  pass int;
begin
  for pass in 1..6 loop
    for r in
      select c.table_name
      from information_schema.columns c
      join information_schema.tables t
        on t.table_schema = c.table_schema and t.table_name = c.table_name
      where c.table_schema = 'public'
        and c.column_name = 'retailer_id'
        and t.table_type = 'BASE TABLE'
    loop
      begin
        execute format('delete from public.%I where retailer_id = $1', r.table_name) using p_retailer;
      exception when others then
        null; -- FK-avhengighet mellom barn-tabeller loeses i et senere pass
      end;
    end loop;
  end loop;
  delete from public.retailers where id = p_retailer;
end;
$$;

revoke all on function public.slett_retailer_permanent(uuid) from public, anon, authenticated;
grant execute on function public.slett_retailer_permanent(uuid) to service_role;
