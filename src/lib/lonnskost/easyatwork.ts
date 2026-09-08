// Lønnskost regnet av easy@work-eksporten, måned for måned.
//
// REGNSKAPET ER FORTSATT FASITEN. Dette er et anslag, og det skal aldri
// presenteres som noe annet. Verdien er at det finnes dagen etter at
// måneden er over, mens regnskapsrapporten kommer midt i den neste.
//
// TRE TING MANGLER PER KONSTRUKSJON, og de skal stå skrevet fordi de
// ikke kan oppdages i tallet:
//
//   501  Fastlønn        — en fastlønnet dukker ikke opp med null i
//                          eksporten; hen dukker ikke opp i det hele
//                          tatt. På Bønes var lederens fastlønn 27 % av
//                          lønnskosten. Fravær er usynlig.
//   506  Refundert sykelønn — NAV betaler tilbake etter dag 16. Anslaget
//                          er derfor for høyt i måneder med lange fravær.
//   509  Bonus           — utbetales gjennom lønnssystemet, ikke gjennom
//                          en stemplet time.
//
// Derfor sier `mangler` hva som ikke er med, og flaten skal vise det ved
// siden av tallet — ikke i en fotnote.

import type { Lonnsartlinje } from '@/lib/parsere/lonnsart'

/**
 * En ferdig summert linje: en loennsart i en maaned.
 *
 * AGGREGERINGEN HOERER HJEMME I BASEN. Tretten maaneder raa linjer er
 * over fem tusen rader, og PostgREST kutter et for stort svar UTEN aa
 * feile - en avkortet spoerring ser ut som en liten stasjon, ikke som en
 * feil (0090, 0166, 0175). `v_lonnsart_maaned` gjoer det samme svaret til
 * en drøy handfull rader per maaned.
 */
export type Lonnsartsum = {
  maaned: string // yyyy-mm
  lonnsart: string
  lonnsartTekst: string
  timer: number
  belopKr: number
}

/** Raa linjer til samme form, saa parseren kan mates rett inn i tester. */
export const fraLinjer = (linjer: Lonnsartlinje[]): Lonnsartsum[] =>
  linjer.map((l) => ({
    maaned: l.dato.slice(0, 7),
    lonnsart: l.lonnsart,
    lonnsartTekst: l.lonnsartTekst,
    timer: l.timer,
    belopKr: l.belopKr,
  }))

/**
 * Påslagene som gjør kontantlønn til arbeidsgivers kostnad.
 *
 * DISSE ER KELSARS, IKKE UNIVERSELLE. Arbeidsgiveravgiften er 14,1 % i
 * sone 1 og 0 % i Finnmark og Nord-Troms; feriepengesatsen er 12 % med
 * fem ukers ferie og 14,3 % for ansatte over 60. Pensjonen er OTP-
 * minimum, som en kjede kan velge å ligge over.
 *
 * De står som konstanter fordi det finnes én kjede i dag. Kommer kunde
 * nummer to, er dette konfigurasjon per retailer — ikke et spørsmål til
 * noen. En standardverdi som gir feil tall for en annen kjede er nytt
 * onboardingsteg, ikke en trygg default.
 */
export const SATSER = {
  /** Feriepenger, konto 508. */
  feriepengerPst: 12,
  /** OTP fra første krone (lovendring 2022), konto 590 eller sentralt. */
  pensjonPst: 2,
  /** Arbeidsgiveravgift sone 1, konti 540 og 541. */
  agaPst: 14.1,
} as const

/**
 * Lønnsart → St1-konto.
 *
 * EN UKJENT ART SKAL RAPPORTERES, IKKE BØTTES. Fristelsen er «alt som
 * ikke er 2 eller 12 er tillegg» — den ville lagt en fastlønnsart rett i
 * 502 og gjort et hull til et tall. Samme form som `ukjenteLonnskoder`
 * i `bp.ts`.
 */
