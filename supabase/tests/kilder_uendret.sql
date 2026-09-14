-- =====================================================================
-- KILDENE SKAL IKKE FLYTTE SEG
-- =====================================================================
-- Rent lesende. Kjoeres FOER og ETTER en regenerering av
-- maanedsplanutkastene, og de to svarene sammenlignes rad for rad.
--
-- Alt unntatt de tre `maanedsplan`-radene skal vaere IDENTISK.
--
-- ---------------------------------------------------------------------
-- RADANTALL OG SUM BEVISER IKKE UENDRET INNHOLD
-- ---------------------------------------------------------------------
--
-- Foerste utgave sa at antall og sum «dekker hverandres blindsone».
-- Det er matematisk feil, og det er verdt aa skrive ned hvorfor:
--
--     rad A  +100
--     rad B  -100
--
-- Antallet er likt. Summen er lik. To beloep har flyttet seg. To
-- aggregater over samme mengde er begge invariante under et par som
-- opphever hverandre - de DELER blindsonen, de dekker den ikke.
--
-- Beviset er derfor en DIGEST over hver rad, hele raden:
--
--     md5(string_agg(md5(t::text), '' order by <noekkel>))
--
-- `t::text` renderer hver kolonne i hver rad. Endres ett beloep hvor som
-- helst, endres digesten - ogsaa naar summen staar stille.
--
-- Antall og sum staar fortsatt her. De er LESBARE for et menneske og
-- sier hvor man skal lete. De er ikke beviset.
--
-- ---------------------------------------------------------------------
-- NULL, TOM TABELL, SORTERING
-- ---------------------------------------------------------------------
--
-- NULL:  `t::text` skriver raden som record-literal. NULL blir et tomt
--        felt `(1,,x)`, tom streng blir sitert `(1,"",x)`. De er
--        entydig forskjellige - det er Postgres' egen record-utskrift,
--        ikke en antakelse.
--
-- TOM:   `string_agg` over null rader gir NULL, og `md5(NULL)` er NULL.
--        `coalesce(..., 'TOM')` gir en definert verdi.
--
-- ORDEN: hver digest sorteres paa en DOKUMENTERT unik noekkel. Ti av
--        tabellene har `id uuid primary key`. `daglig_salg` har ingen
--        `id` - den har sammensatt primaernoekkel
--        `(retailer_id, stasjon_id, dato, ean)`, og den brukes.
--
-- ---------------------------------------------------------------------
-- DAGLIG_SALG: PER MAANED, IKKE SLAATT SAMMEN
-- ---------------------------------------------------------------------
--
-- 2 847 193 rader. Én ordnet `string_agg` over hele tabellen ville
-- sortert alt paa én gang; her grupperes det per maaned, saa
-- minnebehovet er én periode av gangen mens HVER rad er dekket.
--
-- Maanedsdigestene slaas IKKE sammen til én verdi. Flytter noe seg,
-- skal man kunne se noeyaktig hvilken maaned - en samlet verdi ville
-- sagt «noe er galt» og ingenting mer.
--
-- Et analysevindu ville ikke bevist paastanden. Regenereringen skal
-- aldri roere NOEN periode, og da maa alle periodene maales.
-- =====================================================================

