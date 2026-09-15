# Lønnskontroll: Basis Export + Daglig lønnskost

**Status:** foreløpig beslutning tatt 2026-09-15. Ingenting er bygget.
**Bevisgrunnlag:** fem stasjonsmåneder mot kronefil, tre av dem også mot regnskapet.
Alt read-only.
**Beslutning:** 503-motoren er GODKJENT FOR BYGGING. Beslutning A og B tatt (§8).


---

## 1. Beslutningen

Sentiqas lønnskontroll bygges på **to easy@work-eksporter per stasjon per måned**:

| fil | hva den bestemmer |
|---|---|
| **Basis Export** | hvem som faktisk jobbet på stasjonen, og hvor mange betalte timer som tilhører stasjonen |
| **Daglig lønnskost** | lønnssats og lønnsopplysninger for den ansatte |

Sentiqa beregner estimert kostnad mot **konto 503** etter regler som er målt, ikke utledet.

**Kronefila (Lønnsoversikt) er kontrollfasit, ikke månedlig kilde.** Den finnes bare for
Dale og Bønes, og modellen skal ikke være avhengig av den.

---

## 2. Bevisgrunnlaget

```
stasjonsmåned     kronefil 503   beregnet 503     avvik        %    overtid   uten overtid
Bønes  juli 2026       139 384        139 303       -80   -0,058       118      0,027 %
Bønes  aug  2026       145 093        143 889    -1 204   -0,830     1 393      0,131 %
Dale   mai  2026       315 854        315 237      -617   -0,195       553     -0,020 %
Dale   juli 2026       310 105        313 345    +3 240   +1,045       137      1,089 % *
Dale   aug  2026       265 785        259 715    -6 070   -2,284     7 023      0,358 %
────────────────────────────────────────────────────────────────────────────────────────
SUM                  1 176 221      1 171 489    -4 732   -0,402     9 224      0,382 %
```

\* 2 737 kr av dette er **én ansatt der de to easy@work-kildene er uenige med hverandre**
(ansatt 1104304). Daglig lønnskost for juli sier 185,58 kr/t; kronefila betalte 143,34 kr/t
samme måned. Regner vi med den observerte satsen: 0,162 %.

**KORRIGERT 2026-09-15 — dette ble først kalt «utdatert sats i Easy». Det var feil, og
retningen var motsatt.** Lønnsgrunnlaget har den NYE satsen; utbetalingen brukte den GAMLE.
Ansatt 1104304 fikk lønnsøkning i juni 2026: 143,34 i april og mai, 185,58 fra juni.

Lærdommen er viktigere enn tallet: **Easy-kildene kan være uenige med hverandre innenfor
samme måned.** Sentiqa skal derfor si *«kildene er uenige»* — ikke stemple én av dem som
utdatert. Hvilken som har rett, bærer ikke dataene svar på, og da skal vi ikke gjette.
Samme prinsipp som overalt ellers i dette dokumentet.

### Kontrollbeviset: Bønes juli

Carmen (1104265) og Julian (1104270) har **Lone** som hovedlokasjon, men jobbet på Bønes.

```
Basis Export   79,82 t + 17,49 t
kronefil       79,82 t + 17,49 t     diff 0,00
```

Dagens modell, som bare leser Bønes' eget lønnsgrunnlag, **utelater dem helt**:
−15 191 kr, −10,9 %. Feilen går alltid i samme retning — for lite lønn, altså for mye
lønnsrom. Det er den farlige retningen, og den forsvinner ikke av å rydde i Easy.

### Kryssarbeid per stasjon

```
Bønes           juli 10,9 %    aug 3,3 %
Varden                         aug  0,1 %
Dale                           aug  0,0 %
Laguneparken                   aug  0,0 %
Lone                           aug  0,0 %
```

Bønes er unntaket, ikke regelen. Modellen er likevel verdt å bygge: feilen er stor der den
finnes, og ingen annen kilde ser den.

### Hvorfor lønnsgrunnlaget aldri kan løse dette alene

