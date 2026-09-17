# Tablet og ansatte fra innlogging til avsluttet vakt — 2026-09-17

## Omfang og status

Read-only analyse av lokal kode for tablet-skall, vakt/PIN, oversettelse, opplæring, rutiner, sjekkpunkt, IK-mat-måling, produksjon, stempling, varsler, polling og service worker. Ingen produksjonsdata er åpnet og ingen produktkode er endret av analysen.

Den lokale grenen inneholder tabletforbedringer som ennå ikke er produksjonsbevis. Den målte reduksjonen i datakall og responstid er dokumentert separat i `tablet-arkitektur-2026-09-17.md`; her brukes ikke disse tallene som bevis for faktisk fart på butikkens nettbrett. Verifisering må skille lokal kode, godkjent PR, deployet commit og måling på fysisk enhet.

## Flyten som allerede fungerer godt

1. Tablet-kontoen åpner et eget stasjonsbundet skall. Dette er ikke adminmenyen krympet til en liten skjerm.
2. Ansattnummer identifiserer personen, PIN bekrefter identiteten. Databasefunksjonen begrenser forsøk og svarer likt for ukjent nummer og feil PIN. Infrastrukturfeil meldes separat.
3. I dag viser arbeidskø, stemplingsinngang og planlagt opplæring. Rutiner og Hjelp er stabile hovedinnganger.
4. Rutiner og sjekkpunkt viser lagringstilstand og har umiddelbar ref-lås mot dobbeltinnsending. Sjekkpunkt stilles som ja/nei-spørsmål, ikke som en generell ferdig-hake.
5. IK-mat-måling viser én enhet og ett krav om gangen. Serveren beregner avvik og krever strakstiltak; klientens vurdering er bare veiledning.
6. Opplæringshaken settes etter bekreftet svar. Angring er en lederhandling og forklares på skjermen.
7. Stempling krever eget nummer/PIN og gir kvittering med person, retning og klokkeslett. Vakt-PIN er ikke innstempling. Skjemaet tømmes etter suksess før neste person bruker det.

Disse kvalitetene bør bevares under menydesign og ytelsesarbeid.

## Prioriterte funn

| Prioritet | Funn | Bevis og konsekvens | Forslag og nødvendig test |
| --- | --- | --- | --- |
| Høy | Produksjonsantall kan lagres i feil rekkefølge | `produksjonsplan/tablet-plan.tsx` kaller absolutte `loggLagd(..., v)` for hvert trykk/tegn. Transitionens pending-verdi brukes ikke til å låse eller serialisere. Serveren skriver absolutt antall. To samtidige endringer kan fullføres i omvendt rekkefølge; rollback fra et eldre mislykket kall kan også overskrive en nyere verdi. | Én kø per produkt, slå sammen ikke-sendte endringer eller bruk en versjonert serverkontrakt. Test 1→2 med forsinket første kall, og eldre feil etter nyere suksess. Ikke anta at transporten alltid serialiserer klientkall. |
| Høy | Polling oppdaterer ikke nødvendigvis lokal ferdigtilstand | `TabletPlan`, `TabletMaaling`, `TabletSjekk` og `TabletOpplaering` initialiserer state fra props én gang, uten senere samstilling. RSC-refresh bevarer klientstate for samme komponent. Nye serverprops kan derfor inneholde en annen persons endring uten at telleren/arbeidslisten oppdateres. | Definer autoritativ serverversjon og samstill med pågående lokale writes. Test lederrettelse og annet nettbrett mens siden står åpen, samt døgnskifte. Ukritisk useEffect som overskriver lokale endringer er ikke tilstrekkelig. |
| Høy | Ingen faktisk offline-arbeidsflyt | `public/sw.js` har tom fetch-handler, ingen cache, kø eller synkronisering av registreringer. `navigator.onLine` hindrer lokale pollingkall når offline, men garanterer ikke fungerende API når online. | Vis forbindelses-/ferskhetsstatus og si klart når en registrering ikke er lagret. Avklar produktkrav før eventuell offlinekø for lønn og mattrygghet. Test nettverksbrudd før, under og etter commit. |
| Høy, sikkerhetskandidat | Vaktens 12 timers levetid håndheves ikke i signert payload | `src/lib/ansatt.ts` signerer bare ansatt-id. `maxAge=12t` regulerer nettleserens cookie, men serveren kontrollerer ingen utstedelses-/utløpstid ved replay av en tidligere signert verdi. Oppslag kontrollerer aktiv ansatt og kjede, ikke tokenalder. | Inkluder servervalidert utløp og relevant sesjons-/stasjonsbinding i signaturen. Bekreft med direkte test av gammel signert kapsel. Dette er et statisk kontraktsfunn, ikke et påvist produksjonsangrep. |
| Middels | Opplæring har ufullstendig samtidighetskontroll | Én `venter`-nøkkel brukes for alle oppgaver. Bare knappen med denne nøkkelen disables. Klikk B mens A lagres flytter nøkkelen til B; A kan nå trykkes igjen, og første finally kan rydde B sin ventetilstand. | Bruk pending-sett og ref-lås per oppgave eller én lås for hele lista. Test to ulike samtidige haker og dobbelttrykk på samme hake. Serverens idempotens må også kontrolleres. |
| Middels | Temperatur har svakere dobbelttrykksvern enn rutiner | `TabletMaaling.lagre()` bruker bare React-state for `venter`. Ingen synkron ref-lås før serverkall. Enter og knapp kan prinsipielt sende før state er rendret. | Gjenbruk ref-låsen fra RutineTrykk/TabletSjekk. Test Enter+klikk samme tick og på forsinket forbindelse. |
| Middels | Polling etter reconnect venter unødvendig | Lokal `AutoRefresh` lytter til visibilitychange og intervall, men ikke online-event. Ved reconnect mens siden er synlig kan ferske data vente opptil 30 sekunder. | Online-event som utløser én refresh; unngå overlap mellom intervall, synlighet og writes. Dette gjelder lokal forbedring, ikke bekreftet live oppførsel. |

