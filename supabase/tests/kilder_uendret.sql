-- =====================================================================
-- KILDENE SKAL IKKE FLYTTE SEG
-- =====================================================================
-- Rent lesende. Kjoeres FOER og ETTER en regenerering av
-- maanedsplanutkastene, og de to svarene sammenlignes kolonne for
-- kolonne.
--
-- Alt unntatt de fire `maanedsplan_*`-kolonnene skal vaere IDENTISK.
--
-- ---------------------------------------------------------------------
-- HVORFOR BAADE RADANTALL OG SUMMER
--
-- Et radantall alene ser en sletting og en innsetting, men ikke en
-- endring: en rad som faar et nytt beloep har samme antall. En sum alene
-- ser en endring, men to endringer som opphever hverandre gaar fri.
-- Sammen dekker de hverandres blindsone.
--
-- Summene har `::numeric` og ingen avrunding. En avrundet sum ville
-- skjult noeyaktig de smaa flyttingene dette er ment aa fange.
--
-- ---------------------------------------------------------------------
-- IKKE FILTRERT PAA KJEDE
--
-- Med vilje: regenereringen kjoerer i én kjede, og en sonde som bare
-- ser den kjeden ville ikke oppdaget at noe traff en annen. Et tall som
-- flytter seg et sted denne veien ikke skulle naadd, er det viktigste
-- funnet sonden kan gjoere.
--
-- ---------------------------------------------------------------------
-- SLETTEDE RADER TELLES MED
--
-- `slettet_tid` filtreres IKKE bort. En myk sletting er en endring, og
-- en sonde som leser som flaten ville sett den som «raden var her hele
-- tiden, den er bare borte naa».
-- =====================================================================

select
  -- --- Regnskapsgrunnlaget ------------------------------------------
  (select count(*) from public.regnskapslinjer)                   as regnskapslinjer_rader,
  (select count(*) from public.regnskapslinjer
    where slettet_tid is not null)                                as regnskapslinjer_slettede,
  (select coalesce(sum(regnskap), 0)::numeric
     from public.regnskapslinjer)                                 as regnskapslinjer_sum,
  (select coalesce(sum(budsjett), 0)::numeric
     from public.regnskapslinjer)                                 as regnskapslinjer_budsjett,

  (select count(*) from public.regnskap_usynlig_svinn)            as usynlig_svinn_rader,
  (select coalesce(sum(usynlig_kr), 0)::numeric
     from public.regnskap_usynlig_svinn)                          as usynlig_svinn_sum,
  (select coalesce(sum(salg), 0)::numeric
     from public.regnskap_usynlig_svinn)                          as usynlig_svinn_salg,

  (select count(*) from public.bilagssum)                         as bilagssum_rader,
  (select coalesce(sum(belop_kr), 0)::numeric
     from public.bilagssum)                                       as bilagssum_sum,
  (select coalesce(sum(antall), 0)
     from public.bilagssum)                                       as bilagssum_antall,

  -- --- Budsjett og satser -------------------------------------------
  (select count(*) from public.bp_aar)                            as bp_aar_rader,
  (select count(*) from public.bp_linje)                          as bp_linje_rader,
  (select coalesce(sum(belop_kr), 0)::numeric
     from public.bp_linje)                                        as bp_linje_sum,
  (select count(*) from public.kastbudsjett)                      as kastbudsjett_rader,
  (select coalesce(sum(kast_pst_av_salg), 0)::numeric
     from public.kastbudsjett)                                    as kastbudsjett_sum,
  (select count(*) from public.royaltysats)                       as royaltysats_rader,
  (select coalesce(sum(lav_sats + hoy_sats_vask + pant_sats), 0)::numeric
     from public.royaltysats)                                     as royaltysats_sum,

  -- --- Proveniens og importkoe --------------------------------------
  (select count(*) from public.raa_filer)                         as raa_filer_rader,
  (select count(*) from public.import_jobber)                     as import_jobber_rader,
  (select coalesce(string_agg(s, ':' || n::text, ', ' order by s), '-')
     from (select status::text as s, count(*) as n
             from public.import_jobber group by 1) x)             as import_jobber_status,
  (select max(oppdatert_tid) from public.import_jobber)           as import_jobber_sist_rort,

  -- --- Tallene planen faktisk leser ---------------------------------
  -- Gjennom samme view som motoren. Flytter noe seg her, flytter
  -- analysen seg - uansett hvilken tabell under som var aarsaken.
  (select count(*) from public.v_kurs_maanedstall)                as kurs_rader,
  (select coalesce(sum(matsalg_kr), 0)::numeric
     from public.v_kurs_maanedstall)                              as kurs_matsalg,
  (select coalesce(sum(matkast_kr), 0)::numeric
     from public.v_kurs_maanedstall)                              as kurs_synlig_kast,
  (select coalesce(sum(usynlig_mat_kr), 0)::numeric
     from public.v_kurs_maanedstall)                              as kurs_usynlig_mat,
  (select coalesce(sum(usynlig_rest_kr), 0)::numeric
     from public.v_kurs_maanedstall)                              as kurs_usynlig_rest,
  (select coalesce(sum(resultat_kr), 0)::numeric
     from public.v_kurs_maanedstall)                              as kurs_resultat,
  (select coalesce(sum(omsetning_kr), 0)::numeric
     from public.v_kurs_maanedstall)                              as kurs_omsetning,

  -- --- DET SOM HAR LOV TIL AA ENDRE SEG -----------------------------
  -- Bare disse fire. Antallet planer skal staa likt; det er BARE
  -- innholdet i juli-radene som skrives om.
  (select count(*) from public.maanedsplan)                       as maanedsplan_rader,
  (select count(*) from public.maanedsplan
    where matkast is not null)                                    as maanedsplan_med_snapshot,
  (select count(*) from public.maanedsplan
    where maaned = date '2026-07-01')                             as maanedsplan_juli,
  (select count(*) from public.maanedsplan
    where maaned = date '2026-07-01' and matkast is not null)     as maanedsplan_juli_snapshot;
