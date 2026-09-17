# Ukesbrief: er innholdet tilstrekkelig?

Vurdert 17. september 2026. Dette er en gjennomgang, ikke nye kodeendringer eller e-postutsending.

Briefen har et godt fundament som kort driftsbrief. Den er ikke alene nok som økonomisk styringsbrief for en butikksjef som trenger konkret hjelp. Før mer innhold legges til, bør målinger og konklusjoner rettes. Mer innhold på feil grunnlag vil gjøre den mindre nyttig.

## Det som fungerer

- Tekst og anbefalinger bygges deterministisk fra tall; ingen AI finner på årsaker i ingressen.
- Nettvisning, e-post og PDF bygger på samme modell.
- Handlingene knyttes til signaler. Fakta, indikasjoner, hypoteser og ukjent grunnlag er egne begreper.
- Kritiske sjekkpunkter og alvorlige tilbakemeldinger omtales uten unødvendige persondetaljer.
- Manglende bemanningsramme og BP kan vises som ukjent.
- Utsending venter på søndagstall og støtter tørrkjøring.

## Rett dette først

| Prioritet | Funn | Hva bør endres |
|---|---|---|
| P1 | `hent.ts:340` henter prognosetreff uten type-/totalfilter. Briefen blander produksjon, salgsprognose og kategorier/totaler. | Bruk kun produksjonsmodellens dagsresultat, og si nøyaktig hva som måles. |
| P1 | `bygg.ts:253–260` kaller dette bom på planen og foreslår endret startprosent. Startprosent påvirker ikke råprognosen som måles. | Anbefal gjennomgang av modellen og kategoriene; ikke et ubegrunnet produksjonstiltak. |
| P1 | Ingressen kan si «Ingenting krever oppmerksomhet» selv med viktige ukjente målinger. Salgshull begrenser ikke alltid vekstdommen. | Bruk «Ingen kjente avvik i det målte grunnlaget» og tydelig foreløpig resultat ved ufullstendig uke. Ikke sammenlign ufullstendig periode med full referanse. |
| P1/P2 | Flere oppslag for timer, BP, treff og meldinger leser ikke konsekvent databasefeil. | Skill feil fra bekreftet null eller fravær; stopp utsending eller merk utilgjengelig grunnlag. |
| P2 | Ukesvelgeren tar et begrenset antall EAN-rader, ikke distinkte uker. En travel dag kan fylle hele utvalget. | Bruk daglig aggregat/distinkte datoer som ukekilde. |
| P2 | Funnlenkene tar ikke alltid med stasjon og rapportperiode. | Bevar konteksten fra brevet til undersiden, særlig for ledere med flere butikker. |
| P2 | Enkelte årsaksforklaringer er mer bastante enn tallene tilsier. | Skill observert forhold fra mulig årsak. «Undersøk hvorfor varen ikke ble bestilt» må ikke antyde at bestilling faktisk var årsaken. |

Kilder: `src/lib/ukebrief/hent.ts`, `bygg.ts`, `src/app/(beskyttet)/ukebrief/*`.

## Minste nyttige brief

En butikksjef bør kunne lese hoveddelen på to–tre minutter og vite hva som skal gjøres. Anbefalt rekkefølge:

1. **Ukens svar:** hva gikk bra, hva krever vurdering, og hvor sikkert er grunnlaget?
2. **Tre prioriterte tiltak:** hva skjedde, hva bør undersøkes, og hva gjør sjefen nå? Kritiske sikkerhetssaker kommer alltid i tillegg.
3. **Fire korte kontrollpunkter:** butikksalg, svinn, bemanning og produksjon. Vis bare mål som har sammenlignbart og tilstrekkelig grunnlag.
4. **Siste avsluttede måneds økonomi:** brutto, BP-kompatibel lønn og lønnsrom med tydelig måned/datakvalitet. Ikke fremstille månedstall som uketall eller bruke alle lønnskonti mot et smalere BP.
5. **Oppfølging:** hva fra forrige uke eller godkjent månedsplan som fortsatt må gjøres.
6. **Dette vet vi ikke:** kort og konkret, og reflektert i hovedkonklusjonen — ikke bare som fotnote.

## Hva som mangler for enkel styring

**Økonomi:** Omsetning alene sier ikke om butikken tjener penger. Dagens omsetnings-BP bør suppleres med siste bekreftede måneds brutto og sammenlignbart lønnsrom. Bruk eksisterende økonomimodells kontodefinisjon, stasjon og sikkerhetsnivå.

**Svinn:** Vis dokumenterte kroner og viktigste varegruppe når dekningen er god. Ikke automatisk oversett høyt svinn til mindre produksjon eller lavere margin.

**Bemanning:** Ukestimer mot en flat ramme er ikke nok til å si hvor problemet ligger. Relevant kundetrykk og dagen/tidsrommet som bør vurderes er mer nyttig. Flat månedsfordeling må merkes som anslag.

**Produksjon:** Skill modellens forventede salg fra lederens plan, faktisk produsert, salg og svinn. En lav råmodelltreffprosent dokumenterer ikke at ansatte har produsert feil.

**Oppfølging:** Bruk allerede godkjente tiltak fra månedsplanen der det passer, så briefen ikke skaper enda en uavhengig anbefalingsliste.

## Eksempel på tydelig tiltak

> **Sjekk produksjonsgrunnlaget før torsdag.** Produksjonsmodellens forventede salg avvek fra registrert salg sist uke. Se varegruppen med størst avvik, og kontroller datadekning og eventuelle utsolgte dager før du endrer planen.

Dette lover ikke en årsak som dataene ikke beviser, og peker på en handling sjefen kan gjennomføre.

Anbefaling: rett målekontraktene først, så lag en kort prototype med tre tiltak og månedens økonomisvar. Flere grafer og AI-avsnitt er ikke nødvendig for å gjøre briefen bedre.

Onboardingpåvirkning: NEI — gjennomgangen endrer ingen funksjon. Hvis nye økonomi-/svinnkilder legges til, må deres eksisterende datakrav utledes fra modulene og vurderes på nytt.