const TIL_KONTO: Record<string, string> = {
  '2': '503', // Timelønn
  '12': '505', // Sykelønn
  // TILLEGGENE FØRES I 503, IKKE I 502.
  //
  // Her sto de på 502 «Lønnstillegg», som er navnet man ville gjettet
  // på. Målt mot Dale 2026 er 502 nøyaktig 500 kroner HVER måned — et
  // fast mobiltillegg, ikke kveld og helg. De variable tilleggene ligger
  // inne i 503 sammen med timelønna, og der hører de derfor hjemme her.
  //
  // Totalen er den samme uansett; det er per-konto-sammenligningen som
  // ville løyet, og den er nettopp den man leser når noe spriker.
  '96': '503', // 50 % overtidstillegg
  '97': '503', // 100 % overtidstillegg
  '1410': '503', // Helligdagstillegg
  '1429': '503', // Tillegg hverdag 18-21
  '1430': '503', // Tillegg hverdag 21-24
  '1431': '503', // Tillegg hverdag 00-06
  '1432': '503', // Tillegg lørdag
  '1433': '503', // Tillegg søndag 00-06
  '1434': '503', // Tillegg søndag 06-18
  '1435': '503', // Tillegg søndag 18-24
}

/** Arten som bærer arbeidede timer. Tilleggene teller de SAMME timene. */
const TIMEART = '2'

/** Sykelønnskontoen. Den ene som ligger en måned etter i regnskapet. */
const SYKEKONTO = '505'

/** Fastlønn. Finnes ALDRI i easy@work — den hentes fra regnskapet. */
const FASTKONTO = '501'

export type EasyatworkMaaned = {
  maaned: string // yyyy-mm
  /**
   * Arbeidede timer.
   *
   * KUN LØNNSART 2. Tilleggene bærer de samme timene en gang til — et
   * kveldstillegg er ikke en ekstra time, det er en dyrere time. Summen
   * over alle artene ga 1 907,81 der de arbeidede var 1 264,73.
   */
  timer: number
  kontantKr: number
  perKonto: Record<string, number>
  feriepengerKr: number
  pensjonKr: number
  agaKr: number
  /**
   * Kontantlønn + feriepenger + aga. PENSJONEN ER IKKE MED.
   *
   * Den lå her til 2026-09-07, og gjorde tallet usammenlignbart med
   * regnskapet uten at noe sa fra. St1 fører OTP som `5945 Obligatorisk
   * tjenestepensjon` under konto 590 «Andre personal» — altså UTENFOR de
   * ni lønnskontiene, og /lonnskost holder 590 utenfor med vilje.
   *
   * `pensjonKr` står fortsatt for seg, som 590 gjør på regnskapssiden.
   */
  lonnskostKr: number
  /** Lønnsarter uten konto. Skal være tom. */
  ukjenteArter: string[]
  /**
   * Hvilken måned sykelønna er hentet fra.
   *
   * Lik `maaned` i den rå opprullingen. Etter
   * `medSykelonnsforskyvning()` er den måneden før — og `null` når den
   * måneden ikke finnes i dataene, som for den eldste. Da er raden ikke
   * sammenlignbar med regnskapet, og flaten skal si det i stedet for å
   * vise et tall som mangler en post.
   */
  sykelonnFraMaaned: string | null
  /**
   * Fastlønn, hentet fra regnskapets konto 501.
   *
   * EN FASTLØNNET FINNES IKKE I EASY@WORK. Hen stempler ikke for å få
   * betalt, så eksporten har ingen linje — og fraværet er usynlig, det
   * ser ut som en stasjon uten den personen. På Bønes er lederens
   * fastlønn 27 % av lønnskosten.
   */
  fastlonnKr: number
  /**
   * Hvilken måned fastlønna ble lest av. Er den en ANNEN enn `maaned`,
   * er tallet båret fram fra sist kjente — det holder fordi fastlønn er
   * fast, men det er en antakelse, og den skal stå på skjermen.
   */
  fastlonnFraMaaned: string | null
  /**
   * Hvor sikkert fastlønnstallet er. Tre ulike grader:
   *
   *   `regnskap`  månedens egen konto 501. Fasit.
   *   `oppgitt`   grunnlønna eieren har lagt inn, med påslag regnet av
   *               den. Sann for måneden, men ikke avstemt.
   *   `baaret`    sist kjente 501, ført fram. Holder fordi fastlønn er
   *               fast — men en lønnsøkning eller en ny butikksjef
   *               bryter den, og da er den stille feil.
   */
  fastlonnKilde: 'regnskap' | 'oppgitt' | 'baaret' | null
}

