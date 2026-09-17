-- Run manually BEFORE the application deploy. Additive and safe to rerun.
-- One transaction publishes the complete snapshot; never reset lagd_hittil.
create or replace function public.publiser_produksjonsplan(
  p_stasjon uuid, p_dato date, p_linjer jsonb, p_notat text
) returns void
language plpgsql security invoker
set search_path = pg_catalog, public
as $$
declare
  v_retailer uuid;
begin
  if coalesce((select public.gjeldende_rolle())::text, '') not in ('retailer_admin', 'butikksjef') then
    raise exception 'Only managers may publish' using errcode = '42501';
  end if;
  select s.retailer_id into v_retailer from public.stasjoner s
    where s.id = p_stasjon and s.slettet_tid is null
      and s.retailer_id = (select public.gjeldende_retailer_id())
      and s.id in (select public.mine_stasjoner());
  if v_retailer is null then
    raise exception 'Station access denied' using errcode = '42501';
  end if;
  if p_dato is null or p_linjer is null or jsonb_typeof(p_linjer) <> 'array' then
    raise exception 'Invalid plan snapshot' using errcode = '22023';
  end if;
  if jsonb_array_length(p_linjer) > 1000 then
    raise exception 'Plan snapshot too large' using errcode = '22023';
  end if;
  if exists (
    select 1 from jsonb_to_recordset(p_linjer) as x(
      varenavn text, foreslatt integer, planlagt integer, start_antall integer, ekskludert boolean
    ) where nullif(btrim(x.varenavn), '') is null
      or x.foreslatt is null or x.foreslatt < 0
      or x.planlagt is null or x.planlagt < 0
      or x.start_antall is null or x.start_antall < 0 or x.start_antall > x.planlagt
      or x.ekskludert is null
  ) or exists (
    select btrim(x.varenavn) from jsonb_to_recordset(p_linjer) as x(varenavn text)
      group by btrim(x.varenavn) having count(*) > 1
  ) then
    raise exception 'Invalid or duplicate plan line' using errcode = '22023';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_stasjon::text || ':' || p_dato::text, 0));
  insert into public.produksjonsplan_linjer (
    retailer_id, stasjon_id, dato, varenavn, varegruppe_kode, varegruppe_navn,
    foreslatt, planlagt, start_antall, ekskludert, oppdatert_tid
  ) select v_retailer, p_stasjon, p_dato, btrim(x.varenavn), x.varegruppe_kode, x.varegruppe_navn,
      x.foreslatt, x.planlagt, x.start_antall, x.ekskludert, now()
    from jsonb_to_recordset(p_linjer) as x(
      varenavn text, varegruppe_kode text, varegruppe_navn text,
      foreslatt integer, planlagt integer, start_antall integer, ekskludert boolean
    )
    on conflict (stasjon_id, dato, varenavn) do update set
      varegruppe_kode = excluded.varegruppe_kode, varegruppe_navn = excluded.varegruppe_navn,
      foreslatt = excluded.foreslatt, planlagt = excluded.planlagt,
      start_antall = excluded.start_antall, ekskludert = excluded.ekskludert,
      oppdatert_tid = excluded.oppdatert_tid;
  -- Old products omitted from the snapshot must not remain on the tablet.
  update public.produksjonsplan_linjer l set ekskludert = true, oppdatert_tid = now()
    where l.stasjon_id = p_stasjon and l.dato = p_dato and l.retailer_id = v_retailer
      and not l.ekskludert
      and not exists (select 1 from jsonb_to_recordset(p_linjer) as x(varenavn text)
        where btrim(x.varenavn) = l.varenavn);
  insert into public.produksjonsplan_hode (
    retailer_id, stasjon_id, dato, notat, publisert_tid, oppdatert_tid
  ) values (v_retailer, p_stasjon, p_dato, nullif(btrim(p_notat), ''), now(), now())
    on conflict (stasjon_id, dato) do update set
      notat = excluded.notat, publisert_tid = excluded.publisert_tid,
      oppdatert_tid = excluded.oppdatert_tid;
end;
$$;
revoke all on function public.publiser_produksjonsplan(uuid, date, jsonb, text) from public, anon;
grant execute on function public.publiser_produksjonsplan(uuid, date, jsonb, text) to authenticated;
