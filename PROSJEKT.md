# Sentiqa — PROSJEKT.md

**Sentiqa — Fornemmer. Forstår. Forutser.**
Et multi-tenant SaaS-system for drift, analyse og AI-assistanse for bensinstasjons-eiere (retailere).
Domene: sentiqa.ai (primær), sentiqa.no (sikret).

Dette dokumentet er marsjordren for å bygge Sentiqa fra bunnen av. Det bygger på et fungerende single-tenant forgjenger-system (Driftsassistent, 5 St1-stasjoner i daglig drift), men ingen gammel kode skal gjenbrukes — forgjengeren beskriver kun funksjonell fasit. Bygg nytt og rent.

Mål: 50 retailere, ~250 stasjoner, ~500 brukere. Det skal virke smertefritt, og se merkbart mer profesjonelt ut enn forgjengeren.

---

## 1. Hva Sentiqa er — og hvorfor

Sentiqa tar inn rapportene en stasjonseier allerede eksporterer (St1/Salesgrid/Visma), tolker dem automatisk, og gir eieren svar i stedet for dashboards å lete i. Verdien ligger ikke i modulene — den ligger i at AI-en kan svare på spørsmål om driften.

**Nordstjerne — de tre spørsmålene produktet skal kunne svare på:**

- «Hvorfor falt salget av pølser 12 % i Bergen i går?» — forklarer fortid (sammenligner fjorår + slår opp vær + sjekker kampanje + arrangement).
- «Hvordan påvirker varslet regnvær neste uke salget vårt?» — forutser (vær-sensitivitet per varegruppe mot værvarsel).
- «Hvor mye baguetter bør vi produsere på fredag?» — handler (produksjonsplan-motor).

Alle tre er dekket av arkitekturen under. Vi trenger ikke finne opp nytt — vi må bygge kjernen riktig.

**Prinsipp om omfang:** forgjengeren var overbygget (40+ moduler). Sentiqa bygger en lean kjerne først, og legger resten som valgbare moduler. Kjernen er: datainntak, svinn, salg/regnskap-dashboard, og AI-assistenten.

## 2. Arkitektur — dataens reise

Systemet tenkes som dataens reise gjennom seks ledd. Det bærende prinsippet: **Vercel håndterer kun raske web-forespørsler. Alt tungt — import og analyse — kjører på egne arbeidere.** Det er skillet som gjør systemet pålitelig.

1. **Inntak.** E-post per tenant + manuell drop-zone som reserve. Rå filer lander i object storage. Ingen parsing her — bare mottak, så det er lynraskt.
2. **Prosessering (kø).** Bakgrunnsarbeidere utenfor Vercel plukker jobber, parser, upserter idempotent. Status synlig (mottatt → parset → feilet, med retry). Anbefalt: Inngest eller Trigger.dev (ferdig retry + status), eller egen worker på Railway/Render/Fly.io.
3. **Datalag.** Postgres (Supabase). Delt skjema med `retailer_id` på hver rad + RLS. Daglig salg partisjonert på måned. Soft-delete (`slettet_tid`) overalt. Tilkoblinger via Supabase-pooler.
4. **Analyselag.** Nattlige forhåndsaggregeringer (vær-buckets, korrelasjoner, trender, produksjonsplan-baseliner). Dashboards leser ferdige tall, aldri rådata på direkten.
5. **AI-lag.** Tool-loop-orkestrator. Modell-ruting, prompt-caching, token-måling per tenant, `ai_tool_log` med PII-redaksjon, rollebevisste systemprompter.
6. **App-lag.** Next.js App Router, Server Components default, server actions. Rollestyrt UI. White-label per tenant.

Tverrgående: Supabase Auth, Stripe (billing), Sentry (feilsporing), web-push/SMS/e-post (varsler), all tidsvisning tvunget til Europe/Oslo. UI på norsk bokmål, men forbered i18n for tablet (ikke-norsktalende ansatte).

## 3. Multi-tenancy — det viktigste kravet

Modell: **delt skjema med `retailer_id` + Row Level Security (RLS)**. Ikke database-per-tenant — det er en operasjonell felle på 50 tenants (migrasjoner ×50, overvåking ×50, kostnad ×50). RLS gir reell, vanntett logisk adskillelse når den er gjort riktig, og er industristandard. Fysisk isolasjon kan tilbys som dyr enterprise-tier senere hvis en stor kunde krever det — men bygg ikke den vanskeligste varianten først.

**Salgsløftet:** ingen ser på tvers av tenanter — heller ikke vi som drifter. Det skal ikke finnes én skjerm som viser flere tenanters tall.

### Roller

