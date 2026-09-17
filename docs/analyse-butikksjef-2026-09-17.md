# Butikksjef: arbeidsflyt, overlapp og kodefunn

Dato: 2026-09-17. Read-only kildeanalyse på arbeidsgrenen. Ingen produktkode er endret av denne gjennomgangen. Dette er ikke en påstand om at alle skjermbilder eller produksjonsdata er testet. Konkrete kodefunn står separat fra forslag som trenger brukertesting.

## Hovedvurdering

Systemet har allerede redusert en del menydobling gjennom fanegrupper. Det viktigste neste steget er å gjøre arbeidsflytene og stasjonskonteksten sammenhengende, heller enn å slå sammen alle sider med lignende tall. Det finnes konkrete inkonsistenser mellom meny, valgt stasjon og tall på butikksjefens forside. Flere listeflater kan vise «tomt» når en databaseforespørsel feiler. Disse bør prioriteres før kosmetisk omorganisering.

## Funksjonskart for butikksjef

Kartet bygger på `src/app/(beskyttet)/navigasjon.ts`, rollegater og sidekilde. Underliggende detaljsider er egne ruter selv om de ikke bør være egne menylinjer.

| Arbeidsområde | Ruter | Hva butikksjefen gjør |
|---|---|---|
| Butikken min | `/oversikt`, `/min-maaned`, `/min-plan` | Prioriterer dagens signaler, følger måneden, leser eierens sluppede plan |
| Produksjon og vareflyt | `/produksjonsplan`, `/produksjonsplan/treffsikkerhet`, `/utsolgt`, `/svinn` | Planlegger mengder, kontrollerer modellens treff, undersøker mulig utsolgt og kast |
| Bemanning | `/bemanning` | Fordeler timerammen, setter bemannede vinduer, faste vakter, minimumskrav og fravær |
| Rutiner | `/rutiner/min`, `/rutiner/oversikt`, `/rutiner/oppsett`, `/rutiner/oppsett/[id]` | Gjør egen sjekkliste, følger gjennomføring, setter opp rutiner |
| Dagens oppfølging | `/oppgaver`, `/sjekkpunkt`, `/ikmat`, `/ikmat/oppsett`, `/avvik` | Oppretter oppgaver, følger sjekkpunkter og mattrygghet, lukker avvik |
| Salg | `/salg`, `/timesalg`, `/salgsprognose` | Ser faktiske salg og kundeform og sammenligner med forventninger |
| Folk | `/ansatte`, `/kontrakt`, `/kontrakt/[id]`, `/lonn`, `/opplaring` | Vedlikeholder ansatte og avtaler, følger lønnsgrunnlag og opplæring |
| Kommunikasjon | `/fokus`, `/tilbakemeldinger`, `/meldinger`, `/puls`, `/puls/sporsmal`, `/puls/[id]` | Formidler fokus og tablet-meldinger, følger tilbakemeldinger og pulssvar |
| Anerkjennelse | `/skills`, `/merker`, `/konkurranser`, `/premier` | Følger kompetanse, merker, konkurranser og premiesaldo |
| Økonomi | `/businessplan`, `/regnskap`, `/lonnskost`, `/lonnskost/arbeidssted` | Leser budsjett, fasit og utvikling i lønnsrom og kostnader |
| Oppfølging og transparens | `/maaling`, `/kasserer`, `/lederstotte`, `/mine-opplysninger`, `/persondata` | Følger målinger, får lederstøtte og forstår persondata og måling |
| Hjelp og informasjon | `/nyheter`, `/anvisninger`, `/varsler` | Leser informasjon og varsler |
| Ukentlig oppsummering | `/ukebrief` | Leser samme brev som ukentlig utsending og henter PDF |

`/ukebrief` er ikke registrert som meny/fane i navigasjonsfilen. Den er en reell rute med lederport, ikke dermed nødvendigvis en ferdig synlig navigasjonsdestinasjon. Alle manager-ruter er ikke nødvendigvis primærmeny: enkelte nås gjennom lenker og detaljvisninger. Endelig redesign bør bruke en maskinlesbar oversikt over disse inngangene, ikke bare denne håndskrevne tabellen.

## Konkrete kodefunn

### P1: Valgt stasjon avgrenser ikke alle tall på forsiden

Bevis: `src/app/(beskyttet)/butikksjef-dashbord.tsx:110` definerer `paaStasjon`, men følgende lesninger i samme blokk bruker den ikke:

