# Integrasjoner, import og driftsautomatikk – 2026-09-17

Avgrenset read-only kildeanalyse. Ingen produksjonsspørringer, e-postutsendinger, secrets eller produktendringer. Vurderingen bygger på lokale serverhandlinger, cron-ruter, importkjerne, Cloudflare-worker, tenant-kontrakt og relevante migrasjoner. P1 er fare for feil datagrunnlag, mistet import eller feil ekstern tilstand; P2 er mangelfull feilrapportering, etablering eller driftskontroll. En kodefeilbane er ikke bevis for at en kunde allerede er rammet.

## Integrasjonskart

| Inngang | Flyt | Kontroll |
|---|---|---|
| Nettleserparsing | Parserresultat → `lagreForhandsparset` → batchet DB-lagring | Rolle/retailer, SHA-dublett, forretningsnøkler |
| Rå fil | Direkte Storage eller reserve-action → råfilrad → importjobb → serverparser | Egen retailer-stiprefiks, Storage/RLS, SHA |
| E-post | Cloudflare MIME → webhook → avsender/mottaker → Storage → råfil → jobb | Delt headersecret, aktiv retailer, eksplisitt allowlist |
| Natt | Importkø → vær/iCal/trafikk → kalibrering/backtest → AI/ukerapport | Cronsecret, serviceklient |
| Ukebrief | Kjedens stasjoner/mottakere → ferdig brief → Resend → sendelog | Cronsecret, tørrkjøring, historisk duplikatsperre |
| Kontrollrom | Hendelser, heartbeat, full brukssynk | Egne autentiseringsheadere |
| Opprydding | Retensjonssletting av AI/logg og PIN-forsøk | Cronsecret, eksplisitt tabelliste |

`vercel.json` planlegger heartbeat hvert femte minutt, natt daglig, retensjon daglig, brukssynk daglig og tre ukebrief-forsøk mandag. Kommentaren i `src/app/api/cron/ukebrief/route.ts` om at jobben ikke er planlagt er dermed foreldet. Planen i repo beviser ikke at riktig commit, secrets og alle eksterne tjenester er aktive i produksjon.

## P1: Full brukssynk kan publisere tom eller ufullstendig fasit ved lesefeil

`src/app/api/cron/rapporter-bruk/route.ts` ignorerer `error` fra både retailer- og stasjonsspørringen. `retailers ?? []` blir tom abonnementsmasse og `stasjoner ?? []` gir null stasjoner/prisgrunnlag. Dette sendes til `rapporterBruk`. `src/lib/kontrollrom.ts` dokumenterer endepunktet som fullsynk: det som ikke er med, fjernes.

Kodebeviset er at et ugyldig lokalt grunnlag kan sendes som komplett. At kontrollrommets server faktisk sletter ved tom liste er ikke verifisert her; dette er dokumentert grensesnittsemantikk som gjør feilen viktig. Begge datalister kan dessuten avkortes ved PostgREST-taket. Feltet `antall_brukere` settes til antall retailers, ikke profiler; om mottakersystemet mener kunder eller innloggingsbrukere må kontraktsfestes.

**Forslag:** Verifiser alle kildespørringer og kompletthet før fullsynk. Bruk DB-aggregat per retailer. Publiser ingen erstatningsfasit når målingen feiler. Direkte tester for query-error, manglende data og avkorting. Sammenlign med forrige synk og forklar store nedganger før mottakeren gjør dem permanente.

## P1: Råfil og importjobb opprettes uten samlet transaksjon eller full kompensering

`src/app/(beskyttet)/import/handlinger.ts` registrerer først `raa_filer`, så `import_jobber`. Ved jobbfeil returnerer råfilregistrering feil uten å frigjøre råfilens aktive SHA-dublett. Reserveopplasting gjør tilsvarende. Neste opplasting finner «allerede lastet opp», men ingen importjobb; gjenopplasting alene reparerer ikke tilstanden.

E-postwebhooken er svakere: `src/app/api/epost-inntak/route.ts` destructurerer bare `{data: jobb}` fra jobbinnsetting, ignorerer `error` og øker `antall` selv om `jobb` er null. Den returnerer `ok:true`/mottatt vedlegg uten en jobb som køen kan finne. Råfilen blir stående med dedup-lås.

Nettleserimportens `lagreForhandsparset` har allerede en bedre feilbane: ved jobbfeil mykslettes råfilen før retur, slik at SHA kan forsøkes igjen. Den kompenserende oppdateringen er ikke selv bekreftet, men mønsteret er konkret å harmonisere rundt.

**Forslag:** Atomisk råfil+jobb i DB-funksjon, mens Storage håndteres med eksplisitt kompensering; eller sikker reparasjon av råfil uten jobb ved retry. Ikke øk mottatt-teller før en bekreftet jobb finnes. Legg kanarifixture med råfil uten jobb og feil i jobbinnsetting.

