-- =====================================================================
-- v_timeregnskap: timene er fortjent, ikke gitt
--
-- Kjores i CI etter migrasjonene. Kaster exception ved funn.
--
-- Testdataene er BOKSTAVELIG TALT Roberts to eksempler:
--
--   AVLAGT MAANED   budsjett 12 000 timer og 5 000 000 i BP-brutto.
--                   Regnskapet viser 4 800 000.
--                   -> opptjent 11 520. Brukt 12 000 -> 480 for mye.
--
--   AAPEN MAANED    kassen sier 48 000 brutto paa 55 % margin, men
--                   aarets realiserte margin er 50 %.
--                   -> realisert brutto settes til 43 000, ikke 48 000.
--
-- Det andre er hele poenget: kassens OMSETNING er god, kassens MARGIN
-- er ikke. Brukes kassens egen margin, overvurderer vi timene stasjonen
-- har rett paa - og den feilen peker mot aa bemanne for mye.
--
-- Alt i EN do-blokk, ryddet av en sentinel-exception.
-- =====================================================================
do $$
declare
  feil    int := 0;
  RET     constant uuid := 'dddddddd-0000-4000-8000-000000000001';
  STASJ   constant uuid := 'dddddddd-1111-4000-8000-000000000001';
  jan     constant date := date '2026-01-01';
  feb     constant date := date '2026-02-01';
  r       record;
