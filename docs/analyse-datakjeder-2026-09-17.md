# Datakjeder: økonomi, salg, prognose, bemanning og lønn

Dato: 2026-09-17. Avgrenset read-only kildeanalyse. Ingen produktkode eller produksjonsdata endret. Kodebevis er ikke det samme som målt forekomst hos dagens retailer.

## Kjede og kontrakter

| Kjede | Datakilde og motor | Viktig målenivå |
|---|---|---|
| Faktisk butikksalg | Filimport → butikkviews → salg/rapport/produksjon | Drivstoff holdes utenfor; stasjon, dato og kategori må stemme |
| Salgsprognose | `salg/forventet.ts` → `salgsprognose.ts` → kalibrering i `backtest.ts` | Kroner per avdeling, måldag, korrekt historisk referanse |
| Produksjonsforslag | `produksjonsplan.ts` med vær og helligdagsreferanse | Antall egnede varer, vakt/dag, faktisk volum mot plan |
| Månedlig økonomi | `okonomi/sammenstill.ts` → `lonnskost/hent.ts` → `okonomi/bilde.ts` | Én stasjon og måned; budsjett, anslag og fasit skilles |
| Lønnsrom | BP-månedstall + faktisk/anslått brutto → `lonnskost/rom.ts` | BP-lønn/BP-brutto × brutto; samme kontosett i styringskost |
| Tidlig lønnsanslag | Lønnsartsummer + fastlønn → `lonnskost/easyatwork.ts` | Bokføringsperiode og kontodekning, ukjent fastlønn stopper styringskonklusjon |
| Bemanningsforslag | Timesalg/kunder + avtaler/faste vakter/fravær + ramme → `bemanning.ts` | Arbeidssted, kalenderperiode, time og lønnsform |

Positive arkitekturvalg: Måned og lønnskost deler sammenstiller. `okonomi/bilde.ts` modellerer kilde og mangel eksplisitt. `easyatworkNiva` ved `lonnskost/easyatwork.ts:600` fører ukjent fastlønn som ukjent konto 501 selv om den numeriske modellen internt har 0. Dette må bevares; et generelt søk etter `?? 0` er ikke alene bevis på feil styringstall. Produksjonsplanmotorens `fjorHelligdag` er et annet viktig eksisterende vern.

## P1: Salgsprognosen bruker feil historisk helligdag

Bevis: `src/lib/salgsprognose.ts:36` setter `fjorBase = maalDato - 364`. `helligdag` begrenser referansen til denne ene dagen; den slår ikke opp den tilsvarende navngitte helligdagen. `src/lib/salg/forventet.ts:85` bruker samme base for datahenting og vær. `/salgsprognose/page.tsx:108` sier likevel at prognosen bruker «fjorårets samme helligdag». Backtestens salgsgren ved `src/lib/backtest.ts:140` sender bare boolsk `helligdag`, så en backtest mot samme motor beviser ikke riktig kalenderreferanse.

Konkrete eksempler: 17. mai 2026 minus 364 dager er 18. mai 2025. Første påskedag 2026 er 5. april, mens første påskedag 2025 er 20. april; -364 gir 6. april 2025. Feilen er dermed ikke bare ved bevegelige helligdager.

Produksjonsmotoren har allerede en smal løsning: `src/lib/produksjonsplan.ts:109–120` tar `fjorHelligdag`, og `src/lib/helligdager.ts:95` slår opp navn i forrige år. Salgsmotoren mangler denne kontrakten.

Forslag: bruk samme kalenderreferanse i salgshenting, vær, ren motor og backtest. Legg direkte kalendertest for 17. mai og påske, med svært ulike salgstall på riktig og feil referansedag. Retning kan være begge veier; en vanlig søndag eller hverdag kan bli tolket som helligdagsnivå.

## P1: For høye limit-verdier beskytter ikke lønnskjeden mot avkorting

Bevis: `src/lib/lonnskost/hent.ts:122` ber om 20 000 regnskapsrader; BP og brutto bruker 5 000, lønnsarter 2 000. `supabase/config.toml:18` har `max_rows = 1000`. Feilkontrollen ved `hent.ts:309–321` sjekker `svar.error`, men ikke radantall/kompletthet. PostgREST kan gi et vellykket avkortet svar. Kommentarer flere steder omtaler akkurat denne risikoen, men et `.limit(5000)` opphever ikke serverens maksimum.

Dette beviser manglende beskyttelse og lokal reproduksjonsbetingelse. Dagens produksjonsinnstilling og faktiske radantall må verifiseres før det hevdes at produksjon allerede avkortes. BP-spørringen filtrerer stasjon og seksjon, men ikke år i SQL; år filtreres først senere i TypeScript, så gammel historikk kan øke risikoen.

Forslag: flytt summering til allerede autoriserte aggregatfunksjoner eller paginer stabilt med eksplisitt feilhåndtering. Legg direkte prøve med over 1 000 relevante rader og med flere BP-år. Ikke bare hev limit-verdien. Retning: lønn/budsjett/brutto kan bli for lave, men styringsavvikets retning avhenger av hvilken kilde som avkortes.

## P1/P2: Salgsprognosens siste salgsdato er ikke stasjonsbundet