## P1/P2: Delvis e-postmottak rapporteres, men workeren ser ikke rapporten

Webhooken samler flere feil i `hoppet`, men returnerer HTTP 200 og `ok:true`. `cloudflare/email-worker.js` sjekker bare `res.ok`, og leser ikke JSON-body. Kommentaren i webhooken sier «workeren ser det»; det gjør denne workeren ikke. Et vedlegg som ikke kom inn i Storage/DB kan dermed gi full suksess gjennom leveringskjeden. SHA-dublett er dessuten blandet inn i samme feilliste som reelt mistet vedlegg.

**Forslag:** Skill mottatt, duplikat, avvist og feilet. Gjør reelle retrybare mottaksfeil synlige i workerens kontroll/logg og varig app-logg. Før man bytter til ikke-2xx ved delvis feil må retry være idempotent, inkludert råfil-uten-jobb-feilen over. Ingen anbefaling om å sende prøve-e-post til kunder som del av denne analysen.

Avsenderallowlist er korrekt fail-closed ved tom liste. Secret kan også sendes i URL-query som reserve; ingen secret er lest her. Foretrekk header i konfigurasjon fordi URL-er lettere blir med i proxy-/trafikklogg. Cloudflare-workeren bruker allerede header. Leverandørens SPF/DKIM/DMARC- og envelope-policy er ikke bevist fra appkoden; allowlist alene beviser ikke avsenderautentisering.

## P1/P2: Nattjobben har isolasjon uten komplett sannferdig resultat

`src/app/api/cron/natt/route.ts` kjører import før analysene, som er riktig avhengighetsrekkefølge. Den isolerer kjeder og eksterne tjenester med try/catch, så én feil ikke stopper alt. Men `feilet` fylles kun ved to returnerte RPC-errors for værprofil. Catch for disse RPC-ene fyller heller ikke listen. Feil i import, vær, iCal, trafikk, backtest og AI/ukerapport per retailer svelges. `ok:feilet.length===0` kan derfor være sann etter mange mislykkede ledd.

`src/lib/import/ko.ts` ignorerer query-errors og update-errors under gjenopptakelse. Teller `gjenopptatt`/`oppgitt` økes uten bekreftet oppdatering. `behandleJobbKjerne` returnerer normalt etter nedlastingsfeil eller ukjent rapporttype, etter å ha forsøkt å markere jobben feilet. Køen øker `ut.ok` så lenge funksjonen ikke kaster. Det betyr at «ok» i køresultatet ikke nødvendigvis betyr vellykket import. Køen har limit 200 eldste jobber per kjøring og kjøres sekvensielt innen samme 300-sekunders nattjobb som øvrige tunge analyser.

**Forslag:** Returner eksplisitt terminalresultat fra importkjernen. Alle ledd får forsøkt/lyktes/feilet/hoppet, varighet og sikker feilidentitet. En vellykket heartbeat skal ikke bety vellykket nattkjøring. Prioriter separat køarbeider med kort tidsbudsjett og cursor/claim før man øker parallellitet. Kapasitet ved dagens produksjonsvolum kan ikke bestemmes fra kode alene.

## P1/P2: Gjentakbare jobber er ikke nødvendigvis samtidighetssikre

Importkjernen setter `status:'behandler'` med ukondisjonell `update ... eq(id)`; ingen bekreftet claim med gammel status eller DB-lås vises i dette laget. Nattkø og manuell behandling kan derfor starte samme jobb samtidig. SHA-dedup og den aktive importens unike indeks fra 0209 beskytter andre identitetsnivåer, men er ikke alene en claim på selve jobbkjøringen. Batchede upserts gjør mye gjentakelse trygg; importkjerne har også delete/replace-baner som gjør samtidighet viktig.

Ukebrief leser historisk sendelog før e-post og skriver loggen etter e-post. `src/lib/ukebrief/send.ts` sender uten provider-idempotency-key i det observerte kallet. Krasj etter levering før DB-logg, DB-loggfeil eller samtidige kjøringer kan dermed gi dobbelt brev. Delvis unik indeks `where status='sendt'` hindrer dobbel loggrad, men brevet er allerede sendt når indeksen avviser. Tre mandagsforsøk gjør retry nyttig, og gjør dette vinduet relevant.

**Forslag:** Atomisk jobbclaim og lease med siste aktive tid. For e-post: deterministisk idempotensnøkkel per stasjon/uke/profil hos leverandøren, bekreftet claim i DB og avstemming av ukjent leveringsresultat. Verifiser leverandørens faktiske idempotensstøtte før implementasjon. Eksisterende tørrkjøring skal brukes til review før ekte utsending.

