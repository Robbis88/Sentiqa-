# Navigasjon, overlapp og arbeidsflyt — 2026-09-17

## Konklusjon og avgrensning

Sentiqa har allerede gjort et viktig grep: flere ruter er samlet i faner, og nettbrettet har et eget skall. Problemet er derfor ikke bare antall menylinjer. Navigasjon, søk og aktiv markering bruker forskjellige utsnitt av samme rutemodell. I tillegg ligger økonomiske råd, kommunikasjon og oppfølging spredt på flater med navn som ikke forteller hvilken arbeidsoppgave de løser.

Denne rapporten er en kildekodeanalyse. Den endrer ingen produktkode eller tilgang. Funn om kode og DOM er etterprøvbare; påstander om hvor lett ansatte finner fram må bekreftes i nettleser og brukertest. Ingen produksjonskonto eller private data er åpnet i denne gjennomgangen.

Undersøkt: `navigasjon.ts`, `sidemeny.tsx`, `appskall.tsx`, `toppstripe.tsx`, `kommandopalett.tsx`, `fanerad.tsx`, `tablet-nav.tsx`, UI-faner og globale mobilstiler, rollevakten, samt sider for måned, plan, oppgaver, sjekkpunkt, fokus, meldinger, tilbakemeldinger og lederstøtte.

## Dagens modell

| Rolle | Hovedstruktur | Vurdering |
| --- | --- | --- |
| Retailer-admin/eier | Hjem, Drift, Salg, Team, Innsikt, Innstillinger | Kjedeutvikling og daglig butikkdrift blandes. Innsikt rommer både rå regnskap, analyse, lønn, budsjett, datakvalitet og godkjenning av tiltak. |
| Butikksjef | Butikken min, Drift, Salg, Team, Innsikt, Innstillinger | Oppstarten er god: I dag, Måneden og Planen. Resten krever kjennskap til systemets modulnavn. |
| Nettbrett | I dag, Rutiner, Hjelp; øvrige funksjoner via kø og kontekstuelle lenker | God prioritering av handling. Produksjon og IK-mat er fortsatt viktige direkte innganger under Rutiner. Tre faner bør ikke automatisk bli ti. |
| Plattform-redaktør | Plattform, Trafikk, Kampanjer, Publisering, Kunnskapsbase | Riktig eget fagområde. Skal ikke få butikkinnsikt selv om adminmenyen omorganiseres. |

Åtte fanegrupper finnes allerede: Butikken min, Rutiner, Produksjon, IK-mat, Salg, Puls, Anerkjennelse og Ansatte. `naabart()` teller meny, faner, tabletmeny og kontekstuelle tabletflater. Dette er et godt fundament for omorganisering uten tap av funksjon.

Kommentarer med historiske antall menypunkter spriker mellom filer. De bør ikke brukes som dagens måling. Nye antall må beregnes fra rollefiltrerte data.

## Beviste mangler i navigasjonen

### 1. Søk finner ikke alle flater som rollen kan nå — høy prioritet

`appskall.tsx:42` bygger søkepunkter bare fra `seksjoner`. `kommandopalett.tsx:70` søker bare i disse punktenes tekst og gruppenavn. Fanegruppene kommer ikke med.

Konsekvens: en butikksjef som skriver «timesalg», «prognose», «arbeidsavtaler», «konkurranser» eller «premiesaldo» får ikke den aktuelle ruten som navigasjonstreff. Rutene finnes og rollen kan nå dem via faner. «Finn noe» er dermed mindre komplett enn menyens faktiske rekkevidde.

Forslag: generer søkeindeksen fra samme rollefiltrerte navigasjonsgraf som rekkeviddevakten. Dedupliser etter sti og legg inn begrepsaliaser, eksempelvis lønn → Lønnsgrunnlag/Lønnskost. Skill tydelig mellom sidenavigasjon og et AI-svar. AI må ikke bli nødvendig for å finne en eksisterende side.

### 2. Aktiv hovedgruppe forsvinner på sekundære faner — middels prioritet

`sidemeny.tsx:32` åpner en gruppe hvis dagens sti er lik eller barn av et faktisk menypunkt. Det fungerer på `/produksjonsplan/treffsikkerhet`, men ikke på `/timesalg`, `/salgsprognose` eller `/rutiner/oversikt`, fordi menyens innganger er `/salg` og `/rutiner/min`. På `/min-plan` og `/min-maaned` markeres heller ikke Butikken min.