with t as (

-- --- Regnskapsgrunnlaget ---------------------------------------------
select 'regnskapslinjer' as omraade, '(alle)' as noekkel,
       (select count(*) from public.regnskapslinjer)                    as rader,
       (select coalesce(sum(regnskap), 0)::text from public.regnskapslinjer) as sum_kr,
       (select coalesce(md5(string_agg(md5(x::text), '' order by x.id)), 'TOM')
          from public.regnskapslinjer x)                                as digest
union all
select 'regnskap_usynlig_svinn', '(alle)',
       (select count(*) from public.regnskap_usynlig_svinn),
       (select coalesce(sum(usynlig_kr), 0)::text from public.regnskap_usynlig_svinn),
       (select coalesce(md5(string_agg(md5(x::text), '' order by x.id)), 'TOM')
          from public.regnskap_usynlig_svinn x)
union all
select 'bilagssum', '(alle)',
       (select count(*) from public.bilagssum),
       (select coalesce(sum(belop_kr), 0)::text from public.bilagssum),
       (select coalesce(md5(string_agg(md5(x::text), '' order by x.id)), 'TOM')
          from public.bilagssum x)

-- --- Budsjett og satser ----------------------------------------------
union all
select 'bp_aar', '(alle)',
       (select count(*) from public.bp_aar), '-',
       (select coalesce(md5(string_agg(md5(x::text), '' order by x.id)), 'TOM')
          from public.bp_aar x)
union all
select 'bp_linje', '(alle)',
       (select count(*) from public.bp_linje),
       (select coalesce(sum(belop_kr), 0)::text from public.bp_linje),
       (select coalesce(md5(string_agg(md5(x::text), '' order by x.id)), 'TOM')
          from public.bp_linje x)
union all
select 'kastbudsjett', '(alle)',
       (select count(*) from public.kastbudsjett),
       (select coalesce(sum(kast_pst_av_salg), 0)::text from public.kastbudsjett),
       (select coalesce(md5(string_agg(md5(x::text), '' order by x.id)), 'TOM')
          from public.kastbudsjett x)
union all
select 'royaltysats', '(alle)',
       (select count(*) from public.royaltysats),
       (select coalesce(sum(lav_sats), 0)::text from public.royaltysats),
       (select coalesce(md5(string_agg(md5(x::text), '' order by x.id)), 'TOM')
          from public.royaltysats x)

-- --- Proveniens og importkoe -----------------------------------------
union all
select 'raa_filer', '(alle)',
       (select count(*) from public.raa_filer), '-',
       (select coalesce(md5(string_agg(md5(x::text), '' order by x.id)), 'TOM')
          from public.raa_filer x)
union all
select 'import_jobber', '(alle)',
       (select count(*) from public.import_jobber), '-',
       (select coalesce(md5(string_agg(md5(x::text), '' order by x.id)), 'TOM')
          from public.import_jobber x)

-- --- Stasjonsregisteret ----------------------------------------------
union all
select 'stasjoner', '(alle)',
       (select count(*) from public.stasjoner), '-',
       (select coalesce(md5(string_agg(md5(x::text), '' order by x.id)), 'TOM')
          from public.stasjoner x)

-- --- DAGLIG_SALG, ÉN RAD PER MAANED ------------------------------------
union all
select 'daglig_salg', to_char(d.maaned, 'YYYY-MM'), d.rader, d.sum_kr, d.digest
  from (
    select date_trunc('month', x.dato)::date as maaned,
           count(*)                          as rader,
           coalesce(sum(x.omsetning_eks_mva), 0)::text as sum_kr,
           md5(string_agg(md5(x::text), ''
               order by x.retailer_id, x.stasjon_id, x.dato, x.ean)) as digest
      from public.daglig_salg x
     group by 1) d

-- --- TALLENE PLANEN FAKTISK LESER -------------------------------------
-- Gjennom samme view som motoren. Flytter noe seg her, flytter analysen
-- seg - uansett hvilken tabell under som var aarsaken.
union all
select 'v_kurs_maanedstall', '(alle)',
       (select count(*) from public.v_kurs_maanedstall),
       (select coalesce(sum(matkast_kr), 0)::text from public.v_kurs_maanedstall),
       (select coalesce(md5(string_agg(md5(x::text), ''
                 order by x.stasjon_id, x.maaned)), 'TOM')
          from public.v_kurs_maanedstall x)

-- --- DET SOM HAR LOV TIL AA ENDRE SEG ---------------------------------
-- Bare disse tre radene. `utenom_maalmaaned` er den DIREKTE maalingen
-- av paastanden «bare radene for maalmaaneden kunne endres»: den skal
-- vaere identisk foer og etter.
union all
select 'maanedsplan', '(alle)',
       (select count(*) from public.maanedsplan), '-',
       (select coalesce(md5(string_agg(md5(x::text), '' order by x.id)), 'TOM')
          from public.maanedsplan x)
union all
select 'maanedsplan', 'utenom_maalmaaned',
       (select count(*) from public.maanedsplan
         where maaned <> date '2026-07-01'), '-',
       (select coalesce(md5(string_agg(md5(x::text), '' order by x.id)), 'TOM')
          from public.maanedsplan x where x.maaned <> date '2026-07-01')
union all
select 'maanedsplan', 'maalmaaned_2026-07',
       (select count(*) from public.maanedsplan
         where maaned = date '2026-07-01'),
       (select count(*)::text from public.maanedsplan
         where maaned = date '2026-07-01' and matkast is not null),
       (select coalesce(md5(string_agg(md5(x::text), '' order by x.id)), 'TOM')
          from public.maanedsplan x where x.maaned = date '2026-07-01')
)
select omraade, noekkel, rader, sum_kr, digest
  from t
 order by omraade, noekkel;