## P2: Logg og retensjon kan gi misvisende helse

`loggHendelse` i `src/lib/kontrollrom.ts` ignorerer returnert HTTP-status og har ingen eksplisitt timeout. Logger skal ikke velte produktet, men et hengende fetch kan fortsatt holde en awaitende serverhandling lenge; avvist hendelse gir ingen alternativ diagnostikk. Heartbeat/brukssynk sjekker `res.ok`, men heller ikke disse har eksplisitt tidsgrense i dette laget.

`src/app/api/cron/opprydding/route.ts` gir `ok:true` selv om `slettet` inneholder feiltekster. Slettet-radtelleren bruker returnert data-lengde og kan være avkortet, selv om selve slettingen har skjedd. Rapporter feil og bekreftet antall separat; ikke bruk etterpå-returnerte rader som bevis for komplett revisjon.

Vær og iCal har lignende blinde flekker: `hentVaerMedKlient` kan returnere `ok:true` ved null lagrede værpunkter. iCal hopper over HTTP-/DB-feil og teller `forslag++` ved upsert uten error, også når `ignoreDuplicates` betyr ingen ny rad. `src/lib/ical.ts` bruker UTC-dato for i dag, mens andre driftsmoduler bruker Oslo-dato; ved norsk midnatt kan grensen være én dag forskjellig. RRULE ekspanderes eksplisitt ikke; dette er en dokumentert funksjonsbegrensning, ikke en skjult parserfeil.

## Tenant-kontrakt og etablering

`supabase/tenant-kontrakt.json` klassifiserer importjobber som retailer-eiers skriveflate, butikksjefens stasjonsbundne lesing og ingen tablet-tilgang. Serverhandlingene for import krever retailer_admin, som passer denne modellen. Kampanjer har klientlesing og service-role-skriving; plattformhandlingen bruker nettopp serviceklienten.

Kontrakten dokumenterer derimot `avvik_fra_intensjon` for kalenderkilder og arrangementer: butikksjef kan skrive kjedebredt i databasen, mens `arrangementer/handlinger.ts` sier og håndhever eier alene i UI-serverhandling. Dette er en eksisterende, skrevet produkt-/RLS-forskjell. En grønn generert matrise kan bevise dagens kontrakt, samtidig som produktbeslutningen fortsatt mangler. Dette må ikke forveksles med at kontrakten alltid beskriver ønsket endelig produkt.

Kalenderkilders `stasjon_ider` lagres som array og sendes uvalidert videre fra formdata; cron bruker arrayet direkte med service-role. Migrasjon 0061 legger til array og dedup-index, ikke en tenant-validering av arrayelementene. Kontrakten sier også at arrayet ikke er tenantgrensen. Det er en konkret grense som må testes: avvis stasjoner utenfor egen kjede ved opprettelse/endring og igjen før service-role-import. Denne delanalysen har ikke bevist resultatet mot alle endelige triggere/policies; den hevder derfor ikke en produksjonslekkasje. URL-validering for iCal er bare http(s)-prefiks og serveren fetcher den senere: klassifiser intern nettverkstilgang/redirects før dette åpnes bredere.

Onboarding dekker mange filtyper, historikk og butikksjef-tildeling. Rapporten `analyse-admin-2026-09-17.md` beskriver bilvask-relevans, manglende ferskhet og manglende modulbaserte oppsett. Eksternt etableringsbevis må inkludere Storage, lovlig avsender, Cloudflare routing, secrets samsvar, fungerende SMTP/Resend, provider-rettigheter og planlagt cron. Det skal utledes så langt mulig, med eksplisitte manuelle kvitteringer for det appen faktisk ikke kan måle.

## Hva som fortsatt krever andre bevis

- Ingen produksjonsmåling av kødybde, varighet, timeout, ferskhet, feilede sendelogger eller etterlatte Storage-objekter er gjort.
- Ingen bekreftelse av leverandørretry, autentisert e-postavsender, virkelige invitasjoner eller ekstern fullsynk-semantikk er gjort.
- Endelig databaseatferd krever lokal komplett migrasjonskjøring og tenantmatrise, med direkte negative array-/service-role-prober. Produksjon krever egne read-only katalog-/statuskontroller.
- Nye SQL-funksjoner/migrasjoner må være idempotente og leveres manuelt etter repo-reglene. Ingen migrasjon er skrevet eller kjørt i denne analysen.

Onboardingpåvirkning: NEI for rapporten. Rettelser som gjør nye kanalvalg eller integrasjonskontrollpunkter nødvendige må vurdere JA eksplisitt; robustere retry/logging alene innfører ikke nødvendigvis nye kundekrav.