Daglig lønnskost **har** en `Lokasjon`-kolonne, og parseren leser den per dagslinje. Men over
**4 620 dagslinjer i 23 filer er den lik `Hovedlokasjon` uten ett eneste unntak.** Kolonnen
finnes; den bærer aldri ny informasjon.

Verre: Carmen står i Lones juli-fil med **0 timer** samme måned som hun jobbet 79,82 t på
Bønes. Hun forsvinner ikke — hun dukker opp som en troverdig null. Det er 77 slike
nulltimersrader i materialet.

---

## 3. Premissene

### 3.1 Feil sats skjules ikke

Sentiqa skal **ikke** bygge kompensasjonslogikk for utdaterte satser i easy@work.
Prinsippet er: *korrekt Easy-data → Sentiqa beregner.* Er dataene feil, skal Sentiqa
**varsle**, ikke gjette.

Detektoren er allerede validert på ekte data: observert sats (kronefilas kr/t) mot
registrert sats (Daglig lønnskost) fant ansatt 1104304 med 42,24 kr/t i avvik over 88,8
timer. På Bønes juli/aug og Dale mai avvek **ingen** ansatt mer enn 0,50 kr/t.

**Varselet skal formuleres som uenighet, ikke som en dom.** Se korreksjonen i §2: i det ene
observerte tilfellet var det lønnsgrunnlaget som hadde den nyeste satsen, ikke kronefila.
Teksten skal derfor være «Daglig lønnskost og Lønnsoversikt er uenige om timesatsen for
denne ansatte» — ikke «utdatert sats».

Merk at detektoren krever kronefila og derfor bare virker på Dale og Bønes i dag.

### 3.2 Kryssarbeid løses

Bevist. Se 2.

### 3.3 Fastlønn prises ikke inn på 503

En fastlønnet med arbeidede timer koster **ikke** den lånende stasjonen noe på 503.
Bekreftet: ansatt 1004 (68 t Bønes + 16 t Dale i august) finnes verken i lønnsgrunnlaget
eller i kronefila. Han er innleid på fastlønn og får ikke betalt for Dale-timene.
Ansatt 1041 på Laguneparken (166,3 t) er samme tilfelle.

**Men manglende timesats skal ikke automatisk tolkes som fastlønn.** I august hadde sju
ansatte ingen sats. Fem av dem var timelønnede som bare hadde **feil nummer** (se 3.4).
Hadde «ingen sats = fastlønn» vært regelen, ville 160 timer på Varden stille blitt gratis.

Klassifiseringen må være eksplisitt og komme fra en kilde som vet — ikke fra fravær.

### 3.4 Ansattidentitet må være sikker

**Ingen heuristikk.** Fem ansatte har ulikt nummer i de to eksportene:

```
1058 ↔ 11058      1021 ↔ 11021      1013 ↔ 11013      811 ↔ 0811
1512 ↔ 1104215    ← ingen strengregel kan utlede denne
```

Fire følger et mønster. Den femte gjør ikke. En regel ville tatt fire av fem og **tiet om
den siste** — nøyaktig formen på en vakt som slutter å se.

Det som gjorde koblingen sikker i analysen var ikke navnet, men at **timetallet var
identisk på tidelen i begge eksportene** (160,0 = 160,0; 57,5 = 57,5). Navnekobling i
stillhet er forbudt i dette huset, og skal forbli det.

Kravet: en **eksplisitt bro-tabell** som et menneske har kvittert for, med synlig avvik når
en person i Basis Export ikke kan kobles sikkert.

### 3.5 Ukoblet timelønnet gjør estimatet ufullstendig

Aldri ignorere. Se 4.6 og 4.10.

### 3.6 Overtid gjettes ikke

**Art 96 (50 %)** ser ut til å være *timer over 10 på en dag* — 6 av 8 observasjoner
eksakt. **Ikke nok til produksjon.**

