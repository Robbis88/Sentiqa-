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
  mnd       date;
  mnd_ifjor date;
  siste     date;
  r         record;
begin
  if to_regclass('public.v_bp_status_avdeling') is null then
    raise exception 'BLIND TEST: v_bp_status_avdeling finnes ikke - er 0113 kjort?';
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

    insert into public.retailers (id, navn) values (RET, 'BP-test');
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
