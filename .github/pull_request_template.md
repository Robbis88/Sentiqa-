## Hva endrer seg, og hvorfor

<!-- Én til tre setninger. Hva var galt, ikke hva du gjorde. -->

## Erklærte endringer i fasit

<!--
Kjørte du `OPPDATER_FASIT=1 npx vitest run src/lib/redesign`?
Da skal diffen i fasit.json eller designfasit.json forklares her.

Vaktene forbyr ikke endring — de tvinger den til å bli erklært. Står det
en fasit-diff uten en linje her, er noe gitt slipp på uten at noen skrev
det ned, og det er forskjellen på å flytte noe og å miste det.
-->

- [ ] Ingen fasit er endret
- [ ] Fasit er endret, og det står forklart over

## Migrasjoner

<!--
Nye `.sql`-filer i supabase/migrations/? Husk:
- alt må tåle å kjøres om igjen (`if not exists`, vaktede `insert`/`update`)
- nye tabeller med policy skal inn i `varme` eller `kalde` i rls_vakthund.sql
- nye partisjoner må ha `revoke all ... from anon, authenticated`
- kjør `supabase/tests/rls_vakthund.sql` etterpå
-->

- [ ] Ingen migrasjon
- [ ] Migrasjon lagt ved, og vakthunden er kjørt mot prod etter den

## Sjekket selv

<!-- Vaktene er deterministiske og fanger form, ikke innhold. De kan ikke
se om tallet er riktig, bare om det er formatert riktig. -->

- [ ] Åpnet sidene jeg endret, og de viser det de skal