const rund = (n: number) => Math.round(n * 100) / 100

/**
 * Ruller linjene opp per måned.
 *
 * Rekkefølgen er nyeste først, som ellers på flaten.
 */
export function byggEasyatwork(rader: Lonnsartsum[]): EasyatworkMaaned[] {
  const perMaaned = new Map<string, Lonnsartsum[]>()
  for (const l of rader) {
    const liste = perMaaned.get(l.maaned) ?? []
    liste.push(l)
    perMaaned.set(l.maaned, liste)
  }

  const ut: EasyatworkMaaned[] = []
  for (const [maaned, ls] of perMaaned) {
    const perKonto: Record<string, number> = {}
    const ukjente = new Set<string>()
    let kontantKr = 0
    let timer = 0

    for (const l of ls) {
      const konto = TIL_KONTO[l.lonnsart]
      if (!konto) { ukjente.add(l.lonnsartTekst); continue }
      perKonto[konto] = rund((perKonto[konto] ?? 0) + l.belopKr)
      kontantKr += l.belopKr
      if (l.lonnsart === TIMEART) timer += l.timer
    }

    const feriepengerKr = kontantKr * (SATSER.feriepengerPst / 100)
    const pensjonKr = kontantKr * (SATSER.pensjonPst / 100)
    // AGA PÅLØPER OGSÅ AV FERIEPENGER OG PENSJON. Konto 541 finnes
    // nettopp fordi feriepengedelen føres for seg; premien til OTP er
    // avgiftspliktig på samme måte.
    // AGA AV LØNN OG FERIEPENGER, IKKE AV PENSJONEN. Konti 540 og 541 er
    // nettopp de to; premien til OTP ligger utenfor lønnskosten sammen
    // med resten av 590.
    const agaKr = (kontantKr + feriepengerKr) * (SATSER.agaPst / 100)

    ut.push({
      maaned,
      timer: rund(timer),
      kontantKr: rund(kontantKr),
      perKonto,
      feriepengerKr: rund(feriepengerKr),
      pensjonKr: rund(pensjonKr),
      agaKr: rund(agaKr),
      lonnskostKr: rund(kontantKr + feriepengerKr + agaKr),
      ukjenteArter: [...ukjente].sort(),
      sykelonnFraMaaned: maaned,
      fastlonnKr: 0,
      fastlonnFraMaaned: null,
      fastlonnKilde: null,
    })
  }

  return ut.sort((a, b) => b.maaned.localeCompare(a.maaned))
}

/** Måneden før `maaned`, som «2026-07» → «2026-06». */
function forrigeMaaned(maaned: string): string {
  const [ar, mnd] = maaned.split('-').map(Number)
  return mnd === 1 ? `${ar - 1}-12` : `${ar}-${String(mnd - 1).padStart(2, '0')}`
}

