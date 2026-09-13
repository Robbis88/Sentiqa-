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
  -- 2) «40 CR» ER BUTIKKTOTALEN, OG DEN SKAL IKKE MED
  --
  -- FOERSTE UTGAVE AV DENNE KONTROLLEN VAR FEIL, og den ble roed
  -- foerste gang den kjoerte - 2026-09-13, maaneder etter at den ble
  -- skrevet. Den lette etter drivstofflinjer paa `kode = '10'` og
  -- konkluderte med at noe var borte da den ikke fant dem.
  --
  -- Maalt i produksjon: **drivstoff finnes ikke i `regnskapslinjer` i
  -- det hele tatt.** Omsetningsseksjonen per stasjon er ren butikk:
  --
  --     40 CR   5 928 970      <- TOTALEN, ikke en avdeling
  --    120 Mat  1 936 773
  --    180 …      912 983
  --    …
  --    sum av avdelingene 5 928 749  (= 40 CR, paa avrunding naer)
  --
  -- `'10'` i `UTELAT_KODER` har derfor aldri truffet en eneste rad her.
  -- Det er samme doede filterarm som AGENTS.md beskriver for `ENERGI` i
  -- salgsdataene, og den staar igjen fordi en ubrukt verdi i et sett er
  -- ufarlig - mens en fjerning kan treffe en kjede vi ikke har maalt.
  --
  -- DEN EKTE RISIKOEN ER `40`. Kommer totalen med ved siden av
  -- avdelingene, DOBLES omsetningen i hver maanedsplan. Det er den
  -- kontrollen som hoerer hjemme her.
  -- -------------------------------------------------------------------
  select sum(l.regnskap) filter (where l.kode = '40')                    as cr,
         sum(l.regnskap) filter (where l.kode <> '40')                   as avdelinger,
         sum(l.regnskap) filter (where l.kode = '250')                   as pant,
         (select sum(v.omsetning_kr) from public.v_kurs_maanedstall v
           where v.maaned = date '2026-07-01')                           as i_viewet
    into f
    from public.regnskapslinjer l
   where l.periode = date '2026-07-01'
     and l.seksjon = 'omsetning'
     and l.kode is not null
     and l.stasjon_id is not null
     and l.slettet_tid is null;

  -- KANARI: finnes totalen i det hele tatt? Flytter St1 den, maaler
  -- kontrollen under ingenting - og da skal proben si fra, ikke tie.
  if coalesce(f.cr, 0) = 0 then
    raise exception
      'SONDE: fant ingen «40 CR»-linjer for juli. Da maaler kontrollen '
      'under ingenting - sjekk om St1 har flyttet koden, og se '
      'SKJUL_OMS_KODER i avdelingene.';
  end if;

  -- Viewet skal vaere avdelingene MINUS pant - altsaa verken med
  -- totalen eller med pant.
  if abs(f.i_viewet - (f.avdelinger - coalesce(f.pant, 0))) > 5 then
    avvik := avvik || format(
      'omsetningen i viewet stemmer ikke: view %s, avdelinger minus pant %s',
      round(f.i_viewet), round(f.avdelinger - coalesce(f.pant, 0)));
  end if;

  -- Og det harde symptomet, paa egne bein: kom totalen med, ville
  -- viewet vaert omtrent det dobbelte av den.
  if f.i_viewet > f.cr then
    avvik := avvik || format(
      '«40 CR» er kommet INN i omsetningen: view %s mot total %s',
      round(f.i_viewet), round(f.cr));
  end if;

  raise notice 'SONDE: 40 CR juli % kr, holdt utenfor. Viewet gir % kr.',
    round(f.cr), round(f.i_viewet);

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
