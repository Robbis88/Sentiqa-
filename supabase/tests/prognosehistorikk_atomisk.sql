begin;
set local role service_role;
do $$
declare s uuid; k uuid; t jsonb; c jsonb;
begin
  select id, retailer_id into s,k from public.stasjoner where slettet_tid is null limit 1;
  if s is null then raise exception 'Fixture missing'; end if;
  insert into public.prognose_kalibrering(retailer_id,stasjon_id,type,kategori,korreksjon,n)
  values(k,s,'produksjonsplan','test-223',1.1,8)
  on conflict(stasjon_id,type,kategori) do update set korreksjon=1.1,n=8;
  c=jsonb_build_array(jsonb_build_object('retailer_id',k,'stasjon_id',s,'type','produksjonsplan','kategori','test-223','korreksjon',1.2,'n',8));
  t=jsonb_build_array(jsonb_build_object('retailer_id',k,'stasjon_id',s,'type','produksjonsplan','kategori','test-223','dato','2026-09-17','forventet',10,'faktisk',10,'treff',100));
  begin
    perform public.erstatt_prognosehistorikk(s,t||t,c);
    raise exception 'Expected unique violation';
  exception when unique_violation then null;
  end;
  if not exists(select 1 from public.prognose_kalibrering where stasjon_id=s and kategori='test-223' and korreksjon=1.1) then raise exception 'Old calibration lost'; end if;
  begin
    perform public.erstatt_prognosehistorikk(s,t,jsonb_set(c,'{0,retailer_id}',to_jsonb(gen_random_uuid())));
    raise exception 'Expected tenant rejection';
  exception when raise_exception then
    if sqlerrm <> 'Result tenant does not match station' then raise; end if;
  end;
  perform public.erstatt_prognosehistorikk(s,t,c);
  if not exists(select 1 from public.prognose_kalibrering where stasjon_id=s and kategori='test-223' and korreksjon=1.2) then raise exception 'Replacement missing'; end if;
  if has_function_privilege('anon','public.erstatt_prognosehistorikk(uuid,jsonb,jsonb)','execute') or has_function_privilege('authenticated','public.erstatt_prognosehistorikk(uuid,jsonb,jsonb)','execute') then raise exception 'Client execute open'; end if;
  raise notice 'PASS: atomic rollback, tenant binding, replacement, service-only grants';
end $$;
rollback;