begin
  if to_regclass('public.v_timeregnskap') is null then
    raise exception 'BLIND TEST: v_timeregnskap finnes ikke - er 0117/0121 kjort?';
  end if;

  begin
    insert into public.retailers (id, navn) values (RET, 'Timeregnskap-test');
    -- FAIL-CLOSED FRA 0152. `v_butikksalg` gir null rader til en kjede
    -- uten drivstofferklaering - ogsaa en fixture. Uten denne maaler
    -- fila ingenting, og hver paastand faller paa "ingen data" i stedet
    -- for paa det den skal maale.
    --
    -- Fixturen har ingen drivstoffrader, saa den aerlige erklaeringen er
    -- "ingen drivstoff". Den aapner alle rader og krever derfor kontroll;
    -- her ER testen Sentiqa.
    insert into public.retailer_kodeerklaering
      (retailer_id, rolle, gjelder, kontrollert_av, kontrollert_tid)
      values (RET, 'drivstoff', false, null, now());

    insert into public.stasjoner (id, retailer_id, butikknummer, navn, stasjonstype)
      values (STASJ, RET, '0003', 'Timebutikken', 'pendler');

    -- ============================================================
    -- JANUAR: avlagt. Roberts foerste eksempel, tall for tall.
    -- ============================================================
    -- BP-brutto 5 000 000, regnskapet viser 4 800 000.
    -- Regnskapsomsetningen settes til 9 600 000 -> realisert margin 50 %,
    -- som februar skal arve.
    insert into public.regnskapslinjer
      (retailer_id, stasjon_id, periode, seksjon, kode, post, regnskap, budsjett,
       avvik, index_pct, regnskap_hittil, budsjett_hittil)
    values
      (RET, STASJ, jan, 'bruttofortjeneste', '120', '120 Mat',
       4800000, 5000000, 0, 0, 0, 0),
      (RET, STASJ, jan, 'omsetning', '120', '120 Mat',
       9600000, 10000000, 0, 0, 0, 0);

    -- MAALESTOKKEN ER DET SOM FAKTISK DELES UT.
    -- bemanning_maned.disponible = rettigheten           -> 12 000
    -- bemanning_budsjett.timer   = for eierens fradrag   -> 12 600
    -- De er ULIKE med vilje: maaler viewet mot raatallet, blir
    -- opptjente timer 12 096 i stedet for 11 520, og testen feller.
    --
    -- Fradragene er eierens margin og deles ALDRI ut - de er der for
    -- loennsoekninger, overtid og det som maatte komme. Stasjonen ser
    -- dem aldri, saa rettigheten er disponible og ingenting annet.
    insert into public.bemanning_aar (stasjon_id, ar, timer_aar, fast_arsverk_timer)
      values (STASJ, 2026, 12000 * 12, 0);
    insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer)
      values (STASJ, 2026, 1, 12600);
    insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer)
      values (STASJ, 2026, 1, 12000);

    -- Brukt noeyaktig hele budsjettet: 12 000 timer.
    --
    -- `stempling` har INGEN retailer_id - stasjonen er noekkelen - og
    -- fra_tid/til_tid er paakrevd. Klokkeslettene er nominelle: viewet
    -- summerer `minutter`, ikke differansen mellom dem, saa en rad kan
    -- baere flere timer enn vinduet tilsier. Det er en fikstur, ikke en
    -- vakt som ble stemplet.
    insert into public.stempling
      (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter, betalt)
    values (STASJ, '1', 'Test Testesen', jan,
            time '08:00', time '16:00', 12000 * 60, true);

    select * into r from public.v_timeregnskap
    where stasjon_id = STASJ and maned = jan;

    if r.stasjon_id is null then
      raise warning 'ingen rad for januar';
      feil := feil + 1;
    else
      if r.grunnlag <> 'regnskap' then
        raise warning 'januar er avlagt, men grunnlag er %', r.grunnlag;
        feil := feil + 1;
      end if;
      if r.realisert_brutto_kr is distinct from 4800000 then
        raise warning 'realisert_brutto_kr er % - ventet 4800000 (regnskapet)',
          r.realisert_brutto_kr;
        feil := feil + 1;
      end if;

      -- SELVE REGELEN: 12 000 x (4,8 / 5,0) = 11 520.
      if r.opptjente_timer is distinct from 11520 then
        raise warning 'opptjente_timer er % - ventet 11520 (12000 x 4,8/5,0). '
                      'Er den 12000, deles ikke timene paa brutto i det hele '
                      'tatt - og da er timebudsjettet gitt, ikke fortjent.',
          r.opptjente_timer;
        feil := feil + 1;
      end if;
      if r.brukte_timer is distinct from 12000 then
        raise warning 'brukte_timer er % - ventet 12000', r.brukte_timer;
        feil := feil + 1;
      end if;
      if r.timer_over is distinct from 480 then
        raise warning 'timer_over er % - ventet 480', r.timer_over;
        feil := feil + 1;
      end if;
      -- 4 800 000 / 12 000 = 400 kr brutto per time. Budsjettert:
      -- 5 000 000 / 12 000 = 417.
      if r.brutto_per_time is distinct from 400 then
        raise warning 'brutto_per_time er % - ventet 400', r.brutto_per_time;
        feil := feil + 1;
      end if;
    end if;

    -- ============================================================
    -- LEDERDEKNINGEN LESES FRA FASTE VAKTER
    -- ============================================================
    -- 0086: `timelonnet = true` betyr «vakten er bundet, men belaster
    -- timerammen». Er ingen av stasjonens faste vakter fastloennede,
    -- holder ikke St1s antakelse om en fastloennet butikksjef - og
    -- aarsverket/12 legges tilbake.
    --
    -- Aarsverket settes til 1200 (ikke 1695) med vilje: 1200/12 = 100 er
    -- et rundt tall som ikke kan forveksles med noe annet i denne testen.
    update public.bemanning_aar set fast_arsverk_timer = 1200
     where stasjon_id = STASJ and ar = 2026;

    -- (1) INGEN FASTE VAKTER = UKJENT, IKKE «NEI».
    --     En stasjon som ikke har satt opp bemanning skal ikke faa 100
    --     timer i maaneden av en tom tabell.
    select * into r from public.v_timeregnskap
    where stasjon_id = STASJ and maned = jan;
    if r.lederdekning <> 'ukjent' then
      raise warning 'uten faste vakter er lederdekning % - ventet ukjent',
        r.lederdekning;
      feil := feil + 1;
    end if;
    if r.ramme_justering_timer is distinct from 0 then
      raise warning 'TOM TABELL GA TIMER: justeringen er % uten en eneste '
                    'fast vakt', r.ramme_justering_timer;
      feil := feil + 1;
    end if;
    if r.opptjente_timer is distinct from 11520 then
      raise warning 'opptjente_timer er % - ventet 11520 (uendret)',
        r.opptjente_timer;
      feil := feil + 1;
    end if;

    -- (2) FASTLOENNET VAKT -> St1s fratrekk holder, rammen staar.
    --     Dette er Bjoern paa Laguneparken: fastloennet, og selv om han
    --     er i permisjon staar vakten hans. Ingen timer gis bort.
    insert into public.bemanning_fast_vakt
      (stasjon_id, navn, ukedag, fra_time, til_time, timelonnet)
    values (STASJ, 'butikksjef', 1, 7, 15, false);

    select * into r from public.v_timeregnskap
    where stasjon_id = STASJ and maned = jan;
    if r.lederdekning <> 'fastlonnet' then
      raise warning 'med en fastloennet fast vakt er lederdekning % - '
                    'ventet fastlonnet', r.lederdekning;
      feil := feil + 1;
    end if;
    if r.ramme_justering_timer is distinct from 0 then
      raise warning 'fastloennet vakt ga likevel % timer',
        r.ramme_justering_timer;
      feil := feil + 1;
    end if;

    -- (3) BARE TIMELOENNEDE VAKTER -> aarsverket legges tilbake.
    --     Dette er Sissel paa Dale: butikksjef paa timeloenn, som selv
    --     belaster rammen St1 trakk hennes aarsverk fra.
    --     12 100 x 4,8/5,0 = 11 616
    update public.bemanning_fast_vakt set timelonnet = true
     where stasjon_id = STASJ;

    select * into r from public.v_timeregnskap
    where stasjon_id = STASJ and maned = jan;
    if r.lederdekning <> 'ikke_fastlonnet' then
      raise warning 'med bare timeloennede vakter er lederdekning % - '
                    'ventet ikke_fastlonnet', r.lederdekning;
      feil := feil + 1;
    end if;
    if r.ramme_justering_timer is distinct from 100 then
      raise warning 'justeringen er % - ventet 100 (1200/12)',
        r.ramme_justering_timer;
      feil := feil + 1;
    end if;
    if r.opptjente_timer is distinct from 11616 then
      raise warning 'opptjente_timer er % - ventet 11616 (12100 x 4,8/5,0)',
        r.opptjente_timer;
      feil := feil + 1;
    end if;
    if r.timer_over is distinct from 384 then
      raise warning 'timer_over er % - ventet 384', r.timer_over;
      feil := feil + 1;
    end if;

    -- (4) EN FASTLOENNET BLANT FLERE HOLDER. Stasjonen har en
    --     timeloennet NK OG en fastloennet butikksjef - da er
    --     fratrekket riktig, og ingenting legges tilbake.
    insert into public.bemanning_fast_vakt
      (stasjon_id, navn, ukedag, fra_time, til_time, timelonnet)
    values (STASJ, 'butikksjef', 2, 7, 15, false);

    select * into r from public.v_timeregnskap
    where stasjon_id = STASJ and maned = jan;
    if r.lederdekning <> 'fastlonnet' then
      raise warning 'en fastloennet blant flere ga lederdekning %',
        r.lederdekning;
      feil := feil + 1;
    end if;
    if r.ramme_justering_timer is distinct from 0 then
      raise warning 'justeringen er % naar en av vaktene er fastloennet',
        r.ramme_justering_timer;
      feil := feil + 1;
    end if;

    -- AARSVERKET FALLER TILBAKE PAA 1695 naar det ikke er satt. Uten
    -- reserven ville regelen vaert stum paa hver eneste stasjon i drift,
    -- for `fast_arsverk_timer` er 0 overalt og ingenting setter den.
    update public.bemanning_aar set fast_arsverk_timer = 0
     where stasjon_id = STASJ and ar = 2026;
    update public.bemanning_fast_vakt set timelonnet = true
     where stasjon_id = STASJ;

    select * into r from public.v_timeregnskap
    where stasjon_id = STASJ and maned = jan;
    if r.ramme_justering_timer is distinct from 141.25 then
      raise warning 'uten fast_arsverk_timer er justeringen % - ventet '
                    '141,25 (1695/12). Er den 0, er reserven borte og '
                    'regelen stum paa alle stasjoner i drift.',
        r.ramme_justering_timer;
      feil := feil + 1;
    end if;

    -- Ryddet, saa kontrollene under ser samme tall som foer.
    delete from public.bemanning_fast_vakt where stasjon_id = STASJ;

    -- ============================================================
    -- FEBRUAR: aapen. Roberts andre eksempel.
    -- ============================================================
    -- Kassen: 48 000 brutto paa 55 % margin -> omsetning 87 273.
    -- Aarets realiserte margin er 50 % (fra januar).
    -- Anslaget skal derfor bli 87 273 x 0,50 = 43 636 - IKKE 48 000.
    --
    -- Tallene er valgt slik at de to ikke kan forveksles: 43 636 mot
    -- 48 000 er 4 364 kroner fra hverandre.
    insert into public.regnskapslinjer
      (retailer_id, stasjon_id, periode, seksjon, kode, post, regnskap, budsjett,
       avvik, index_pct, regnskap_hittil, budsjett_hittil)
    values
      (RET, STASJ, feb, 'bp_bruttofortjeneste', '120', '120 Mat',
       0, 50000, 0, 0, 0, 0);

    insert into public.daglig_salg
      (retailer_id, stasjon_id, dato, ean, avdeling_kode, avdeling_navn,
       omsetning_eks_mva, bto_fortjeneste_kr)
    values (RET, STASJ, feb, 'ean-feb', '120', 'MAT', 87273, 48000);

    insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer)
      values (STASJ, 2026, 2, 1050);
    insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer)
      values (STASJ, 2026, 2, 1000);

    select * into r from public.v_timeregnskap
    where stasjon_id = STASJ and maned = feb;

    if r.stasjon_id is null then
      raise warning 'ingen rad for februar';
      feil := feil + 1;
    else
      if r.grunnlag <> 'anslag' then
        raise warning 'februar er ikke avlagt, men grunnlag er %', r.grunnlag;
        feil := feil + 1;
      end if;
      if r.realisert_margin_pst is distinct from 50.0 then
        raise warning 'realisert_margin_pst er % - ventet 50,0 fra januar',
          r.realisert_margin_pst;
        feil := feil + 1;
      end if;

      -- KJERNEN. 87 273 x 0,50 = 43 636 (avrundet), ikke kassens 48 000.
      if r.realisert_brutto_kr is distinct from 43637 then
        raise warning 'realisert_brutto_kr er % - ventet 43637 (kassens '
                      'omsetning 87273 x realisert margin 50 %%). Er den '
                      '48000, brukes KASSENS egen margin - og da '
                      'overvurderer vi timene stasjonen har rett paa.',
          r.realisert_brutto_kr;
        feil := feil + 1;
      end if;
      if r.kasse_omsetning_kr is distinct from 87273 then
        raise warning 'kasse_omsetning_kr er % - ventet 87273. Kassens tall '
                      'skal staa med, saa korreksjonen kan etterregnes.',
          r.kasse_omsetning_kr;
        feil := feil + 1;
      end if;

      -- 1000 x (43 637 / 50 000) = 873.
      if r.opptjente_timer is distinct from 873 then
        raise warning 'opptjente_timer er % - ventet 873. Er den 960, er '
                      'anslaget regnet med kassens margin.', r.opptjente_timer;
        feil := feil + 1;
      end if;
    end if;

    -- ============================================================
    -- INGEN REALISERT MARGIN -> INGEN ANSLAG
    -- ============================================================
    -- En stasjon uten en eneste avlagt maaned kan ikke faa et anslag.
    -- Falt vi tilbake paa BP-margen, ville anslaget blitt lik budsjettet
    -- per konstruksjon: stasjonen ville ligget noeyaktig i rute hver
    -- maaned, uansett drift. Det er verre enn ingen tall.
    if exists (
      select 1 from public.v_timeregnskap v
      where v.grunnlag = 'ukjent' and v.realisert_brutto_kr is not null
    ) then
      raise warning 'en rad uten realisert margin fikk likevel et brutto-tall';
      feil := feil + 1;
    end if;

    -- KANARIFUGL: gir viewet mer enn en grunnlagsverdi i det hele tatt?
    -- Returnerer det bare 'regnskap', ville februar-kontrollen over
    -- vaert trivielt gronn paa en rad som ikke fantes.
    if (select count(distinct grunnlag) from public.v_timeregnskap
        where stasjon_id = STASJ) < 2 then
      raise warning 'BLIND TEST: viewet ga bare en grunnlagsverdi for '
                    'testdata som dekker bade avlagt og aapen maaned';
      feil := feil + 1;
    end if;

    raise exception 'RULL_TILBAKE';
  exception
    when others then
      if sqlerrm <> 'RULL_TILBAKE' then raise; end if;
  end;

  if feil > 0 then
    raise exception 'v_timeregnskap: % funn. Se advarslene over.', feil;
  end if;
  raise notice '--- v_timeregnskap: timene er fortjent, ikke gitt ---';
end $$;
