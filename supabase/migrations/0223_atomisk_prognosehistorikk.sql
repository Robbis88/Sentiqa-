-- Run manually BEFORE the app deploy that calls this RPC. Idempotent DDL.
-- Historical scenario results and calibration replace together or not at all.
create or replace function public.erstatt_prognosehistorikk(
  p_stasjon uuid, p_treff jsonb, p_kalibrering jsonb
) returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  kjede uuid;
begin
  if jsonb_typeof(p_treff) is distinct from 'array'
     or jsonb_typeof(p_kalibrering) is distinct from 'array' then
    raise exception 'Expected result arrays';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_stasjon::text, 223));
  select retailer_id into kjede from public.stasjoner
    where id = p_stasjon and slettet_tid is null;
  if kjede is null then raise exception 'Station not found'; end if;
  if exists (
    select 1 from jsonb_array_elements(p_treff || p_kalibrering) r
    where (r->>'stasjon_id')::uuid is distinct from p_stasjon
       or (r->>'retailer_id')::uuid is distinct from kjede
  ) then raise exception 'Result tenant does not match station'; end if;
  if exists (
    select 1 from jsonb_to_recordset(p_kalibrering)
      as r(korreksjon numeric, n integer, type text, kategori text)
    where korreksjon is null or korreksjon not between 0.6 and 1.6
      or n is null or n < 8 or type not in ('produksjonsplan','salgsprognose')
      or type is null or kategori is null
  ) then raise exception 'Invalid calibration'; end if;

  delete from public.prognose_treff where stasjon_id = p_stasjon;
  delete from public.prognose_kalibrering where stasjon_id = p_stasjon;
  insert into public.prognose_treff
    (retailer_id, stasjon_id, type, dato, kategori, forventet, faktisk, treff)
  select retailer_id, stasjon_id, type, dato, kategori, forventet, faktisk, treff
  from jsonb_to_recordset(p_treff) as r(
    retailer_id uuid, stasjon_id uuid, type text, dato date, kategori text,
    forventet numeric, faktisk numeric, treff numeric
  );
  insert into public.prognose_kalibrering
    (retailer_id, stasjon_id, type, kategori, korreksjon, n)
  select retailer_id, stasjon_id, type, kategori, korreksjon, n
  from jsonb_to_recordset(p_kalibrering) as r(
    retailer_id uuid, stasjon_id uuid, type text, kategori text,
    korreksjon numeric, n integer
  );
end
$$;
revoke all on function public.erstatt_prognosehistorikk(uuid,jsonb,jsonb)
  from public, anon, authenticated;
grant execute on function public.erstatt_prognosehistorikk(uuid,jsonb,jsonb)
  to service_role;
