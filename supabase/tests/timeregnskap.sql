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
    raise exception 'BLIND TEST: v_timeregnskap finnes ikke - er 0117-0120 kjort?';
  end if;

  begin
    insert into public.retailers (id, navn) values (RET, 'Timeregnskap-test');
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
    -- RAMMEN JUSTERES BARE AV ET TALL EIEREN HAR SATT
    -- ============================================================
    -- St1 trakk fra ett aarsverk fordi de antok fastloenn. Holder ikke
    -- antakelsen, KAN eieren legge timer tilbake - men det er en
    -- beslutning, ikke en konsekvens.
    --
    -- `fast_arsverk_timer` settes til 1200 her, og det er med vilje at
    -- den IKKE lenger paavirker noe: 1200/12 = 100 ville vaert den
    -- automatiske justeringen i 0119. Ser vi 100 eller 11 616 i
    -- kontrollene under uten at noen har satt `timer_tilbake`, er
    -- automatikken tilbake. Tallet staar altsaa der som en felle.
    --
    -- I produktet er den fortsatt et FORSLAG i skjemaet - «full maaned
    -- = 141,25 timer» - men den fylles aldri inn.
    update public.bemanning_aar set fast_arsverk_timer = 1200
     where stasjon_id = STASJ and ar = 2026;

    -- UKJENT FOERST. Ingen rad = ingen justering, og det skal SIES.
    select * into r from public.v_timeregnskap
    where stasjon_id = STASJ and maned = jan;
    if r.lederdekning <> 'ukjent' then
      raise warning 'uten rad i lederdekning er svaret % - ventet ukjent. '
                    'En tom konfigurasjon skal se tom ut.', r.lederdekning;
      feil := feil + 1;
    end if;
    if r.ramme_justering_timer is distinct from 0 then
      raise warning 'ukjent maaned ble justert med % timer', r.ramme_justering_timer;
      feil := feil + 1;
    end if;
    if r.opptjente_timer is distinct from 11520 then
      raise warning 'opptjente_timer er % foer justering - ventet 11520',
        r.opptjente_timer;
      feil := feil + 1;
    end if;

    -- «NEI» ALENE SKAL IKKE GI EN ENESTE TIME.
    --
    -- Dette er hele rettelsen i 0120. For den utloeste fastlonnet =
    -- false en automatisk justering paa aarsverk/12 - og paa
    -- Laguneparken, der lederen er fastloennet men var i pappaperm, ga
    -- det 953 timer uten at noen hadde tatt stilling til om noen
    -- faktisk dekket ham. Stasjonen ville gaatt fra +154 til -799.
    insert into public.bemanning_lederdekning
      (retailer_id, stasjon_id, ar, maned, fastlonnet, notat)
    values (RET, STASJ, 2026, 1, false, 'test: ingen leder, ingen timer gitt');

    select * into r from public.v_timeregnskap
    where stasjon_id = STASJ and maned = jan;
    if r.lederdekning <> 'ikke_fastlonnet' then
      raise warning 'lederdekning er % - ventet ikke_fastlonnet', r.lederdekning;
      feil := feil + 1;
    end if;
    if r.ramme_justering_timer is distinct from 0 then
      raise warning 'AUTOMATIKK: fastlonnet = false ga % timer uten at noen '
                    'satte timer_tilbake. Rammen skal ikke oeke av en '
                    'lederstatus alene.', r.ramme_justering_timer;
      feil := feil + 1;
    end if;
    if r.opptjente_timer is distinct from 11520 then
      raise warning 'opptjente_timer er % - ventet 11520 (uendret). '
                    'Er den 11616, er automatikken tilbake.', r.opptjente_timer;
      feil := feil + 1;
    end if;

    -- ... OG ET TALL EIEREN SETTER SKAL VIRKE, ogsaa med desimal.
    -- 100,5 timer, ikke 100: halve maaneder er hele grunnen til at
    -- feltet er numerisk og ikke en hake.
    update public.bemanning_lederdekning set timer_tilbake = 100.5
     where stasjon_id = STASJ and ar = 2026 and maned = 1;

    select * into r from public.v_timeregnskap
    where stasjon_id = STASJ and maned = jan;
    if r.ramme_justering_timer is distinct from 100.5 then
      raise warning 'ramme_justering_timer er % - ventet 100,5. Er den 100 '
                    'eller 101, avrundes eierens valg bort.',
        r.ramme_justering_timer;
      feil := feil + 1;
    end if;
    if r.budsjett_timer is distinct from 12101 then
      raise warning 'budsjett_timer er % - ventet 12101 (12000 + 100,5)',
        r.budsjett_timer;
      feil := feil + 1;
    end if;
    -- 12 100,5 x 4,8/5,0 = 11 616,48 -> 11 616.
    if r.opptjente_timer is distinct from 11616 then
      raise warning 'opptjente_timer er % - ventet 11616 (12100,5 x 4,8/5,0)',
        r.opptjente_timer;
      feil := feil + 1;
    end if;
    if r.timer_over is distinct from 384 then
      raise warning 'timer_over er % - ventet 384', r.timer_over;
      feil := feil + 1;
    end if;

    -- FASTLOENNET LEDER OG TIMER SAMTIDIG ER LOV. Hun kan ha vaert
    -- sykmeldt halve maaneden. De to feltene svarer paa hvert sitt
    -- spoersmaal, og skal kunne vaere uenige.
    update public.bemanning_lederdekning set fastlonnet = true
     where stasjon_id = STASJ and ar = 2026 and maned = 1;

    select * into r from public.v_timeregnskap
    where stasjon_id = STASJ and maned = jan;
    if r.lederdekning <> 'fastlonnet' then
      raise warning 'lederdekning er % - ventet fastlonnet', r.lederdekning;
      feil := feil + 1;
    end if;
    if r.ramme_justering_timer is distinct from 100.5 then
      raise warning 'timene forsvant da lederen ble satt til fastloennet '
                    '(%). Feltene skal kunne vaere uenige.',
        r.ramme_justering_timer;
      feil := feil + 1;
    end if;

    -- ALLE TIMER TELLES. Ingen ekskluderes.
    if r.brukte_timer is distinct from 12000 then
      raise warning 'brukte_timer er % - ventet 12000', r.brukte_timer;
      feil := feil + 1;
    end if;

    -- 0 ER FORBUDT VED SKRANKE. «Ingenting» skal ha en representasjon,
    -- ellers bommer en spoerring etter `is null` paa halvparten.
    begin
      update public.bemanning_lederdekning set timer_tilbake = 0
       where stasjon_id = STASJ and ar = 2026 and maned = 1;
      raise warning 'timer_tilbake = 0 ble godtatt - skranken mangler';
      feil := feil + 1;
    exception
      when check_violation then null;
    end;

    -- ============================================================
    -- DE FIRE TILFELLENE, MED DE EKTE TALLENE
    -- ============================================================
    -- 1695/12 = 141,25 er forslaget for en hel maaned. Disse fire er
    -- situasjonene Robert beskrev, og de skal kunne skilles fra
    -- hverandre uten spesiallogikk - bare et tall i et felt.
    --
    -- Rammen er 12 000 og bruttoforholdet 4,8/5,0 = 0,96 hele veien, saa
    -- hver opptjent-verdi er regnbar for haand.

    -- (1) FULL MAANED. Sissel paa Dale gaar paa timeloenn hele veien.
    --     12 141,25 x 0,96 = 11 655,6 -> 11 656
    update public.bemanning_lederdekning
       set fastlonnet = false, timer_tilbake = 141.25,
           notat = 'Sissel timeloenn hele maaneden'
     where stasjon_id = STASJ and ar = 2026 and maned = 1;

    select * into r from public.v_timeregnskap
    where stasjon_id = STASJ and maned = jan;
    if r.ramme_justering_timer is distinct from 141.25 then
      raise warning 'FULL MAANED: justeringen er % - ventet 141,25. Er den '
                    '141,3, avrunder viewet eierens valg til feil tall.',
        r.ramme_justering_timer;
      feil := feil + 1;
    end if;
    if r.opptjente_timer is distinct from 11656 then
      raise warning 'FULL MAANED: opptjente_timer er % - ventet 11656',
        r.opptjente_timer;
      feil := feil + 1;
    end if;

    -- (2) HALV MAANED. Overgang midt i maaneden - Lone i april.
    --     Hele grunnen til at feltet er et TALL og ikke en hake.
    --     12 070,5 x 0,96 = 11 587,68 -> 11 588
    update public.bemanning_lederdekning
       set timer_tilbake = 70.5, notat = 'vikar halve maaneden'
     where stasjon_id = STASJ and ar = 2026 and maned = 1;

    select * into r from public.v_timeregnskap
    where stasjon_id = STASJ and maned = jan;
    if r.ramme_justering_timer is distinct from 70.50 then
      raise warning 'HALV MAANED: justeringen er % - ventet 70,5',
        r.ramme_justering_timer;
      feil := feil + 1;
    end if;
    if r.opptjente_timer is distinct from 11588 then
      raise warning 'HALV MAANED: opptjente_timer er % - ventet 11588',
        r.opptjente_timer;
      feil := feil + 1;
    end if;

    -- (3) PERMISJON UTEN TILBAKEFOERING. Bjoern paa Laguneparken:
    --     fastloennet leder, men i pappaperm - og ingen vikar spiste av
    --     timebudsjettet. Faktumet registreres, ingenting gis tilbake.
    --
    --     DETTE ER TILFELLET DEN GAMLE AUTOMATIKKEN TOK FEIL PAA. Der ga
    --     `fastlonnet = false` 953 timer paa aaret, og stasjonen gikk fra
    --     +154 til -799 uten at noen hadde tatt stilling.
    update public.bemanning_lederdekning
       set fastlonnet = false, timer_tilbake = null,
           notat = 'Bjoern i pappaperm - ingen vikar'
     where stasjon_id = STASJ and ar = 2026 and maned = 1;

    select * into r from public.v_timeregnskap
    where stasjon_id = STASJ and maned = jan;
    if r.lederdekning <> 'ikke_fastlonnet' then
      raise warning 'PERMISJON: lederdekning er % - faktumet skal staa selv '
                    'naar ingenting gis tilbake', r.lederdekning;
      feil := feil + 1;
    end if;
    if r.ramme_justering_timer is distinct from 0 then
      raise warning 'PERMISJON: justeringen er % - ventet 0. Automatikken '
                    'er tilbake, og stasjonen faar timer ingen har gitt den.',
        r.ramme_justering_timer;
      feil := feil + 1;
    end if;
    if r.opptjente_timer is distinct from 11520 then
      raise warning 'PERMISJON: opptjente_timer er % - ventet 11520 (uendret)',
        r.opptjente_timer;
      feil := feil + 1;
    end if;

    -- (4) INGENTING. Verken lederstatus eller timer - raden finnes ikke.
    delete from public.bemanning_lederdekning
     where stasjon_id = STASJ and ar = 2026 and maned = 1;

    select * into r from public.v_timeregnskap
    where stasjon_id = STASJ and maned = jan;
    if r.lederdekning <> 'ukjent' then
      raise warning 'INGENTING: lederdekning er % - ventet ukjent',
        r.lederdekning;
      feil := feil + 1;
    end if;
    if r.ramme_justering_timer is distinct from 0 then
      raise warning 'INGENTING: justeringen er %', r.ramme_justering_timer;
      feil := feil + 1;
    end if;

    -- Ryddet, saa kontrollene under ser samme tall som foer.
    delete from public.bemanning_lederdekning where stasjon_id = STASJ;
    update public.bemanning_aar set fast_arsverk_timer = 0
     where stasjon_id = STASJ and ar = 2026;

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
