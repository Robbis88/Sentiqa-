-- =====================================================================
-- 0213  EN MAANED UTEN SVINNDATA ER IKKE EN MAANED UTEN SVINN
-- =====================================================================
-- `0210` avsluttet `v_kurs_maanedstall` med:
--
--     coalesce(s.matkast_kr, 0)      as matkast_kr,
--     coalesce(s.usynlig_rest_kr, 0) as usynlig_rest_kr
--
-- og joinet svinn med `left join`, der REGNSKAPET avgjoer om maaneden
-- finnes. Det var riktig for alt annet i viewet: en stasjon som staar i
-- regnskapsfila med bare nuller HAR hatt en maaned.
--
-- Men svinnarket foelger ikke regnskapet. Desemberfila 2025 er i eldre
-- rapportformat og har ingen svinnrader i det hele tatt - kvitteringen
-- fra `0208` sa `eldste = 2026-01-01`.
--
-- Maalt i produksjon 2026-09-13:
--
--     des 2025   matomsetning   matkast   svinnrader
--     Dale          511 258        0          0
--     Laguneparken  377 406        0          0
--     Lone          273 865        0          0
--     Varden        174 860        0          0
--     Boenes        121 185        0          0
--
-- `coalesce` gjorde fem manglende maaneder til fem perfekte maaneder.
-- Kastprosenten ville blitt 0,0 % paa hver stasjon, og enhver trend ut
-- av desember ville vist en kraftig forverring inn i januar - fra et
-- nullpunkt som aldri ble maalt.
--
-- ---------------------------------------------------------------------
-- KONTRAKTEN
--
--   har_svinndata = false  ->  matkast_kr og usynlig_rest_kr er NULL
--   har_svinndata = true   ->  begge er tall, og 0 betyr NULL KRONER
--
-- Forskjellen mellom «kastet ingenting» og «vi vet ikke» er hele
-- poenget. Se `sentiqa-usynlig-fortegn` og husregelen: manglende data
-- skal ikke skjules med 0.
--
-- `datastatus` foelger med ut, saa en leser kan se om maaneden staar paa
-- gruppe- eller produktnivaa uten aa slaa opp selv.
--
-- ---------------------------------------------------------------------
-- HVA SOM IKKE ENDRES
--
-- Januar-juli 2026: bit for bit like. De 35 stasjonsmaanedene har alle
-- 55-61 svinnrader, saa `har_svinndata` er `true` og tallene gaar
-- uendret gjennom. Kvitteringen nederst beviser det.
--
-- De oevrige kolonnene beholder sin `coalesce(..., 0)`. De kommer fra
-- regnskapet, som ER kilden til at maaneden finnes.
--
-- ---------------------------------------------------------------------
-- `0210` REDIGERES IKKE. Den er kjoert mot produksjon, og en kjoert
-- migrasjon endres aldri. Denne definerer viewet paa nytt.
--
-- KOLONNER LEGGES TIL, saa `create or replace view` er ikke nok -
-- Postgres tillater bare tillegg PAA SLUTTEN, og det er nettopp det vi
-- gjoer. `security_invoker` settes eksplisitt: en `create or replace`
-- uten klausulen nullstiller flagget i stillhet (0130, vakthund punkt 9).
--
-- Idempotent: `create or replace`, og kvitteringen er rent lesende.
-- =====================================================================

