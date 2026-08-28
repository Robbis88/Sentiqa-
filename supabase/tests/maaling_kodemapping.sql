-- =====================================================================
-- YTELSESMAALING FOER VIEWFORMEN LAASES
--
-- `v_butikksalg` skal slutte aa filtrere paa litteraler og begynne aa
-- lese en mapping per retailer. Formen paa det filteret er den stoerste
-- risikoen i P0: to korrelerte subspoerringer per rad paa en partisjonert
-- tabell er noeyaktig formen som slo ut `daglig_salg` 2026-06-16 -
-- `statement timeout`, null rader, ser ut som datatap.
--
-- Denne fila velger ikke form. Den maaler tre, og lar tallene velge.
--
-- ---------------------------------------------------------------------
-- TRYGG I PRODUKSJON
--
-- Ingen permanente objekter. Tabellene er TEMP og forsvinner naar oekten
-- lukkes. Ingen skriving mot noen produksjonstabell. `explain analyze`
-- KJOERER spoerringen, men alle tre er rene `select`.
--
-- TAR TID: den brede arbeidsmengden skanner 400 dager x alle stasjoner,
-- tre ganger, og hver av dem kjoeres to ganger (en for explain, en for
-- likhetssjekken). Regn med noen minutter.
--
-- ---------------------------------------------------------------------
-- DE TRE VARIANTENE
--
--   A  LITTERAL     dagens form. Referansen alt maales mot.
--   B  NOT EXISTS   korrelert subspoerring, formen i skissen.
--   C  ANTI-JOIN    `left join ... where r.id is null`, som planleggeren
--                   kan hashe.
--
-- ---------------------------------------------------------------------
-- TO ARBEIDSMENGDER
--
--   SMAL   en stasjon, en maaned. Formen /salg og /produksjonsplan har.
--   BRED   alle stasjoner, 400 dager. Formen `beregn_vaerprofil` har -
--          og det er den som ville timet ut foerst.
--
-- ---------------------------------------------------------------------
-- KANARIFUGL: GIR DE SAMME SVAR?
--
-- En rask variant som returnerer feil rader er verdiloes. Seksjonen
-- LIKHET kjoerer alle tre som vanlige aggregater og sammenligner sum og
-- radantall. **Les den foerst.** Er de ulike, betyr tidene ingenting.
-- =====================================================================

create temp table maal_erklaering (
  retailer_id uuid primary key,
  gjelder     boolean not null
) on commit preserve rows;

create temp table maal_regel (
  id          bigserial primary key,
  retailer_id uuid  not null,
  rolle       text  not null,
  nivaa       text  not null,
  kode        text,
  navn        text
) on commit preserve rows;

create index on maal_regel (retailer_id, rolle, nivaa);

-- Alle kjeder erklaerer at de har drivstoff, med Kelsars faktiske regler.
insert into maal_erklaering select id, true from public.retailers;

insert into maal_regel (retailer_id, rolle, nivaa, kode, navn)
select r.id, 'drivstoff', 'avdeling', k.kode, k.navn
from public.retailers r,
     (values ('1000', null::text), (null::text, 'ENERGI')) k(kode, navn);

insert into maal_regel (retailer_id, rolle, nivaa, kode, navn)
select r.id, 'produksjon', 'varegruppe', k, null
from public.retailers r,
     unnest(array['1201','1202','1203','1216','1217','1218','1219','1221']) k;

analyze maal_erklaering;
analyze maal_regel;

create temp table maaling (
  nr        serial,
  arbeid    text,
  variant   text,
  plan_ms   numeric,
  kjor_ms   numeric,
  toppnode  text
) on commit preserve rows;

create temp table likhet (
  arbeid  text, variant text, rader bigint, sum_oms numeric
) on commit preserve rows;

do $$
declare
  v_stasjon uuid;
  v_smal    text;
  v_bred    text;
  v_hvor    text;
  j         json;
  a         record;