| Rolle | Tilgang |
|---|---|
| **Retailer-admin / eier** | Alle sine stasjoner, alle kostnader, alle moduler. Ser alt innenfor egen tenant. |
| **Butikksjef** | Stasjonene admin har gitt. Ser kun konfigurert utvalg av regnskapskoder. Får AI om egne stasjoner. |
| **Butikkbruker (tablet)** | Delt stasjonskonto. Kun publisert innhold for egen stasjon. Ingen AI-tilgang. |
| **Kunde** | (Ikke i kjernen — klikk-og-hent er ikke med. Se §10.) |
| **Plattform-redaktør (du)** | Over tenant-nivå. Kan publisere felles innhold nedover (IK-mat-maler, monteringsanvisninger, kunnskap) til alle. Kan aldri lese en retailers forretningsdata. Strengt enveis. All publisering logges. |

**Datasikkerhet i tre lag:** (1) RLS i Postgres, (2) app-laget bruker alltid innlogget brukers stasjon — stoler aldri på klient-input for stasjonsvalg, (3) AI-systemprompt håndhever kostnad-/tall-skjul.

**Konfigurerbart per tenant:** Avdelings-/kostnadskoder, hvilke koder hver butikksjef ser, KPI-definisjoner, branding (white-label), antall stasjoner, stasjonstyper, svinnterskler. Forgjengeren hadde dette hardkodet — i Sentiqa er det tenant-konfig.

## 4. Prismodell

**Pris per stasjon, ikke per hode.** Begrunnelse: per-hode skattlegger din egen stickiest flate (tablet), kan games (én innlogging for mange stasjoner), og matcher ikke kostnadsgrunnlaget (AI-kostnaden er per stasjon).

- **499 kr/mnd per cluster (retailer)** — konto, onboarding, support, AI-grunnkvote.
- **249 kr/mnd per stasjon** — inkluderer stasjonens butikksjef-tilgang, dens tablet, og AI-kvote. Dekker kjernen (import, svinn, salg, regnskap, AI).
- **AI utover kvote** — målt og fakturert, eller ekstra AI-pakke.
- **Premium-moduler** som tillegg (Avtalevokter, gamification, m.m.).

Eksempel (snitt-cluster, 5 stasjoner): 499 + 5×249 = 1 744 kr/mnd. COGS ~400 kr (AI ~275 + infra ~125) → ~77 % bruttomargin. Sunn SaaS-økonomi — fordi AI-en er optimalisert (se §9).

Gi rabatt ved årlig forskudd, og volumrabatt for store kjeder (20+ stasjoner forhandler uansett).

Kvote: inkludert AI-kvote ≈ 70 kr (~$6) bruk per stasjon/mnd dekker en normalt aktiv stasjon. Mål token-forbruk per tenant fra dag én; juster kvoten etter pilot-data.

## 5. Auth, onboarding og billing

**Auth (Supabase Auth):**

- Retailer-admin og butikksjef: ekte personlige kontoer — e-post + passord, glemt-passord på e-post, sterke passordkrav, 2FA påkrevd/tilbudt på admin og butikksjef.
- Butikksjef opprettes via invitasjon på e-post og setter sitt eget passord første gang (admin kjenner aldri passordet).
- Tablet: stasjonskonto med PIN/kode, ikke e-post (delt skjerm, ingen innboks). Butikksjef nullstiller direkte fra egen innlogging.
- Invitasjoner bærer med seg tenant + hvilke stasjoner + hvilke regnskapskoder brukeren ser.

**Onboarding (selvbetjent):**

1. Retailer registrerer seg → oppretter tenant.
2. Legger inn stasjoner: butikknummer (4-sifret) + navn per stasjon, samt stasjonstype (se §8).
3. Setter svinnterskel per stasjon (Sentiqa foreslår fra historikk).
4. Kobler på e-post-inntak (sett opp videresending fra St1/Visma én gang).
5. Laster opp historikk: mål 14 måneder (se §7).
6. Inviterer butikksjefer, velger stasjoner + synlige regnskapskoder per butikksjef.

**Billing (Stripe):** abonnement per cluster, stasjoner som mengde, AI-overforbruk som målt komponent. 14 dagers prøve → kort → aktiv. Opp/nedgrader ved å legge til/fjerne stasjoner.

**Å AVKLARE:** plattform-nødluke for innlogging — skal du kunne utløse tilbakestilling for en låst retailer? Hvis ja: snever, logget nødluke. Hvis nei: ren selvbetjening.

## 6. Datainntak

Systemet lever av filer retaileren allerede eksporterer.

**E-post-inntak (primær)**

- Egen adresse per tenant (f.eks. `retailer@inn.sentiqa.ai`).
- Avsender-allowlist — kun forhåndsgodkjente avsendere slipper gjennom.
- Vedlegg → object storage → kø. 200 filer/dag er trivielt for mottaket (kommer som mange små e-poster, ikke én). NB: sjekk leverandørens tak på samlet vedleggsstørrelse per melding.
- Manuell drop-zone finnes som reserve.

**Filtyper (St1-tilfellet — parserne må være konfigurerbare for andre kjeder)**

