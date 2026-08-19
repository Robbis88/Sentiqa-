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

## Databasen

CI starter en **lokal Supabase** (`npx supabase start`) — fersk for hver kjøring.
Migrasjonene `0001→` kjøres fra repoet, og `supabase/seed.sql` legger inn testdata.

Ingen hemmeligheter er involvert: en lokal Supabase har faste, offentlig dokumenterte
nøkler, og basen slettes når jobben er ferdig. Det er også den eneste kontrollen på at
**hele migrasjonssettet fortsatt kjører fra bunn** — AGENTS.md sier det skjer av og
til, men ingen hadde verifisert det.

Seeden gir én kjede, to stasjoner og to brukere: `butikksjef@test.sentiqa.no` og
`nettbrett@test.sentiqa.no`. **Ingen salgsdata, med vilje** — tomme tilstander er de
som aldri ses under utvikling, fordi utvikleren alltid har data.

Kan ikke kjøres lokalt på denne maskinen (ingen Docker på win32/arm64). Resultatene
leses i CI.

## Hva som mangler, og hva det krever

**Eier og plattform-redaktør.** Begge tvinges gjennom TOTP (`mfaPaakrevd` i
`src/lib/auth/mfa.ts`), så en innlogging havner i innrullering i stedet for på
forsiden. Det krever en seedet MFA-faktor med kjent hemmelighet, og en TOTP-generator
i testen. Alt som bare eier ser — `/regnskap`, `/analyse`, `/import`, `/plattform` —
er derfor utestet gjennom grensesnittet.

**De kritiske arbeidsflytene.** Last opp fil → behandle → se tall. Sett lønnsform →
last ned Visma-fil. Legg inn bemannet vindu → få en plan. De krever både eier-rollen
og ekte datafiler.

**Alt som trenger data.** Seeden er tom med vilje, så testene måler tom tilstand.
Grafer, tabeller og tall er ikke sett av noen test.
