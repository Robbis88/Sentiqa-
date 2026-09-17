# Sentiqa: admin og plattform, kodeanalyse 2026-09-17

Dette er en read-only gjennomgang av den lokale kildekoden. Ingen produksjonsdata, brukerkontoer eller tilgang er endret. Funnene nedenfor beskriver observerbar kodeatferd; faktisk frekvens, produksjonsomfang og brukeropplevelse er ikke målt i denne delanalysen. Rapporten er et forslag til arbeid, ikke en bekreftelse på at alle funksjoner er feilfrie.

## Rollekart og arbeidsflyter

`src/app/(beskyttet)/navigasjon.ts` skiller mellom kjedeeier (`retailer_admin`), butikksjef, tablet og plattformredaktør. Kjedeeieren har porteføljehjem, drift, salg, team, økonomi/innsikt og innstillinger. Plattform har fem innganger: Plattform, Trafikk, Kampanjer, Publisering og Kunnskapsbase. Sidemeny og faner er data og kan kontrolleres uten å bygge appen. Dette er et godt fundament for omorganisering uten å slette funksjoner.

Kjedens etablering går gjennom registrering eller plattformens `opprettKunde`, invitasjon/passord, godkjenning, stasjoner, bruker/stasjon-tildeling, ansatte/PIN, filimport og eventuelle integrasjonsoppsett. Dagens onboarding vises inne på Import. Den dekker datakilder og ett oppsettkrav: butikksjef på stasjon. Trafikk kobles av plattformen; koordinater og værfølsomhet settes av kjeden. Persondata, abonnement og støttehistorikk har egne funksjoner.

Plattformens livssyklus er opprett/inviter, godkjenn, åpne tidsavgrenset støtte, deaktiver/reaktiver og slett permanent. Permanente kjededata slettes med databasefunksjon, auth-brukere etterpå; koden rapporterer etterlatte innlogginger ved delvis feil. Dette er eksplisitt og bør bevares.

## Prioriterte funn

### P1: Datadekning kan gi et falskt positivt svar ved databasefeil

**Kodebevis:** `src/app/(beskyttet)/dekning/page.tsx:123` leser bare `data` fra `v_datohull`; `hullRader ?? []` blir tom liste ved query-feil. Deretter velger linje 135 «Ingen huller de siste 14 månedene». De første fire `v_datodekning`-spørringene ignorerer også `error`. Dermed kan siden som skal bevise datakvalitet presentere fravær av måling som fravær av problemer.

**Endring:** Krev vellykket og komplett måling før en dom. Vis «Datadekning kunne ikke kontrolleres» ved feil, med retry. Legg direkte test på query-feil og avkorting. Ingen påstand om at denne feilbanen er utløst i produksjon.

### P1: Tablet kan tildeles flere stasjoner i administrasjonen

**Kodebevis:** `src/app/(beskyttet)/brukere/handlinger.ts:13` lar samme skjema opprette både butikksjef og tablet. Linje 48 krever minst én stasjon, men setter ingen maksgrense for tablet. `endreStasjoner` godtar også flere stasjoner uten tablet-spesifikk validering. Det strider mot det skrevne produktprinsippet «nettbrettet er stasjonsbundet». Dette beviser en mulig feilkonfigurasjon, ikke en lekkasje på tvers av retailer.

**Endring:** Tablet krever nøyaktig én stasjon på serveren og i skjema. Kontroller eksisterende tildelinger før innstramming. Databasekontrakt og atferdstester må følge samme regel dersom prinsippet skal være en databasegrense.

### P1/P2: Bilvask-krav gjelder alle i onboarding, selv om relevansregelen finnes

**Kodebevis:** `src/lib/onboarding.ts:249` inkluderer bilvask i `KILDER`. `gjelderBilvask` finnes på linje 336 og kommentar sier stasjoner uten vask ikke skal ha steget. Et søk i hele `src` viser ingen produktkall til funksjonen. `src/app/(beskyttet)/import/page.tsx:196` sender alle målinger og totalt antall stasjoner direkte til `onboardingsteg`, som krever dekning for alle. En kjede med både stasjoner med og uten vask kan derfor aldri få et korrekt «på plass» på dette steget uten data som ikke finnes.

**Endring:** Utled aktuelle stasjoner fra BP, og bruk dette settet som nevner for akkurat bilvask. Skill «ikke relevant» fra «mangler» og «relevans ukjent før BP». Direkte blandet-fixture-test må inkludere én stasjon med vask og én uten. Prioritet P1 hvis steget brukes til økonomisk konklusjon; P2 for ren etableringsveiledning.

### P2: Søk finner ikke funksjoner som er flyttet til faner

**Kodebevis:** `src/app/(beskyttet)/appskall.tsx` bygger `menypunkter` bare fra `seksjoner.flatMap`. `toppstripe.tsx` sender disse til `Kommandopalett`; `kommandopalett.tsx:70` søker kun navn og gruppe i denne listen. Faner som Timesalg, Salgsprognose, Arbeidsavtaler, Merker, Konkurranser og Premiesaldo er derfor ikke selvstendige søkeresultater. De er fortsatt tilgjengelige via faner, men søket kan ikke hjelpe den som kjenner funksjonsnavnet.

