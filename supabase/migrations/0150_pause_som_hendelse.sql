-- =====================================================================
-- 0150 - pause er en hendelse, aldri en beregning
--
-- PRODUKTBESLUTNING, Robert 2026-08-28:
--
--   All tid mellom inn- og utstempling er betalt arbeidstid. Ingen
--   automatisk pause trekkes. En ubetalt pause reduserer arbeidstiden
--   kun naar pausen faktisk er registrert ved at den ansatte trykker.
--   Nettbrettet faar EN pauseknapp: fast 30 minutter, ingen andre
--   lengder kan velges.
--
-- ---------------------------------------------------------------------
-- HVA SOM VAR GALT FOER
--
-- Fram til naa trakk systemet 30 minutter automatisk av hver vakt over
-- 5,5 time, naar kjeden hadde slaatt av `stempling_pause_betalt`.
-- Trekket ble skrevet til `stempling.minutter` - som loennsfila ikke
-- leser. Den regner klokketimer fra `fra_tid` til `til_tid` paa nytt,
-- saa trekket naadde aldri fram til Visma.
--
-- Verre: avstemmingen paa /lonn sammenligner `minutter` fra begge
-- kilder. Med trekket paa ble nettbrettets `minutter` lik easy@works
-- sum, avstemmingen viste null avvik, og fila betalte likevel pausen.
-- Innstillingen som fikk kildene til aa se like ut, var den som skjulte
-- at fila ikke var det.
--
-- Denne migrasjonen fjerner divergensen ved roten i stedet for aa rette
-- den: trekkes ingenting automatisk, er det ingenting aa miste.
--
-- ---------------------------------------------------------------------
-- HVORFOR PAUSEN BAERES SOM ET INTERVALL, IKKE SOM ET TALL
--
-- De samme minuttene skal utelates fra BAADE ordinaere timer og fra
-- tilleggsbaandene. Et fratrukket tall alene kan ikke svare paa om de
-- tretti minuttene laa foer eller etter klokka 18 - og en pause i
-- kveldsbaandet ville gitt kveldstillegg for tid ingen jobbet.
--
-- `pause_fra`/`pause_til` er derfor klokkeslett, som `fra_tid`/`til_tid`.
-- `minutter` er allerede redusert av avledningen.
--
-- ---------------------------------------------------------------------
-- HVA SOM IKKE ENDRES
--
-- Ingen policy, ingen rettighet, ingen ny tabell. Nettbrettet skriver
-- pausehendelsen gjennom NOEYAKTIG samme insert-policy som inn og ut -
-- en ny verdi i en check-liste er ikke en ny capability.
--
-- `type` er fortsatt det eneste som skiller hendelsene. Ingen andre
-- deler av stemplingsmodellen roeres.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1) `pause` som hendelsestype
--
-- Constrainten fra 0110 er navngitt av Postgres (`..._type_check`).
-- Begge navn droppes foerst, saa hele settet taaler aa kjores om igjen
-- fra bunn - da lages tabellen med den innebygde sjekken, og denne
-- migrasjonen erstatter den.
-- ---------------------------------------------------------------------
alter table public.stempling_hendelse
  drop constraint if exists stempling_hendelse_type_check;
alter table public.stempling_hendelse
  drop constraint if exists stempling_hendelse_type_sjekk;
alter table public.stempling_hendelse
  add constraint stempling_hendelse_type_sjekk
  check (type in ('inn', 'ut', 'pause'));

comment on column public.stempling_hendelse.type is
  'inn, ut eller pause. En pause er en REGISTRERT hendelse med fast '
  'lengde (30 min), ikke et beregnet trekk - og den snur ikke retningen: '
  'etter en pause er neste trykk fortsatt «ut». Se 0150.';


-- ---------------------------------------------------------------------
-- 2) Pausevinduet paa den avledede vakta
-- ---------------------------------------------------------------------
alter table public.stempling
  add column if not exists pause_fra time,
  add column if not exists pause_til time;

comment on column public.stempling.pause_fra is
  'Start paa registrert pause. Null naar ingen ble trykket. Baeres som '
  'INTERVALL og ikke bare som et fratrukket tall, fordi de samme '
  'minuttene skal utelates fra tilleggsbaandene ogsaa. Se 0150.';
comment on column public.stempling.pause_til is
  'Slutt paa registrert pause. KLEMT MOT SLUTTIDEN: trykker hun pause '
  '14:50 og stempler ut 15:00, er pausen ti minutter, ikke tretti.';


-- ---------------------------------------------------------------------
-- 3) Viewet maa gjenskapes for aa se de nye kolonnene
--
-- `select s.*` utvides ved OPPRETTELSE. Nye kolonner paa `stempling`
-- dukker ikke opp i et eksisterende view av seg selv, og loennsfila
-- ville lest en rad uten pausevindu uten at noe feilet.
--
-- `create or replace` framfor drop: den tillater aa LEGGE TIL kolonner
-- paa slutten, og de nye ligger nettopp der. Da roeres ikke
-- `v_stempling_ansatt_mnd` eller de seks funksjonene som leser den.
--
-- `with (security_invoker = true)` MAA staa: uten klausulen nullstiller
-- en replace flagget i stillhet, og viewet ville lest som eier - forbi
-- RLS. Punkt 9 i vakthunden kaster paa det.
-- ---------------------------------------------------------------------
create or replace view public.v_stempling_aktiv
with (security_invoker = true) as
select s.*
from public.stempling s
join public.stasjoner st on st.id = s.stasjon_id
where s.kilde = st.stempling_kilde;

comment on view public.v_stempling_aktiv is
  'Stemplinger fra kilden som teller for stasjonen. LES DENNE, ikke '
  'stempling, i alt som summerer timer. Fra 0150 baerer den ogsaa '
  'pause_fra/pause_til, som loennsfila trenger for aa holde de samme '
  'minuttene utenfor tilleggsbaandene.';

revoke all on public.v_stempling_aktiv from anon;
grant select on public.v_stempling_aktiv to authenticated;


-- ---------------------------------------------------------------------
-- 4) Den gamle innstillingen er ute av bruk
--
-- Kolonnen droppes IKKE her - det er en egen ryddejobb, og en drop av
-- en kolonne noen fortsatt kan lese er en stoerre endring enn denne
-- migrasjonen skal gjoere. Men ingenting leser den lenger:
-- `skrivAvledteVakter` sluttet aa slaa den opp i samme endring.
-- ---------------------------------------------------------------------
comment on column public.retailers.stempling_pause_betalt is
  'UTE AV BRUK fra 0150. Ingen kode leser den. Pause trekkes bare naar '
  'den er REGISTRERT som hendelse; det finnes ikke lenger et automatisk '
  'trekk aa slaa av eller paa. Kolonnen staar igjen til en egen '
  'ryddejobb - se pause.ts for regelen som gjelder.';


-- ---------------------------------------------------------------------
-- ETTER DENNE: kjor supabase/tests/rls_vakthund.sql.
--
-- Ingen policy er roert, men viewet er gjenskapt - og punkt 9 er
-- nettopp vakten mot at en replace mister `security_invoker`.
-- ---------------------------------------------------------------------
