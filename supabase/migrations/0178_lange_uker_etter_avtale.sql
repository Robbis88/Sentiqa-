-- =====================================================================
-- «JOBBER LANGE UKER ETTER AVTALE»
--
-- `/lonn` varsler naar en uke bikker 37,5 timer (35,5 for to skift).
-- Grensene er riktige, men de gjelder ikke alle: **paa hver stasjon
-- finnes ansatte med individuell avtale om uke paa / uke av**, og en slik
-- arbeidsuke er sju dager og rundt 53 timer HVER GANG.
--
-- Varselet fyrte altsaa hver maaned paa folk som gjorde noeyaktig det
-- avtalen deres sier. Maalt paa Boenes, august 2026:
--
--     Lars Neteland   39,7   40,1   15,9   53,6   8,2   (snitt 35,5)
--
-- Fire funn, 20,9 timer «over» - av dem er tre stoey. En vakt som roper
-- om det normale blir ikke lest, og da drukner det ene funnet som betyr
-- noe. Samme grunn som `0159` tok 538 normale svinndager ut av
-- hulltellingen.
--
-- ---------------------------------------------------------------------
-- HAKEN FJERNER IKKE GRENSEN. DEN BYTTER DEN.
--
-- Aml. § 10-5 tillater gjennomsnittsberegning ved skriftlig avtale, og
-- setter da egne tak. Robert bekreftet 2026-09-06 at avtalene deres er
-- INDIVIDUELLE - ikke inngaatt med tillitsvalgt - og da gjelder:
--
--     10 timer per dag   (mot 9 i aml. § 10-4)
--     48 timer per uke   (54 krever avtale med fagforening)
--
-- Lars' tyngste uke er 53,6. **Den er fortsatt et funn**, og et ekte et:
-- den er mer enn en individuell avtale tillater. Med haken gaar han fra
-- fire funn til ett, og det ene er verdt aa se paa.
--
-- ---------------------------------------------------------------------
-- INGEN AVTALEPERIODE, OG DET ER MED VILJE
--
-- § 10-5 krever at avtalen definerer en periode, og et snitt kunne vaert
-- regnet over den. Men haken skal ikke REGNE noe - den skal si at lange
-- uker er avtalt, og bytte taket. Da trenger den ingen periode, og vi
-- slipper aa lagre en opplysning noen maa vedlikeholde for at et varsel
-- skal vaere riktig.
--
-- ---------------------------------------------------------------------
-- INGEN HAKE FOR § 10-12
--
-- «Ledende» og «saerlig uavhengig» stilling er unntatt arbeidstidsreglene
-- helt. Det er et smalt unntak, og en NK paa en stasjon faller normalt
-- utenfor. En avkryssing for det ville blitt satt paa hver NK, og da er
-- hele varselet borte. Den vurderingen hoerer hjemme i kontrakten.
--
-- Idempotent: `add column if not exists`, default false. En ansatt som
-- ikke er vurdert faar den strengeste grensen - det trygge svaret.
-- =====================================================================

alter table public.ansatt_avtale
  add column if not exists lange_uker_avtalt boolean not null default false;

comment on column public.ansatt_avtale.lange_uker_avtalt is
  'Individuell avtale om gjennomsnittsberegnet arbeidstid (aml. § 10-5) - '
  'typisk uke paa / uke av. Byttet ut ukegrensen 37,5/35,5 med § 10-5-taket '
  '48 t/uke og dagsgrensen 9 med 10. Satt av butikksjef, aldri utledet: '
  'avtalen er skriftlig og finnes utenfor systemet.';

-- Kvittering. `raise notice` vises ikke i SQL Editor - se 0145.
select count(*) filter (where lange_uker_avtalt) as med_haken,
       count(*)                                  as avtaler_i_alt,
       (select count(*) from information_schema.columns
         where table_schema = 'public' and table_name = 'ansatt_avtale'
           and column_name = 'lange_uker_avtalt')  as kolonnen_finnes
from public.ansatt_avtale;