**Art 97 (100 %) kan ikke utledes av Basis Export.** Den avhenger av *planlagt* vakt:
22. august var planlagt 14:00–24:00, stemplet fra 12:00, og 97 ble nøyaktig 2,00 t. Basis
Export har ingen planlagt tid. Kronefila har det — derfor kan den fordele 97.

Overtid er 9 224 kr av 1 176 221 målte kroner (0,78 %), men fordeler seg svært ujevnt:
0,04 % på Dale mai, **2,64 %** på Dale august.

**Neste forbedring:** vaktplanen Sentiqa allerede bygger bærer planlagt tid. Når den er i
drift for en stasjon, kan 97 utledes av differansen mellom planlagt og stemplet — og da kan
regelen måles mot kronefila på samme måte som tilleggene ble det.

### 3.7 Bare målte helligdagsregler

**Målt og beholdt:**
- Helligdag gir `2 Timelønn` + `1410`, og **erstatter** de vanlige tilleggene. 17. mai er
  søndag, men får ingen 1434/1435. Mandag 18. mai i samme fil har tilleggene som normalt.
- **Pinseaften starter kl. 15.** En vakt 09:00–15:57:51 fikk `1410 = 0,96 t`.
  Lørdag 16. mai — dagen før 17. mai — fikk derimot helt vanlig lørdagstillegg.

**Ikke målt, skal ikke generaliseres:** påskeaften, julaften, nyttårsaften. Vi har kronefil
for mai, juli og august. Ingen av dem inneholder disse dagene.

**Ikke bekreftet:** lørdag 00–06 er antatt å følge hverdagsnattsats (1431). Ingen av de fem
månedene motbeviser det; ingen bekrefter det.

---

## 4. Anbefaling for første produksjonsversjon

### 4.1 Hvilke to filer butikksjefen laster opp

Per stasjon, per måned:

1. **Daglig lønnskost**
2. **Basis Export**

Ingen manuell sammenstilling. Ingen av de øvrige fem eksportene trengs, og butikksjefene har
ikke tilgang til alle.

### 4.2 Hvordan de kobles

På **`Stemplingsnummer`**, gjennom en eksplisitt bro-tabell for de kjente avvikene.
Aldri på navn. Aldri på et utledet mønster.

Satsen hentes fra **hjemstasjonens** lønnsgrunnlag. Det virker fordi en utlånt ansatt står
i sin egen stasjons fil med 0 timer — men med satsen sin. Alle fem stasjoner leverer
lønnsgrunnlaget, så hjemstasjonens fil finnes alltid.

### 4.3 Hvordan 503 beregnes

```
for hver rad i Basis Export (Type = «Betalt tid»):
    del intervallet minutt for minutt på lønnsart
    pris hver art med belopFor(art, timer, hjemstasjonens timesats)
503 = timelønn (art 2) + alle tillegg
```

Konto **505** (sykelønn, art 12) er ikke 503 og er ikke en stempling. Holdes utenfor.

**Fordeleren må måles mot kronefila før den brukes,** slik den ble her: 199 av 200 linjer
innenfor 0,02 t på Bønes juli. Den ene bommen var overtid.

**Parserkrav:** `Fra` er som regel `HH:MM`, men når vakten krysser døgnet skriver easy@work
av og til hele datoen — `Forretningsdato 2026-07-31`, `Fra "1 august 2026 00:00"`. En parser
som bare leser klokkeslettet får NaN, eller verre: riktig timetall på feil ukedag, og dermed
feil tillegg.

### 4.4 Kryssarbeid

Arbeidsstedet er `Lokasjon` **per rad** i Basis Export. Timene føres der arbeidet skjedde,
uavhengig av hovedlokasjon. Ingen omfordeling, ingen fratrekk hos hjemstasjonen — hver
stasjon leser sin egen Basis Export.

Innlånt arbeid skal være **synlig som egen linje**, ikke bakt inn:

```
Herav innlånte ansatte: 14 850 kr
```

### 4.5 Fastlønn