- `pengepremie` og `pengepremie_bruk`, linje 126–127, som summeres til `premieIgjen` ved linje 205.
- `v_salg_per_stasjon_dag`, linje 128, som blir ferskhetsmerket ved linje 381.
- `fokuspunkter`, linje 134 og 167, som velger nyeste periode over hele lesetilgangen og deretter de første seks punktene.
- `import_jobber`, linje 159, som blir grunnlag for importsignaler.

For en butikksjef med flere tildelte stasjoner kan overskriften vise én valgt stasjon mens deler av bildet dekker flere. Dette er også relevant for admin som går inn på én stasjon. RLS hindrer tilgang utenfor tillatt omfang; den løser ikke feil kontekst innenfor dette omfanget. En fersk salgsdag på stasjon B kan få valgt stasjon A til å se oppdatert ut.

Forslag: klassifiser hvert kort eksplisitt som stasjon eller samlet ansvarsområde. Stasjonskort skal filtrere og vise den samme stasjonen som overskriften. Samlede kort skal navngis som samlede. Legg direkte test med to stasjoner og ulik ferskhet, fokus og premiegrunnlag. Ingen påvist datalekkasje i dette funnet.

### P1: Rutinebrøken på forsiden måler ulike mengder

Bevis: `butikksjef-dashbord.tsx:130` teller alle ikke-slettede rutiner. Linje 131 teller utføringer med `dato = idag`. Disse settes til `rutTot` og `rutGjort` ved linje 207–208 og vises sammen som brøk ved linje 443. Nevneren filtrerer ikke frekvens, ukedag eller aktiv vakt. Dermed er ukentlige/månedlige rutiner med også når de ikke skal utføres i dag, og nattvaktens vaktdato kan skille seg fra kalenderdato.

Forslag: bruk felles forventningsmotor for perioden kortet faktisk beskriver, og tell bare godkjente utføringer av disse forventningene. Nettbrettets nye skiftkø er relevant som regelgjenbruk, men en lederoversikt over hele dagen skal ikke ukritisk overta «vakten nå». Test daglig, ukentlig, månedlig og nattvakt direkte. Retning: gjennomføringen kan se dårligere ut enn den faktisk er.

### P1: Databasefeil kan se ut som ingen oppgaver eller ingen bemanning

Bevis: `/oppgaver/page.tsx:33` destrukturerer bare `data`; linje 45–46 bruker `oppgaver ?? []`. Den samme formen finnes i `/meldinger/page.tsx:24`, `/fokus/page.tsx:30` og `/sjekkpunkt/page.tsx:28`. En PostgREST-feil returnerer normalt et resultat med `error`, ikke en kastet exception. `try/catch` rundt en større blokk erstatter derfor ikke en eksplisitt feilkontroll.

I `/bemanning/page.tsx:102`, `:117` og `:135` ignorerer `hentUkeprofil`, `hentFaktisk` og `hentAnsattmaaneder` feil og returnerer tomme grunnlag. Risikoen er mer alvorlig der tomhet inngår i vurdering av kapasitet eller plan mot faktisk arbeid. Feilen er påvist i kodeveien; produksjonsforekomst er ikke målt.

Forslag: skill feil, legitimt tomt og avkortet svar. Ikke la feilgrunnlag gi grønn vurdering. Test et Supabase-resultat med `data: null, error: ...` på de smale hjelpefunksjonene før bred UI-testing.

### P2: Sidemenyen mister aktiv gruppe på flere faner

Bevis: `sidemeny.tsx:32` beregner aktiv seksjon bare gjennom prefiks mot primærmenypunktet. `/timesalg` og `/salgsprognose` er Salg-faner, men er ikke under `/salg/`. `/min-maaned` og `/min-plan` er Butikken min-faner, men er ikke under `/oversikt/`. Det samme gjelder Anerkjennelse-faner som `/premier` og `/konkurranser`, som ikke begynner med `/skills/`. Menyen kan derfor være lukket og uten tilhørighet selv om fanen er korrekt.

Forslag: bestem menytilhørighet med den eksisterende `gruppeFor`/fanegruppedata, og bruk separat menymarkering for aktiv destinasjon og aktiv gruppe. Test alle fane-URL-er mot seksjonen de skal åpne. Dette er et konkret navigasjonsproblem, ikke grunn til å fjerne faner.

### P2: Månedssiden har levetidstak som kommentaren beskriver som periodevindu

Bevis: `/min-maaned/page.tsx:83` setter `TAK_PLANER = 60` med begrunnelsen tretten måneder. Planspørringen ved linje 268–274 filtrerer stasjon og publisert status, men ingen nedre månedsgrense. Etter 60 publiserte månedsplaner vil fullstendighetskontrollen avvise listen. `/min-plan` har et større historikktak på 240. Dette er en fremtidig skaleringsfeil, ikke en påvist feil ved dagens antall planer.

