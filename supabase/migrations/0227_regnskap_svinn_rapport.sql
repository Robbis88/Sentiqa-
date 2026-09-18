-- Sikker, stasjonsavgrenset lesing av svinngrunnlaget for regnskapsrapporten.
create or replace function public.regnskap_svinn_rapport(p_fra date, p_til date, p_stasjon_id uuid)
returns table(stasjon_id uuid, kode text, navn text, salg numeric, usynlig_kr numeric, kast numeric, datastatus text)
language plpgsql stable security definer set search_path = ''
as $$
begin
  if (select public.gjeldende_rolle()) not in ('retailer_admin', 'butikksjef') then
    raise exception 'Rollen din kan ikke lese regnskapssvinn.' using errcode = '42501';
  end if;
  if p_fra is null or p_til is null or p_fra > p_til then
    raise exception 'Ugyldig periode.' using errcode = '22023';
  end if;
  if not exists (select 1 from public.mine_stasjoner() m where m = p_stasjon_id) then
    raise exception 'Ikke tilgang til stasjonen.' using errcode = '42501';
  end if;
  if not exists (select 1 from public.stasjoner s where s.id = p_stasjon_id and s.retailer_id = (select public.gjeldende_retailer_id())) then
    raise exception 'Stasjonen tilhører ikke din kjede.' using errcode = '42501';
  end if;
  return query
    select v.stasjon_id, v.kode, v.navn,
           sum(v.salg)::numeric, sum(v.usynlig_kr)::numeric, sum(v.kast)::numeric,
           case when bool_or(v.datastatus = 'eldre_grunnlag') then 'eldre_grunnlag' else 'gruppe' end
      from public.v_svinn_grunnlag v
     where v.stasjon_id = p_stasjon_id and v.periode between p_fra and p_til
     group by v.stasjon_id, v.kode, v.navn;
end;
$$;
revoke all on function public.regnskap_svinn_rapport(date, date, uuid) from public, anon;
grant execute on function public.regnskap_svinn_rapport(date, date, uuid) to authenticated;