Samtidighetsfunnene beskriver kode som tillater problemforløpet. Faktisk trafikkrekkefølge og databasekonsekvens må demonstreres med kontrollerte tester før man hevder observert feil i butikk.

## Språk og forståelse

Språkvelgeren viser språkets eget navn og valgt tilstand. Oversettelse faller tilbake til norsk ved mangler/feil. Dette er godt som teknisk fallback, men norsk er ikke nødvendigvis en forståelig sikkerhetsinstruks for den som valgte et annet språk.

Beviste hull:

- `vakt.tsx` bruker norske feltnavn, Vakt, Logg av og serverfeil uten `useT`.
- Stemplingsskjemaets pauseknapp, hjelpetekst og kvittering er delvis hardkodet norsk; andre felter bruker oversettelseskonteksten.
- Opplæringens kategorier og oppgavetitler gjengis rått. Varselsiden oversetter rammen, men sier eksplisitt at dynamiske varseltekster ikke oversettes.
- Rotdokumentet har fast `lang="nb"`; ingen overordnet språk/retning settes på tablet-skallet ved språkvalg. Arabisk bør vurderes med korrekt `lang` og `dir`, ikke bare oversatte ord.

Forslag: kvalitetsgodkjente, statiske ordbøker for sikkerhets- og lønnskritiske systemtekster. Dynamiske butikktekster trenger en eksplisitt publiserings-/oversettelsesmodell og tydelig originaltekst ved behov. Ikke la mattrygghetskrav oppstå som uverifisert AI-oversettelse ved første besøk.

`oversettMange()` gjør AI-kall for cachemiss under serverrendering og venter på cache-upsert. Kaldt valgt språk eller mange nye instruksjoner kan derfor bidra til lang ventetid. Mål norsk, varm oversettelse og kald oversettelse separat. Forvarming/publiseringsoversettelse bør vurderes før rendering blir avhengig av AI-responstid.

## Varsler og personvern på delt enhet

Varsler er stasjonsbasert. Tabletens «marker alle» er med rette fjernet slik at den ikke tømmer lederens innboks. Bjellas tilgjengelige navn på tablet inkluderer ikke antall uleste, selv om tallet vises visuelt; desktop gjør dette bedre.

Web-push vises med varseltekst på enhetsnivå. Gjennomgangen bekrefter ikke noen konkret lekkasje, men produktet må avklare hvilke typer som kan vises på låseskjerm og delt enhet. Følsomme ansattforhold må ikke bli generelt pushinnhold bare fordi stasjonen er riktig. Undersøk tillatelses- og avmeldingsflyten ved utskifting av enheten.

PIN-kapselen husker én aktiv ansatt for hele nettleseren i inntil klientens 12 timer. Test vaktbytte og glemte Logg av-handlinger. Tydelig «Du registrerer som …» på kritiske flater kan hindre utilsiktet attribusjon, uten å kreve PIN for hvert rutinetrykk. Utlogging av tablet-konto og ansattens Logg av bør forklares som ulike handlinger.

## Praktisk akseptanse på selve nettbrettet

Test med representativt butikkoppsett, aktive rutiner, nattvakt, opplæringsskift, publisert produksjonsplan og avviksgrenser. Et tomt seedsett beviser ikke arbeidet gjennom en travel vakt.

Mål oppstart, navigasjon, umiddelbar trykkrespons, bekreftet lagring og neste oppgave separat. Registrer fysisk enhet, nettleser, nettverk, valgt språk og deployet commit. Bruk også CPU-belastning og begrenset nettverk i nettleser; 150 ms simulert databasesvartid måler ikke touch, hydration eller rendering.

Akseptansekriterier bør inkludere dobbelttrykk, tap av forbindelse, to samtidige brukere, vaktbytte, døgnskifte, norsk og minst ett annet språk, og korrekt kvittering uten falsk ferdigtilstand. Test med ulik erfaring, syn og motorikk fremfor å anta at 20- og 50-åringer er to ensartede brukergrupper.

Onboardingpåvirkning: NEI for denne analysen. Senere endringer i godkjente oversettelser, offlinefunksjon eller vakt-tokenkontrakt må vurderes eksplisitt; nye krav til ansattnummer/PIN, signaturnøkkel eller import må ikke bare dukke opp i en feiltilstand.
