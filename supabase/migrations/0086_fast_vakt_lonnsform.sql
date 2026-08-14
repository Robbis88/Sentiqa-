-- ---------------------------------------------------------------------
-- 0086: lonnsform paa faste vakter
-- ---------------------------------------------------------------------
-- "Fast vakt" betydde fastlonn. Det holdt saa lenge det bare var
-- butikksjefen, men en NK kan ha en like fast vakt og likevel vaere
-- timelonnet: staar hun 05-12 hver tirsdag, er det sju timer som skal
-- betales av timerammen. Fort som fastlonn trodde planen at de timene
-- var gratis, og delte dem ut en gang til et annet sted i uka.
--
-- Default false = fastlonn, altsaa dagens oppforsel for alle
-- eksisterende rader. Ingen backfill: det er butikksjefen som vet hvem
-- av dem som er timelonnet, og en gjetning her ville roret budsjettet.
alter table public.bemanning_fast_vakt
  add column if not exists timelonnet boolean not null default false;

comment on column public.bemanning_fast_vakt.timelonnet is
  'true = vakten er bundet, men belaster timerammen (timelonnet NK). '
  'false = fastlonn, dekker gulvet uten a koste rammen.';

comment on table public.bemanning_fast_vakt is
  'Faste bindinger, f.eks. butikksjef 07-15 man-fre. En rad per ukedag. '
  'timelonnet skiller de som koster timerammen fra de som ikke gjor det.';