| Rapport | Frekvens | Brukes til |
|---|---|---|
| Visma Resultatrapport | Månedlig | Regnskap, BRF, usynlig svinn, auto-fokus |
| St1 Salgsstatistikk (produktnivå) | Daglig | Daglig salg, produksjonsplan, lavselgere, analyse |
| St1 0758 SalesPerHour | Daglig | Salg pr time, heatmap, bemanning |
| St1 0018 CashierStatistics | Daglig | Kassererstatistikk |
| Salesgrid Varetransaksjonsliste | Daglig | Kasse-svinn (synlig) |

**Importlogikk (kritisk)**

- **Stasjons-matching:** primært på 4-sifret butikknummer, med navn som bekreftelse. Filer er merket «St1 Bønes» / «real Bønes». Stemmer nummer men ikke navn → varsel. Finner verken → avvis + flagg (gjett aldri).
- **Idempotent upsert** per nøkkel: `retailer_id + butikknummer + dato + vare/kode`. Re-opplasting overskriver (ikke hopper over — en ny versjon kan være en korreksjon). Ingen dubletter, uansett hvor mange ganger samme dag lastes opp.
- **Duplikat-deteksjon:** flagg (ikke slett) en dag hvis omsetning > 2× medianen for samme ukedag (tegn på dobbel/sammenslått eksport). Hold bilvask utenfor (værvariasjon).
- **Synlig import-status:** dashboard «mottatt / parset / feilet» per fil + varsel ved feil. En stille feil = en stasjon med manglende tall.

**Historikk-import (onboarding)**

- Mål 14 mnd (12 for fjorår-sammenligning + 2 for trend/sesong-overlapp fra dag én).
- Gradert verdi: fungerer med det det får, bedre ved fjorår, full kraft ved 14 mnd. Vis datadybde-måler som gulrot.
- Bulk via samme kø som daglig drift — tåler flere ivrige retailere samtidig (se §14).
- Onboarding-tekst: «Last opp så mye historikk du har, helst 14 måneder. Jo mer, jo smartere er Sentiqa fra start.»

**Å AVKLARE:** er St1-butikknumre globalt unike, eller bare innenfor en eier? (Påvirker om nummeret alene holder som nøkkel — vi binder uansett til `retailer_id` for sikkerhets skyld.)

## 7. Analyselag — den smarte motoren

Dette er det som gjør Sentiqa «jævli bra» i stedet for generisk. Bygges som eget lag som mater dashboards, produksjonsplan og AI. Tunge beregninger kjøres nattlig; ferske værvarsler hentes ved behov.

### Stasjonstype — hver stasjon får sin personlighet

Avgjørende fordi samme vær gir motsatt effekt på ulike stasjoner (solrik fredag før langhelg: utfart eksploderer, pendler dør). Admin setter type ved onboarding; dataene bekrefter/korrigerer over tid (Sentiqa foreslår korreksjon, bytter aldri i det stille).

Fem typer, hver med forklarende undertekst i onboarding:

- **Utfart** — lever av folk på vei til hytte/tur. Eksploderer solrike fredager + før langhelger, stille midt i uka.
- **Pendler** — to rush morgen/ettermiddag på hverdager, rolig i helgene.
- **Bydel/lokal** — fast lokal kundekrets, jevn handel, lite væravhengig.
- **Gjennomfart/hovedvei** — forbipasserende trafikk, drevet av trafikkmengde + bensinpris mer enn lokale folk.
- **Sentrum** — bytrafikk, gåved, kveldshandel, arrangement/uteliv.

Velg én primær + valgfri sekundær (virkeligheten er ofte miks). Undertekst: «Velg det som ligner mest — Sentiqa lærer det faktiske mønsteret fra salgsdataene dine og justerer over tid.»

**Å AVKLARE:** stemmer disse fem med virkeligheten, eller skal «pendler» ut / en kategori legges til?

### De dype analysene

- **Vær-sensitivitet per stasjon** — daglig omsetning i temp-buckets (<0/0–10/10–20/>20°) og nedbør-buckets (tørt/0–5/5–15/>15mm), median per bucket → værsensitivitet-score (0–100). Sammenlign mot manuelt satt innstilling, anbefal riktig. Finn toppdag varme + toppdag regn.
- **Ukedagsjustert vær-korrelasjon** — trekk fra ukedag-snitt (residual), Pearson-korrelasjon temp↔residual og nedbør↔residual, kun hverdager, kun MAT. Tekstlig tolkning. Krev ≥~30 datapunkter.
- **Dagstype-analyse** — hverdag/helg/langhelg/skoleferie/helligdag (helligdager dynamisk), snitt + avvik mot hverdag, per stasjon (langhelg = topp på utfart, bunn på pendler).
- **Skoleferie-effekt** — snitt per ferietype vs normaluker.
- **Varegruppe-vær-sensitivitet (180 dager)** — varme (≥18° = «badevær», terskel-effekt) vs kald (<5°) → varmeeffekt %; regn (≥5mm) vs tørt → regneffekt %. Rangér varegrupper.
- **Trendanalyse** — siste 4 uker vs samme periode i fjor, per vare, %-endring, retning. Topp 50 endringer.
- **Produksjonsplan-motor** — se under.
- **Duplikat-deteksjon** — som §6.
- **Bensinpris-indeks** — pris per produkt vs 30-dagers snitt (lav/normal/høy). Høy pris demper diskresjonær trafikk → trafikkdemper på forslag + AI-kontekst.