**Endring:** Bruk rollefiltrert union av meny og faner i søket, med deduplisering på sti og relevante synonymer. Bevar samme rolletilgang. Dette er en liten, konkret forbedring som kan prøves før full menyombygging.

### P2: Aktiv gruppe i sidemenyen følger ikke faner på andre stier

**Kodebevis:** `src/app/(beskyttet)/sidemeny.tsx:32` matcher aktiv sti bare mot seksjonens menypunkter med strengprefiks. `/timesalg` matcher ikke `/salg`, `/kontrakt` matcher ikke `/ansatte`, og `/merker` matcher ikke `/skills`. Etter navigasjon via fane kan den logiske seksjonen dermed være lukket og ingen sidemenylenke være aktiv. `navigasjon.ts` har allerede `gruppeFor`, men denne brukes ikke av sidemenyen; `fanerad.tsx` har dessuten en egen kopi av gruppealgoritmen.

**Endring:** Utled seksjon/forelder fra samme navigasjonsmodell. Gi aktiv forelder tydelig visning selv om valgt side er en fane. Fjern den dupliserte gruppealgoritmen når funksjonaliteten er bevart med direkte tester.

### P2: Plattformoversikt har harde skaleringsgrenser uten kompletthetskontroll

**Kodebevis:** `src/app/(beskyttet)/plattform/page.tsx:40` henter alle importjobber uten sortering, aggregat eller eksplisitt kompletthetskontroll og regner siste importdato i TypeScript. `listUsers({page:1, perPage:1000})` leser kun første auth-side. Stasjoner og profiler summeres fra uavgrensede datalister. Ved vekst utover standardtaket kan importdato, kontaktadresse, antall eller prisgrunnlag bli feil. Støttelisten har eksplisitt limit 200, men ingen kontroll for treff på taket; presentasjonen «ingen åpen støtte» kan da være ufullstendig selv om selve støtteporten fortsatt håndheves.

**Endring:** SQL-aggregater per retailer for antall/siste import; paginer auth-kontakter eller hent bare kontaktpersonene som faktisk vises. Kontrollér hver kompletthetsforutsetning. Plattformpris er vist som beregnet abonnement, og bør ikke brukes til fakturering før grunnlaget er bekreftet komplett.

### P2: Plattformhandlinger har fortsatt stille feilbaner

**Kodebevis:** `src/app/(beskyttet)/trafikk/handlinger.ts:19` og 38 returnerer uten kvittering ved manglende serviceklient. Manglende koordinater/ingen teller gir heller ingen forklaring til brukeren. `src/app/(beskyttet)/kampanjer/handlinger.ts:25` har samme stille return ved opprettelse, mens sletting allerede gir eksplisitt feil. Kampanjedatoer valideres med regex, men uten kontroll av reell kalenderdato eller at fra er før til. `src/lib/vaer.ts` hopper over API-/upsert-feil og returnerer `ok:true` selv om null rader ble lagret; stasjonsknappen kan dermed si «vær hentet» ved total feil.

**Endring:** Samme kvitteringsmønster for opprettelse, trafikk og vær som eksisterende slett/brukerhandlinger. Værresultat må skille full suksess, delvis suksess og total feil. Kampanje krever gyldig datointervall.

### P2: Onboarding måler historikk, men ikke ferskhet eller hele etableringen

**Kodebevis:** `src/lib/onboarding.ts:401` kan gi `status:'ok'` basert på stasjonsdekning og historikklengde. `sisteDato` bæres som data, men brukes aldri til status. En gammel komplett serie kan dermed stå «på plass» lenge etter siste import. `OPPSETT` på linje 417 dekker bare butikksjef; avsender-allowlist er korrekt fail-closed og viser lokal advarsel på Import, men inngår ikke i «neste steg». Tablet-konto, PIN, koordinater og modulrelevant integrasjonsoppsett er heller ikke i denne oppsettsmodellen.

**Endring:** Skill etableringsdekning fra løpende ferskhet. Utled modulkrav fra samme konfigurasjon som funksjonene leser; ikke utvid en separat håndholdt sjekkliste i blinde. E-postinntak er valgfritt: det skal bare gi etableringsoppgave dersom kjeden velger denne kanalen. «Alt på plass — systemet har det det trenger» bør avgrenses til det som faktisk er kontrollert.

### P3: Opprettelse av brukere har svakere validering enn senere endring

**Kodebevis:** Opprettelse filtrerer innsendte stasjoner til egne stasjoner og godtar resultatet så lenge minst én gjenstår (`brukere/handlinger.ts:65`). Endring av tildelinger avviser hvis ikke alle stasjoner er gyldige (linje 140). Opprettelse kan derfor lykkes med færre stasjoner enn valgt; ingen fremmed tenant får tilgang. Feil i kobling etter konto/profil-opprettelse blir rapportert som delvis suksess, men konto blir stående uten ønsket tildeling.

