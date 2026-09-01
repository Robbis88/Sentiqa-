-- =====================================================================
-- Sentiqa 0158 - Datahull PER STASJON
--
-- HVORFOR
--
-- `v_datodekning` (0059) grupperer paa (retailer_id, dato). Har fire av
-- fem stasjoner data en dag, staar dagen groenn selv om den femte
-- mangler. /dekning finnes for aa svare paa «kan jeg stole paa
-- analysene?», og paa stasjonsnivaa kunne den ikke det.
--
-- Laguneparken manglet 26. og 27. august 2026. /dekning viste ingen
-- hull. Robert oppdaget det ved aa sammenligne en maanedsfil fra St1 mot
-- Sentiqa for haand.
--
-- HVORFOR HULL OG IKKE DEKNING
--
-- Aa legge `stasjon_id` inn i det gamle viewet var det aapenbare - og
-- ville brutt noe annet. Kommentaren i 0059 sier «~430 rader hver ->
-- under 1000-grensen»; med fem stasjoner blir det ~2150 per datasett, og
-- PostgREST kutter stille ved 1000. Siden ville da vist FAERRE hull enn
-- det finnes, som er verre enn i dag.
--
-- Dette viewet returnerer hullene i stedet, aggregert per (datasett,
-- stasjon). Det er fire datasett ganger antall stasjoner - tjue rader
-- for Kelsar - uansett hvor mange hull det er. Og det er svaret siden
-- skal gi, ikke raadataene den skal regne det ut av.
--
-- `datoer` er kappet paa 60. En stasjon med flere enn 60 hull i et
-- datasett har ikke et hull, den har et systemproblem, og da er tallet
-- `hull` beskjeden - ikke lista.
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
datasett (kode, navn) as (
  values ('daglig_salg', 'Salg'),
         ('kassererstatistikk', 'Kasserer'),
         ('timesalg', 'Timesalg'),
         ('synlig_svinn', 'Svinn')
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
  union all
  select 'synlig_svinn', stasjon_id, dato
    from public.synlig_svinn where slettet_tid is null and dato is not null
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
  -- Soendager og helligdager kan vaere ekte stengt. En rekke HVERDAGER
  -- hos en stasjon er derimot alltid en import som mangler.
  count(*) filter (
    where extract(dow from dato) not in (0, 6)
  )::bigint                                                as hull_hverdag,
  min(dato)                                                as forste,
  max(dato)                                                as siste,
  (array_agg(dato order by dato))[1:60]                    as datoer
from hull
group by kode, datasett_navn, retailer_id, stasjon_id, butikknummer, stasjon_navn;

comment on view public.v_datohull is
  'Manglende dager per datasett OG stasjon, 13 maaneder bakover. '
  'Erstatter v_datodekning som svar paa /dekning: den grupperte paa '
  'kjede, saa et hull hos en stasjon var usynlig naar de andre hadde '
  'dagen. Se migrasjon 0158.';

grant select on public.v_datohull to authenticated;
revoke all on public.v_datohull from anon;
