-- =====================================================================
-- SONDE: v_kurs_maanedstall MOT EKTE TALL
-- =====================================================================
-- `0205` flyttet summeringen fra TypeScript til basen, fordi app-laget
-- hentet 1 563 raa rader med et tak paa 7 200 og PostgREST kutter paa
-- tusen UTEN aa feile. Siste maaned falt utenfor, og maanedsplanene sto
-- med 0 kroner paa hver stasjon mens tallene laa i basen.
--
-- Prisen var at aritmetikken ikke lenger kan kjoeres i vitest. Den
-- dekningen var ekte, og den erstattes her: fasiten under er lest RETT
-- UT AV julifila med parseren, med noeyaktig de samme reglene viewet
-- bruker - drivstoff (10), pant (250) og «40 CR» utenfor, personal og
-- drift paa BEGREP.
--
-- Kilde: `190 Kelsar Bil AS 202607-202607(1).xlsx`, malt 2026-09-12.
--
-- LES KUN. Trygg i produksjon. Kaster exception ved avvik.
--
-- Toleranse 1 krone: viewet runder i numeric, parseren i float64.
-- =====================================================================

do $$
declare
  r          record;
  f          record;
  avvik      text[] := '{}';
  antall     bigint;
  siste      date;
  -- Fasiten. Butikknummer, og de seks tallene viewet skal gi for juli.
  fasit      text[][] := array[
    array['4177', '1006494.10', '1160911.55', '509204.28', '300525.64', '34631.58', '-10200.97'],
    array['4185', '1799649.80', '1857223.46', '943176.12', '451349.68', '28325.59', '63246.02'],
    array['9038', '1562134.54', '1676834.53', '747599.37', '413162.32', '46861.89', '-53151.88'],
    array['9145', '847941.98',  '872387.47',  '473306.50', '314258.94', '26251.37', '36990.81'],
    array['9467', '669514.13',  '764461.40',  '349281.23', '246822.06', '-13965.90', '42254.26']
  ];
begin
  -- -------------------------------------------------------------------
  -- 0) VIEWET FINNES OG GIR RADER. En tom sonde beviser ingenting.
  -- -------------------------------------------------------------------
  select count(*), max(maaned) into antall, siste from public.v_kurs_maanedstall;
  if antall = 0 then
    raise exception 'SONDE: v_kurs_maanedstall er tom. Ingenting kan maales.';
  end if;
  raise notice 'SONDE: % rader, siste maaned %', antall, siste;

  -- -------------------------------------------------------------------
  -- 1) JULI 2026 MOT FASITEN
  -- -------------------------------------------------------------------
  for i in 1 .. array_length(fasit, 1) loop
    select v.*, s.butikknummer into r
      from public.v_kurs_maanedstall v
      join public.stasjoner s on s.id = v.stasjon_id
     where v.maaned = date '2026-07-01'
       and s.butikknummer = fasit[i][1];

    if not found then
      avvik := avvik || format('%s: ingen rad for juli 2026', fasit[i][1]);
      continue;
    end if;

    if abs(r.omsetning_kr - fasit[i][2]::numeric) > 1 then
      avvik := avvik || format('%s omsetning: %s, forventet %s',
        fasit[i][1], round(r.omsetning_kr), fasit[i][2]);
    end if;
    if abs(r.omsetning_budsjett_kr - fasit[i][3]::numeric) > 1 then
      avvik := avvik || format('%s omsetningsbudsjett: %s, forventet %s',
        fasit[i][1], round(r.omsetning_budsjett_kr), fasit[i][3]);
    end if;
    if abs(r.brutto_kr - fasit[i][4]::numeric) > 1 then
      avvik := avvik || format('%s brutto: %s, forventet %s',
        fasit[i][1], round(r.brutto_kr), fasit[i][4]);
    end if;
    if abs(r.personal_kr - fasit[i][5]::numeric) > 1 then
      avvik := avvik || format('%s personal: %s, forventet %s',
        fasit[i][1], round(r.personal_kr), fasit[i][5]);
    end if;
    if abs(r.paavirkbar_drift_kr - fasit[i][6]::numeric) > 1 then
      avvik := avvik || format('%s paavirkbar drift: %s, forventet %s',
        fasit[i][1], round(r.paavirkbar_drift_kr), fasit[i][6]);
    end if;
    if abs(r.resultat_kr - fasit[i][7]::numeric) > 1 then
      avvik := avvik || format('%s resultat: %s, forventet %s',
        fasit[i][1], round(r.resultat_kr), fasit[i][7]);
    end if;
  end loop;

  -- -------------------------------------------------------------------
  -- 2) DRIVSTOFF ER UTENFOR, OG DET SKAL MAALES - IKKE ANTAS
  --
  -- Drivstoff er ~68 % av omsetningen. Kom den med, ville hver av
  -- summene over vaert flere ganger for hoey - saa punkt 1 fanger det.
  -- Men den fanger det bare saa lenge fasiten er riktig, og denne
  -- kontrollen staar paa egne bein: raadataene for kode 10 skal vaere
  -- STORE, og viewet skal likevel vaere lite.
  -- -------------------------------------------------------------------
  select sum(l.regnskap) as drivstoff,
         (select sum(v.omsetning_kr) from public.v_kurs_maanedstall v
           where v.maaned = date '2026-07-01') as i_viewet
    into f
    from public.regnskapslinjer l
   where l.periode = date '2026-07-01'
     and l.seksjon = 'omsetning'
     and l.kode = '10'
     and l.stasjon_id is not null
     and l.slettet_tid is null;

  if coalesce(f.drivstoff, 0) = 0 then
    raise exception
      'SONDE: fant ingen drivstofflinjer (kode 10) for juli. Da maaler '
      'kontrollen under ingenting - sjekk om St1 har flyttet koden, og '
      'se omsetningsvakt.ts.';
  end if;
  if f.i_viewet > f.drivstoff then
    avvik := avvik || format(
      'drivstoff er kommet INN i omsetningen: view %s mot drivstoff %s',
      round(f.i_viewet), round(f.drivstoff));
  end if;
  raise notice 'SONDE: drivstoff juli % kr, holdt utenfor. Viewet gir % kr.',
    round(f.drivstoff), round(f.i_viewet);

  -- -------------------------------------------------------------------
  -- 3) INGEN MAANED MED TALL SKAL STAA MED NULL OMSETNING
  --
  -- Det var symptomet: siste maaned tom fordi svaret var avkortet.
  -- -------------------------------------------------------------------
  select count(*) into antall
    from public.v_kurs_maanedstall
   where omsetning_kr = 0 and resultat_kr = 0 and matkast_kr = 0;
  if antall > 0 then
    raise notice 'SONDE: % rader er helt tomme - se om en maaned mangler stasjonsark', antall;
  end if;

  -- -------------------------------------------------------------------
  if array_length(avvik, 1) > 0 then
    raise exception E'SONDE FEILET:\n  %', array_to_string(avvik, E'\n  ');
  end if;
  raise notice 'SONDE: v_kurs_maanedstall stemmer med julifila paa alle fem stasjoner.';
end $$;