/**
 * Flytter sykelønna én måned fram, slik regnskapet fører den.
 *
 * MÅLT, IKKE ANTATT — OG DET VAR IKKE MIN IDÉ.
 *
 * Timelønna periodiseres riktig: julis rapport har julis 1 527,66
 * arbeidede timer, på 0,13 % av easy@works kroner. Sykelønna gjør det
 * ikke, og forskjellen er dokumentasjonen — en sykmelding kommer inn
 * etter at lønnskjøringen for måneden er stengt, og havner i den neste.
 *
 *     regnskapets juli, konto 505     34 830
 *     easy@work juni, lønnsart 12     34 829,52
 *                                     ---------
 *                                          0,48 kr
 *
 * Med den ene flyttingen faller hele avviket for juli fra 30 086 kroner
 * til 373 — fra 6,8 % til 0,08 %. Kontantlønna bommer med 102 kroner,
 * som er mobildekningen (500) minus en vakt over månedsskiftet (398).
 *
 * ÉN OBSERVASJON, MEN PÅ 48 ØRE. Presisjonen utelukker tilfeldighet;
 * antallet gjør at en måned uten forrige måned i dataene skal si fra i
 * stedet for å gjette. Derfor `sykelonnFraMaaned: null` der.
 *
 * KALENDERMÅNEDEN MÅ FAKTISK FINNES. Hoppet noen over en måned i
 * eksporten, ville «forrige rad i lista» vært feil måned — og det ville
 * sett ut som et treff. Derfor slås den opp på nøkkel, ikke på posisjon.
 */
export function medSykelonnsforskyvning(maaneder: EasyatworkMaaned[]): EasyatworkMaaned[] {
  const per = new Map(maaneder.map((m) => [m.maaned, m]))

  return maaneder.map((m) => {
    const kilde = per.get(forrigeMaaned(m.maaned))
    const sykKr = kilde?.perKonto[SYKEKONTO] ?? 0
    const perKonto = { ...m.perKonto }
    if (sykKr === 0) delete perKonto[SYKEKONTO]
    else perKonto[SYKEKONTO] = sykKr

    // Kontantlønna bygges om uten den EGNE sykelønna og med forrige
    // måneds. Påslagene følger med: feriepenger og avgift regnes av det
    // regnskapet faktisk bokfører i måneden.
    const kontantKr = m.kontantKr - (m.perKonto[SYKEKONTO] ?? 0) + sykKr
    const feriepengerKr = kontantKr * (SATSER.feriepengerPst / 100)
    const pensjonKr = kontantKr * (SATSER.pensjonPst / 100)
    const agaKr = (kontantKr + feriepengerKr) * (SATSER.agaPst / 100)

    return {
      ...m,
      perKonto,
      kontantKr: rund(kontantKr),
      feriepengerKr: rund(feriepengerKr),
      pensjonKr: rund(pensjonKr),
      agaKr: rund(agaKr),
      lonnskostKr: rund(kontantKr + feriepengerKr + agaKr),
      sykelonnFraMaaned: kilde ? kilde.maaned : null,
    }
  })
}

/** Hvor regnskapets sykelønn for en måned kom fra. */
export type Sykelonnskilde = 'samme_maaned' | 'forrige_maaned' | 'ukjent'

/**
 * Hvor stort avvik som fortsatt regnes som treff.
 *
 * Kandidatene skiller seg med en faktor seks i juli (5 934 mot 34 830),
 * så terskelen trenger ikke være stram for å skille dem. Den er der for
 * øredifferanser og små korreksjoner, ikke for å tvinge fram et svar.
 */
const treffer = (a: number, b: number) => Math.abs(a - b) <= Math.max(50, b * 0.02)

/**
 * Leser ut av tallene HVILKEN måned regnskapet førte sykelønna i.
 *
 * ===================================================================
 * OPPDAG, IKKE ANTA.
 *
 * Forrige runde slo forskyvningen fast som en regel: sykelønna ligger
 * én måned etter. Det var målt, og det stemte — på juli 2026, til 48
 * øre. Men det er en PRAKSIS, ikke en naturlov. Regnskapskontoret kan
 * periodisere sykelønna hvis Kelsar ber om det, og gjør de det, blir
 * regelen gal fra den måneden av.
 *
 * En hardkodet forskyvning ville da flyttet sykelønna en måned for
 * langt, hver måned, uten at noe ble rødt. Tallet ville sett like
 * rimelig ut som før — bare feil.
 *
 * Derfor spør denne funksjonen tallene i stedet: hvilken av de to
 * månedene ligner regnskapets konto 505? Endrer praksisen seg, følger
 * svaret etter av seg selv, og påminnelsen om at det ER en forsinkelse
 * blir en observasjon i stedet for en påstand.
 *
 * `ukjent` når ingen av dem treffer, eller når måneden ikke er avlagt.
 * Å gjette der ville gjort en usikkerhet til et tall.
 * ===================================================================
 */