Alle tåler store datamengder (paginer mot DB) og krever minimum datapunkter før de svarer.

### Produksjonsplan-motor (skal være «jævli bra»)

For en gitt dag på en gitt stasjon, vekt sammen:

- **Baseline:** median samme ukedag ±2 uker (eller samme helligdag i fjor).
- **Trend:** siste 28 dager mot i fjor.
- **Vær**, via stasjonens egen målte følsomhet (ikke «det er varmt», men «denne stasjonen +22 % kald drikke ved badevær»). Terskel-effekter, ikke glidende.
- **Dagstype** med multiplikator per stasjon.
- **Utfartseffekt:** avreisedager (fredag før langhelg, påske-/fellesferiestart) egen vekt, fortegn avhenger av stasjonstype.
- **Bensinpris** som trafikkdemper.
- **Arrangementer** knyttet til stasjon.

Natt vs sanntid: natten lærer hvordan stasjonen reagerer på vær (tungt, endrer seg ikke time for time). Morgenen henter morgendagens ferske varsel og bruker den lærte følsomheten. Rask + oppdatert.

Treffsikkerhet: etter publisering, mål plan og AI-forslag mot faktisk salg (median absolutt %-feil). Motoren blir bedre per uke; butikksjef ser at den traff.

### Utsolgt-håndtering (viktig — unngår ond sirkel)

Problem: en 0 fordi stasjonen var tom ≠ etterspørsel 0. Behandles den som ekte salg, dras snittet ned → planen foreslår færre → ny utsolgt. Verst på høyselgere.

Løsning (tablet-markering finnes IKKE her — nettbutikkens data skal ikke inn):

- **Mønster-deteksjon:** stabilt salg → en/flere 0-dager → tilbake til normalt (ofte etterslep-topp).
- **Spør, ikke gjett:** Sentiqa spør butikksjefen — «Baguett solgte 0 tre dager på rad, men ligger normalt på 8 — var dere utsolgt?» Ja → ut av baseline. Nei → ekte nullsalg.
- **Kun høyselgere:** terskel snitt ≥ ~2–3/dag. Smale varer (0 = bare tirsdag) utløser aldri spørsmål.
- **Etter bekreftet ja:** ut av baseline + trend, og estimer tapt salg i antall + kroner («3 dager utsolgt ≈ 24 tapte ≈ 600 kr»). Synlig og overstyrbar.

## 8. AI-assistenten — hjertet i Sentiqa

Claude-drevet. Svarer på vanlig norsk med tall fra retailerens egne data.

**Grunnkontrakt**

- Fri til å svare på alt den har tilgang til — oppslag («hvor mye pølser solgte vi for 3 dager siden»), prediksjon («hva selger vi neste uke»), forklaring («hvorfor falt salget»).
- **Aldri finn på et tall** — slå det opp via verktøy. Kan den ikke slå det opp: si det ærlig. Ett oppdiktet tall ødelegger tilliten til alle de riktige.
- **Tilgang = grensen:**
  - Mellom retailere: hard mur (RLS — AI-en når ikke engang dataene).
  - Innad i retailer: eier ser alt; butikksjef spør om egne stasjoner. Aldri andre stasjoners eksakte tall til butikksjef. Relativ plassering er lov («nr. 3 av 5 på svinn»), eksakte tall ikke («Varden hadde 1,2 %»).
- **«Vis kildene»:** AI-en viser hvilke verktøy den kjørte før svaret (fjorår, vær, kampanje, arrangement). Dette er tillitsmekanismen — ikke pynt.
- **Tone:** oppsummer i 2–4 setninger med konkrete tiltak («sjekk vaktplan man–ons», ikke «vurder bemanning»). Kort output = lavere kostnad.

**Arkitektur**

Tool-loop (opptil ~12 iterasjoner). Rik kontekst injiseres per melding (rolle, stasjon, siste regnskapsmåned, KPI vs budsjett, aktiv konkurranse, aktive fokuspunkter, relevante kunnskapsartikler). Systemprompt bygges per rolle. Alle tool-kall → `ai_tool_log` (PII-redaksjon).

**Fire AI-bruksområder**

