# Syntetiske arbeidsbøker for parsertestene

## Hvorfor de finnes

`eksempelfiler/` er gitignored — der ligger **ekte** rapporter fra St1 og
Azets, og de skal ikke i git. Testene som leste dem sto derfor med

```ts
describe.skipIf(!existsSync(FIL))('parseX (ekte St1-fil)', …)
```

og hoppet over seg selv. Ikke bare i CI: mappa er tom lokalt også, så de
hadde ikke kjørt noe sted på lenge. **Tjueto påstander som så ut som
grønne tester.**

Det er den samme formen som resten av dette repoet er bygget for å nekte:
en vakt som ikke ser, ser nøyaktig ut som en vakt som ikke finner noe.

## Hva de beviser, og hva de ikke gjør

Disse modulene bygger arbeidsbøker med ExcelJS i minnet, i samme form som
rapportene, med de verdiene testene alt sto og påsto — verdier som ble
lest ut av ekte filer da testene ble skrevet.

**De beviser at parseren gjør jobben sin på den formen:** at kolonnene
mappes til riktige felt, at `Sum EAN`-rader hoppes over, at delsummer
ikke tredobler timer, at tall med komma leses som tall, at datoer blir
ISO.

**De beviser IKKE at formen stemmer med det St1 sender i dag.** Bare en
ekte fil kan si det. Endrer St1 arket, er disse fortsatt grønne — og det
er en ærlig begrensning, ikke en skjult en.

Derfor: legger du en ekte fil i `eksempelfiler/`, brukes DEN. Testene
leser fixture bare når fila mangler, og suiten sier i navnet sitt hvilken
kilde den kjørte mot.

## Regelen

**En fixture skal bygges fra det testen påstår, ikke fra det parseren
gjør.** Bygger man den fra parserens egne konstanter, beviser testen bare
at parseren er enig med seg selv. Verdiene her er observasjoner —
stasjonsnumre, EAN, datoer, beløp — og de hører hjemme i fixturen med
samme tallverdi som i påstanden.