export function sykelonnskilde(
  regnskapKr: number | null,
  egenMaaned: number,
  forrigeMaaned: number,
): Sykelonnskilde {
  if (regnskapKr == null) return 'ukjent'
  // KANDIDATENE MÅ VÆRE TIL Å SKILLE. Er de to månedene like store —
  // typisk begge null, i en måned uten sykefravær — bærer måneden ingen
  // informasjon om praksisen, og valget endrer ingen krone. En slik
  // måned skal ikke stemme over mønsteret. Uten dette ville hver rolige
  // måned trukket svaret mot «ingen forsinkelse» av ren aritmetikk.
  if (treffer(egenMaaned, forrigeMaaned)) return 'ukjent'
  if (treffer(egenMaaned, regnskapKr)) return 'samme_maaned'
  if (treffer(forrigeMaaned, regnskapKr)) return 'forrige_maaned'
  return 'ukjent'
}

/**
 * Bygger om én måned med sykelønn hentet et annet sted.
 *
 * Påslagene følger med: feriepenger og avgift regnes av det regnskapet
 * faktisk bokfører i måneden, ikke av det som ble opptjent i den.
 */
function medSykelonn(
  m: EasyatworkMaaned, sykKr: number, fraMaaned: string | null,
): EasyatworkMaaned {
  const perKonto = { ...m.perKonto }
  if (sykKr === 0) delete perKonto[SYKEKONTO]
  else perKonto[SYKEKONTO] = sykKr

  const kontantKr = m.kontantKr - (m.perKonto[SYKEKONTO] ?? 0) + sykKr
  const feriepengerKr = kontantKr * (SATSER.feriepengerPst / 100)
  const pensjonKr = kontantKr * (SATSER.pensjonPst / 100)
  const agaKr = (kontantKr + feriepengerKr) * (SATSER.agaPst / 100)

  return {
    ...m,
    perKonto,
    kontantKr: rund(kontantKr),
    feriepengerKr: rund(feriepengerKr),
    pensjonKr: rund(pensjonKr),
    agaKr: rund(agaKr),
    lonnskostKr: rund(kontantKr + feriepengerKr + agaKr),
    sykelonnFraMaaned: fraMaaned,
  }
}

export type Sykelonnsfunn = {
  maaneder: EasyatworkMaaned[]
  /** Mønsteret som gjelder for serien. Styrer også de åpne månedene. */
  moenster: Sykelonnskilde
  /** Hvor mange avlagte måneder som faktisk lot seg måle. */
  maalte: number
  /** Av dem: hvor mange som viste forsinkelse. */
  forsinkede: number
}

/**
 * Velger sykelønn per måned ved å MÅLE mot regnskapet, ikke ved å anta.
 *
 * ===================================================================
 * DETTE ERSTATTER EN HARDKODET REGEL MED EN OBSERVASJON.
 *
 * Forrige runde flyttet sykelønna én måned, alltid, fordi det stemte på
 * juli 2026 til 48 øre. Men forsinkelsen er en PRAKSIS: regnskapskontoret
 * kan periodisere sykelønna hvis Kelsar ber om det. Skjer det, ville en
 * fast forskyvning flyttet den en måned for langt — hver måned, uten at
 * noe ble rødt, og med et tall som fortsatt så rimelig ut.
 *
 * Nå spør hver måned tallene sine. Endres praksisen, følger svaret etter
 * av seg selv, og `moenster` sier hva som faktisk skjer i stedet for hva
 * vi trodde i september.
 *
 * ÅPNE MÅNEDER ARVER MØNSTERET. De har intet regnskap å måles mot, så de
 * følger det de avlagte viste. Er praksisen i endring, retter de seg
 * etter hvert som månedene lukkes — som er den rette rekkefølgen: en åpen
 * måned er en gjetning uansett.
 * ===================================================================
 */