Bevis: `/salgsprognose/page.tsx:84` kaller `sisteDag(supabase, 'v_salg_per_avdeling_dag')`. `src/lib/dagvindu.ts:51` leser nyeste dato uten `stasjon_id`. Deretter henter `hentForventet` nylig salg for valgt stasjon i et vindu basert på denne datoen. En butikksjef med flere stasjoner, eller admin, kan bruke stasjon Bs siste dato til stasjon As prognose.

Hvis A ligger langt bak B, kan siste 35 dagers vindu utelate As relevante data og ferskhetsadvarselen bruke feil dato. Selv ved mindre forskjell er metadataen uriktig.

Forslag: en smal variant av sisteDag med valgt stasjon, eller siste dato av det samme stasjonsgrunnlaget modellen bruker. Test to stasjoner med ulik importdato. Ikke bruk global nyeste dag som bevis på at valgt stasjon er oppdatert.

## P1/P2: Prognosehenting kan produsere et troverdig tall fra delvis grunnlag

Bevis: `src/lib/salg/forventet.ts:87–112` destrukturerer bare `data` fra nylig salg, fjorårssalg og vær; feil ignoreres. Linje 114 slår sammen `nylig ?? []` og `fjor ?? []`. Hvis fjorårshentingen feiler, faller modellen tilbake på nylig gjennomsnitt. Hvis nylig-hentingen feiler, kan den bruke fjorårsgrunnlag og trend 1. Dette er legitim modellfallback ved manglende historikk, men ikke ved mislykket databaseforespørsel.

Hentingen mangler også eksplisitt kompletthetskontroll. Fjorårsvinduet omfatter 50 dager per avdeling; 20 avdelinger kan fylle 1 000 rader. Avkorting er en skaleringsrisiko, ikke påvist produksjonsforekomst. `omsetning: r.omsetning ?? 0` gjør nullsummer til null kroner; om viewkontrakten garanterer fullstendige summer må undersøkes.

Forslag: skill nødvendig salgskilde fra valgfritt vær. Salgsfeil bør stoppe konklusjonen eller vise tydelig feilgrunnlag. Manglende vær kan fortsatt være eksplisitt merket fallback. Test hver salgskilde som feiler separat og et avkortet svar. Ikke kalibrer bort en IO-feil.

## P2: Royalty null blir 0 i en sammenstiller som lover å bevare ukjent

Bevis: `src/lib/okonomi/sammenstill.ts:184` summerer `(f.royaltyKr ?? 0) + (tall(r.regnskap) ?? 0)`. Dersom en royaltylinje finnes med `regnskap = null`, blir feltet 0. Filens `Fasittall`-kommentar lover at manglende verdier forblir null, og `tall` er laget for å bevare nettopp dette. Feltet kan dermed se kjent ut uten kjent beløp. Dette gjelder eierens økonomibilde; butikksjefens royalty er skjult.

Forslag: bevar ukjent hvis en nødvendig del er null, eller dokumenter og valider at royaltylinjer aldri kan ha null beløp. Ikke påstå skade på lønnsrommet: royalty inngår ikke i den viste romformelen.

## Bemanning: kjeden trenger feilstatus og eksplisitt kildedekning

Se også `analyse-butikksjef-2026-09-17.md`. `/bemanning/page.tsx:102`, `:117` og `:135` returnerer tomme grunnlag fra ukeprofil, faktisk bemanning og ansatte-måneder uten å sjekke databasefeil. Timesalghentingen bruker derimot datobolker, som er en sterkere kontrakt. Gjennomfør samme vern på de andre nødvendige grunnlagene.

Dataproduktene har ulike maksimum: faktisk bemanning per dato/time er normalt under 1 000 rader for én måned, mens ansatt-måned-historikk kan vokse med antall ansatte. Ikke paginer alle tabeller mekanisk; mål øvre domenestørrelse og velg aggregat, periodevindu eller stabil paginering der det trengs.

## Anbefalt kontrollmatrise før endringer

| Akse | Direkte prøve |
|---|---|
| Konto | Styringskost har nøyaktig BP-kontosett; sykdom/bonus vises separat |
| Periode | Påske/17. mai bruker navngitt referansedag; åpen måned og avlagt måned skilles |
| Stasjon | To tillatte stasjoner med forskjellige importdatoer og arbeidssteder |
| Ukjent | Null beløp og databasefeil får ikke bli grønn nullkost |
| Kompletthet | 1 001+ rader og pagineringsfeil kan ikke gi mindre gyldig total |
| Kilder | Manglende vær kan gi merket prognose; feil salgshenting stopper eller merker svaret |

Denne analysen verifiserer ikke hele SQL-/importkjeden eller produksjonsmålinger. Før en komplett fasit må viewdefinisjonene og importer prøves mot representativ lokal fixture, og reell produksjonskonfigurasjon bekreftes read-only. Ingen nye migrasjoner er foreslått som nødvendige uten videre undersøkelse.

Onboardingpåvirkning: NEI for denne analysen. Kalenderkorreksjon, stasjonsbinding og kompletthetsvern bør bruke eksisterende data. Hvis nullfunn senere viser et nytt obligatorisk import-/mappingkrav, må onboardingen oppdateres sammen med implementasjonen.