Prises **ikke** på 503. Men fravær av sats er ikke bevis for fastlønn — se 3.3.
Første versjon skal derfor **ikke** klassifisere selv: den skal spørre.

### 4.6 Ved ukjent ansatt

En timelønnet i Basis Export som ikke kan kobles sikkert til et lønnsgrunnlag gjør
estimatet **ufullstendig**. Tallet vises som et **minimum**, aldri som komplett, og
lønnsrommet beregnes ikke.

Dette er den viktigste enkeltregelen i hele dokumentet. Uten den ville 160 manglende timer
på Varden vist seg som 38 000 kr ekstra lønnsrom.

### 4.7 Ved manglende eller utdatert sats

- **Manglende sats:** som 4.6.
- **Utdatert sats:** kan bare oppdages der kronefila finnes. Der den gjør det, vises et
  eget varsel — og estimatet endres **ikke**. Sentiqa kompenserer ikke; Sentiqa varsler.

```
Mulig feil lønnssats — ansatt 1104304
easy@work: 185,58 kr/t
Observert:  143,34 kr/t
Kontroller lønnssatsen i easy@work.
```

### 4.8 Lønnsarter som er sikre

Målt mot kronefil, 199/200 linjer innenfor 0,02 t:

| art | |
|---|---|
| `2` | Timelønn |
| `1429` `1430` `1431` | hverdag 18-21, 21-24, 00-06 |
| `1432` | lørdag 18-24 |
| `1433` `1434` `1435` | søndag 00-06, 06-18, 18-24 |
| `1410` | helligdag, og pinseaften fra kl. 15 |

### 4.9 Lønnsarter som fortsatt er estimat

| art | status |
|---|---|
| `96` | 50 % overtid — 6 av 8 passer «over 10 t/dag». Ikke produksjonssettes. |
| `97` | 100 % overtid — **ikke utledbar** av Basis Export. Krever vaktplan. |
| `1410` på påskeaften / julaften / nyttårsaften | ikke målt |
| lørdag 00–06 | antatt 1431, ikke bekreftet |

### 4.10 Hvordan lønnsrommet presenteres

**Komplett datagrunnlag:**

```
Estimert lønnskost 503     143 889 kr
Datagrunnlag: komplett ✓
87 ansatte koblet · kryssarbeid inkludert · satser kontrollert
Overtid kan gi mindre avvik.
```

**Ufullstendig datagrunnlag:**

```
Estimert lønnskost 503     minst 105 900 kr  ⚠
1 ansatt / 160 timer mangler lønnssats
Lønnsrom kan ikke beregnes sikkert før dette er rettet.
```

Regelen bak begge: **Sentiqa skal aldri vise et stort grønt lønnsrom fordi 38 000 kroner
tilfeldigvis mangler.** Et ufullstendig grunnlag gir et *minimum*, ikke et estimat, og
lønnsrommet uteblir helt.

Dette er samme form som `kilde`-modellen i `okonomi/bilde.ts`: svakeste kilde arves, og
kilden følger med ut.

### 4.11 Kontroller som må være grønne før tallet vises som komplett

1. **Alle timelønnede i Basis Export er koblet** til et lønnsgrunnlag.
2. **Alle koblede har timesats** > 0.
3. **Hver ukoblet er eksplisitt klassifisert** som fastlønn av et menneske — ikke utledet.
4. **Begge filer dekker samme periode**, og perioden er hel.
5. **Ingen ukjent lønnsart.** `belopFor` kaster allerede på en art uten sats; den innsatsen
   beholdes.
6. **Ingen ukjent lokasjon** i Basis Export.
7. **Fordeleren er målt mot kronefila** for minst én stasjonsmåned etter hver regelendring,
   med kanarifugl.
8. **Timesum stemmer**: Basis Export sine timer = lønnsgrunnlagets timer for de
   hjemmehørende. Sprik betyr at én av filene er avkortet.

Kontroll 1–3 avgjør om tallet er *komplett* eller et *minimum*. 4–8 avgjør om det skal vises
i det hele tatt.

---

## 5. Hva som ikke bygges nå