**Endring:** Samme validering før opprettelse, dedupliser input, og gi konkret reparerbar visning for delvis opprettet bruker. Vurder transaksjon for profil/tildeling med kompensering for auth-opprettelse.

## Overlapp: hva bør samles, og hva bør bevares?

Kildekoden viser allerede utført samling: Butikken min er tre faner, salg er dag/time/prognose, og anerkjennelse er score/merker/konkurranse/premie. Men kommentar i `navigasjon.ts` om at hele månedsplanen tegnes likt to steder er nå foreldet: `min-maaned/page.tsx:459` sier og viser kort oppsummering, mens full `Planlesing` bor på `min-plan`. Ikke slett denne ruten på grunnlag av den gamle kommentaren.

Administrasjon av Brukere og Ansatte er ulike domener: konto/stasjonsrettigheter versus arbeidsforhold/PIN. Bevar begge, men forklar skillet i én samlet administrasjonsinngang. På samme måte er Publisering (nyheter til kjeder), Anvisninger (stasjonens oppslagsverk) og Kunnskapsbase (grunnlag for AI) ulike kanaler. Problemet er å gjøre målgruppe og publiseringsmål tydelig; en automatisk databasesammenslåing er ikke begrunnet.

Regnskap, Regnskapsanalyse, Regnskapsrommet, Lønnskost, Timeregnskap, Businessplan og Månedsplaner ligger alle under Innsikt. Det er mange navn for forskjellige beslutninger. Foreslå et felles økonomiområde med arbeidsoppgaver først: «Månedsresultat», «Lønn og timer», «Budsjett», «Kostnadsavtaler» og «Tiltak». Modulene beholdes som undersider inntil data- og handlingskontrakter er kartlagt. Dette er en designhypotese; klikkmåling og brukeroppgaver må bekrefte rekkefølgen.

Team blander kommunikasjon (Fokus, meldinger, tilbakemeldinger), kompetanse/motivasjon og administrasjon. Innstillinger inneholder samtidig Nyheter og Anvisninger, som er innhold snarere enn innstillinger. En prøve bør skille «Team», «Kommunikasjon» og «Administrasjon» og la kjedeeier og butikksjef få ulike startoppgaver. Unngå flere nye hovedgrupper før søk/aktiv-gruppe-problemene er rettet.

Plattformens fem menyvalg kan bevares, men kunden bør være en gjennomgående kontekst for invitasjon, etablering, trafikk, kampanjer og støtte. Foreslå en kundedetaljside med siste import, etableringsblokker, tildelinger og støttehistorikk; ikke vis navngitte ansattes driftsdata uten et begrunnet produktbehov og korrekt støtte-/tenantgrense.

## Tilgang og begrensninger

Undersøkte plattformruter kontrollerer `plattform_redaktor` før admin-klient. Brukeropprettelse og passordbytte er eksplisitt bundet til egen retailer. Støtte kreves for deaktivering, reaktivering og permanent sletting. Disse grensene skal bevares ved omorganisering.

`src/lib/auth/dal.ts:56` dokumenterer bevisst fail-open for godkjenningslesing; tenantisolasjon er fortsatt RLS. Dette er et produktvalg, ikke automatisk en ny sikkerhetsfeil. Konsekvensen bør testes direkte: en lesefeil kan slippe en ennå ikke godkjent kjede gjennom forretningsporten. Plattformens Trafikk og Kampanjer skriver med admin-klient etter rollegate, uten den støtteporten livssyklushandlingene bruker; behovet for støtteport må klassifiseres per handling fremfor å antas.

Ingen ny databasepolicy eller databaseendring foreslås kjørt som del av analysen. Live RLS, komplett multi-role-kanarimatrise, reell SMTP/invitasjon og fakturagrunnlag er ikke verifisert av denne delanalysen. Systemgjennomgang skal kombinere rapporten med de øvrige agentenes arbeid og faktiske nettleserprøver.

## Anbefalt rekkefølge og bevis

1. Rett falskt grønn datadekning og klassifiser tabletens én-stasjonsregel.
2. Rett bilvask-relevans med blandede stasjoner som testfixture.
3. Gjør alle rolleautoriserte faner søkbare og vis logisk aktiv menygruppe.
4. Fjern stille admin-feil og ufullstendige plattformberegninger.
5. Prøv ny økonomi-/kommunikasjonsnavigasjon med konkrete oppgaver hos kjedeeier og butikksjef. Mål tid til riktig side, feilklikk og om brukeren kan forklare hva tallet betyr.
6. Utled modulbasert etablering/ferskhet og oppdater onboarding fra de faktiske kravene.

Onboardingpåvirkning: NEI for denne rapporten; ingen funksjoner er endret. Foreslåtte implementasjoner av bilvask-relevans, tablet-tildeling eller modulkrav må svare separat på onboardingpåvirkning og oppdatere veiledningen der etableringskrav endres.
