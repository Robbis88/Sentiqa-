-- =====================================================================
-- Sentiqa 0168 - nettbrettet bekrefter for seg selv, ikke for hvem som helst
--
-- SPEILBILDET AV 0165/0167, OG DET SISTE AV DEM
--
-- `kontrolltiltak_ins` (0145) tillater:
--
--   ansatt_id is null
--   or ansatt_id in (select a.id from public.ansatte a
--                     where a.stasjon_id in (select public.mine_stasjoner()))
--
-- Altsaa: en nettbrettsesjon kan skrive en aml. § 9-2-bekreftelse for
-- HVILKEN SOM HELST ansatt paa sin stasjon. Appen skriver alltid
-- vaktkapselens egen id - men RLS avgjoer hva som ER mulig, ikke hva
-- skjermen tilbyr.
--
-- Det er ikke en teoretisk flate. En bekreftelse er dokumentasjon paa at
-- informasjonsplikten er oppfylt overfor en navngitt person. Skrives den
-- for feil person, dokumenterer den noe som ikke har skjedd - og
-- arbeidsgiver staar med et papir som sier at hun er informert.
--
-- HVORFOR IKKE EN RPC
--
-- Fordi RLS - og en `security definer`-funksjon like saa - ikke kan se
-- vaktkapselen. `checkInn` setter en signert informasjonskapsel og
-- etterlater INGEN rad i basen. En RPC maatte tatt `p_ansatt_id` fra
-- kalleren, og da er vi noeyaktig der vi startet.
--
-- Serveren KAN se den: `lesAktivAnsatt` har to laaser - signaturen
-- beviser at noen tastet nummer og PIN, og oppslaget gaar gjennom
-- nettbrettets EGEN RLS. Skrivingen gjoeres derfor serverside med den
-- identiteten, og policyen her stenger den brede veien.
--
-- Samme regel som `admin.ts` naa baerer: en identitet serveren har
-- bevist, men RLS ikke kan se. Smalhet, ikke rang.
--
-- LEDEREN BEKREFTER SOM SEG SELV. `bekreftLest` setter `ansatt_id` bare
-- naar rollen er nettbrett; for alle andre settes `bruker_id`. Derfor kan
-- `ansatt_id`-armen tas helt bort her.
-- =====================================================================

drop policy if exists kontrolltiltak_ins on public.kontrolltiltak_bekreftelse;
create policy kontrolltiltak_ins on public.kontrolltiltak_bekreftelse
  for insert to authenticated
  with check (
    retailer_id = (select public.gjeldende_retailer_id())
    -- Bare lederflaten. Nettbrettets rad skrives serverside.
    and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef')
    -- Og hun bekrefter for SEG SELV. Ikke «eller null» - en lederrad uten
    -- bruker er en rad ingen kan staa inne for.
    and bruker_id = (select auth.uid())
    and ansatt_id is null
    -- Stasjonsloes er lovlig: en leder bekrefter som person, ikke som sted.
    -- Se 0147, som gir eieren lesetilgang til nettopp de radene.
    and (stasjon_id is null or stasjon_id in (select public.mine_stasjoner()))
  );

comment on policy kontrolltiltak_ins on public.kontrolltiltak_bekreftelse is
  'Lederflate, og bare for seg selv. Nettbrettets bekreftelse skrives '
  'serverside med identiteten fra lesAktivAnsatt - RLS kan ikke se '
  'vaktkapselen. Se migrasjon 0168.';