Forslag: hent valgt måneds plan direkte og eventuelt nyeste plan separat, eller legg et bevisst datovindu på spørringen. Kontroller forventet produktbehov for historikk før vinduet snevres.

## Overlapp som bør sorteres etter arbeidsoppgave

Dette er informasjonsarkitektur-forslag og trenger korte brukertester:

1. **Produksjon, mulig utsolgt, svinn og Traff vi?** er én læringssløyfe: bestem mengde → gjør → observer mangler/kast → juster. Behold egne fagmotorer, men gi felles inngang «Produksjon og varer» og kontekstuelle lenker til samme stasjon/periode/vare. Å bare samle dem i faner kan skjule skillet mellom observasjon og modell.
2. **Oppgaver, rutiner, sjekkpunkter og IK-mat** trenger én oversikt over arbeid som venter. Behold ulike typer fordi repetisjon, kritisk kontroll og avvik har forskjellige regler og dokumentasjonskrav. En enhetlig kø kan vise type, frist, ansvarlig og kilde uten å slå sammen tabellene.
3. **Fokus, månedsplan, tablet-meldinger og opplæring** bruker flere kanaler for «hva skal vi gjøre». Månedsplanen er eierens godkjente styring; fokus er generert vurdering; meldinger er kommunikasjon; opplæring er ferdigheter. Definer hvem som eier neste handling og vis kobling til oppgave fremfor fire konkurrerende tiltakslister.
4. **Måneden, regnskap, lønnskost og businessplan** bør ha Måneden som standard historie og fagflatene som grunnlag. Nåværende månedsside bruker felles `okonomi/sammenstill.ts`, noe som er verdifullt. Ikke lag ny separat beregning ved menyendring.
5. **Skills, merker, konkurranser og premier** har allerede fanegruppen Anerkjennelse. Neste forbedring er begrepsforklaring og koblingen mellom utført arbeid, vurdering og belønning, ikke flere nye menypunkter.

Navigasjonsfilens store kommentar om at `/min-plan` og månedssiden tegner samme `Planlesing` er utdatert: dagens månedsside oppsummerer planen og kommentaren rundt linje 459 sier eksplisitt at hele `Planlesing` bare ligger på `/min-plan`. Beslutninger om sletting må bygge på dagens render, ikke gamle arkitekturkommentarer.

## Foreslått manager-meny for utprøving

| Primærinngang | Innhold |
|---|---|
| Butikken min | I dag, Uken, Måneden, eierens plan |
| Drift | Produksjon og varer, bemanning, arbeid og kontroll |
| Team | Ansatte/avtaler, opplæring, kommunikasjon, anerkjennelse |
| Tall og grunnlag | Salg, økonomi, lønn, målinger |
| Hjelp og innstillinger | Anvisninger, nyheter, persondata |

Dette er en prototype til vurdering, ikke godkjent implementasjon. Start med tre konkrete spørsmål i brukertesting: «Hvor ser du hva som haster i dag?», «Hvor endrer du mengden i morgen?», «Hvor ser du om månedens lønnsbruk er innenfor?» Mål tid, feilvalg og behov for hjelp. Test både nye og erfarne brukere; alder alene forklarer ikke navigasjonskompetanse.

## Ytelse og prioritering

Forsiden har en stor første `Promise.all`, men venter deretter på fokus og ukeoppsummering, før utsolgt- og treffsignaler og filtrering av lukkede signaler. `hentEllerLagUkerapport` kan beregne og generere et sammendrag når cache mangler. Kilde: `butikksjef-dashbord.tsx:167`, `:187`, `:334`, `:360` og `src/lib/ukerapport.ts`. Dette er en kandidat til treg førstegangsvisning, ikke en målt manager-forbedring. Mål kald/varm cache og gjentatte databasefeil før eventuell oppdeling i rendergrenser eller bakgrunnsberegning.

Prioritert rekkefølge: 1) rett tallenes stasjonsomfang og rutinegrunnlag, 2) skill feil fra tomhet, 3) rett aktiv menygruppe, 4) mål manager-sider med representative data, 5) prøv ny meny og felles arbeidskø med faktiske brukere. Et stort redesign før disse funnene er avklart kan gjøre de samme feilene vanskeligere å oppdage.

Onboardingpåvirkning: NEI for denne dokumentasjonsanalysen. Forslag om meny, feilvisning og korrekte stasjonsfiltre krever ingen nye retailer-data. Eventuell implementasjon som endrer oppsett for bemanning eller moduler må vurderes på nytt.