begin
  select id into v_stasjon from public.stasjoner
  where slettet_tid is null order by butikknummer limit 1;

  v_smal := format('d.stasjon_id = %L and d.dato between date ''2026-07-01'' '
                   'and date ''2026-07-31''', v_stasjon);
  v_bred := 'd.dato >= current_date - interval ''400 days''';

  for a in
    select * from (values
      ('SMAL', v_smal), ('BRED', v_bred)
    ) w(arbeid, hvor)
    cross join (values
      ('A LITTERAL',
       'coalesce(d.avdeling_kode,'''') <> ''10''
        and upper(coalesce(d.avdeling_navn,'''')) <> ''ENERGI'''),
      ('B NOT EXISTS',
       'exists (select 1 from maal_erklaering e where e.retailer_id = d.retailer_id)
        and not exists (select 1 from maal_regel r
              where r.retailer_id = d.retailer_id and r.rolle = ''drivstoff''
                and r.nivaa = ''avdeling''
                and ((r.kode is not null and r.kode = d.avdeling_kode)
                  or (r.navn is not null
                      and upper(r.navn) = upper(coalesce(d.avdeling_navn,'''')))))'),
      ('C ANTI-JOIN', null::text)
    ) v(variant, filter)
  loop
    if a.variant = 'C ANTI-JOIN' then
      v_hvor := format(
        'select count(*) as rader, coalesce(sum(d.omsetning_eks_mva),0) as oms
         from public.daglig_salg d
         join maal_erklaering e on e.retailer_id = d.retailer_id
         left join maal_regel r
           on r.retailer_id = d.retailer_id and r.rolle = ''drivstoff''
          and r.nivaa = ''avdeling''
          and ((r.kode is not null and r.kode = d.avdeling_kode)
            or (r.navn is not null
                and upper(r.navn) = upper(coalesce(d.avdeling_navn,''''))))
         where d.slettet_tid is null and r.id is null and %s', a.hvor);
    else
      v_hvor := format(
        'select count(*) as rader, coalesce(sum(d.omsetning_eks_mva),0) as oms
         from public.daglig_salg d
         where d.slettet_tid is null and %s and %s', a.hvor, a.filter);
    end if;

    execute 'explain (analyze, buffers, format json) ' || v_hvor into j;
    insert into maaling (arbeid, variant, plan_ms, kjor_ms, toppnode)
    values (a.arbeid, a.variant,
            round((j->0->>'Planning Time')::numeric, 1),
            round((j->0->>'Execution Time')::numeric, 1),
            j->0->'Plan'->>'Node Type');

    -- Samme spoerring uten explain: gir variantene samme svar?
    execute 'insert into likhet select ' || quote_literal(a.arbeid) || ', '
            || quote_literal(a.variant) || ', rader, oms from (' || v_hvor || ') x';
  end loop;
end $$;

select 'TID'::text as seksjon,
       (m.arbeid || ' | ' || m.variant)::text as noekkel,
       ('kjoring=' || m.kjor_ms || ' ms'
         || ' planlegging=' || m.plan_ms || ' ms'
         || ' toppnode=' || m.toppnode)::text as verdi
from maaling m
union all
select 'LIKHET',
       (l.arbeid || ' | ' || l.variant),
       ('rader=' || l.rader || ' sum_oms=' || round(l.sum_oms, 2))
from likhet l
union all
select 'KANARIFUGL', 'gir de tre variantene samme svar',
       case when count(distinct (rader::text || '|' || round(sum_oms,2)::text)) = 1
            then 'JA - alle tre er enige. Tidene kan sammenlignes.'
            else 'NEI - VARIANTENE GIR ULIKE SVAR. En rask variant som '
                 || 'returnerer feil rader er verdiloes. Tidene under betyr '
                 || 'ingenting foer dette er rettet.' end
from likhet where arbeid = 'SMAL'
union all
select 'KANARIFUGL', 'maalte den noe i det hele tatt',
       case when max(rader) > 0 then 'JA - ' || max(rader) || ' rader i det smale uttrekket'
            else 'NEI - INGEN RADER. Feil stasjon eller feil maaned.' end
from likhet where arbeid = 'SMAL'
order by 1 desc, 2;