Brukeren kan derfor ha riktig fane valgt mens hovedmenyen mangler valgt område og folder relevant gruppe sammen. Forslag: beregn valgt menypunkt fra fanegruppens forelder, ikke bare URL-prefiks. Behold `aria-current="page"` for den eksakte siden; bruk egen visuell områdemarkering på forelderen.

### 3. Lukket mobilmeny er fortsatt i fokusrekkefølgen — høy prioritet

`globals.css:558` skjuler menyen med `transform: translateX(-100%)`. `sidemeny.tsx` beholder lenker og knapper i DOM uten `inert`, skjult tilstand eller endret fokusrekkefølge. CSS-transform gjør ikke interaktive elementer ufokuserbare.

Når menyen er åpen finnes Escape-lukking, men ingen fokusoverføring til menyen, fokusavgrensning eller eksplisitt retur til hamburgerknappen. Knappen sier «Lukk meny» når åpen, men handleren gjør alltid `setApen(true)`. Fysisk tilgjengelighet til knappen bak overlayet må prøves i nettleser; handlerens manglende toggle er uansett direkte synlig.

Forslag: implementer skuffen med en tilgjengelig dialogmekanisme, og sørg for at lukket mobilmeny ikke kan tabbes til. Desktopmenyen må fortsatt være vanlig navigasjon. Verifiser Tab, Shift+Tab, Escape og fokusretur ved 375 og 900 px.

### 4. Kommandopaletten lover modalitet uten å håndheve den — høy prioritet

`kommandopalett.tsx:110` har `role="dialog"` og `aria-modal="true"`. Den flytter fokus til input, men ingen mekanisme holder Tab inne i dialogen eller gjør bakgrunnen inert. Treffene er klikkbare `<li>`-elementer uten knapper/lenker eller listbox-semantikk. Piltast og Enter fungerer i input, men aktivt treff annonseres ikke med `aria-activedescendant`/valgt tilstand.

Forslag: behold tekstfeltet og bruk en gjennomført combobox/listbox-modell, eller fokuserbare lenker og knapper i en tilgjengelig dialog. Test også at et sent AI-svar ikke gjenbrukes i en ny søkesesjon.

### 5. Tabletens valgte fane er kun visuell — middels prioritet

`tablet-nav.tsx` setter aktiv CSS-klasse, men mangler `aria-current` og navn på navigasjonslandemerket. UI-primitiven `Faner` har begge. Flere viktige undersider, som produksjon og IK-mat, har heller ikke tilhørighet til en valgt hovedfane; dette er en orienteringsbeslutning som bør testes med ansatte.

Forslag: gjenbruk semantikken fra UI-fanene. Vis en tydelig retur til arbeidskø/Rutiner på undersider. Ikke legg sensitive lederdata på nettbrettet for å gjøre navigasjonen lik desktop.

## Overlapp: hva bør samles, og hva bør bestå?

| Flater | Faktisk forskjell | Anbefaling |
| --- | --- | --- |
| Fokus, månedens råd og månedsplan | Fokus leser egne `fokuspunkter` fra regnskap. Månedsplan er egen, godkjent og sluppet tiltakskjede. | Samle inngangen under Oppfølging. Avklar hvilken rådskjede som er autoritativ før gammel funksjon avvikles. Ikke vis automatisk råd som godkjent plan. |
| Oppgaver, rutiner, sjekkpunkt, IK-mat | Engangsoppgave, gjentatt arbeid, datert ja/nei-kontroll og faglig kontroll med avvik/måling. | Samle oversikten over gjenstående arbeid, behold type, egne regler og bevis. En generell checkbox-tabell er ikke en sikker erstatning. |
| Lønnsgrunnlag, Lønnskost, Timeregnskap, Bemanning | Registrert lønnsgrunnlag, økonomisk kostnad, analyse av timer og planlegging. | Samle innganger rundt arbeidsoppgaven Bemanning og lønn; behold perioder og referanser eksplisitte. Eierens Timeregnskap forblir eierens. |
| Tablet-meldinger, tilbakemeldinger, nyheter, varsler | Utgående butikkmelding, ansattes innspill/hendelse, publisert innhold og systemvarsel. | Bruk Kommunikasjon som felles landingsside. Skille mellom sendt/mottatt/hendelser og skjermingsbehov. Krenkelser må ikke gjøres til vanlig melding. |
| Skills, merker, konkurranser, premier, opplæring | Vurdering, oppnådd anerkjennelse, sammenligning, premie og læring. | Behold Anerkjennelse som underområde av Team. Sett opplæring ved siden av, ikke som synonym. |
| Min måned og Min plan | Månedens økonomiske bilde mot den godkjente planen. | Dagens kode viser allerede bare kort oppsummering på Måneden og full plan på Planen. Historisk kommentar om to fulle Planlesing-kort er ikke bevis på dagens dobbeltvisning. Behold dette grepet. |
| AI-boble og kommandopalett | Samme assistentmotor, ulike innganger. Paletten sender spørsmål med tom historikk; boblen har samtale. | La paletten åpne assistenten med spørsmålet hvis brukeren trenger en fortsettbar samtale. Behold rask sidenavigasjon som egen evne. |

