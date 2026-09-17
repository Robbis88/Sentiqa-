-- Local seeded database only. psql -v ON_ERROR_STOP=1. Rolls back everything.
begin;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"33333333-3333-4333-8333-111111111111","role":"authenticated"}', true);
select public.publiser_produksjonsplan('22222222-2222-4222-8222-222222222222', '2099-01-01',
  '[{"varenavn":"Publisering A","foreslatt":20,"planlagt":22,"start_antall":10,"ekskludert":false},
    {"varenavn":"Publisering B","foreslatt":10,"planlagt":12,"start_antall":5,"ekskludert":false}]', 'Original');
do $$ begin
  if (select count(*) from public.produksjonsplan_linjer where stasjon_id='22222222-2222-4222-8222-222222222222' and dato='2099-01-01') <> 2 then
    raise exception 'Complete snapshot was not saved';
  end if;
end $$;
select public.logg_lagd('22222222-2222-4222-8222-222222222222', '2099-01-01', 'Publisering A', 7);
select public.publiser_produksjonsplan('22222222-2222-4222-8222-222222222222', '2099-01-01',
  '[{"varenavn":"Publisering A","foreslatt":20,"planlagt":24,"start_antall":10,"ekskludert":false}]', 'Original');
do $$ begin
  if (select lagd_hittil from public.produksjonsplan_linjer where stasjon_id='22222222-2222-4222-8222-222222222222' and dato='2099-01-01' and varenavn='Publisering A') <> 7 then
    raise exception 'Republishing reset production';
  end if;
  if not (select ekskludert from public.produksjonsplan_linjer where stasjon_id='22222222-2222-4222-8222-222222222222' and dato='2099-01-01' and varenavn='Publisering B') then
    raise exception 'Old omitted product remains visible';
  end if;
  begin
    perform public.publiser_produksjonsplan('22222222-2222-4222-8222-222222222222', '2099-01-01',
      '[{"varenavn":"A","foreslatt":1,"planlagt":2,"start_antall":3,"ekskludert":false}]', 'Invalid');
    raise exception 'Invalid start accepted';
  exception when invalid_parameter_value then null; end;
  begin
    perform public.publiser_produksjonsplan('44444444-4444-4444-8444-111111111111', '2099-01-01', '[]', 'Foreign');
    raise exception 'Foreign station accepted';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
-- Force a failure AFTER the line upsert, so atomic rollback is exercised.
create function pg_temp.fail_plan_head() returns trigger language plpgsql as $$
begin raise exception 'Test head failure' using errcode='P0002'; end $$;
create trigger test_plan_head_failure before insert or update on public.produksjonsplan_hode
  for each row execute function pg_temp.fail_plan_head();
set local role authenticated;
do $$ begin
  begin
    perform public.publiser_produksjonsplan('22222222-2222-4222-8222-222222222222', '2099-01-01',
      '[{"varenavn":"Publisering A","foreslatt":20,"planlagt":99,"start_antall":10,"ekskludert":false}]', 'Failed');
    raise exception 'Forced failure did not occur';
  exception when no_data_found then null; end;
  if (select planlagt from public.produksjonsplan_linjer where stasjon_id='22222222-2222-4222-8222-222222222222' and dato='2099-01-01' and varenavn='Publisering A') <> 24 then
    raise exception 'Failed publish changed old lines';
  end if;
  if (select notat from public.produksjonsplan_hode where stasjon_id='22222222-2222-4222-8222-222222222222' and dato='2099-01-01') <> 'Original' then
    raise exception 'Failed publish changed old head';
  end if;
end $$;
select set_config('request.jwt.claims', '{"sub":"33333333-3333-4333-8333-222222222222","role":"authenticated"}', true);
do $$ begin
  begin
    perform public.publiser_produksjonsplan('22222222-2222-4222-8222-222222222222', '2099-01-01', '[]', 'Tablet');
    raise exception 'Tablet may publish';
  exception when insufficient_privilege then null; end;
end $$;
rollback;
