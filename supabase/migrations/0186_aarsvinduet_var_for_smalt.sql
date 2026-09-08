-- ---------------------------------------------------------------------
-- 0186: aarsvinduet i 0184 og 0185 var for smalt
-- ---------------------------------------------------------------------
-- Begge tabellene fikk `check (ar between 2000 and 2100)`. Det er den
-- samme feilen `0155` skrev ned en advarsel om, og jeg gjentok den:
--
--     «Vinduet er vidt med vilje. Sjekken skal fange villskap - 0,
--      negative tall, 9999 fra en parser paa avveie - ikke gjette
--      hvilke aar en kjede kan ha BP for. Et smalere vindu ga dessuten
--      tenantmatrisen for faa verdier aa variere over, og en fixture
--      som kolliderer med seg selv gir 23505: en domenefeil forkledd
--      som en sikkerhetsavvisning.»
--
-- Konkret: `ar` staar i `business_unik` for begge tabellene, og
-- tenantmatrisen krever at hver slik kolonne VARIERER per forsoek.
-- Plassholderen `{{unik_aar}}` gir 2100-2499 fra generatoren og
-- 2500-2899 fra sekvensen - to atskilte rom, nettopp for at proberaden
-- og forsoeket ved siden av den ikke skal kollidere.
--
-- Med et tak paa 2100 ville nesten hver verdi brutt sjekken, og 23514
-- ser ut som en avvisning uten aa vaere en.
--
-- 2999 er samme vindu som `bp_aar`. Taaler aa kjoeres om igjen.
alter table public.bilvask_abonnement
  drop constraint if exists bilvask_abonnement_ar_check;
alter table public.bilvask_abonnement
  add constraint bilvask_abonnement_ar_check check (ar between 2000 and 2999);

alter table public.butikksjef_fastlonn
  drop constraint if exists butikksjef_fastlonn_ar_check;
alter table public.butikksjef_fastlonn
  add constraint butikksjef_fastlonn_ar_check check (ar between 2000 and 2999);

-- Kvittering. Begge skal staa med 2999 som oevre grense.
select
  rel.relname                                as tabell,
  pg_get_constraintdef(c.oid)                as sjekk
from pg_constraint c
join pg_class rel on rel.oid = c.conrelid
where rel.relname in ('bilvask_abonnement', 'butikksjef_fastlonn')
  and c.conname like '%_ar_check'
order by rel.relname;