- **A) Chatbot** — samtalen over. Verktøy: les (produksjonsplan, svinn-oversikt, lavselgere, liga/konkurranse-status, smart-tips, dyp analyse, arrangementer, drivstoffpris, historisk vær, sammenlign-perioder, produkt-salg) + handling (opprett oppgave, lagre fokuspunkt, publiser produksjonsplan, send melding til stasjon, opprett_konkurranse, kår_vinner). To-stegs bekreftelse for irreversible handlinger («VENTER PÅ BEKREFTELSE: …» → bruker bekrefter → kall igjen med bekreftet: true).
- **B) Auto-fokus etter regnskap** — 6 fokuspunkter per stasjon til butikksjef (3 forbedring + 3 positivt), konkrete tall.
- **C) Regnskaps-analyse for eier** — strukturert JSON: sammendrag, per-stasjon grønn/gul/rød, røde flagg, muligheter, prioriterte tiltak, endringer vs forrige.
- **D) Lederstøtte-rapport** — utviklingsorientert, coaching-tone (grønn/gul/blå, aldri rød/«dårlig»).

**Modell-ruting og kostnad (kritisk for margin)**

- Chatbot → **Sonnet** (ikke Opus — henter tall + oppsummerer, krever ikke Opus-kvalitet).
- Tung eier-regnskapsanalyse → **Opus** (der kvalitet teller).
- **Batch-API (50 % rabatt)** → alt ikke-sanntid (auto-fokus, regnskapsanalyse, ukerapport, lederstøtte — nattlig).
- **Prompt-caching** på systemprompt + kontekst (chatboten re-sender samme store prompt hver iterasjon — perfekt cache-kandidat).
- Token-måling per tenant med kvote (`ai_tool_log`-mønster).

Uoptimalisert (alt på Opus) ≈ 130 kr/stasjon/mnd — dreper margin. Optimalisert ≈ 50–60 kr/stasjon/mnd. Den dominerende kostnaden er chatboten; alt annet er avrundingsfeil.

## 9. Moduler — fordelt på pris-tiers

Kjernen er alltid på. Tillegg og meningsdelte funksjoner er valgbare (se §13 toggles).

- **Kjerne (analytisk + AI):** daglig salg, salg pr time, kassererstatistikk, dyp analyse, svinn, regnskap pr stasjon, retailer-regnskap, drivstoffpris, produksjonsplan, arrangementer. («Sammenligning» er ikke egen skjerm — AI-en absorberer den.)
- **Drift (tablet/operasjonelt):** IK-mat, rutiner (butikksjef), rutine-historikk/rangering, sjekkpunkt-tablet, opplæring, monteringsanvisning.
- **Engasjement:** skills, pengepremier, puls, tilbakemeldinger, forslag butikksjef, konkurranser (AI-drevet).
- **Premium-tillegg:** Avtalevokter, gamification.
- **Tverrgående infrastruktur:** push-varsler, kunnskap, vær (datakilde).
- **Ikke med i Sentiqa (kuttet fra forgjengeren):** klikk-og-hent, chat, innkjøp, varetelling, BP-utlegg, tilstedeværelse, driftliga (erstattet av AI-konkurranser), vikariater.

## 10. Tablet — uendret og bevisst enkel

Tableten er dum med vilje: store knapper, rutineskjema, IK-mat, oppgaver, kryss av, ta bilde. Ingen AI, ingen analyser, ingen valg. Auto-refresh. Arver fargene fra designsystemet, men ikke tettheten — egen lyssterk variant. Behold den slik den er i forgjengeren. Touch-targets ≥ 44×44 px. Språkhint for ikke-norsktalende.

## 11. Detaljerte modul-spesifikasjoner (nytt for Sentiqa)

### Avtalevokter (premium-tillegg)

Dra inn fakturaer (PDF/bilde, vision-parsing) → AI bygger forbruksprofil per leverandør på tvers av stasjoner (mobil: linjer/dataforbruk/ubrukte linjer; renovasjon: hentinger/størrelse/frekvens; strøm: profil).

- Sammenlign på tvers av egne stasjoner (betaler Bønes 40 % mer enn Varden for renovasjon?).
- Prisøknings-deteksjon → varsel + foreslår forhandlings-utkast automatisk.
- Forhandlings-e-post: AI fyller ut utkast med dine faktiske tall (særlig total årlig spend = kjøpekraften — en 8-stasjoners retailer forhandler som én samlet konto). Du sender, aldri AI-en (menneske-i-loopen).
- Ikke «best i markedet» (AI har ingen markeds-fasit → hallusinasjon). Ikke benchmark mot andre retailere (bryter dataadskillelse).
- Vanskeligst: pålitelig faktura-parsing på tvers av formater (valideres, som andre parsere). E-post-skriving er trivielt.

### Sjekkpunkt-tablet (drift)

Tidsstyrte ja/nei-sjekkpunkter på tablet («Er diskene fulle?» kl. 08:00).

