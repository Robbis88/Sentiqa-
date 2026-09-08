-- ---------------------------------------------------------------------
-- 0188: et beregnet beloep skal ikke se ut som et lest beloep
-- ---------------------------------------------------------------------
-- easy@work har tre eksporter som dekker loenn. Den ene har kroner
-- ferdig utregnet - og den finnes bare for TRE av fem stasjoner. For de
-- to andre fantes det ingen loennskost i det hele tatt.
--
-- Loennsgrunnlaget finnes for alle fem, men har antall og ikke kroner.
-- `lib/lonn/tilleggssats.ts` gjoer antall om til kroner med satser som
-- er MAALT mot kronefilene: 3 422,86 timer timeloenn og 1 425,72 timer
-- tillegg over Dale (juli, august) og Boenes (august). Alle
-- tilleggssatsene traff en rund verdi paa oeret.
--
-- Men et beregnet tall og et lest tall er ikke det samme tallet, selv
-- naar de er like. Endrer St1 en sats, er de leste radene fortsatt
-- riktige og de beregnede stille gale. Kolonnen her er det eneste
-- stedet den forskjellen kan staa.
--
-- Den brukes ogsaa som en regel i importen: kronefila vinner alltid.
-- Lastes loennsgrunnlaget for en periode som alt har leste rader,
-- hoppes stasjonen over med en merknad; lastes kronefila etterpaa,
-- ryddes de beregnede radene i samme spenn bort. Uten det ville
-- overtidsradene ligget dobbelt - kronefila skiller seks varianter av
-- 96/97, loennsgrunnlaget har to kolonner som baerer summen av sine, og
-- de kan ikke dele noekkel.
--
-- Taaler aa kjoeres om igjen: `if not exists`, og default false gjoer
-- hver eksisterende rad til det den er - lest.
alter table public.lonnsart_linje
  add column if not exists belop_beregnet boolean not null default false;

comment on column public.lonnsart_linje.belop_beregnet is
  'Er beloepet regnet av satstabellen (loennsgrunnlaget) i stedet for lest (loennsarteksporten)? Kronefila vinner alltid.';

-- Importen sporr «har denne stasjonen leste rader i dette spennet?» for
-- hver fil. Uten indeksen er det en full skanning per import.
create index if not exists lonnsart_linje_beregnet_idx
  on public.lonnsart_linje (stasjon_id, dato, belop_beregnet);

-- Kvittering. Kolonnen skal finnes, og alt som alt ligger der skal
-- staa som lest.
select
  count(*) filter (where belop_beregnet)       as beregnet,
  count(*) filter (where not belop_beregnet)   as lest
from public.lonnsart_linje;
