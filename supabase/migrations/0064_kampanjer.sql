-- =====================================================================
-- Sentiqa - Kampanjer: plattform-eier registrerer en St1-kampanje (navn, fra-til,
-- kampanjevarer (EAN) og stasjoner) for fangstrate-/uke-mot-uke-analyse.
-- Auto-forslag bygges fra daglig_salg.antall_tilbud; her lagres de valgte.
-- =====================================================================
create table if not exists public.kampanjer (
  id            uuid primary key default gen_random_uuid(),
  retailer_id   uuid not null references public.retailers(id) on delete cascade,
  navn          text not null,
  fra_dato      date not null,
  til_dato      date not null,
  eaner         text[],            -- kampanjevarer (EAN). Tomt = alle tilbudsvarer i perioden.
  stasjon_ider  uuid[],            -- tomt = alle stasjoner i kjeden.
  opprettet_av  uuid references auth.users(id) on delete set null,
  opprettet_tid timestamptz not null default now(),
  slettet_tid   timestamptz
);
create index if not exists kampanjer_retailer_idx on public.kampanjer (retailer_id);

alter table public.kampanjer enable row level security;

-- Les: kjedens egne brukere (for evt. framtidig kjede-visning). Skriv: kun
-- service-role (plattform-eier styrer via redaktoer-gate i app-laget).
drop policy if exists kampanjer_les on public.kampanjer;
create policy kampanjer_les on public.kampanjer for select to authenticated
  using (slettet_tid is null and retailer_id = public.gjeldende_retailer_id());

grant select on public.kampanjer to authenticated;

-- Aggregert dagstall for kampanjeanalysen (kampanjeperiode + like lang baseline
-- rett foer). Tomt eaner = alle tilbudsvarer i perioden; tomt stasjoner = alle i
-- kjeden. Biler kun fra stasjoner med aktiv maaling. Service-role (redaktoer-gate).
create or replace function public.kampanje_analyse(
  p_retailer uuid, p_fra date, p_til date, p_eaner text[], p_stasjoner uuid[]
)
returns table(dato date, antall numeric, antall_tilbud numeric, omsetning numeric, innekunder numeric, biler numeric)
language plpgsql security definer set search_path = public as $$
declare
  v_lengde   int  := (p_til - p_fra) + 1;
  v_base_fra date := p_fra - ((p_til - p_fra) + 1);
  v_stasjoner uuid[];
  v_eaner     text[];
begin
  if p_stasjoner is null or array_length(p_stasjoner, 1) is null then
    select array_agg(id) into v_stasjoner from stasjoner where retailer_id = p_retailer and slettet_tid is null;
  else
    v_stasjoner := p_stasjoner;
  end if;

  if p_eaner is null or array_length(p_eaner, 1) is null then
    select array_agg(distinct ds.ean) into v_eaner from daglig_salg ds
      where ds.retailer_id = p_retailer and ds.stasjon_id = any(v_stasjoner)
        and ds.dato between p_fra and p_til and coalesce(ds.antall_tilbud, 0) > 0 and ds.slettet_tid is null;
  else
    v_eaner := p_eaner;
  end if;
  v_eaner := coalesce(v_eaner, array[]::text[]);

  return query
  with dager as (
    select generate_series(v_base_fra, p_til, interval '1 day')::date d
  ), salg as (
    select ds.dato, sum(ds.antall) a, sum(ds.antall_tilbud) t, sum(ds.omsetning_eks_mva) o
    from daglig_salg ds
    where ds.retailer_id = p_retailer and ds.stasjon_id = any(v_stasjoner)
      and ds.ean = any(v_eaner) and ds.dato between v_base_fra and p_til and ds.slettet_tid is null
    group by ds.dato
  ), kund as (
    select ts.dato, sum(coalesce(ts.inne_kunder, ts.antall_kunder)) ik
    from timesalg ts
    where ts.stasjon_id = any(v_stasjoner) and ts.dato between v_base_fra and p_til and ts.slettet_tid is null
    group by ts.dato
  ), traf as (
    select tr.dato, sum(tr.antall_kjoretoy) b
    from trafikk tr join stasjoner s on s.id = tr.stasjon_id and s.trafikk_aktiv
    where tr.stasjon_id = any(v_stasjoner) and tr.dato between v_base_fra and p_til
    group by tr.dato
  )
  select dg.d, coalesce(s.a, 0), coalesce(s.t, 0), coalesce(s.o, 0), coalesce(k.ik, 0), coalesce(tr.b, 0)
  from dager dg
  left join salg s  on s.dato = dg.d
  left join kund k  on k.dato = dg.d
  left join traf tr on tr.dato = dg.d
  order by dg.d;
end $$;

revoke all on function public.kampanje_analyse(uuid, date, date, text[], uuid[]) from public, anon, authenticated;
grant execute on function public.kampanje_analyse(uuid, date, date, text[], uuid[]) to service_role;