- Sentiqas egen nettbrettstempling som kilde. Den ligger lenger fram og skal ikke ventes på.
  Senere kan den gjøre Basis Export overflødig.
- Overtid (se 3.6).
- Kompensasjonslogikk for feilregistrerte satser (se 3.1).
- Aftener uten måling (se 3.7).

---

## 6. Onboardingpåvirkning

**JA.** Vedtas dette blir **Basis Export en ny obligatorisk månedlig fil** ved siden av
Daglig lønnskost, for hver stasjon. Onboarding må i tillegg dekke:

- bro-tabellen for ansattnumre som spriker mellom de to eksportene
- eksplisitt klassifisering av fastlønnede
- at lønnssatsene i easy@work må ryddes før første måned regnes som komplett

---

## 7. Kostnadskjeden — målt 2026-09-15

Målt mot regnskapsrapportene (`190 Kelsar Bil AS 2026xx`) med prosjektets egen
`parseRegnskapStasjoner`. Tre stasjonsmåneder der alle tre lag finnes.

### 7.1 Hva Sentiqa kaller «lønnskost»

Ni konti, og rekkefølgen er visningsrekkefølgen (`lonnskost/maaned.ts`):

```
501 Fastlønn   502 Lønnstillegg   503 Timelønn   505 Sykelønn
506 Refundert sykelønn (negativ)  508 Feriepenger  509 Bonus
540 Aga av lønn                   541 Aga av feriepenger
```

`590 Andre personalkostnader` holdes **utenfor** — vises ved siden av, aldri i.

```
lønnskost = kontant + feriepenger + aga
kontant   = 501 + 502 + 503 + 505 + 506 + 509
```

For en **avlagt** måned leses alle tre fra regnskapet. For en **åpen** måned regnes
påbygningen av kontantlønna i `easyatwork.ts`.

### 7.2 Satsene, og hvor de kommer fra

```
feriepenger  12 %    av kontant
aga          14,1 %  av (kontant + feriepenger)
pensjon       2 %    av kontant  — REGNES, MEN INNGÅR IKKE
```

De står som **konstanter i kode** (`SATSER` i `easyatwork.ts`), ikke som konfigurasjon.
Kommentaren sier selv at dette er Kelsars tall og blir konfigurasjon per retailer ved
kunde nummer to.

**Målt mot bokførte tall:**

| | feriepenger / kontant | aga / (kontant+fp) |
|---|---|---|
| Bønes juli | 12,00 % | 14,10 % |
| Dale mai | 12,00 % | 14,10 % |
| Dale juli | 12,16 % | 14,00 % |
| Lone mai | **11,00 %** | 14,10 % |

Formlene stemmer. Avvikene er periodisering, ikke feil sats — men de finnes, så
påbygningen er ikke eksakt.

**`pensjonKr` beregnes og returneres, men inngår ikke i `lonnskostKr`.** To motstridende
kommentarer står rett over hverandre i `easyatwork.ts:212-217`; koden følger den andre
(OTP ligger utenfor, sammen med 590). Det er riktig og konsistent med BP-siden, men
kommentarparet bør ryddes.

### 7.3 Endrer Basis Export noe ved påbygningen?

**Nei.** Basis Export + Daglig lønnskost gjør bare kontantlønnas 503-ledd bedre.
Påbygningen over er uendret og kan brukes som den står.

### 7.4 Tre-veis-måling: beregnet → kronefil → bokført

```
                     beregnet 503   kronefil 503   bokført 503   beregnet vs bokført
Bønes juli 2026           139 303        139 384       140 723        -1 420   -1,01 %
Dale  juli 2026           313 345        310 105       309 707        +3 638   +1,17 %
Dale  mai  2026           315 237        315 854       313 214        +2 023   +0,65 %
```

**Viktig: kronefila er heller ikke identisk med bokført 503** — den avviker −0,95 %,
+0,13 % og +0,84 %. Vår modells feil mot regnskapet er altså av samme størrelsesorden som
easy@works egen. Differansen er etterfølgende Azets-korreksjoner, ikke modellfeil.