export function medOppdagetSykelonn(
  raa: EasyatworkMaaned[],
  regnskapSykelonn: Map<string, number>,
): Sykelonnsfunn {
  const per = new Map(raa.map((m) => [m.maaned, m]))
  const forrigeKr = (maaned: string) =>
    per.get(forrigeMaaned(maaned))?.perKonto[SYKEKONTO] ?? 0

  const funn = raa.map((m) => sykelonnskilde(
    regnskapSykelonn.get(m.maaned) ?? null,
    m.perKonto[SYKEKONTO] ?? 0,
    forrigeKr(m.maaned),
  ))

  const antall = (k: Sykelonnskilde) => funn.filter((x) => x === k).length
  const forsinkede = antall('forrige_maaned')
  const samme = antall('samme_maaned')
  const moenster: Sykelonnskilde = forsinkede > samme
    ? 'forrige_maaned'
    : samme > 0 ? 'samme_maaned' : 'ukjent'

  const maaneder = raa.map((m, i) => {
    const kilde = funn[i] === 'ukjent' ? moenster : funn[i]
    if (kilde !== 'forrige_maaned') return m
    const kildeMaaned = per.get(forrigeMaaned(m.maaned))
    return medSykelonn(m, kildeMaaned?.perKonto[SYKEKONTO] ?? 0, kildeMaaned?.maaned ?? null)
  })

  return { maaneder, moenster, maalte: forsinkede + samme, forsinkede }
}

/**
 * Legger fastlønna inn fra regnskapet.
 *
 * ===================================================================
 * DEN ENE POSTEN EASY@WORK ALDRI KAN SE.
 *
 * En fastlønnet stempler ikke for å få betalt. Hen dukker ikke opp med
 * null i eksporten — hen dukker ikke opp i det hele tatt, og fraværet
 * er usynlig: anslaget ser ut som en komplett stasjon, bare billigere.
 * På Bønes er lederens fastlønn 27 % av lønnskosten.
 *
 * Men regnskapet HAR tallet, på konto 501, for hver avlagt måned. Og
 * fastlønn er fast — det er nettopp det som gjør den til fastlønn. Da
 * er sist kjente verdi et godt anslag for den åpne måneden, ikke en
 * gjetning.
 *
 * MÅNEDEN STÅR PÅ RADEN. Er tallet båret fram fra en tidligere måned,
 * er det en antakelse — en som slutter eller ansettes bryter den — og
 * en antakelse som ikke sier fra er den farligste sorten. Er måneden
 * avlagt, brukes dens EGEN 501, og da er det ingen antakelse igjen.
 *
 * Ingen fastlønn i regnskapet betyr null her, ikke «ukjent»: en stasjon
 * uten konto 501 har ingen fastlønnede. Dale er en slik.
 * ===================================================================
 */