- Faste klokkeslett, daglig gjentakelse.
- Står fremme til noen svarer (ingen auto-utløp).
- Rent ja/nei (ingen forklaring).
- Sendes til valgte stasjoner eller «alle».
- Eier/butikksjef ser svarene.
- Vurder ved bygging: push til butikksjef ved «Nei» på kritiske punkter. Hold separat fra rutineskjema (utløses av klokkeslett, ikke vakttype).

### AI-drevne konkurranser (engasjement)

Samtalestyrt: «Lag en konkurranse på pølsevekst neste uke, 1000 kr til vinneren.»

- Nye verktøy: `opprett_konkurranse` (KPI, stasjoner, periode, premie), `kår_vinner`.
- Måling gjenbruker analyselaget (daglig salg + sammenlign-perioder) — AI gjetter ikke.
- To-stegs bekreftelse (premie = penger på spill).
- Premie kobles til pengepremier-modulen.
- Daglig status-push til tablet («dag 3: Varden leder +18 %») — motoren som driver atferd.
- Kåring foreslår utbetaling. Alltid innenfor tenant-grensen (RLS).

### Svinnterskel + før/etter (kjerne)

- Konfigurerbar terskel i % av matsalg per stasjon. Sentiqa foreslår fra historikk («snitt 2,4 %, foreslått grense 2,8 %»). Per stasjon fordi utfart ≠ bydel.
- Måles mot rullende periode (uke/måned), ikke dag (unngå støy-flagg).
- Flagg ved overskridelse (coaching-tone: «verdt et blikk», ikke anklage). Positiv bekreftelse ved milepæl («lavt svinn 3 uker på rad»), ikke hver dag.
- Mater dashboard (grønn/gul/rød), AI, og auto-fokus.
- Før/etter-graf: trend med «tatt i bruk»-markør + fjorår-sammenligning i samme graf (ærlig bevis — skiller reell forbedring fra sesong). Nivå + retning side om side.
- Synlig svinn på tvers av ALLE kategorier (mat fremhevet, men tobakk/drikke/kiosk med), målt som % av brutto per kategori. Tydelig skilt fra usynlig svinn (fra regnskap, mest mat/tobakk) — summeres aldri sammen.

### Rutineskjema (drift) — tonivå-hierarki

- **Retailer → butikksjef:** retailer lager skjema for butikksjefer. Finnes ingen → vises ingenting (ingen tom skjerm).
- **Butikksjef → tablet:** butikksjef lager skjema for egen stasjons tablet.
- Per skjema: flere konfigurerbare vakter/dag (morgen/midt/kveld/natt), hver med tidsvindu (fra–til) + dager + 1t overlapp før/etter.
- Per rutine: tittel (hva skal gjøres), valgfritt/påkrevd bildebevis, egne dager (kan kun snevre inn innenfor vaktens dager), ?-knapp med utfyllende forklaring (kobles til språkhint for ikke-norsktalende).
- Gjennomføringssporing: streak + rangering på tvers av stasjoner (motoren som får folk til å krysse av).
- **Å AVKLARE:** (1) bekreftet at rutinens dager kun snevrer inn vaktens? (2) rutine fullført i overlapp-time krediteres sin egen vakt (ikke den som gjorde den)?

### Opplæring (drift) — eget tidsbegrenset domene

- Kun synlig på tablet i opplæringsperioden for en ny ansatt.
- Butikksjef planlegger dager + klokkeslett over flere dager (plan over dager, ikke ukentlig syklus).
- Knyttet til personen (ny ansatt), ikke stasjonen.
- Ansvarlig per punkt/skift. Framdriftsoversikt («Sara 6 av 9 punkter, mangler varetelling + avvik»).
- **Å AVKLARE:** hvem bekrefter et lært punkt — den ansvarlige (anbefalt, mer pålitelig), den nye selv, eller begge?

### PIN-logging av ansatte (drift, valgfri per stasjon)

- Lett ansatt-identifisering oppå den delte tablet-kontoen: butikksjef oppretter ansatte (navn + 4-sifret PIN). Ved rutine-utførelse taster ansatt PIN → navn logges. Flere på vakt → begge kan registrere.
- PIN = identifisering, ikke bevis. Bygg og ramm inn som positivt prestasjons-/gamification-verktøy (hvem er god), aldri overvåkning/kontroll (hvem er dårlig — kan bestrides, skader kultur).
- Av som standard, toggle per stasjon (ikke alle butikksjefer trenger det).
- Butikksjef nullstiller PIN. Ansatt slutter → historikk beholdes, PIN deaktiveres.
- Persondata → under personvern-kapittelet (§15).

## 12. Designretning

Referanse: **Microsoft Power Apps / Fluent 2** — lyst, tett, verktøy-aktig. Brukerne skal jobbe i dette 8 timer, ikke beundre det i 10 sekunder. «Proft» = ligner verktøyene de stoler på (Business Central, Dynamics), ikke en mørk konsument-app.

