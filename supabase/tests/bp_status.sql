-- =====================================================================
-- v_bp_status_avdeling: omsetning mot omsetning, brutto mot brutto
-- =====================================================================
--
-- Kjores i CI etter migrasjonene. Kaster exception ved funn.
--
-- DEN VIKTIGSTE INVARIANTEN: en dom om «foran eller bak plan» skal
-- ALLTID vaere regnet av omsetning mot OMSETNINGSBUDSJETT. Foerste
-- utkast av viewet satte `bp_bruttofortjeneste` mot faktisk omsetning -
-- to ulike stoerrelser paa hver sin side av samme sammenligning. Avviket
-- ville sett ut som et funn, og vaert en regnefeil.
--
-- Testdataene er laget slik at en kryssing IKKE KAN SKJULE SEG:
-- omsetningsbudsjettet er 100 000 og bruttobudsjettet 40 000. Blir de
-- byttet om, endrer `mot_bp_kr` seg med 60 000 - ikke med noe som kunne
-- forveksles med avrunding.
--
-- Alt i EN do-blokk: `supabase db query --file` sender fila som en
-- prepared statement. Testdataene ryddes av en sentinel-exception.
-- =====================================================================
do $$
declare
  feil      int := 0;
  RET       constant uuid := 'eeeeeeee-0000-4000-8000-000000000001';
  STASJ     constant uuid := 'eeeeeeee-1111-4000-8000-000000000001';
  STASJ2    constant uuid := 'eeeeeeee-2222-4000-8000-000000000002';
  mnd       date;
  forrige_mnd date;
  mnd_ifjor date;
  siste     date;
  r         record;
