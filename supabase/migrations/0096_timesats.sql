-- ---------------------------------------------------------------------
-- 0096: timesats per ansatt
-- ---------------------------------------------------------------------
-- Tariffkontrollen trenger satsen, og den finnes ikke i systemet.
-- Stemplingene gir timer, ikke kroner. Satsen staar i lonnseksporten fra
-- easy@work, men den importerer vi ikke.
--
-- Hvorfor det er verdt en kolonne: av ti ansatte paa Bones i mai traff
-- sju Energiavtalens satser eksakt. Tre gjorde ikke - to laa mellom to
-- trinn, og en laa 15,44 UNDER laveste voksensats. Det siste er enten
-- feil alder registrert, eller en sats som aldri ble justert etter
-- forrige oppgjor. Ingen av delene ser noen i dag.
--
-- skiftordning avgjor ukentlig arbeidstid: 37,5 timer ordinaert, 35,5
-- ved to skift. Den som gaar fast kveld og helg er paa to skift og skal
-- ha den hoyere satsen - det folger av hvordan vaktene faktisk ligger,
-- ikke av hva som staar i kontrakten.
alter table public.ansatt_avtale
  add column if not exists timesats numeric,
  add column if not exists skiftordning text,
  add column if not exists tariffgruppe text,
  add column if not exists ansiennitet int;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'ansatt_avtale_timesats_sjekk'
  ) then
    alter table public.ansatt_avtale
      add constraint ansatt_avtale_timesats_sjekk
      check (timesats is null or (timesats > 0 and timesats < 2000));
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'ansatt_avtale_skift_sjekk'
  ) then
    alter table public.ansatt_avtale
      add constraint ansatt_avtale_skift_sjekk
      check (skiftordning is null or skiftordning in ('ordinaer', 'to_skift'));
  end if;
end $$;

comment on column public.ansatt_avtale.timesats is
  'Utbetalt timesats. Males mot Energiavtalen i lonnskontrollen.';
comment on column public.ansatt_avtale.skiftordning is
  'ordinaer = 37,5 t/uke, to_skift = 35,5 t/uke.';