- Lys grå bakgrunn, hvite kort med fin skygge («floating»/depth). Tett, mye info synlig samtidig.
- Venstremeny med tekst + ikon, gruppert i seksjoner. Kommandolinje på toppen (handlinger).
- Stasjoner som datatabell med statuskolonner (grønn/gul/rød-pip).
- Segoe UI (matcher Fluent bevisst — her overstyrer referansen «vær distinkt»).
- Sentiqa-gradient (cyan→blå→lilla) kun som brand-aksent (logo, primærknapp, statuspip) — ikke flate fargeflater.
- «Vis kildene»-mønster gjennomgående: hver modul leder med hva som krever oppmerksomhet, AI viser hva den sjekket.
- Dashboard-oppbygging: øverst «Trenger oppmerksomhet» (det Sentiqa fant) → nøkkeltall → stasjoner side om side → AI alltid tilgjengelig nederst. Rekkefølge styrt av hastverk, ikke modul-liste. Hver modul får sin variant av samme mønster.
- Logo: bygges om som ren SVG/vektor med ekte font før produksjon (nåværende er AI-generert med skavanker).

Mockups laget i samtalen: `sentiqa-fluent.html` (godkjent retning), `sentiqa-mockup.html` + `sentiqa-dashboard.html` (mørke, forkastet).

## 13. Funksjons-toggles

Unngå overbygging uten å lage en jungel av brytere:

- Kjernen alltid på (import, salg, svinn, regnskap, AI) — det er produktet.
- Retailer-valg: kjede-brede/kjøpte moduler (gamification på/av, Avtalevokter kjøpt).
- Stasjons-/butikksjef-valg: lokale ting (PIN-logging, hvilke rutiner kjører).
- Koblet til pris-tiers: kjøpt = kan aktiveres; ikke kjøpt = vises ikke.
- Regel: kun tillegg og meningsdelte funksjoner er valgfrie — ikke alt, ellers flyttes kompleksiteten til innstillingssiden.

## 14. Driftssikkerhet og skala

500 brukere er ikke et skaleringsproblem — det er liten/mellomstor B2B-SaaS. Postgres/Supabase/Vercel håndterer det lett. Ingen microservices, ingen Kubernetes. «Smertefritt» = disiplin på de få stedene som faktisk kan ryke (filer + bakgrunnsjobber), ikke eksotisk infrastruktur.

**Prinsipper:**

- Skill servering fra tungarbeid (Vercel = klikk; arbeidere = import/analyse).
- Forhåndsaggreger nattlig (dashboards leser ferdige tall). Partisjoner daglig salg på måned. Tilkoblinger via pooler.
- Alt idempotent (kjør hva som helst om igjen uten skade).

**Kø under press** (flere retailere laster opp 14 mnd samtidig): kø ≠ dør. Opplasting er lett (bare mottak). Køen holder rekken uansett om det er 50 eller 5000 jobber. Arbeidere tar unna i kontrollert tempo med samtidighetstak + auto-retry. Verste tilfelle = importen tar lengre tid, ikke krasj. Skaler arbeidere midlertidig opp ved bulk. Synlig framdriftsmåler per retailer («147 av 420 filer behandlet»).

**Feilmodi og forsvar:**

- Fil feiler stille → import-status-dashboard + varsel.
- Vær-API/AI nede → graceful degradation (appen funker uten den ene funksjonen).
- Kode-feil i produksjon → Sentry + staging-miljø fanger før kunden.
- RLS-bug (tenant-lekkasje) → den eksistensielle. Testes som førsteklasses bekymring, automatisk. Den ene feilen du ikke overlever omdømmemessig.
- Datatap → daglige backups + point-in-time recovery.

Tester der det koster penger: parserne og analyselaget (stille feil = feil tall = tapt tillit).

Over-bygging er like farlig som under-bygging — bygg den kjedelige, disiplinerte versjonen av den valgte stacken.

## 15. Personvern og sikkerhet (GDPR)

GDPR er en del av salget: du selger «dine data er trygge og adskilt fra konkurrentene» til folk som er på vakt nettopp fordi de er konkurrenter. En seriøs personvernside er et tillitssignal.

> Merk: Strukturen og tiltakene under er korrekte, men en juridisk bindende personvernerklæring må gjennom juridisk gjennomgang før publisering. Dette er et solid utgangspunkt, ikke en erstatning for advokat.

**Teknisk (bygget inn):**

- DPA (databehandleravtale) med hver kunde — du er databehandler, retaileren er behandlingsansvarlig.
- Datalagring i EU/EØS (Supabase + hosting i europeisk region) — fjerner tredjeland-problematikk. Velges nå, ikke etterpå.
- Underdatabehandler-liste (Supabase, Vercel, Anthropic, SMS/e-post) — hva hver gjør.
- Eksport + ekte sletting når kunde slutter (soft-delete er drift; reell sletteforespørsel krever faktisk hard sletting — må bygges).
- Kryptering i transport + ro. Tilgangslogg (hvem så hva). `ai_tool_log` med PII-redaksjon.

