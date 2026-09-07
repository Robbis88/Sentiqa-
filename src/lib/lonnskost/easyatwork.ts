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
  '96': '502', // 50 % overtidstillegg
  '97': '502', // 100 % overtidstillegg
  '1410': '502', // Helligdagstillegg
  '1429': '502', // Tillegg hverdag 18-21
  '1430': '502', // Tillegg hverdag 21-24
  '1431': '502', // Tillegg hverdag 00-06
  '1432': '502', // Tillegg lørdag
  '1433': '502', // Tillegg søndag 00-06
  '1434': '502', // Tillegg søndag 06-18
  '1435': '502', // Tillegg søndag 18-24
}

/** Arten som bærer arbeidede timer. Tilleggene teller de SAMME timene. */
const TIMEART = '2'

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
  /** Kontantlønn + feriepenger + pensjon + aga. */
  lonnskostKr: number
  /** Lønnsarter uten konto. Skal være tom. */
  ukjenteArter: string[]
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
    const agaKr = (kontantKr + feriepengerKr + pensjonKr) * (SATSER.agaPst / 100)

    ut.push({
      maaned,
      timer: rund(timer),
      kontantKr: rund(kontantKr),
      perKonto,
      feriepengerKr: rund(feriepengerKr),
      pensjonKr: rund(pensjonKr),
      agaKr: rund(agaKr),
      lonnskostKr: rund(kontantKr + feriepengerKr + pensjonKr + agaKr),
      ukjenteArter: [...ukjente].sort(),
    })
  }

  return ut.sort((a, b) => b.maaned.localeCompare(a.maaned))
}

/** Hva anslaget ikke kan se. Vises ved siden av tallet, ikke i en fotnote. */
export const MANGLER = [
  'fastlønn (konto 501)',
  'refundert sykelønn (konto 506)',
  'bonus (konto 509)',
] as const