export function medFastlonn(
  maaneder: EasyatworkMaaned[],
  regnskapFastlonn: Map<string, number>,
  /**
   * Grunnloenn eieren har lagt inn, per maaned (0185).
   *
   * BRUKES BARE DER REGNSKAPET IKKE HAR SVART. Konto 501 er faktisk
   * foert loenn og vinner alltid; det oppgitte tallet fyller maaneden som
   * ikke er avlagt, der alternativet er aa baere sist kjente framover.
   *
   * Paaslagene legges paa her, ikke ved innlegging: eieren taster
   * grunnloenn, systemet regner feriepenger og avgift. Endres satsene,
   * skal ingen taste inn paa nytt.
   */
  oppgittGrunnlonn: Map<string, number> = new Map(),
): EasyatworkMaaned[] {
  // Nyeste først, saa «sist kjente» er den foerste som finnes.
  const kjente = [...regnskapFastlonn.entries()].sort((a, b) => b[0].localeCompare(a[0]))

  return maaneder.map((m) => {
    const egen = regnskapFastlonn.get(m.maaned)
    // BAERES BARE BAKOVER I TID. En maaned som mangler 501 skal arve fra
    // en TIDLIGERE maaned, aldri fra en senere - ellers ville en gammel
    // maaned faatt dagens loenn, og serien sett ut som om ingen hadde
    // faatt loennsoekning.
    const baaret = egen === undefined
      ? kjente.find(([maaned]) => maaned < m.maaned)
      : undefined
    // OPPGITT SLAAR BAARET, MEN ALDRI REGNSKAPET.
    //
    // Rekkefoelgen er graden av sikkerhet: maanedens egen 501 er fasit,
    // en oppgitt grunnloenn er sann for maaneden men ikke avstemt, og
    // sist kjente 501 er en antakelse som brytes av en loennsoekning.
    const oppgitt = egen === undefined ? oppgittGrunnlonn.get(m.maaned) : undefined
    const fastlonnKr = egen ?? oppgitt ?? baaret?.[1] ?? 0
    const kilde: EasyatworkMaaned['fastlonnKilde'] = egen !== undefined
      ? 'regnskap'
      : oppgitt !== undefined ? 'oppgitt' : baaret ? 'baaret' : null
    const fraMaaned = egen !== undefined || oppgitt !== undefined
      ? m.maaned
      : baaret?.[0] ?? null
    if (fastlonnKr === 0) {
      return { ...m, fastlonnKr: 0, fastlonnFraMaaned: fraMaaned, fastlonnKilde: kilde }
    }

    const kontantKr = m.kontantKr + fastlonnKr
    const feriepengerKr = kontantKr * (SATSER.feriepengerPst / 100)
    const pensjonKr = kontantKr * (SATSER.pensjonPst / 100)
    const agaKr = (kontantKr + feriepengerKr) * (SATSER.agaPst / 100)

    return {
      ...m,
      perKonto: { ...m.perKonto, [FASTKONTO]: rund(fastlonnKr) },
      kontantKr: rund(kontantKr),
      feriepengerKr: rund(feriepengerKr),
      pensjonKr: rund(pensjonKr),
      agaKr: rund(agaKr),
      lonnskostKr: rund(kontantKr + feriepengerKr + agaKr),
      fastlonnKr: rund(fastlonnKr),
      fastlonnFraMaaned: fraMaaned,
      fastlonnKilde: kilde,
    }
  })
}

/**
 * Hva anslaget ikke kan se. Vises ved siden av tallet, ikke i en fotnote.
 *
 * REKKEFØLGEN ER MÅLT, IKKE GJETTET. Fastlønn sto først her, fordi det
 * er den som kan skjule en hel person. Målt på Dale juli 2026 er det
 * sykelønna som faktisk mangler — 28 896 av et gap på 28 998, altså
 * 99,6 %. Stasjonen har ingen konto 501 i det hele tatt. * SYKELØNNA ER IKKE PÅ LISTA, OG DET ER EN RETTELSE.
 *
 * Den sto her i to runder — først som «en langtidssykmeldt uten
 * vaktplan», så som «stopper ved dag 16». Begge beskrev noe sant om
 * eksporten, men ingen av dem var forklaringen på avviket. Det var en
 * PERIODISERING: regnskapet fører sykelønna måneden etter, og
 * `medSykelonnsforskyvning()` flytter den nå. Julis avvik falt fra
 * 30 086 kroner til 373.
 *
 * At sykelønn etter dag 16 mangler i eksporten er fortsatt sant — men
 * den mangler i regnskapet også, fordi NAV betaler den. To kilder som
 * begge utelater det samme har ikke et avvik.
 *
 * Det som står igjen er ekte, og lite: fastlønn om stasjonen har noen,
 * faste tillegg som ikke er en arbeidet time, og bonus. Målt på Dale
 * juli 2026 er hele resten 373 kroner av 441 172 — 0,08 %.
 */
export const MANGLER = [
  'faste tillegg som ikke er en arbeidet time (konto 502), for eksempel mobildekning',
  'bonus (konto 509)',
] as const