begin
  if to_regclass('public.v_bp_status_avdeling') is null then
    raise exception 'BLIND TEST: v_bp_status_avdeling finnes ikke - er 0113/0114 kjort?';
  end if;

  -- Kolonnene kom i 0114 (`kobling`) og 0115 (`bp_vekst_pst`). Kjores
  -- testen mot et eldre view, feiler den paa «column does not exist»
  -- midt inne i en kontroll - en feilmelding som ser ut som en kodefeil
  -- i testen. Her sier den i stedet hva som mangler.
  if (select count(*) from information_schema.columns
      where table_schema = 'public'
        and table_name = 'v_bp_status_avdeling'
        and column_name in ('kobling', 'bp_vekst_pst')) < 2 then
    raise exception 'BLIND TEST: viewet mangler kobling og/eller bp_vekst_pst - er 0114 og 0115 kjort?';
  end if;

  begin
    -- Referansedatoen er global (max(dato) i v_butikksalg). Testen
    -- legger seg PAA den i stedet for aa velge egne datoer: ellers ville
    -- «inneveaerende maaned» betydd noe annet i CI enn i produksjon.
    select max(dato) into siste from public.v_butikksalg;
    if siste is null then
      raise exception 'BLIND TEST: ingen salgsdata i basen - viewet kan ikke maales';
    end if;
    mnd       := date_trunc('month', siste)::date;
    mnd_ifjor := (mnd - interval '1 year')::date;
    forrige_mnd := (mnd - interval '1 month')::date;

    insert into public.retailers (id, navn) values (RET, 'BP-test');
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
      values (STASJ, RET, '0001', 'BP-butikken', 'pendler');

    -- --- BUDSJETT: omsetning 100 000, brutto 40 000 ------------------
    -- Ulike med vilje, og langt fra hverandre.
    insert into public.regnskapslinjer
      (retailer_id, stasjon_id, periode, seksjon, kode, post, regnskap, budsjett,
       avvik, index_pct, regnskap_hittil, budsjett_hittil)
    values
      (RET, STASJ, mnd, 'bp_omsetning',         '120', '120 Mat', 0, 100000, 0, 0, 0, 0),
      (RET, STASJ, mnd, 'bp_bruttofortjeneste', '120', '120 Mat', 0,  40000, 0, 0, 0, 0);

    -- --- SALG: hele maaneden i fjor, og hittil i aar -----------------
    -- I fjor: 1 000 kr per dag hele maaneden. I aar: 900 kr per dag
    -- hittil. Da er fjoraarets kurve jevn, andelen blir dagnr/dager,
    -- og «burde_naa» er regnbar for haand.
    --
    -- `kilde_jobb_id` er nullbar, saa testen trenger ingen importjobb.
    -- Foerste utkast opprettet en - paa en kolonne som ikke finnes.

    insert into public.daglig_salg
      (retailer_id, stasjon_id, dato, ean, avdeling_kode, avdeling_navn,
       omsetning_eks_mva, bto_fortjeneste_kr)
    select RET, STASJ, d::date, '1', '120', 'MAT', 1000, 500
    from generate_series(mnd_ifjor,
                         (mnd_ifjor + interval '1 month - 1 day')::date,
                         interval '1 day') d;

    insert into public.daglig_salg
      (retailer_id, stasjon_id, dato, ean, avdeling_kode, avdeling_navn,
       omsetning_eks_mva, bto_fortjeneste_kr)
    select RET, STASJ, d::date, '1', '120', 'MAT', 900, 360
    from generate_series(mnd, siste, interval '1 day') d;

    select * into r
    from public.v_bp_status_avdeling
    where stasjon_id = STASJ and maned = mnd and gruppe_kode = '120';

    if r.stasjon_id is null then
      raise warning 'viewet ga ingen rad for testdataene';
      feil := feil + 1;
    else
      -- 1) Budsjettene skal staa hver for seg, uendret.
      if r.bp_omsetning_kr <> 100000 then
        raise warning 'bp_omsetning_kr er % - ventet 100000', r.bp_omsetning_kr;
        feil := feil + 1;
      end if;
      if r.bp_brutto_kr <> 40000 then
        raise warning 'bp_brutto_kr er % - ventet 40000', r.bp_brutto_kr;
        feil := feil + 1;
      end if;

      -- 2) INGEN KRYSSING. `burde_naa` skal vaere pro-ratert av
      --    OMSETNINGSbudsjettet. Med fjoraarets kurve er andelen
      --    dagnr/dager_i_mnd (jevnt salg i fjor), saa forventningen er
      --    regnbar - og ville vaert 40 % av tallet om noen hadde brukt
      --    bruttobudsjettet.
      if r.burde_naa_omsetning is null then
        raise warning 'burde_naa_omsetning er null for inneveaerende maaned';
        feil := feil + 1;
      elsif r.burde_naa_omsetning
            > 100000 * (extract(day from siste)::numeric
                        / extract(days from (mnd + interval '1 month - 1 day'))) + 1
         or r.burde_naa_omsetning
            < 100000 * (extract(day from siste)::numeric
                        / extract(days from (mnd + interval '1 month - 1 day'))) - 1 then
        raise warning 'burde_naa_omsetning er % - ikke pro-ratert av OMSETNINGSbudsjettet',
          r.burde_naa_omsetning;
        feil := feil + 1;
      end if;

      -- 3) Dommen skal vaere faktisk omsetning minus forventningen.
      if r.mot_bp_kr is distinct from (r.faktisk_omsetning - r.burde_naa_omsetning) then
        raise warning 'mot_bp_kr (%) er ikke faktisk (%) minus burde (%)',
          r.mot_bp_kr, r.faktisk_omsetning, r.burde_naa_omsetning;
        feil := feil + 1;
      end if;

      -- 4) OG DEN SKARPESTE: dommen skal ALDRI kunne forklares av
      --    bruttobudsjettet. Med 100 000 mot 40 000 er de 60 000 fra
      --    hverandre - en kryssing kan ikke gjemme seg i avrunding.
      if r.mot_bp_kr is not distinct from
         (r.faktisk_omsetning - round(40000 * (extract(day from siste)::numeric
            / extract(days from (mnd + interval '1 month - 1 day'))))) then
        raise warning 'KRYSSING: mot_bp_kr er regnet av BRUTTObudsjettet';
        feil := feil + 1;
      end if;

      -- 5) Teoretisk brutto er kassas egen margin: 360/900 = 40 %.
      if r.teoretisk_brutto_pst is distinct from 40.0 then
        raise warning 'teoretisk_brutto_pst er % - ventet 40.0', r.teoretisk_brutto_pst;
        feil := feil + 1;
      end if;

      -- 6) Fjoraaret er KONTEKST: 900 mot 1000 per dag = -10 %.
      if r.mot_ifjor_pst is distinct from -10.0 then
        raise warning 'mot_ifjor_pst er % - ventet -10.0', r.mot_ifjor_pst;
        feil := feil + 1;
      end if;

      -- 7) Grunnlaget skal si at fjoraaret ble brukt.
      if r.grunnlag <> 'ifjor' then
        raise warning 'grunnlag er % - ventet ifjor', r.grunnlag;
        feil := feil + 1;
      end if;

      if r.periode_status <> 'innevaerende' then
        raise warning 'periode_status er % - ventet innevaerende', r.periode_status;
        feil := feil + 1;
      end if;
    end if;

    -- --- KOMMENDE MAANED: ingen falsk performance -------------------
    insert into public.regnskapslinjer
      (retailer_id, stasjon_id, periode, seksjon, kode, post, regnskap, budsjett,
       avvik, index_pct, regnskap_hittil, budsjett_hittil)
    values
      (RET, STASJ, (mnd + interval '2 months')::date, 'bp_omsetning',
       '120', '120 Mat', 0, 120000, 0, 0, 0, 0);

    select * into r
    from public.v_bp_status_avdeling
    where stasjon_id = STASJ and maned = (mnd + interval '2 months')::date
      and gruppe_kode = '120';

    if r.periode_status is distinct from 'kommende' then
      raise warning 'framtidig maaned fikk status % - ventet kommende', r.periode_status;
      feil := feil + 1;
    end if;
    if r.faktisk_omsetning is not null or r.mot_bp_kr is not null
       or r.mot_ifjor_pst is not null then
      raise warning 'KOMMENDE MAANED HAR TALL: faktisk=%, mot_bp=%, mot_ifjor=% '
                    '- en maaned som ikke har skjedd kan ikke ligge foran eller bak',
        r.faktisk_omsetning, r.mot_bp_kr, r.mot_ifjor_pst;
      feil := feil + 1;
    end if;
    if r.bp_omsetning_kr is distinct from 120000 then
      raise warning 'kommende maaned mangler BP: %', r.bp_omsetning_kr;
      feil := feil + 1;
    end if;

    -- --- YTD ER VEKTET, IKKE ET SNITT AV PROSENTER ------------------
    -- To avlagte maaneder, ulik stoerrelse og ulik margin:
    --   liten:  10 000 oms, 5 000 brutto  = 50 %
    --   stor:  100 000 oms, 20 000 brutto = 20 %
    -- Vektet: 25 000 / 110 000 = 22,7 %. Aritmetisk snitt: 35 %.
    -- Tallene er valgt saa de to svarene ikke kan forveksles.
    insert into public.regnskapslinjer
      (retailer_id, stasjon_id, periode, seksjon, kode, post, regnskap, budsjett,
       avvik, index_pct, regnskap_hittil, budsjett_hittil)
    values
      (RET, STASJ, date_trunc('year', mnd)::date, 'omsetning',
       '130', '130 Varm drikke', 10000, 10000, 0, 0, 0, 0),
      (RET, STASJ, date_trunc('year', mnd)::date, 'bruttofortjeneste',
       '130', '130 Varm drikke', 5000, 5000, 0, 0, 0, 0),
      (RET, STASJ, (date_trunc('year', mnd) + interval '1 month')::date, 'omsetning',
       '130', '130 Varm drikke', 100000, 100000, 0, 0, 0, 0),
      (RET, STASJ, (date_trunc('year', mnd) + interval '1 month')::date, 'bruttofortjeneste',
       '130', '130 Varm drikke', 20000, 20000, 0, 0, 0, 0);

    select * into r
    from public.v_bp_status_avdeling
    where stasjon_id = STASJ and gruppe_kode = '130'
      and maned = date_trunc('year', mnd)::date;

    if r.faktisk_brutto_ytd_pst is distinct from 22.7 then
      raise warning 'faktisk_brutto_ytd_pst er % - ventet 22.7 (vektet). '
                    'Er den 35.0, er det et aritmetisk snitt av maanedsprosentene.',
        r.faktisk_brutto_ytd_pst;
      feil := feil + 1;
    end if;
    if r.periode_status <> 'avlagt' then
      raise warning 'maaned med regnskap fikk status % - ventet avlagt', r.periode_status;
      feil := feil + 1;
    end if;

    -- --- ROLLUPEN «40 CR» SKAL VAERE UTE ----------------------------
    if exists (select 1 from public.v_bp_status_avdeling
               where stasjon_id = STASJ and gruppe_kode = '40') then
      raise warning 'ROLLUP MED: kode 40 CR staar i viewet og dobbelteller stasjonen';
      feil := feil + 1;
    end if;

    -- --- HVER STASJON MAALES MOT SIN EGEN SISTE SALGSDATO ----------
    --
    -- STASJ2 ligger en HEL MAANED etter med importen. Da er dens
    -- inneveaerende maaned forrige maaned - ikke kjedens.
    --
    -- Dagnummer brukes med vilje IKKE som maalepunkt her: hvilken dag
    -- CI-seeden slutter paa er ukjent, og en test som er stum den 1. i
    -- maaneden er en test som ser ut til aa maale noe den ikke maaler.
    -- Periodestatus er derimot entydig: med global dato ville raden
    -- faatt «venter_regnskap», med stasjonens egen faar den
    -- «innevaerende». De to kan ikke forveksles.
    insert into public.stasjoner (id, retailer_id, butikknummer, navn, stasjonstype)
      values (STASJ2, RET, '0002', 'BP-etternoelaren', 'pendler');

    insert into public.regnskapslinjer
      (retailer_id, stasjon_id, periode, seksjon, kode, post, regnskap, budsjett,
       avvik, index_pct, regnskap_hittil, budsjett_hittil)
    values
      (RET, STASJ2, forrige_mnd, 'bp_omsetning', '120', '120 Mat', 0, 100000, 0, 0, 0, 0);

    -- Fjoraaret for den maaneden, jevnt - saa andelen er regnbar.
    insert into public.daglig_salg
      (retailer_id, stasjon_id, dato, ean, avdeling_kode, avdeling_navn,
       omsetning_eks_mva, bto_fortjeneste_kr)
    select RET, STASJ2, d::date, '1', '120', 'MAT', 1000, 500
    from generate_series((forrige_mnd - interval '1 year')::date,
                         (forrige_mnd - interval '1 year' + interval '1 month - 1 day')::date,
                         interval '1 day') d;

    -- ... og i aar: bare de ti foerste dagene av FORRIGE maaned.
    insert into public.daglig_salg
      (retailer_id, stasjon_id, dato, ean, avdeling_kode, avdeling_navn,
       omsetning_eks_mva, bto_fortjeneste_kr)
    select RET, STASJ2, d::date, '1', '120', 'MAT', 900, 360
    from generate_series(forrige_mnd,
                         (forrige_mnd + interval '9 days')::date,
                         interval '1 day') d;

    select * into r
    from public.v_bp_status_avdeling
    where stasjon_id = STASJ2 and maned = forrige_mnd and gruppe_kode = '120';

    if r.stasjon_id is null then
      raise warning 'etternoelaren fikk ingen rad for sin egen siste maaned';
      feil := feil + 1;
    elsif r.periode_status <> 'innevaerende' then
      raise warning 'GLOBAL DATO: stasjonen som ligger en maaned etter fikk '
                    'status % - ventet innevaerende. Maales den mot kjedens '
                    'siste salgsdato i stedet for sin egen?', r.periode_status;
      feil := feil + 1;
    elsif r.burde_naa_omsetning is null then
      raise warning 'etternoelaren fikk ingen burde_naa - er andelen borte?';
      feil := feil + 1;
    end if;

    -- --- BRUTTOPROSENT UTEN MENINGSFULL NEVNER ---------------------
    --
    -- 10 kr omsetning og -500 kr brutto er ikke en margin paa -5000 %.
    -- Det er to tall som kommer fra hver sin stoerrelse. `DRIFT` viste
    -- -3536,4 % i produksjon foer dette.
    --
    -- KRONENE SKAL STAA. Nulles ogsaa de, forsvinner beviset paa at noe
    -- er galt sammen med det gale tallet.
    insert into public.daglig_salg
      (retailer_id, stasjon_id, dato, ean, avdeling_kode, avdeling_navn,
       omsetning_eks_mva, bto_fortjeneste_kr)
    -- `ean` er del av primaernoekkelen (retailer_id, stasjon_id, dato,
    -- ean) - avdelingskoden er det IKKE. Gjenbrukes ean paa samme dato,
    -- kolliderer raden med MAT-serien over selv om avdelingen er en
    -- annen. Det gjorde den, og CI fanget det.
    values (RET, STASJ, siste, 'ean-drift', '900', 'DRIFT', 10, -500);

    select * into r
    from public.v_bp_status_avdeling
    where stasjon_id = STASJ and maned = mnd and gruppe_kode = '900';

    if r.stasjon_id is null then
      raise warning 'raden for DRIFT forsvant helt - den skal vises, bare uten prosent';
      feil := feil + 1;
    else
      if r.teoretisk_brutto_pst is not null then
        raise warning 'teoretisk_brutto_pst er % for 10 kr omsetning og '
                      '-500 kr brutto - ventet null', r.teoretisk_brutto_pst;
        feil := feil + 1;
      end if;
      if r.brutto_gap_pst is not null then
        raise warning 'brutto_gap_pst er % naar den ene prosenten ikke '
                      'finnes - et gap mot ingenting er ikke en lekkasje',
          r.brutto_gap_pst;
        feil := feil + 1;
      end if;
      if r.teoretisk_brutto_kr is distinct from -500 then
        raise warning 'teoretisk_brutto_kr er % - ventet -500. Kronene skal '
                      'staa selv naar prosenten ikke kan regnes', r.teoretisk_brutto_kr;
        feil := feil + 1;
      end if;
    end if;

    -- --- KOBLINGEN: FIRE TILSTANDER, IKKE TO -----------------------
    --
    -- 0113 kalte baade «har plan, ingen salg» og «har plan, ingen kode
    -- aa koble til» for «ingen plan lagt inn» - motsatt av sannheten
    -- for begge.

    -- (c) plan, men koden finnes ikke i salgsdataene i det hele tatt.
    --     Dette er `211 Selvvask`, `DRIFT` og `SYSTEM` i produksjon.
    insert into public.regnskapslinjer
      (retailer_id, stasjon_id, periode, seksjon, kode, post, regnskap, budsjett,
       avvik, index_pct, regnskap_hittil, budsjett_hittil)
    values
      (RET, STASJ, mnd, 'bp_omsetning', '211', '211 Selvvask', 0, 50000, 0, 0, 0, 0);

    -- (d) plan, og koden FINNES i stasjonens salgsdata - men ikke denne
    --     maaneden. En ekte nulltilstand: avdelingen er kjent, den har
    --     bare ikke solgt.
    insert into public.regnskapslinjer
      (retailer_id, stasjon_id, periode, seksjon, kode, post, regnskap, budsjett,
       avvik, index_pct, regnskap_hittil, budsjett_hittil)
    values
      (RET, STASJ, mnd, 'bp_omsetning', '140', '140 Bilvask', 0, 30000, 0, 0, 0, 0);

    insert into public.daglig_salg
      (retailer_id, stasjon_id, dato, ean, avdeling_kode, avdeling_navn,
       omsetning_eks_mva, bto_fortjeneste_kr)
    values (RET, STASJ, mnd_ifjor, 'ean-bilvask', '140', 'BILVASK', 5000, 4000);

    for r in
      select gruppe_kode, kobling from public.v_bp_status_avdeling
      where stasjon_id = STASJ and maned = mnd
        and gruppe_kode in ('120', '900', '211', '140')
    loop
      if r.gruppe_kode = '120' and r.kobling <> 'plan_med_salg' then
        raise warning 'kode 120 har baade plan og salg, men kobling er %', r.kobling;
        feil := feil + 1;
      elsif r.gruppe_kode = '900' and r.kobling <> 'salg_uten_plan' then
        raise warning 'kode 900 selger uten budsjett, men kobling er %', r.kobling;
        feil := feil + 1;
      elsif r.gruppe_kode = '211' and r.kobling <> 'plan_uten_kobling' then
        raise warning 'kode 211 finnes ikke i salgsdataene, men kobling er %. '
                      'Dette er feilen som kalte «211 Selvvask» for «ingen '
                      'plan lagt inn»', r.kobling;
        feil := feil + 1;
      elsif r.gruppe_kode = '140' and r.kobling <> 'plan_uten_salg' then
        raise warning 'kode 140 er kjent i salgsdataene men solgte ikke denne '
                      'maaneden, og kobling er % - ventet plan_uten_salg', r.kobling;
        feil := feil + 1;
      end if;
    end loop;

    -- KANARIFUGL FOR SELVE KLASSIFISERINGEN. Returnerer viewet bare en
    -- av verdiene, gaar loekka over trivielt grønn for de andre.
    if (select count(distinct kobling) from public.v_bp_status_avdeling
        where stasjon_id = STASJ and maned = mnd) < 4 then
      raise warning 'BLIND TEST: viewet ga faerre enn fire koblingsverdier for '
                    'testdata som dekker alle fire. Klassifiserer den i det '
                    'hele tatt?';
      feil := feil + 1;
    end if;

    -- --- VEKSTKRAVET: HVA PLANEN BER OM MOT I FJOR -----------------
    --
    -- Testdataene over: budsjett 100 000 for maaneden, og i fjor 1 000
    -- kr per dag i en hel maaned. Vekstkravet er derfor regnbart for
    -- haand - og det er 100 000 mot (1000 * dager), ikke mot noe
    -- «hittil»-tall.
    --
    -- MAALT MOT HELE MAANEDEN MED VILJE. Regnes kravet mot fjoraaret
    -- HITTIL, beveger det seg med dagteljaren: den samme planen ville
    -- sett ut som et annet krav hver morgen. Denne testen felles hvis
    -- noen bytter til hittil-tallet, fordi de to er langt fra hverandre.
    select * into r
    from public.v_bp_status_avdeling
    where stasjon_id = STASJ and maned = mnd and gruppe_kode = '120';

    if r.ifjor_omsetning_kr is distinct from
       round(1000 * extract(days from (mnd + interval '1 month - 1 day')))
    then
      raise warning 'ifjor_omsetning_kr er % - ventet hele fjoraarets '
                    'maaned (1000 kr x % dager)', r.ifjor_omsetning_kr,
        extract(days from (mnd + interval '1 month - 1 day'));
      feil := feil + 1;
    end if;

    if r.bp_vekst_pst is null then
      raise warning 'bp_vekst_pst er null selv om baade budsjett og '
                    'fjoraar finnes';
      feil := feil + 1;
    elsif abs(r.bp_vekst_pst
              - (100 * (100000 - 1000 * extract(days from (mnd + interval '1 month - 1 day')))
                 / (1000 * extract(days from (mnd + interval '1 month - 1 day'))))) > 0.2
    then
      raise warning 'bp_vekst_pst er % - stemmer ikke med 100000 mot '
                    'fjoraarets hele maaned. Er den regnet mot '
                    'hittil-tallet i stedet?', r.bp_vekst_pst;
      feil := feil + 1;
    end if;

    -- UTEN FJORAAR: INTET KRAV. En ny avdeling har ikke uendelig
    -- vekstkrav - den har ikke noe. `211` har budsjett og ingen
    -- salgshistorikk i det hele tatt.
    select * into r
    from public.v_bp_status_avdeling
    where stasjon_id = STASJ and maned = mnd and gruppe_kode = '211';

    if r.bp_vekst_pst is not null then
      raise warning 'bp_vekst_pst er % for en avdeling uten fjoraarstall '
                    '- et vekstkrav mot ingenting finnes ikke',
        r.bp_vekst_pst;
      feil := feil + 1;
    end if;

    -- --- BRUTTO: PLANEN MOT REGNSKAPET, IKKE KASSA -----------------
    --
    -- Robert, 2026-08-21: «Kassen er fasit paa en perfekt hverdag.
    -- BP-budsjett i brutto mot regnskap er fasiten paa pengene vi
    -- tjener. Sier BP 60 %, kassa 80 % og regnskapet 40 %, saa er gapet
    -- mellom BP og regnskap det som maa dekkes.»
    --
    -- Testdataene er BOKSTAVELIG TALT det eksempelet, paa kode 130 i
    -- aarets foerste avlagte maaned:
    --
    --   budsjett   omsetning 100 000, brutto 60 000   -> 60 %
    --   regnskap   omsetning 100 000, brutto 40 000   -> 40 %
    --   kassa      omsetning  50 000, brutto 40 000   -> 80 %
    --
    -- Forventet: brutto_mot_bp_pp = -20,0. Ikke +40 (kassa mot
    -- regnskap), og ikke -40 (kassa mot budsjett). De tre tallene er
    -- valgt slik at ingen av forvekslingene kan gi det samme svaret.
    --
    -- KAFFEAVTALEN er hele grunnen til at kassaomsetningen er lavere
    -- enn regnskapets: koppene gaar ut uten et salg bak seg.
    insert into public.regnskapslinjer
      (retailer_id, stasjon_id, periode, seksjon, kode, post, regnskap, budsjett,
       avvik, index_pct, regnskap_hittil, budsjett_hittil)
    values
      (RET, STASJ, date_trunc('year', mnd)::date, 'omsetning',
       '131', '131 Kaffeavtale', 100000, 100000, 0, 0, 0, 0),
      (RET, STASJ, date_trunc('year', mnd)::date, 'bruttofortjeneste',
       '131', '131 Kaffeavtale', 40000, 60000, 0, 0, 0, 0);

    insert into public.daglig_salg
      (retailer_id, stasjon_id, dato, ean, avdeling_kode, avdeling_navn,
       omsetning_eks_mva, bto_fortjeneste_kr)
    values (RET, STASJ, date_trunc('year', mnd)::date, 'ean-kaffe',
            '131', 'VARM DRIKKE', 50000, 40000);

    select * into r
    from public.v_bp_status_avdeling
    where stasjon_id = STASJ and gruppe_kode = '131'
      and maned = date_trunc('year', mnd)::date;

    if r.stasjon_id is null then
      raise warning 'ingen rad for varm drikke i aarets foerste maaned';
      feil := feil + 1;
    else
      if r.bp_brutto_ytd_pst is distinct from 60.0 then
        raise warning 'bp_brutto_ytd_pst er % - ventet 60,0 (planen lover)',
          r.bp_brutto_ytd_pst;
        feil := feil + 1;
      end if;
      if r.faktisk_brutto_ytd_pst is distinct from 40.0 then
        raise warning 'faktisk_brutto_ytd_pst er % - ventet 40,0 (regnskapet)',
          r.faktisk_brutto_ytd_pst;
        feil := feil + 1;
      end if;
      if r.teoretisk_brutto_pst is distinct from 80.0 then
        raise warning 'teoretisk_brutto_pst er % - ventet 80,0 (kassa)',
          r.teoretisk_brutto_pst;
        feil := feil + 1;
      end if;

      -- DOMMEN.
      if r.brutto_mot_bp_pp is distinct from -20.0 then
        raise warning 'brutto_mot_bp_pp er % - ventet -20,0 (regnskap 40 mot '
                      'plan 60). Er den +40, maaler den kassa mot regnskapet; '
                      'er den -40, maaler den kassa mot budsjettet.',
          r.brutto_mot_bp_pp;
        feil := feil + 1;
      end if;
      if r.brutto_mot_bp_kr is distinct from -20000 then
        raise warning 'brutto_mot_bp_kr er % - ventet -20000', r.brutto_mot_bp_kr;
        feil := feil + 1;
      end if;
      -- Indeksen alvoret hentes fra: (40000-60000)/60000 = -33,3 %.
      if r.brutto_mot_bp_indeks is distinct from -33.3 then
        raise warning 'brutto_mot_bp_indeks er % - ventet -33,3',
          r.brutto_mot_bp_indeks;
        feil := feil + 1;
      end if;

      -- KAFFEAVTALEN SKAL IKKE VAERE EN DOM. Kassa-mot-regnskap er
      -- fortsatt 40 pp her, og det er helt normalt for varm drikke.
      -- Faller den verdien sammen med `brutto_mot_bp_pp`, er de to
      -- blandet sammen igjen.
      if r.brutto_gap_pst is distinct from 40.0 then
        raise warning 'brutto_gap_pst er % - ventet 40,0 (kassa 80 mot '
                      'regnskap 40). Den skal fortsatt regnes, den skal '
                      'bare ikke vaere dommen.', r.brutto_gap_pst;
        feil := feil + 1;
      end if;
      if r.brutto_gap_pst = r.brutto_mot_bp_pp then
        raise warning 'BLANDET SAMMEN: kassa-mot-regnskap og plan-mot-regnskap '
                      'gir samme tall (%). Testdataene er valgt slik at de '
                      'IKKE kan vaere like.', r.brutto_gap_pst;
        feil := feil + 1;
      end if;
    end if;

    raise exception 'RULL_TILBAKE';
  exception
    when others then
      if sqlerrm <> 'RULL_TILBAKE' then raise; end if;
  end;

  if feil > 0 then
    raise exception 'v_bp_status_avdeling: % funn. Se advarslene over.', feil;
  end if;
  raise notice '--- v_bp_status_avdeling: omsetning mot omsetning, brutto mot brutto ---';
end $$;