### 7.5 Hele kjeden mot bokført lønnskost

Med fastlønn og de øvrige kontantkontiene hentet fra regnskapet:

```
                     vår lønnskost   bokført lønnskost      avvik
Bønes juli 2026            241 149             242 963     -1 814   0,75 %
Dale  juli 2026            445 578             441 171     +4 407   1,00 %
Dale  mai  2026            423 356             420 770     +2 586   0,61 %
```

**Kjeden henger sammen innenfor 1 %.** Men se 7.6 før dette leses som et grønt lys.

### 7.6 Det som IKKE er bevist: den åpne måneden

Tallene i 7.5 brukte **501, 502, 505, 506 og 509 fra regnskapet**. I en åpen måned finnes
ingen av dem:

| konto | i en åpen måned |
|---|---|
| `501` Fastlønn | manuelt, `medFastlonn` — og uten pro-rating |
| `502` Lønnstillegg | finnes ikke i noen easy@work-eksport |
| `505` Sykelønn | delvis — art 12 finnes i eksporten |
| `506` Refundert sykelønn | finnes ikke |
| `509` Bonus | finnes ikke |

7.5 beviser altså **aritmetikken i påbygningen**, ikke at den åpne månedens anslag treffer
innenfor 1 %.

### 7.7 Er tallet sammenlignbart med budsjettet? — NEI

Dette er det viktigste funnet i kontrollen.

**Lønnstallet er ni konti. Rommet er utledet av BP, som bare har fem.**

`bilde.ts` gjør `styringsavvik(rom, lonn.verdi)`, der `lonn.verdi` er ni-konto-lønnskosten
og `rom.romKr` er `(BP-lønn / BP-brutto) × faktisk brutto`. BP-lønn er
`BP_TIL_REGNSKAP` = **501, 503, 508, 540, 541**. `bp.ts` sier det selv: «Regnskapet har
502, 505, 506 og 509. BP-en har ingen tilsvarende koder — de budsjetteres ikke separat.»

Målt hvor stort avviket er:

```
                     bokført på BP-nivå   utenfor BP (502+505+506+509)   andel
Bønes juli 2026                241 351                          1 612    0,67 %
Dale  mai  2026                404 722                         16 048    3,97 %
Dale  juli 2026                405 842                         35 330    8,71 %
```

**St1s eget budsjett for 502/505/506/509 er 0 i alle tre månedene.** Kostnaden måles, men
budsjetteres aldri.

Følgen: en måned med mye sykefravær leser som et overforbruk som ikke er et
styringsproblem. På Dale i juli er det 8,71 % — og 506 (NAV-refusjonen) var ennå ikke
bokført, så kostnaden er dessuten midlertidig for høy i regnskapet selv.

Retningen er den trygge — det ser dyrere ut enn det er, ikke billigere. Men det er feil,
og det er feil nettopp når noen er syk.

**Dette er en eksisterende svakhet, ikke noe 503-arbeidet innfører.** Det er første gang
den er målt.

---

## 8. Beslutninger

### 8.1 Beslutning A — lønnsrommet sammenligner likt med likt

**Besluttet 2026-09-15.**

Når BP har lønnsbudsjett for **501 + 503 + 508 + 540 + 541**, er det disse kontiene som
inngår i kostnaden som sammenlignes mot BP og bestemmer brukt og gjenværende lønnsrom.

**502, 505, 506 og 509 skal ikke redusere BP-lønnsrommet** når BP ikke inneholder budsjett
for dem.

Sentiqa skal **ikke** konstruere et budsjett St1 ikke har gitt oss. Alternativet — å utvide
budsjettsiden — er forkastet.

Målt effekt: 0,67 % (Bønes juli), 3,97 % (Dale mai), 8,71 % (Dale juli). Se 7.7.

### 8.2 Beslutning B — tre tilstander, ikke en disclaimer

**Besluttet 2026-09-15.**

