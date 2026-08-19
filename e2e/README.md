# Nettlesertestene

```bash
npx next build          # --webpack på win32/arm64
npx playwright test
```

Bygget trenger `.env.local` med dummyverdier — se `playwright.config.ts`. CI setter
dem som miljøvariabler i stedet.

## Hva disse måler som de raske vaktene ikke kan

De seks vaktene i `src/lib/redesign/` leser kildekode. Disse kjører systemet.

**Kontrast og størrelser.** `tilgjengelighet.test.ts` kjører axe i jsdom og må slå av
contrast-regelen: uten rendering finnes det ingen farger å regne på. Her finnes de.
Første kjøring fant at innloggingsknappen var 40 px høy — under iOS-minimum på 44.
Ingen av de raske vaktene kunne se det.

**At redirect faktisk skjer.** `tilgang.test.ts` leser portneren ut av kilden.
`tilgang.spec.ts` spør systemet, uten økt, rett på URL-en — slik en angriper ville
møtt det. De to kan være uenige: en side kan ha riktig rollesjekk i koden og likevel
svare 200 fordi middleware, layout eller en cache kom i veien. 53 ruter sjekkes.

## Hva som mangler, og hva det krever

**Alt bak innlogging.** Disse testene kjører uten database. Dummy-nøkler er nok fordi
hver side er dynamisk, men det betyr også at ingen side med data kan åpnes.

Det som ikke testes, og som betyr mest:

- **Nettbrettets treffområder.** `.tablet .kryss` er 56×56 i `globals.css` fordi
  arbeidshansker bommer på 44. Den regelen er aldri målt i en nettleser — skjermen
  krever økt.
- **Kontrast på de 58 sidene.** Bare de fire åpne sidene måles i dag.
- **De kritiske arbeidsflytene.** Last opp fil → behandle → se tall. Sett lønnsform →
  last ned Visma-fil. Legg inn bemannet vindu → få en plan.
- **Rolleforskjeller i praksis.** At butikksjefen ser sin stasjon og ikke andres er
  testet i SQL (`rls_isolasjon.sql`), ikke gjennom grensesnittet.

**Det krever ett seedet test-Supabase-prosjekt** med kjente stasjoner, ansatte og noen
måneder salgsdata, og tre hemmeligheter i GitHub: prosjekt-URL, anon-nøkkel og
service-nøkkel til seedingen. Det er en beslutning om oppsett og kostnad, ikke om kode.

Til det finnes, er det ærlig å si at disse testene dekker **inngangen** til systemet,
ikke systemet.
