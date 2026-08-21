// =====================================================================
// Åtte mønstre, 68 ruter.
//
// Poenget med å klassifisere før man redesigner: uten det blir hver side
// løst for seg, og systemet ender som 68 sider bygget på 68 tidspunkt —
// nøyaktig det vi prøver å komme oss vekk fra.
//
// Mønsteret sier hva NIVÅ 1 er på siden. Det er den vanskelige
// beslutningen, og den er ulik per mønster: på en liste er det «hvor
// mange, og hva krever noe av meg», på en analyse er det «hva er svaret»,
// på en arbeidsflyt er det «hvor langt er jeg kommet».
//
// Kartet er sjekket av en test: hver rute MÅ ha et mønster. Legger noen
// til en side uten å ta stilling til hva slags side det er, feiler
// vakthunden. Det er billigere å svare på det spørsmålet én gang enn å
// oppdage om et halvt år at siden ble en tabell fordi ingen tenkte.
// =====================================================================

export type Monster =
  | 'dashbord'      // Rollens samlede bilde. Oppmerksomhet først.
  | 'liste'         // Mange av samme sort. Skanne og handle.
  | 'detalj'        // Én ting i dybden.
  | 'arbeidsflyt'   // En rekkefølge med et mål og en slutt.
  | 'analyse'       // Forstå hvorfor tallene ser slik ut.
  | 'innstillinger' // Sjelden endret oppsett.
  | 'opprett'       // Skal bli sidepanel, ikke egen side.
  | 'tablet'        // Arbeidsverktøy i butikken. Egne regler.
  | 'utenfor'       // Før innlogging. Eget formspråk, rører vi ikke nå.

export type Monsterspek = {
  navn: string
  nivaa1: string
  nivaa2: string
  nivaa3: string
  nivaa4: string
  /** Det som er lett å gjøre feil i nettopp dette mønsteret. */
  fella: string
}

export const MONSTRE: Record<Monster, Monsterspek> = {
  dashbord: {
    navn: 'Dashbord',
    nivaa1: 'Hva krever oppmerksomhet? Rangert, ikke alfabetisk.',
    nivaa2: 'Handlingen som lukker funnet, rett i raden.',
    nivaa3: 'Dagens tall, med sammenligning mot normalen.',
    nivaa4: 'Veien videre inn i modulene.',
    fella: 'Et rutenett av widgets der alt er like viktig. Da må brukeren '
      + 'selv sortere, og det var jobben systemet skulle gjøre.',
  },
  liste: {
    navn: 'Liste',
    nivaa1: 'Hvor mange, og hvor mange av dem krever noe av meg.',
    nivaa2: 'Søk, filter og «Ny …» — sistnevnte åpner sidepanel.',
    nivaa3: 'Radene, med status som kan leses på avstand.',
    nivaa4: 'Kolonner de fleste ikke trenger.',
    fella: 'Å åpne med skjemaet for å opprette. Det er den sjeldneste '
      + 'handlingen på siden, og den står øverst på /ansatte i dag.',
  },
  detalj: {
    navn: 'Detaljside',
    nivaa1: 'Hva er dette, og hvilken tilstand er det i.',
    nivaa2: 'Det man kom hit for å gjøre.',
    nivaa3: 'Historikk og sammenheng.',
    nivaa4: 'Rådata og felter.',
    fella: 'Å gjenta hele lista i toppen. Brukeren kom fra den.',
  },
  arbeidsflyt: {
    navn: 'Arbeidsflyt',
    nivaa1: 'Hvor langt er jeg kommet, og hva stopper meg.',
    nivaa2: 'Neste steg. Én knapp, ikke fem likeverdige.',
    nivaa3: 'Hva systemet foreslår, og hvorfor.',
    nivaa4: 'Grunnlaget bak forslaget.',
    fella: 'Å vise beregningen før anbefalingen. /produksjonsplan gjør det '
      + 'i dag — brukeren møter metoden før svaret.',
  },
  analyse: {
    navn: 'Analyse',
    nivaa1: 'Svaret, som én setning på norsk.',
    nivaa2: 'Perioden og hva som sammenlignes.',
    nivaa3: 'Kurven eller fordelingen.',
    nivaa4: 'Tabellen.',
    fella: 'Et tall uten sammenligning. «34 200 kr» betyr ingenting; '
      + '«+7,8 % mot en vanlig tirsdag» betyr alt.',
  },
  innstillinger: {
    navn: 'Innstillinger',
    nivaa1: 'Hva som gjelder nå.',
    nivaa2: 'Endre det.',
    nivaa3: 'Hva endringen fører til.',
    nivaa4: 'Sjeldne valg.',
    fella: 'Å be om et valg systemet kunne tatt selv. Standardverdien '
      + 'skal være riktig for de fleste.',
  },
  opprett: {
    navn: 'Opprett eller rediger',
    nivaa1: 'Hva du er i ferd med å lage.',
    nivaa2: 'De påkrevde feltene. Ikke flere.',
    nivaa3: 'Det valgfrie, sammenleggbart.',
    nivaa4: '—',
    fella: 'Å være en egen side. Da mister brukeren konteksten sin for å '
      + 'legge inn ett navn. Dette skal være sidepanel.',
  },
  tablet: {
    navn: 'Nettbrett',
    nivaa1: 'Hva gjenstår på skiftet mitt. Tre ting, ikke tjue.',
    nivaa2: 'Den ene oppgaven, stor nok til å treffe med hansker.',
    nivaa3: '—',
    nivaa4: '—',
    fella: 'Å arve desktop. Se → forstå → gjør → ferdig, ikke meny → '
      + 'underside → skjema → lagre → tilbake. En 16-åring på første '
      + 'arbeidsdag er målestokken.',
  },
  utenfor: {
    navn: 'Utenfor innlogging',
    nivaa1: 'Ett ærend per side.',
    nivaa2: '—',
    nivaa3: '—',
    nivaa4: '—',
    fella: 'Å dra med seg systemets formspråk inn på en side der brukeren '
      + 'ikke er en bruker ennå.',
  },
}