## Konkret menyskisse

Dette er en skisse til prototype, ikke et forslag om umiddelbart å endre alle ruter. En landingsside kan lenke til eksisterende ruter uten å lage fanegrupper med ti valg.

### Butikksjef

1. **Butikken min** — I dag, Måneden, Planen. Behold dagens tidsakse.
2. **Daglig drift** — Arbeidsliste (Oppgaver/Rutiner/Sjekkpunkt), Produksjon, IK-mat, Svinn. Mulig utsolgt nås også fra produksjon og salg.
3. **Salg og økonomi** — Salg (dag/time/prognose), Regnskap, Budsjett/Businessplan, Lønnskost. Måling og Kasserer som navngitte analyseverktøy på landingssiden.
4. **Team** — Ansatte/Arbeidsavtaler, Bemanning og lønn, Opplæring, Anerkjennelse, Puls. Maks fem hovedinnganger; detaljer på eksisterende sider.
5. **Oppfølging** — Godkjent plan, Fokus med tydelig rådstatus, Lederstøtte, Kommunikasjon.
6. **Innstillinger** — Persondata, Anvisninger, tilgang til egen informasjon. Sikkerhet og brukerfunksjoner i toppstripen.

### Retailer-admin

1. **Kjeden** — Portefølje/I dag, Sammenligning, Planer til godkjenning.
2. **Drift** — Produksjon, Arbeidsoppfølging, IK-mat, Svinn, Arrangementer.
3. **Økonomi** — Regnskap/Regnskapsrommet/Analyse, Budsjett og BP-sammenligning, Salg, Lønn og timer, Datakvalitet/Datadekning.
4. **Team** — Ansatte/Arbeidsavtaler, Bemanning, Anerkjennelse, Puls, Lederstøtte.
5. **Kommunikasjon** — Mottatte tilbakemeldinger, Tablet-meldinger, Nyheter/innhold.
6. **Oppsett** — Stasjoner, Brukere, Import og integrasjoner, Persondata, Anvisninger.

Ruter som Måling og Kasserer må beskrives med brukeroppgaven på riktig landingsside før de flyttes. Alle eier-only ruter over forblir eier-only. Butikksjefens flere eksplisitte stasjonstildelinger består. Plattformredaktørens meny endres ikke av denne skissen.

### Nettbrett

Behold I dag/Rutiner/Hjelp. Forbedre orientering og direkte, stabile innganger til Produksjon, IK-mat og stempling. Vis hva som gjenstår og kvitter for lagring. PIN som identifiserer hvem som holder nettbrettet må fortsatt skilles fra inn-/utstempling som skriver lønnsgrunnlag. Vår stasjon er sekundær innsikt, ikke et krav for å fullføre vakten.

## Validering før omorganisering

- Generer før/etter-liste over nåbare ruter per rolle og la rolle-/rutevaktene bevise uendret tilgang. Databasens tenant-kontrakt er autorisasjonen; menyen er ikke en sikkerhetsgrense.
- Test søk etter dagens skjulte fanenavn og synonymer uten AI-kall.
- Test valgt hovedområde på alle fanegrupper og dyplenker.
- Test mobilmeny og søkedialog med tastatur og skjermleser, ikke bare axe på primitive komponenter.
- La ansatte og ledere utføre konkrete oppgaver: finn vaktens kontroll, før temperatur, korriger oppgave, finn lønnsgrunnlag, finn månedens godkjente tiltak. Mål tid, feilvalg og behov for hjelp. Ta med ulik erfaring og syn/motorikk; alder alene beskriver ikke behovet.
- Innfør små endringer i rekkefølge: søk og fokusfeil først, deretter begreper, så prototype av hovedmeny. Avvikling av råd/moduler krever kartlegging av faktiske brukere og historikk.

Onboardingpåvirkning: NEI for denne analysen; ingen funksjon, konfigurasjon eller datamodell er endret. En senere avvikling av Fokus eller en endret import-/rådsløyfe må vurderes særskilt, siden manuelle oppstartskontrollpunkter da kan fjernes eller endres.
