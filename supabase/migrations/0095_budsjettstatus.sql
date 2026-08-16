-- ---------------------------------------------------------------------
-- 0095: hvordan ligger stasjonene an mot budsjettet AKKURAT NA?
-- ---------------------------------------------------------------------
-- Systemet har hatt begge tallene hele tiden - faktisk brutto per dag i
-- daglig_salg, og BP-ens brutto per maaned i bemanning_budsjett - men
-- ingen skjerm satte dem mot hverandre. /salg viser omsetning, /regnskap
-- viser maaneden som er avsluttet. Ingen av dem svarer paa spoersmaalet
-- eieren faktisk stiller.
--
-- PRO-RATERINGEN ER POENGET. Halvveis i august er ikke halve budsjettet
-- brukt opp: maanedene er ujevne, og fellesferien gjor august spesielt
-- skjev. Forventningen hittil regnes derfor fra stasjonens EGEN fordeling
-- samme maaned i fjor - hvor stor andel av maanedens brutto som laa paa
-- dag 1 til i dag.
--
-- Mangler fjoraaret, faller den tilbake paa lineaert (dager gaatt /
-- dager i maaneden) og sier fra via kolonnen `grunnlag`, saa ingen leser
-- et anslag som en maaling.
--
-- Leser v_butikksalg, aldri daglig_salg: drivstoff er ~68 % av
-- omsetningen og hoerer ikke hjemme i noe som males mot butikkens BP.
create or replace view public.v_budsjettstatus
with (security_invoker = true) as
with siste as (
  -- Salgstallene er alltid gaarsdagens. Vi maaler mot den datoen vi
  -- faktisk har, ikke mot dagens dato.
  select max(dato) as dato,
         date_trunc('month', max(dato))::date as mnd_start
  from public.v_butikksalg
  where dato >= date_trunc('month', current_date)::date
),
hittil as (
  select v.stasjon_id,
         sum(v.bto_fortjeneste_kr) as brutto,
         sum(v.omsetning_eks_mva)  as omsetning
  from public.v_butikksalg v, siste s
  where v.dato between s.mnd_start and s.dato
  group by v.stasjon_id
),
ifjor as (
  -- Andelen av samme maaned i fjor som laa paa dag 1 .. samme dagnummer.
  select v.stasjon_id,
         sum(v.bto_fortjeneste_kr) filter (
           where extract(day from v.dato) <= extract(day from s.dato)
         ) / nullif(sum(v.bto_fortjeneste_kr), 0) as andel
  from public.v_butikksalg v, siste s
  where v.dato >= (s.mnd_start - interval '1 year')::date
    and v.dato <  ((s.mnd_start - interval '1 year') + interval '1 month')::date
  group by v.stasjon_id
)
select st.id                                   as stasjon_id,
       st.butikknummer,
       st.navn,
       s.dato                                  as til_og_med,
       h.brutto                                as brutto_hittil,
       h.omsetning                             as omsetning_hittil,
       b.brutto_bp_kr                          as bp_maned,
       -- Lineaert som reserve: dagnummer / dager i maaneden.
       coalesce(
         f.andel,
         extract(day from s.dato)
           / extract(day from (s.mnd_start + interval '1 month - 1 day'))
       )                                       as andel_av_maned,
       case when f.andel is not null then 'i fjor' else 'lineaert' end as grunnlag,
       b.brutto_bp_kr * coalesce(
         f.andel,
         extract(day from s.dato)
           / extract(day from (s.mnd_start + interval '1 month - 1 day'))
       )                                       as forventet_naa
from public.stasjoner st
cross join siste s
left join hittil h on h.stasjon_id = st.id
left join ifjor  f on f.stasjon_id = st.id
left join public.bemanning_budsjett b
       on b.stasjon_id = st.id
      and b.ar    = extract(year  from s.mnd_start)::int
      and b.maned = extract(month from s.mnd_start)::int
where st.slettet_tid is null;

comment on view public.v_budsjettstatus is
  'Brutto hittil i maaneden mot BP, pro-ratert etter stasjonens egen '
  'fordeling samme maaned i fjor. grunnlag sier om andelen er maalt '
  'eller lineaer reserve.';

grant select on public.v_budsjettstatus to authenticated;