/**
 * Hvilket mønster hver rute følger.
 *
 * `tablet` betyr at ruta er nettbrettets, ikke at nettbrettet er eneste
 * som når den — flere sider tjener både leder og nettbrett med samme rute
 * og ulik presentasjon. De står med lederens mønster her, og
 * nettbrettvarianten hører til `tablet`-runden.
 */
export const RUTEMONSTER: Record<string, Monster> = {
  // --- Utenfor innlogging ---
  '/': 'utenfor',
  '/logg-inn': 'utenfor',
  '/logg-inn/totp': 'utenfor',
  '/registrer': 'utenfor',
  '/sett-passord': 'utenfor',
  '/ingen-tilgang': 'utenfor',
  '/personvern': 'utenfor',
  '/databehandleravtale': 'utenfor',

  // --- Dashbord ---
  // /oversikt er ren ruting: den velger TabletHjem, AdminDashbord eller
  // ButikksjefDashbord etter rolle. Mønsteret er oppfylt i de tre, som har
  // sitt eget `sq-hode` med hilsen, tall og ferskhet fra forsiderunden —
  // Sidehode hører til vanlige sider og ville vært et steg tilbake her.
  '/oversikt': 'dashbord',
  '/plattform': 'dashbord',

  // --- Arbeidsflyt ---
  '/produksjonsplan': 'arbeidsflyt',
  '/lonn': 'arbeidsflyt',
  '/bemanning': 'arbeidsflyt',
  '/kontrakt': 'arbeidsflyt',
  '/import': 'arbeidsflyt',
  '/opplaring': 'arbeidsflyt',
  '/sjekkpunkt': 'arbeidsflyt',
  '/rutiner/min': 'arbeidsflyt',
  // Ren redirect til /ikmat (avvik ble flettet inn der). Ingen nivåer å
  // ordne — står her bare fordi kartet skal dekke alle ruter.
  '/avvik': 'arbeidsflyt',
  '/ikmat': 'arbeidsflyt',

  // --- Analyse ---
  '/salg': 'analyse',
  '/timesalg': 'analyse',
  '/salgsprognose': 'analyse',
  '/svinn': 'analyse',
  // «Ligger vi i rute mot planen?» Analyse og ikke dashbord: den
  // forklarer hvorfor tallene ser slik ut, og rangerer ikke funn paa
  // tvers av systemet. Men den KREVER noe - derfor staar det som
  // krever mest oeverst, sortert paa kroner bak plan.
  '/businessplan': 'analyse',
  '/regnskap': 'analyse',
  '/analyse': 'analyse',
  '/maaling': 'analyse',
  '/kasserer': 'analyse',
  '/produksjonsplan/treffsikkerhet': 'analyse',
  '/dekning': 'analyse',
  '/rutiner/oversikt': 'analyse',
  // Sto som 'arbeidsflyt'. Det er ingen rekkefølge med en slutt her — det
  // er en rapport per stasjon. Nivå 1 er svaret: hvor mange stasjoner som
  // står sterkt, og hvor mange som har utviklingspotensial.
  '/lederstotte': 'analyse',

  // --- Liste ---
  '/ansatte': 'liste',
  '/brukere': 'liste',
  '/stasjoner': 'liste',
  '/oppgaver': 'liste',
  '/varsler': 'liste',
  '/nyheter': 'liste',
  '/meldinger': 'liste',
  '/tilbakemeldinger': 'liste',
  '/kunnskap': 'liste',
  '/anvisninger': 'liste',
  '/merker': 'liste',
  '/premier': 'liste',
  '/skills': 'liste',
  '/konkurranser': 'liste',
  '/arrangementer': 'liste',
  '/kampanjer': 'liste',
  '/redaktor': 'liste',
  '/puls': 'liste',
  '/puls/sporsmal': 'liste',
  '/utsolgt': 'liste',
  '/fokus': 'liste',
  // Sto som 'analyse'. Siden analyserer ingenting — den kobler hver
  // stasjon til nærmeste bilteller og skrur måling på. Nivå 1 er «hvor
  // mange, og hvor mange mangler noe», altså listemønsteret.
  '/trafikk': 'liste',

  // --- Detalj ---
  '/kontrakt/[id]': 'detalj',
  '/puls/[id]': 'detalj',
  '/rutiner/oppsett/[id]': 'detalj',
  '/ikmat/maaling': 'detalj',
  '/mine-opplysninger': 'detalj',

  // --- Innstillinger ---
  '/timeregnskap': 'analyse',
  '/timeregnskap/oppsett': 'innstillinger',
  '/ikmat/oppsett': 'innstillinger',
  '/rutiner/oppsett': 'innstillinger',
  '/persondata': 'innstillinger',
  '/abonnement': 'innstillinger',
  // Ligger utenfor (beskyttet) og tegner seg i innloggingsskallet, fordi
  // den også møter deg midt i pålogging når rollen krever to-faktor.
  // Derfor ingen Sidehode her — den hører til appskallet, som siden ikke
  // har. Sjekket 2026-08-18; la den stå.
  '/sikkerhet': 'innstillinger',

  // --- Opprett ---
  // Tom med vilje. '/puls/ny' lå her; den er nå sidepanelet «Start måling»
  // på /puls, slik mønsteret foreskriver. Havner en ny opprett-rute her,
  // er det et varsel om at et skjema har fått egen side igjen.

  // --- Nettbrett ---
  '/rutiner': 'tablet',
  '/lenker': 'tablet',
  // Sekundær engasjementsflate (bølge 5). Brukerærendet er «hvordan gjør
  // vi det som stasjon?» — ikke «hva skal jeg gjøre nå?».
  //
  // DEN ER MED VILJE IKKE `dashbord` OG IKKE `analyse`. Et dashbord
  // rangerer det som krever oppmerksomhet, og analyse forklarer hvorfor
  // tallene ble slik. Denne gjør ingen av delene: den viser fire faste
  // tall uten filtre, uten perioder og uten drill-down, og ingenting på
  // den krever en handling i dag. Å gi den `dashbord` ville sagt at den
  // skal vokse i den retningen — og det er nettopp det den ikke skal.
  //
  // Den er heller ikke en fjerde hovedmodus. Fanene er tre — I dag ·
  // Rutiner · Hjelp — og denne nås som én rad fra «I dag». Plasseringen
  // er selve beskjeden om rangordenen.
  '/vaar-stasjon': 'tablet',
  // Stemple inn og ut (0110). Nivå 1 er «hva skjer når jeg trykker» —
  // to felter, én knapp, og en kvittering som sier navn og klokkeslett
  // stort nok til å ses uten å lete.
  '/stempling': 'tablet',
}

/**
 * Rutene nettbrettet når, uansett hvilket mønster de har for lederen.
 *
 * Disse deler rute med desktop og skal presentere seg ulikt etter rolle —
 * ikke bli egne ruter. Se `roller` i menyen for fasit.
 */
export const TABLETRUTER = [
  '/oversikt', '/ikmat', '/merker', '/nyheter', '/lenker', '/rutiner',
  '/mine-opplysninger',
] as const