**AI-spesifikt (verifisert fortrinn, per 2026):**

- Anthropics kommersielle/API-vilkår: input/output brukes som standard ikke til trening. API-logger oppbevares kort (7 dager per sept. 2025), brukes aldri til trening. GDPR støttes via DPA.
- Fire ærlige løfter til kundene: (1) dataene dine er adskilt fra alle andres (RLS), (2) lagres i EU/EØS, (3) AI-en trener ikke på dataene + ser kun din egen tenant, (4) du eier dataene — eksport/sletting når du vil.
- Datostempling: API-vilkår endrer seg — skriv «per [dato], se leverandørens gjeldende vilkår», ikke et fast tall i betong. Avklar ZDR/formell DPA direkte med Anthropic før du lover null lagring spesifikt.

Plattform-redaktør-rollen (§3): publiserer kun innhold nedover, leser aldri forretningsdata, all publisering logges (samme disiplin som innloggings-nødluken).

Felles innhold fra St1: IK-mat-maler, monteringsanvisninger, kunnskap publiseres som mal/utgangspunkt (retailer bruker som-det-er eller tilpasser egen kopi; oppdatering varsler, overkjører ikke tilpasset versjon). **Å AVKLARE med St1:** eierskap + fagansvar for lovpålagt delt innhold (særlig IK-mat). Bør være at St1/retailer eier det faglige, Sentiqa er distribusjonskanal.

## 16. Byggerekkefølge (lag for lag — stopp mellom hvert)

1. **Fundament:** auth, tenant-isolasjon (RLS), roller, stasjoner, brukere, tillatelser, plattform-redaktør-rolle.
2. **Datainntak:** e-post-inntak + kø + parsere (Salgsstatistikk + Visma først), idempotens, butikknummer-matching, import-status, historikk-bulk.
3. **Kjerneverdi:** regnskap-dashboard, daglig salg, svinn (m/terskel + før/etter), sammenligning + analyselaget (dype analyser, stasjonstyper, produksjonsplan, utsolgt-håndtering).
4. **AI-assistenten** på toppen av (3): chatbot + auto-fokus + regnskaps-analyse + lederstøtte, m/modell-ruting + caching + token-måling.
5. **Drift (tablet):** rutineskjema (tonivå), IK-mat, sjekkpunkt, opplæring, PIN-logging, oppgaver.
6. **Engasjement:** konkurranser (AI-drevet), pengepremier, skills, puls, tilbakemeldinger.
7. **Premium:** Avtalevokter, gamification.
8. **Resten:** kunnskap, monteringsanvisning, drivstoffpris-finpuss, kommunikasjon/varsler.

Tverrgående gjennom alt: design (§12), driftssikkerhet (§14), personvern (§15). Skriv tester for parsere + analyselag underveis, ikke etterpå.

## 17. Åpne avklaringer (samlet)

1. **Stasjonstyper:** stemmer de fem (utfart/pendler/bydel/gjennomfart/sentrum), eller skal pendler ut / en legges til?
2. **Opplæring:** hvem bekrefter et lært punkt — ansvarlig (anbefalt) / den nye / begge?
3. **Innloggings-nødluke:** skal plattform kunne utløse tilbakestilling for en låst retailer (snever, logget), eller ren selvbetjening?
4. **Butikknumre:** er St1-butikknumre globalt unike, eller bare per eier?
5. **Rutineskjema:** (a) rutinens dager kun snevrer inn vaktens? (b) overlapp-time krediteres rutinens egen vakt?
6. **St1 delt innhold:** eierskap/fagansvar for lovpålagt IK-mat-innhold som distribueres til andre stasjoner.

## 18. Teknisk stack (utgangspunkt — foreslå bedre der det passer)

Next.js (App Router) + React + TypeScript + Tailwind. Supabase (Postgres + Auth + Realtime + Storage + RLS). Anthropic Claude (Sonnet til chatbot, Opus til tung analyse, batch-API til nattjobber). Kø: Inngest/Trigger.dev (eller egen worker). Stripe (billing). Sentry (feilsporing). SMS/e-post/web-push (varsler). yr.no/Open-Meteo (vær). Hosting i EU/EØS-region.

**Faste krav uansett stack:** all tid i Europe/Oslo; norsk bokmål i UI + domenekode (stasjon, svinn, oppgave); soft-delete (`slettet_tid`); Server Components default; touch-targets ≥44×44 px på tablet; signerte Storage-URL-er batchet (aldri i loop).

---

_Kilde: Roberts marsjordre, limt inn 2026-06-06._