create or replace view public.v_kurs_maanedstall
with (security_invoker = true) as
with linjer as (
  select
    l.retailer_id,
    l.stasjon_id,
    date_trunc('month', l.periode)::date as maaned,
    sum(l.regnskap) filter (
      where l.seksjon = 'omsetning'
        and l.kode is not null
        and l.kode not in ('10', '250', '40')
        and l.kode not like '250%'
    ) as omsetning_kr,
    sum(l.budsjett) filter (
      where l.seksjon = 'omsetning'
        and l.kode is not null
        and l.kode not in ('10', '250', '40')
        and l.kode not like '250%'
    ) as omsetning_budsjett_kr,
    sum(l.regnskap) filter (
      where l.seksjon = 'bruttofortjeneste'
        and l.kode is not null
        and l.kode not in ('10', '250', '40')
        and l.kode not like '250%'
    ) as brutto_kr,
    sum(l.regnskap) filter (
      where l.seksjon = 'omsetning' and l.kode like '12%'
    ) as matsalg_kr,
    sum(l.regnskap) filter (
      where l.seksjon = 'driftskostnader' and l.begrep = any (array[
        'faste_lonninger', 'lonnstillegg', 'timelonn', 'sykelonn',
        'refundert_sykelonn', 'palopte_feriepenger', 'bonus',
        'arbeidsgiveravgift_lonn', 'arbeidsgiveravgift_feriepenger',
        'andre_personalkostnader'
      ])
    ) as personal_kr,
    sum(l.budsjett) filter (
      where l.seksjon = 'driftskostnader' and l.begrep = any (array[
        'faste_lonninger', 'lonnstillegg', 'timelonn', 'sykelonn',
        'refundert_sykelonn', 'palopte_feriepenger', 'bonus',
        'arbeidsgiveravgift_lonn', 'arbeidsgiveravgift_feriepenger',
        'andre_personalkostnader'
      ])
    ) as personal_budsjett_kr,
    sum(l.regnskap) filter (
      where l.seksjon = 'driftskostnader' and l.begrep = any (array[
        'renhold', 'renhold_og_renovasjon', 'renovasjon', 'broyting',
        'utstyr_verktoy', 'forbruksmateriell', 'rep_vedlikehold',
        'pengehandtering', 'kontorrekvisita', 'kassedifferanse'
      ])
    ) as paavirkbar_drift_kr,
    sum(l.budsjett) filter (
      where l.seksjon = 'driftskostnader' and l.begrep = any (array[
        'renhold', 'renhold_og_renovasjon', 'renovasjon', 'broyting',
        'utstyr_verktoy', 'forbruksmateriell', 'rep_vedlikehold',
        'pengehandtering', 'kontorrekvisita', 'kassedifferanse'
      ])
    ) as paavirkbar_drift_kr_budsjett,
    sum(l.regnskap) filter (where l.seksjon = 'resultat') as resultat_kr
  from public.regnskapslinjer l
  where l.stasjon_id is not null
    and l.slettet_tid is null
    and l.seksjon in (
      'omsetning', 'bruttofortjeneste', 'driftskostnader', 'resultat'
    )
  group by l.retailer_id, l.stasjon_id, date_trunc('month', l.periode)
),
svinn as (
  -- FRA `v_svinn_grunnlag` (0210): ett nivaa per stasjonsmaaned.
  -- `count(*)` er beviset paa at grunnlaget finnes i det hele tatt -
  -- en `sum()` over null rader gir NULL, som er umulig aa skille fra
  -- en sum som tilfeldigvis ble null uten telleren ved siden av.
  select
    s.retailer_id,
    s.stasjon_id,
    date_trunc('month', s.periode)::date as maaned,
    count(*)                                   as svinnrader,
    -- `max` fordi aggregatet krever ett uttrykk. `datastatus` er
    -- konstant innenfor en stasjonsmaaned ved konstruksjon: viewet
    -- setter den av `bool_or(nivaa = 'gruppe')` per samme gruppering.
    max(s.datastatus)                          as datastatus,
    coalesce(sum(s.kast) filter (where s.kode like '12%'), 0) as matkast_kr,
    coalesce(sum(s.usynlig_kr) filter (
      where s.kode is null
         or (s.kode not like '12%' and s.kode not like '21%' and s.kode not like '250%')
    ), 0)                                      as usynlig_rest_kr
  from public.v_svinn_grunnlag s
  where s.stasjon_id is not null
    and s.slettet_tid is null
  group by s.retailer_id, s.stasjon_id, date_trunc('month', s.periode)
)
select
  l.retailer_id,
  l.stasjon_id,
  l.maaned,
  coalesce(l.omsetning_kr, 0)                 as omsetning_kr,
  coalesce(l.omsetning_budsjett_kr, 0)        as omsetning_budsjett_kr,
  coalesce(l.brutto_kr, 0)                    as brutto_kr,
  coalesce(l.matsalg_kr, 0)                   as matsalg_kr,
  coalesce(l.personal_kr, 0)                  as personal_kr,
  coalesce(l.personal_budsjett_kr, 0)         as personal_budsjett_kr,
  coalesce(l.paavirkbar_drift_kr, 0)          as paavirkbar_drift_kr,
  coalesce(l.paavirkbar_drift_kr_budsjett, 0) as paavirkbar_drift_budsjett_kr,
  coalesce(l.resultat_kr, 0)                  as resultat_kr,
  -- INGEN COALESCE. Null her betyr «ingen svinnrader for denne
  -- stasjonsmaaneden», og det er et annet svar enn null kroner.
  s.matkast_kr,
  s.usynlig_rest_kr,
  -- NYE KOLONNER, lagt til paa slutten.
  (s.svinnrader is not null and s.svinnrader > 0) as har_svinndata,
  s.datastatus
from linjer l
left join svinn s
  on  s.retailer_id = l.retailer_id
  and s.stasjon_id  = l.stasjon_id
  and s.maaned      = l.maaned;

grant select on public.v_kurs_maanedstall to authenticated;
revoke all on public.v_kurs_maanedstall from anon;

comment on view public.v_kurs_maanedstall is
  'Maanedstall per stasjon. matkast_kr og usynlig_rest_kr er NULL naar '
  'stasjonsmaaneden ikke har svinnrader - se har_svinndata. 0 betyr '
  'null kroner, aldri manglende data.';

-- ---------------------------------------------------------------------
-- KVITTERING. `raise notice` er usynlig i SQL Editor, saa dette er en
-- select. Rent lesende.
-- ---------------------------------------------------------------------
select
  case
    when (select count(*) from public.v_kurs_maanedstall) = 0
      then 'INGEN DATA - MIGRASJONEN KAN IKKE KONTROLLERES'
    when (select count(*) from public.v_kurs_maanedstall
           where not har_svinndata and matkast_kr is not null) > 0
      then 'FEIL: matkast_kr er utfylt uten svinndata'
    when (select count(*) from public.v_kurs_maanedstall
           where har_svinndata and matkast_kr is null) > 0
      then 'FEIL: svinndata finnes, men matkast_kr er null'
    else 'OK'
  end                                                          as dom,
  (select count(*) from public.v_kurs_maanedstall)             as rader,
  (select count(*) from public.v_kurs_maanedstall
    where har_svinndata)                                       as med_svinndata,
  (select count(*) from public.v_kurs_maanedstall
    where not har_svinndata)                                   as uten_svinndata,
  (select count(*) from public.v_kurs_maanedstall
    where matkast_kr is null)                                  as matkast_null,
  (select count(*) from public.v_kurs_maanedstall
    where matkast_kr = 0)                                      as matkast_null_kroner,
  (select round(sum(matkast_kr)) from public.v_kurs_maanedstall
    where maaned >= date '2026-01-01' and maaned <= date '2026-07-01')
                                                               as matkast_jan_jul,
  (select round(sum(matsalg_kr)) from public.v_kurs_maanedstall
    where maaned >= date '2026-01-01' and maaned <= date '2026-07-01')
                                                               as matsalg_jan_jul;
