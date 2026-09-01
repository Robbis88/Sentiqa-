-- =====================================================================
-- Sentiqa 0159 - Svinn ut av hulltellingen
--
-- 0158 telte fire datasett likt. Foerste kjoering ga dette:
--
--   Laguneparken  Svinn      267 dager (155 hverdager)
--   Boenes        Svinn      215        (120)
--   Varden        Svinn      121         (24)
--   Dale          Svinn       30         (22)
--   Lone          Svinn       27         (16)
--   Laguneparken  Kasserer     2          (2)   <- ekte
--   Laguneparken  Timesalg     2          (2)   <- ekte
--
-- SVINN ER IKKE ET DAGLIG DATASETT. Det foeres NAAR noe kastes - mat
-- igjen ved stengetid - ikke hver dag. En dag uten svinnfoering er en
-- normal dag, ikke et hull. Salg, kasserer og timesalg kommer derimot
-- som en fil per dag og SKAL vaere komplette.
--
-- Konsekvensen var ikke bare stoey. Sorteringen er paa hverdager, saa de
-- 538 normale svinndagene sto OEVERST og skjoev de fire ekte funnene
-- under seg. Man maatte scrolle forbi stoeyen for aa finne saken.
--
-- Det er samme feilform som terskelen i rimelighetssjekken, som ogsaa
-- ble rettet i dag: en vakt som roper om det normale, blir ikke lest.
--
-- Svinn forsvinner ikke fra /dekning - maanedsrutenettet viser fortsatt
-- om det kom svinn den maaneden, og det er et meningsfullt spoersmaal.
-- Det er «manglende DAGER» som ikke gir mening for svinn.
-- =====================================================================

create or replace view public.v_datohull
with (security_invoker = true) as
with dager as (
  select generate_series(
           date_trunc('month', current_date) - interval '13 months',
           current_date - interval '1 day',
           interval '1 day'
         )::date as dato
),
st as (
  select id, retailer_id, butikknummer, navn
  from public.stasjoner
  where slettet_tid is null
),
-- Bare de datasettene som kommer EN FIL PER DAG. Se blokken over.
datasett (kode, navn) as (
  values ('daglig_salg', 'Salg'),
         ('kassererstatistikk', 'Kasserer'),
         ('timesalg', 'Timesalg')
),
har as (
  select 'daglig_salg'::text as kode, stasjon_id, dato
    from public.daglig_salg where slettet_tid is null and dato is not null
   group by stasjon_id, dato
  union all
  select 'kassererstatistikk', stasjon_id, dato
    from public.kassererstatistikk where slettet_tid is null and dato is not null
   group by stasjon_id, dato
  union all
  select 'timesalg', stasjon_id, dato
    from public.timesalg where slettet_tid is null and dato is not null
   group by stasjon_id, dato
),
hull as (
  select ds.kode, ds.navn as datasett_navn, st.retailer_id, st.id as stasjon_id,
         st.butikknummer, st.navn as stasjon_navn, d.dato
  from dager d
  cross join st
  cross join datasett ds
  left join har h on h.kode = ds.kode and h.stasjon_id = st.id and h.dato = d.dato
  where h.dato is null
)
select
  kode                                                     as datasett,
  datasett_navn,
  retailer_id,
  stasjon_id,
  butikknummer,
  stasjon_navn,
  count(*)::bigint                                         as hull,
  count(*) filter (
    where extract(dow from dato) not in (0, 6)
  )::bigint                                                as hull_hverdag,
  min(dato)                                                as forste,
  max(dato)                                                as siste,
  (array_agg(dato order by dato))[1:60]                    as datoer
from hull
group by kode, datasett_navn, retailer_id, stasjon_id, butikknummer, stasjon_navn;

comment on view public.v_datohull is
  'Manglende dager per datasett OG stasjon, 13 maaneder bakover. Bare '
  'datasett som kommer en fil per dag: salg, kasserer, timesalg. Svinn '
  'foeres naar noe kastes, ikke daglig, saa «manglende dager» gir ikke '
  'mening for det - se migrasjon 0159.';

grant select on public.v_datohull to authenticated;
revoke all on public.v_datohull from anon;
