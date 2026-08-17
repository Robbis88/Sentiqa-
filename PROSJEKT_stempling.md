# Stempling på nettbrettet

Design, ikke kode. Skrevet 2026-08-17.

## Problemet

`stempling` skrives i dag av importen alene — Basis Export fra easy@work,
lest av `src/lib/import/kjerne.ts`. Kelsar skal av easy@work. Da stopper
tilførselen, og lønnsfila står uten grunnlag.

Én ting skal erstattes, men den henger sammen med tre andre: identiteten,
korreksjonene og overgangen.

## Det som binder designet

**Løftet i «Slik måler vi».** Siden sier at vi ikke har GPS, ikke kamera, og
ikke registrerer hvor folk er utenom jobb. Det utelukker geofencing og
bildeverifisering — de vanlige svarene på juks med stempling. Løsningen må
ligge innenfor det som allerede er lovet de ansatte.

**Stemplingen blir regnskapsdokumentasjon.** I dag er den en rapport fra et
annet system. Etterpå er den *kilden* til lønn, og bokføringslovens krav om
sporbarhet slår inn: en rettet stempling må vise hva som sto der før, hvem
som endret den, og når.

**Sentiqa er et SaaS-produkt.** Kelsar er første kunde, ikke den eneste.
Driftsregler som varierer mellom kjeder skal være konfigurasjon med en
forsvarlig standard — ikke innebygde antakelser.

## Modellen: hendelser, ikke vakter

Dagens `stempling` er vaktformet (`fra_tid`, `til_tid`, `minutter`). Riktig
for en ferdig vakt, umulig som kilde: sluttiden finnes ikke når hun stempler
inn.

Ny tabell med **hendelser** — ansatt, stasjon, tidspunkt, type (`inn`/`ut`),
kilde. `stempling` blir avledet av dem.

Alt som er bygget leser fortsatt `stempling` og merker ingenting: lønnsfila,
bemanningsplanen, innsynsutskriften, plan-mot-faktisk.

Korreksjoner får da en naturlig form. Du retter ikke en vakt — du legger til
eller endrer en hendelse, og vakten regnes på nytt. Originalen blir stående,
og endringen logges i `persondata_logg`.

## Identiteten

**Ansattnummeret blir nøkkelen**, ikke `ansatte.id`. Det kobler nettbrettet
til lønn, og to av de tre identitetene (se `sentiqa-tre-identiteter`) smelter
sammen. Sømmen som i dag tvinger innsynsutskriften til å merke halvparten av
opplysningene som usikre, forsvinner.

Nummeret skal være **lønnsbyråets**, ikke et lokalt stemplingsnummer. Det var
nettopp forskjellen — 11058 mot 1058 — som gjorde maiavstemmingen vanskelig.

Nummeret behandles som en **ugjennomsiktig streng**. Ingen antakelse om seks
siffer: neste kunde bruker et annet byrå med et annet format.

**PIN kreves, og kan ikke skrus av.** Ansattnummeret står på lønnsslippen, på
vaktlista og i alle systemer — det er ikke en hemmelighet. Er det også PIN-en,
kan hvem som helst stemple inn hvem som helst, og det er den klassiske
svindelen med stemplingsur. Nummeret identifiserer, PIN-en beviser.

Dette er med vilje ikke en innstilling. Et produkt skal ikke tilby kunden å
skru av det som beskytter lønnsgrunnlaget, når konsekvensen rammer en ansatt
som ikke var med på valget.

## Hva som er innstilling, og hva som ikke er det

Skillet: **det som varierer med drift og kultur blir konfigurasjon; det som
beskytter lønnsgrunnlaget eller de ansatte gjør det ikke.**

| Innstilling på `retailers` | Standard | Hvorfor den varierer |
|---|---|---|
| Pauseregel | alt betalt | Med én til to på jobb kan folk sjelden forlate stasjonen, og da er pausen arbeidstid etter aml. § 10-9. Større enheter har andre ordninger. |
| Vis hvem som er stemplet inn | på | Kulturvalg. Gir sosial kontroll, men noen kjeder vil ikke ha det. |

Ikke innstilling: PIN-krav, sporbare korreksjoner, at åpne vakter blokkerer
lønnsfila.

## De vonde tilfellene

Her råtner slike systemer. Avgjort nå, ikke senere.

**Glemt utstempling** er den vanligste. Vi gjetter ikke sluttiden — en
automatisk lukking som treffer feil er verre enn ingen, fordi ingen oppdager
den. Vakten står åpen, dukker opp på butikksjefens liste neste morgen, og
**lønnsfila lages ikke før den er lukket.** Samme mønster som lønnsform
(`src/lib/lonn/lonnsform.ts`), og det virker: én blokkering folk må rydde i,
framfor et stille feilaktig tall.

**Feil stasjon** løser seg nesten av seg selv — nettbrettet vet hvor det står.
Trenger likevel en rettevei, siden folk jobber på tvers i clusteret.

**Over midnatt** er allerede løst. `src/lib/lonn/tidsband.ts` lar
forretningsdatoen følge starten, og det er testet.

**Nettet faller.** Stemplingen skal feile **høyt** — stor rød skjerm, «dette
ble ikke registrert, si fra til butikksjefen» — og rettes manuelt. Ingen lokal
kø i første omgang: en stille kø som synkroniserer feil er verre enn en synlig
feil, og vi vet ennå ikke om nettet faktisk svikter. Bygg køen hvis det svir.

**Korreksjoner** logges alltid, med gammel verdi.

## Overgangen fra easy@work

Ny kolonne `kilde` på stemplingene: `import` eller `tablet`. Da kan én stasjon
gå over mens de andre står, uten at noe telles to ganger — og lønnsfila viser
hvilken kilde hver time kom fra mens dere kjører parallelt.

**Én stasjon, én måned, begge kilder, avstemt mot hverandre før neste.**
Nøyaktig slik de 27 prosentene på Bønes ble funnet.

## SaaS-gjeld dette avdekker

Ikke i veien for stemplingen, men verdt å vite før kunde nummer to:

- **Lønnsartkodene** (`2`, `1410`, `1429` …) i `src/lib/lonn/tidsband.ts` er
  Azets/Visma-koder, hentet fra Kelsars egne filer. Et annet byrå bruker andre.
- **Tariffsatsene** i `src/lib/lonn/tariff.ts` er Energiavtalen. En
  dagligvarekjede ligger på Landsoverenskomsten.
- **Filformatet** i `src/lib/lonn/vismafil.ts` er ett byrås format.

Alle tre er i dag konstanter. De må bli data per kjede før produktet selges
til noen som ikke er på Energiavtalen med Azets.

## Åpne spørsmål

- Kelsars egne verdier for pauseregel og synlighet — settes i grensesnittet.
- Hvilken stasjon går først i parallellkjøringen.
- Fastlønnede og lønnsart 1410 på røde dager — spørsmål til Azets.