Lønnskosten deles i to synlige størrelser:

| | |
|---|---|
| **Lønn mot budsjett** | samme kontonivå som BP. Dette tallet bestemmer lønnsrommet. |
| **Øvrige lønnskostnader** | lønnskonti utenfor BP. Synlige separat, spiser aldri av rommet. |

Mye sykelønn skal kunne være et **viktig signal** uten at butikksjefen får beskjed om at
lønnsbudsjettet er sprengt.

Modellen skal skille eksplisitt mellom tre tilstander per konto:

```
BUDSJETTERT / STYRINGSRELEVANT     inngår i lønnsrommet
UTENFOR BP                          vises separat
IKKE KJENT ENNÅ                     vises som ukjent
```

**En ukjent kostnad er ikke 0.** Ukjente konti skal ikke fylles med null og ikke
presenteres som komplette. Dette er samme form som `kilde`-modellen i `okonomi/bilde.ts`:
`mangler` er en egen tilstand, ikke en nullverdi.

---

## 9. Implementeringsrekkefølge

**Ingen stor omskriving.** Eksisterende kontrakter bevares der de er riktige.
`parsere/stempling.ts` har allerede typen `Stempling` med `lokasjon` per rad — den brukes
som den er. `lonn/tilleggssats.ts`, `lonnskost/easyatwork.ts` og `lonnskost/maaned.ts`
røres ikke i trinn 1.

### Trinn 1 — 503-kjeden som ren beregning  ← DETTE TRINNET

Ingen database, ingen UI, ingen migrasjon. Bare ren beregning med tester rundt hvert bevis.

| fil | ansvar |
|---|---|
| `parsere/basiseksport.ts` | CSV-varianten av Basis Export → `Stempling[]` |
| `lonn/tilleggsfordeling.ts` | stemplingsintervall → lønnsarter, etter **målte** regler |
| `lonn/identitet.ts` | bro-tabellen; ukoblet ansatt rapporteres, aldri gjettes |
| `lonnskost/arbeidssted.ts` | Basis + lønnsgrunnlag → 503 per stasjon/måned + datagrunnlag |

Med vakter: parsertester, fordelertester med kanarifugl, identitetstester, og en
måletest mot de fem kontrollmånedene.

### Trinn 2 — kostnadsnivået (beslutning A)

`lonnskost/maaned.ts` og `okonomi/bilde.ts`: skill `styringskost` (BP-nivå) fra
`ovrigLonnKr`. `styringsavvik` regnes av styringskosten.

### Trinn 3 — tre tilstander i flaten (beslutning B)

Datagrunnlagsmerket fra 4.10, og «Øvrige lønnskostnader» som egen linje.

### Trinn 4 — import og lagring

Opplastingsvei for Basis Export, og `stempling`-tabellen som lagringssted.

### Trinn 5 — senere

Overtid via vaktplanen (3.6). Aftener som mangler måling (3.7).

---

## 10. Fortsatt uavklart

1. **BP-tallene selv er ikke målt.** 7.7 bygger på kodens dokumentasjon av
   `BP_TIL_REGNSKAP` og på regnskapsfilas budsjettkolonne. De faktiske BP-linjene ligger i
   basen. Skal romnivået måles eksakt, trengs en read-only SQL-sonde mot `bp_linje`.
2. **August-regnskapet (202608) finnes ikke lokalt.** Med det kunne de to
   august-stasjonsmånedene også måles mot bokførte tall — og august har mest overtid.
3. **Kan de tre andre stasjonene få Lønnsoversikt-tilgang?** Uten kronefil kan utdaterte
   satser ikke oppdages på Lone, Varden og Laguneparken.
4. **Hvem klassifiserer fastlønnede,** og hvor lagres det? Trinn 1 tar imot
   klassifiseringen som inndata; den må få et hjem i trinn 4.
5. **`pensjonKr` og kommentarparet** i `easyatwork.ts:212-217` bør ryddes. Ikke hastverk —
   koden gjør det riktige.
