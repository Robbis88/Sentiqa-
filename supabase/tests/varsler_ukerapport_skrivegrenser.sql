-- Local/CI fixture test. Every change rolls back. Run with ON_ERROR_STOP=1.
begin;
insert into auth.users(id,email) values ('22400000-0000-4000-8000-000000000001','owner224@test.local');
insert into public.profiler(id,retailer_id,rolle) values
('22400000-0000-4000-8000-000000000001','11111111-1111-4111-8111-111111111111','retailer_admin');
insert into public.retailers(id,navn) values ('22400000-0000-4000-8000-000000000002','Other224');
insert into public.stasjoner(id,retailer_id,butikknummer,navn,stasjonstype) values
('22400000-0000-4000-8000-000000000003','22400000-0000-4000-8000-000000000002','0224','Other224','pendler');
delete from public.butikksjef_stasjoner where profil_id in
('33333333-3333-4333-8333-111111111111','33333333-3333-4333-8333-222222222222');
insert into public.butikksjef_stasjoner(profil_id,stasjon_id) values
('33333333-3333-4333-8333-111111111111','22222222-2222-4222-8222-222222222222'),
('33333333-3333-4333-8333-222222222222','22222222-2222-4222-8222-222222222222');
insert into public.uke_rapport(retailer_id,stasjon_id,uke_mandag) values
('11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222','2080-01-01'),
('11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-333333333333','2080-01-01');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"33333333-3333-4333-8333-222222222222","role":"authenticated"}',true);
do $$ declare n int; target uuid; begin
  insert into public.varsler(retailer_id,stasjon_id,type,tittel) values
  ('11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222','ikmat','Allowed own station');
  select id into target from public.uke_rapport where stasjon_id='22222222-2222-4222-8222-222222222222' and uke_mandag='2080-01-01';
  if target is null then raise exception 'Positive visibility control failed'; end if;
  delete from public.uke_rapport where id=target;
  get diagnostics n=row_count;
  if n<>0 then raise exception 'Tablet deleted report'; end if;
  if not exists(select 1 from public.uke_rapport where id=target) then raise exception 'Target not preserved'; end if;
  begin
    insert into public.varsler(retailer_id,stasjon_id,type,tittel) values
    ('11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-333333333333','ikmat','Other station');
    raise exception 'Other-station insert accepted';
  exception when insufficient_privilege then null; end;
  begin
    insert into public.varsler(retailer_id,stasjon_id,mottaker_id,type,tittel) values
    ('11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222','33333333-3333-4333-8333-222222222222','ikmat','Personal tablet notice');
    raise exception 'Tablet personal notice accepted';
  exception when insufficient_privilege then null; end;
  begin
    insert into public.varsler(retailer_id,stasjon_id,type,tittel) values
    ('11111111-1111-4111-8111-111111111111','22400000-0000-4000-8000-000000000003','ikmat','Foreign station disguised');
    raise exception 'Foreign station accepted';
  exception when insufficient_privilege then null; end;
  begin
    insert into public.varsler(retailer_id,type,tittel) values
    ('11111111-1111-4111-8111-111111111111','ikmat','Chain notice');
    raise exception 'Tablet chain notice accepted';
  exception when insufficient_privilege then null; end;
end $$;
select set_config('request.jwt.claims','{"sub":"33333333-3333-4333-8333-111111111111","role":"authenticated"}',true);
do $$ declare n int; begin
  insert into public.varsler(retailer_id,stasjon_id,type,tittel) values
  ('11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222','sjekkpunkt','Manager positive');
  delete from public.uke_rapport where stasjon_id='22222222-2222-4222-8222-222222222222' and uke_mandag='2080-01-01';
  get diagnostics n=row_count;
  if n<>1 then raise exception 'Manager positive DELETE failed'; end if;
  delete from public.uke_rapport where stasjon_id='22222222-2222-4222-8222-333333333333' and uke_mandag='2080-01-01';
  get diagnostics n=row_count;
  if n<>0 then raise exception 'Manager unassigned DELETE accepted'; end if;
  begin
    insert into public.varsler(retailer_id,stasjon_id,type,tittel) values
    ('11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-333333333333','sjekkpunkt','Manager unassigned');
    raise exception 'Manager unassigned insert accepted';
  exception when insufficient_privilege then null; end;
end $$;
select set_config('request.jwt.claims','{"sub":"22400000-0000-4000-8000-000000000001","role":"authenticated"}',true);
do $$ declare n int; begin
  insert into public.varsler(retailer_id,type,tittel) values
  ('11111111-1111-4111-8111-111111111111','import_feil','Owner chain notice');
  delete from public.uke_rapport where stasjon_id='22222222-2222-4222-8222-333333333333' and uke_mandag='2080-01-01';
  get diagnostics n=row_count;
  if n<>1 then raise exception 'Owner positive DELETE failed'; end if;
  raise notice 'PASS: own-station notices preserved, cross-station denied, report DELETE leader-only';
end $$;
rollback;
