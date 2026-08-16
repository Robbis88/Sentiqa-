-- ---------------------------------------------------------------------
-- 0097: rammeavtale om tilkalling
-- ---------------------------------------------------------------------
-- Virke er tydelige: en deltidsansatt som skal kunne ta en ekstravakt ved
-- sykdom trenger en RAMMEAVTALE OM TILKALLING i tillegg til den faste
-- avtalen. Uten den kan de ekstra timene senere kreves som overtid.
--
-- Det er derfor ikke et dokument i en mappe - det er en TILSTAND som
-- avgjor om en vakt kan settes opp. En mappe maa apnes for aa vite
-- svaret; et felt kan sperre en publisering.
--
-- Malt paa Kelsars egne stemplinger, 19 maaneder: Olaf paa Bones har
-- median 19 % og topp 66 %. Jonathan paa Laguneparken 41 % mot 114 %.
-- Uten rammeavtale er hver av de maanedene en apen fordring.
alter table public.ansatt_avtale
  add column if not exists har_rammeavtale boolean not null default false,
  add column if not exists rammeavtale_signert date;

comment on column public.ansatt_avtale.har_rammeavtale is
  'Rammeavtale om tilkalling signert. Uten den kan ekstravakter utover '
  'stillingsprosenten senere kreves som overtid (Virke).';
comment on column public.ansatt_avtale.rammeavtale_signert is
  'Naar den ble signert. Null selv om har_rammeavtale er true betyr at '
  'noen har krysset av uten aa registrere datoen.';
