# Forklaring av produksjonsplanen

Forklaringen bygges i samme kjøring som produksjonsforslaget. `lagProduksjonsplan()` returnerer både dagens forslag og et passivt spor med datoer, observasjoner og faktorer som motoren allerede brukte. Forklaringslaget formatterer disse verdiene, men beregner ingen nye forslag.

Bit-for-bit-vernet ligger i `src/lib/produksjonsplan.test.ts`. Testen sammenligner de eksisterende motorfeltene (`basis`, værfaktor, trendfaktor, samlet faktor, forslag og flagg) med faste forventede verdier og kontrollerer samtidig forklaringssporet. Margin, planlagt antall og startantall testes separat gjennom eksisterende produksjonsplantester og forklaringstesten i `plan-tabell.test.tsx`.

Forklaringen vises bare gjennom lederflaten for `retailer_admin` og `butikksjef`. Tabletflaten bruker fortsatt `TabletPlan` og mottar ingen forklaringsdata.

Uvanlige salgsutslag omtales som «mulig kampanjepåvirkning». Systemet bekrefter ikke at en kampanje har funnet sted.

## Fremtidig arbeid

Undersøk kontrollert justering av produksjonsforslaget basert på faktisk salg, registrert svinn per produkt, planlagt mengde, datadekning og signal om mulig utsolgt. Dette inngår ikke i forklaringsversjonen.
