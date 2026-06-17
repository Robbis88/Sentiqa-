-- =====================================================================
-- Sentiqa - MULIG UTSOLGT. Finner FASTE varer (som selger jevnt, snitt >= 1.5
-- pr salgsdag og selger de fleste dager) og returnerer deres daglige serie.
-- Selve hull-deteksjonen (0 i >=2 dager omkranset av normalt salg) gjores i JS.
-- security invoker -> RLS gjelder, sa leder kun ser egne stasjoner.
-- Aggregerer i SQL -> bare faste varer slipper gjennom (ikke drukne i smavarer).
-- =====================================================================

create or replace function public.utsolgt_kandidater(p_stasjon uuid, p_dager integer default 35)
returns table(ean text, varenavn text, dato date, antall numeric, omsetning numeric)
language sql
stable
security invoker
set search_path = public
as $$
  with dag as (
    select ds.ean,
           max(ds.varenavn)            as varenavn,
           ds.dato,
           sum(ds.antall)              as antall,
           sum(ds.omsetning_eks_mva)   as omsetning
    from public.daglig_salg ds
    where ds.stasjon_id = p_stasjon
      and ds.slettet_tid is null
      and ds.ean is not null
      and ds.dato >= (current_date - p_dager)
      and ds.dato <  current_date
    group by ds.ean, ds.dato
  ),
  kval as (
    select ean
    from dag
    group by ean
    having count(*) filter (where antall > 0) >= greatest(2, floor(p_dager * 0.6)) -- selger de fleste dager
       and sum(antall) / nullif(count(*) filter (where antall > 0), 0) >= 1.5       -- snitt >= 1.5 pr salgsdag
  )
  select d.ean, d.varenavn, d.dato, d.antall, d.omsetning
  from dag d
  join kval k on k.ean = d.ean
  order by d.ean, d.dato
$$;

grant execute on function public.utsolgt_kandidater(uuid, integer) to authenticated;
