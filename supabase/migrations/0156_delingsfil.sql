-- =====================================================================
-- DELINGSFILA: TIMEBUDSJETTET SOM IKKE STAAR I BP-EN
--
-- St1 sender to filer for hvert budsjettaar: forretningsplanen og en
-- delingsfil. BP26-malen har et eget ark "Timebudsjett Grunnlagsfil", saa
-- der kommer timene med. DEN GAMLE MALEN HAR DEM IKKE - og BP25 for
-- Laguneparken, Varden og Boenes er den gamle.
--
-- Timene finnes likevel, oppgitt og ikke utledet, i delingsfilas
-- "Timer"-ark, kolonne `Timebudsjett`:
--
--     SHELL BOENES          6 654
--     SHELL LAGUNEPARKEN   13 212,84
--     SHELL VARDEN          8 957,42
--
-- Uten dem kan kr/time ikke leses for 2025, og sammenligningen mot 2026
-- mangler nettopp det tallet Robert er ute etter: "det er posetivt om vi
-- faar hoeyere timepris pr time paa loenn, for det er det st1 gir oss".
--
-- ---------------------------------------------------------------------
-- HVORFOR IKKE BARE REGNE DEM UT
--
-- Arket har byggeklossene ogsaa: grunnbemanning 10 400, stengte timer per
-- doegn, fratrekk per aar, fratrekk aarsverk, mattillegg. Foerste forsoek
-- paa aa utlede timene traff Boenes eksakt (6 654) og bommet paa Varden
-- med 390 og Laguneparken med 2 913 - fordi kolonnen `Tillegg annen oms`
-- ikke var med.
--
-- En utledet formel som bommer 22 % ser noeyaktig like riktig ut som en
-- som treffer. Naar tallet staar i fila, leses det.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. NY RAPPORTTYPE
-- ---------------------------------------------------------------------
-- `if not exists` finnes for enum-verdier fra PG 12, og migrasjonene her
-- kjoeres om igjen fra bunn av og til.

alter type public.rapporttype add value if not exists 'st1_delingsfil';

-- ---------------------------------------------------------------------
-- 2. KVITTERING
-- ---------------------------------------------------------------------
-- SQL Editor viser ikke `raise notice`, saa svaret maa komme som en rad.
-- `verdien_finnes` skal vaere 1.

select count(*) as verdien_finnes
from pg_enum e
join pg_type t on t.oid = e.enumtypid
where t.typname = 'rapporttype' and e.enumlabel = 'st1_delingsfil';
