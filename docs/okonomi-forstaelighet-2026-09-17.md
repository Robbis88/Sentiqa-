# Økonomi og businessplan for en leder med lite økonomierfaring

## Vurdering

Kildegjennomgang av Businessplan, BP-sammenligning, butikksjefens Regnskap og Måneden. Dagens visning har flere gode grep, men er ikke gjennomgående selvforklarende for en ny leder. Dette er vurdering av faktisk rendret tekst og visningslogikk i kildekoden, ikke en gjennomført brukertest eller et regnskapsfaglig produksjonsrevisjonsbevis. Ingen funksjoner eller produksjonsdata er endret.

## Det som fungerer

- Businessplan viser kroner og ord før farge/prosent, og sorterer avdelinger etter avvik. Den lar ikke vekst mot fjoråret erstatte sammenligning mot årets plan.
- Manglende businessplan får egen tomtilstand fremfor «i rute».
- Butikksjefens regnskap har egen skjermet visning av salg, bruttofortjeneste og utvalgte kostnader. Hele selskapsresultatet er ikke gjort til lederens personlige prestasjonsmål.
- Måneden har en god fortellerstruktur: dette vet vi → hvordan gikk det → dette bør du vite → godkjent handling. Anslag og fasit skilles, og datakilder kan åpnes.
- BP-sammenligning er en egen eierfunksjon, ikke butikksjefens operative planstatus. Den beholder den tidligere godkjente rekkefølgen med royalty først. Meny-/språkforslag gir ikke mandat til å erstatte denne visningen.

## Konkrete forståelsesproblemer

### 1. «Bak plan» i overskriften er ikke butikkens nettoavvik

`businessplan/page.tsx` bruker `sumBakPlan()` fra `regnskap/bp-dom.ts`. Den summerer bare negative avdelingsavvik. Dette er en bevisst prioriteringsregel, men overskriften ser ut som et samlet økonomisk resultat.

Illustrasjon, ikke produksjonstall: Mat −20 000 kr og Tobakk +30 000 kr gir overskrift «20 000 kr bak plan», selv om netto salgsavvik er +10 000 kr. Begge tall er nyttige, men de svarer på forskjellige spørsmål.

Forslag: vis butikkens målbare nettoavvik som samlet status, og behold en egen arbeidsliste «Avdelinger som ligger bak: 20 000 kr». Ikke endre eller fjerne avdelingsmotoren. Eventuelle brutto-/volumvirkninger må vises separat; salg er ikke lønnsomhet.

### 2. Samme avdelingskort skifter periode

`businessplan/bp-rad.tsx` viser månedens salgsavvik sammen med brutto hittil i år. «Hittil i år» står på avvikets marginlinje, mens de tre foregående margintallene ikke alle gjentar perioden.

Forslag: del synlig i «Salg denne måneden, til siste målte salgsdag» og «Margin januar–siste avlagte regnskapsmåned». Vis eksakte sluttdatoer når grunnlaget tillater det. Den inneværende måneden skal ikke se regnskapsavlagt ut.

### 3. Begrepene forutsetter økonomikunnskap

Eksempler: «pp», «Kassen, perfekt dag», «brutto», «lønn mot rommet», «CR-salg» og «avlagt». En regnskapsfører kan tolke dette; en uerfaren leder må først lære språket.

Forslag: bruk «prosentpoeng» og korte forklaringer ved første forekomst. Bruttofortjeneste: salgsinntekter minus varekostnad, før lønn og øvrige driftskostnader. Margin: bruttofortjeneste som andel av salget. Vis gjerne et tydelig merket eksempel: 100 kr salg − 60 kr varekostnad = 40 kr bruttofortjeneste; de 40 kronene er ikke butikkens endelige overskudd. Avtalebaserte inntekter og regnskapets periodisering må forklares ved relevante avdelinger.

«Kassen, perfekt dag» bør få en presis beskrivelse som beregnet margin fra registrerte salg, med begrensninger. Forskjellen mot regnskap skal ikke automatisk tilskrives svinn.

### 4. Regnskapet viser samme sammenligning på ulike måter

`regnskap/butikksjef-visning.tsx` viser avvik mot budsjett i kroner på toppkort og kostnader, mens salgs-/bruttotabell viser avvik i prosent. Budsjettkolonnen skjules på mobil med `mob-skjul`. En prosent uten synlig referanse gjør at brukeren må regne eller gjette.

Forslag: konsekvent «Faktisk · Plan · Forskjell i kroner», med prosent som sekundær informasjon. På mobil bør referansen finnes i samme rad/kort eller åpnes tydelig. Den grønne kostnadsfargen betyr innenfor rammen, ikke at lavere kostnad alltid er god drift; underbemanning er et mulig moteksempel.

### 5. Regnskapets forklaring kan koble feil årsak til bruttofortjenesten

Butikksjef-visningen sender bruttofortjenestens budsjettavvik og største negative avvik blant påvirkbare driftskostnader til `svaret()`. I `regnskap/mot-budsjett.ts` kan dette bli «Bruttofortjeneste ligger … under budsjett. Personalkostnad drar mest».

Personalkostnad er ikke et ledd i bruttofortjenesten. Teksten kan derfor antyde en årsakssammenheng den ikke beregner. Dette er et konkret semantisk kodefunn, ikke bare et ønske om enklere språk.

Forslag: forklar bruttofortjeneste med drivere på samme faglige nivå. Vis kostnadsavvik separat: «I tillegg er personalkostnaden … over budsjett». Unngå å omtale generell kostnadsreduksjon som løsningen på lav margin.

### 6. Fire økonomiske innganger trenger tydelig formål

Måneden, Regnskap, Businessplan og Planen bør presenteres som én lesereise, med ulike oppgaver:

| Inngang | Spørsmålet den svarer på |
|---|---|
| Måneden | Hvordan går butikken, og hva bør jeg følge opp? |
| Businessplan | Ligger salget og marginen innenfor årets mål? |
| Regnskap | Hva viser de avlagte tallene, og hvor er forskjellen? |
| Planen | Hvilke tiltak har eieren godkjent? |

Behold grunnlagsflatene. La Måneden være den pedagogiske inngangen. BP-sammenligning skal fortsatt være eierens analyse av endrede årsrammer.

## Foreslått presentasjon

Først en kort status med butikk, periode og datagrunnlag. Deretter faktisk mot mål, forklart i kroner. Så to–tre beviste drivere med tydelig skille mellom salg, margin og kostnader. Til slutt ett eller noen få eiergodkjente tiltak med ansvar og tidspunkt. Kontonummer, beregningsdetaljer og hele tabellen åpnes som grunnlag.

Illustrasjon, ikke en analyse av en faktisk stasjon: «Salget er 10 000 kr foran mål til 16. september. Mat ligger 20 000 kr bak sitt mål. Marginen gjelder januar–august; septemberregnskapet er ikke klart. Se eierens godkjente tiltak.» Dette viser både helhet, oppfølging og usikkerhet uten å slå dem sammen.

## Akseptanse før vi kaller det lett å forstå

La ledere med lite økonomierfaring forklare med egne ord: Hva er salg versus fortjeneste? Hvilken periode gjelder hvert tall? Hva er samlet status versus avdelingens avvik? Er tallet målt, anslått eller ukjent? Hva kan jeg påvirke, og hvilket tiltak er godkjent? Test dette på PC og mobil med representative økonomidata, ikke bare tomtilstander.

Onboardingpåvirkning: NEI for denne analysen. Språk og struktur krever ingen nye data; eventuelle fremtidige beregnings-/oppsettendringer må vurderes separat.
