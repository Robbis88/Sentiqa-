// =====================================================================
// Dekker kontraktene planen du nettopp la?
//
// `eksponering.ts` måler bakover: hvem HAR jobbet mer enn papirene sine.
// Da er avviket allerede skjedd, og § 14-4 a-kravet er allerede modnet.
// Dette måler samme sak forlengs, på planen — mens den fortsatt kan
// endres, og mens en kontrakt fortsatt kan skrives i tide.
//
// Spørsmålet er ikke «har vi nok folk». Det er «har vi nok PAPIR».
// Planen kan godt være gjennomførbar med de menneskene som finnes —
// stasjonen ringer noen inn, alle stiller opp, og gulvet blir dekket.
// Regningen kommer et helt annet sted: timene ble jobbet uten at
// kontrakten dekket dem.
//
// Tre utfall, og de krever ulikt papir. Det er den samme tredelingen som
// bakoverblikket bruker, og den må være den samme — ellers sier de to
// sidene av systemet forskjellige ting om samme forhold:
//
//   ÉN MÅNED over        ekstravakter. RAMMEAVTALE om tilkalling.
//   FLERE PÅ RAD         sesong. MIDLERTIDIGE avtaler for perioden.
//   SPREDT / HELE ÅRET   stillingene er for små. ØK dem.
//
// Å øke faste stillinger fordi juli er travel er dyrt alle tolv
// månedene. Å la være å skrive midlertidig avtale er en risiko hver
// sommer. Forskjellen er verdt å regne på.
// =====================================================================

import { sammenhengendeKjede } from './eksponering'

/** 100 % = 37,5 t/uke ≈ 162,5 t/mnd. Samme tall som ellers i systemet. */
export const TIMER_100 = 162.5

// Under dette er avviket støy. En plan som treffer kontraktsrammen på ti
// timer i måneden er ikke et papirproblem — det er en vanlig uke.
const MONN_TIMER = 10

export type Kontraktansatt = {
  ansattNr: string
  navn: string
  /** Bekreftet stillingsprosent. null = ingen kontrakt å måle mot. */
  kontraktProsent: number | null
  harRammeavtale: boolean
}

export type Maanedsbehov = {
  maned: number
  /** Timene planen trenger av timelønnede denne måneden. */
  timer: number
  /**
   * Kontraktstimer som faller bort fordi noen har ferie eller er borte.
   *
   * Uten denne blir sommeren feil vei: juli er den travleste måneden OG
   * den med mest ferie, og teller man full kapasitet begge veier, ser
   * juli dekket ut mens den i praksis er den strammeste måneden i året.
   */
  borteTimer?: number
}

export type Maanedsdekning = {
  maned: number
  behov: number
  kapasitet: number
  /** Positivt = planen trenger mer enn kontraktene dekker. */
  udekket: number
}

export type Tiltak =
  | 'ukjent_grunnlag'  // for mange uten bekreftet kontrakt til å svare
  | 'dekket'           // kontraktene bærer planen
  | 'ramme'            // én måned over — rammeavtale om tilkalling
  | 'midlertidig'      // sammenhengende sesong — midlertidige avtaler
  | 'ny_stilling'      // spredt eller hele året — stillingene er for små

export type Plandekning = {
  maaneder: Maanedsdekning[]
  /** Timelønnede uten bekreftet stillingsprosent. */
  utenKontrakt: string[]
  kontraktTimer: number
  /** Månedene der planen går ut over kontraktene. */
  korte: number[]
  /** Sammenhengende kjede, når de korte månedene henger sammen. */
  sesong: number[] | null
  /** Største enkeltavvik — det er den måneden man kjenner det. */
  verstMaaned: number | null
  sumUdekket: number
  tiltak: Tiltak
  melding: string
}

const MND = ['januar', 'februar', 'mars', 'april', 'mai', 'juni',
  'juli', 'august', 'september', 'oktober', 'november', 'desember']

const dagerI = (ar: number, maned: number) => new Date(Date.UTC(ar, maned, 0)).getUTCDate()

/**
 * Hvor mye kontraktskapasitet ferie og fravær spiser, måned for måned.
 *
 * Bare de timelønnede med kontrakt teller. Er butikksjefen borte, blir
 * det ikke MINDRE behov for timelønnede — det blir mer, fordi den faste
 * vakten hans slutter å dekke gulvet. Den effekten ligger allerede i
 * planen; her ville den blitt trukket fra en gang til, med motsatt
 * fortegn.
 *
 * Fraværet kobles på navn, som er den nøkkelen fraværslista har.
 */
export function borteTimerPerMaaned(
  fravaer: { navn: string; fraDato: string; tilDato: string }[],
  ansatte: Kontraktansatt[],
  ar: number,
): Map<number, number> {
  const prosentFor = new Map(
    ansatte
      .filter((a) => a.kontraktProsent != null)
      .map((a) => [a.navn.trim().toLowerCase(), a.kontraktProsent!]))

  const ut = new Map<number, number>()
  for (const f of fravaer) {
    const prosent = prosentFor.get(f.navn.trim().toLowerCase())
    if (prosent == null) continue
    const fra = new Date(`${f.fraDato}T00:00:00Z`)
    const til = new Date(`${f.tilDato}T00:00:00Z`)
    if (Number.isNaN(fra.getTime()) || Number.isNaN(til.getTime()) || til < fra) continue

    for (let m = 1; m <= 12; m++) {
      const mStart = Date.UTC(ar, m - 1, 1)
      const mSlutt = Date.UTC(ar, m - 1, dagerI(ar, m))
      const start = Math.max(mStart, fra.getTime())
      const slutt = Math.min(mSlutt, til.getTime())
      if (slutt < start) continue
      const dager = (slutt - start) / 86400000 + 1
      const tapt = (prosent / 100) * TIMER_100 * (dager / dagerI(ar, m))
      ut.set(m, (ut.get(m) ?? 0) + tapt)
    }
  }
  return ut
}

const listeOpp = (m: number[]) => {
  const navn = m.map((x) => MND[x - 1])
  if (navn.length === 1) return navn[0]
  return `${navn.slice(0, -1).join(', ')} og ${navn.at(-1)}`
}

/**
 * Måler planen mot kontraktene, måned for måned.
 *
 * Bare bekreftede stillingsprosenter teller. Et anslag fra stemplingene
 * duger til å planlegge med, men ikke til å svare på om papirene holder
 * — anslaget ER jo nettopp de timene som kanskje ble jobbet uten dekning.
 */
export function plandekning(
  ansatte: Kontraktansatt[],
  behov: Maanedsbehov[],
): Plandekning {
  const bekreftet = ansatte.filter((a) => a.kontraktProsent != null)
  const utenKontrakt = ansatte.filter((a) => a.kontraktProsent == null).map((a) => a.navn)
  const kontraktTimer = bekreftet
    .reduce((s, a) => s + (a.kontraktProsent! / 100) * TIMER_100, 0)

  const maaneder: Maanedsdekning[] = behov.map((b) => {
    const kapasitet = Math.max(0, kontraktTimer - (b.borteTimer ?? 0))
    return {
      maned: b.maned,
      behov: b.timer,
      kapasitet,
      udekket: Math.max(0, b.timer - kapasitet),
    }
  })

  const korte = maaneder.filter((m) => m.udekket > MONN_TIMER).map((m) => m.maned)
  const sumUdekket = maaneder.reduce((s, m) => s + m.udekket, 0)
  const verst = maaneder.reduce<Maanedsdekning | null>(
    (v, m) => (v === null || m.udekket > v.udekket ? m : v), null)
  const verstMaaned = verst && verst.udekket > MONN_TIMER ? verst.maned : null
  const sesong = sammenhengendeKjede(korte)

  const felles = { maaneder, utenKontrakt, kontraktTimer, korte, sesong, verstMaaned, sumUdekket }

  // Uten bekreftede kontrakter er kapasiteten et gjett, og et gjett skal
  // ikke gi et råd om å skrive kontrakter. Spørsmålet stilles i stedet.
  if (bekreftet.length === 0 || utenKontrakt.length > bekreftet.length) {
    return {
      ...felles,
      tiltak: 'ukjent_grunnlag',
      melding: utenKontrakt.length === 0
        ? 'Ingen ansatte å måle mot ennå.'
        : `${utenKontrakt.length} av ${ansatte.length} timelønnede mangler bekreftet `
          + 'stillingsprosent. Bekreft dem først — kapasiteten er et gjett så lenge, '
          + 'og et gjett skal ikke utløse en kontraktsendring.',
    }
  }

  if (korte.length === 0) {
    return {
      ...felles,
      tiltak: 'dekket',
      melding: `Kontraktene dekker planen alle tolv månedene (${Math.round(kontraktTimer)} `
        + 'timer i måneden bekreftet).',
    }
  }

  if (korte.length === 1) {
    return {
      ...felles,
      tiltak: 'ramme',
      melding: `Planen trenger ${Math.round(maaneder.find((m) => m.maned === korte[0])!.udekket)} `
        + `timer mer enn kontraktene dekker i ${MND[korte[0] - 1]}, og bare den ene måneden. `
        + 'Det er ekstravakter, ikke en for liten stab — men uten rammeavtale om '
        + 'tilkalling kan de timene senere kreves som overtid. '
        + `${ansatte.filter((a) => !a.harRammeavtale).length} av ${ansatte.length} mangler den.`,
    }
  }

  if (sesong) {
    return {
      ...felles,
      tiltak: 'midlertidig',
      melding: `Planen går ut over kontraktene i ${listeOpp(sesong)} — `
        + `${Math.round(sumUdekket)} timer til sammen, og månedene henger sammen. `
        + 'Det er sesong, ikke for små stillinger. Skriv midlertidige avtaler for '
        + 'perioden framfor å øke de faste, som ellers koster alle tolv månedene.',
    }
  }

  return {
    ...felles,
    tiltak: 'ny_stilling',
    melding: `Planen går ut over kontraktene i ${korte.length} måneder som ikke henger `
      + `sammen (${listeOpp(korte)}), til sammen ${Math.round(sumUdekket)} timer. `
      + 'Spredt over året er det ikke sesong — stillingene er for små. Øk dem, eller '
      + 'ansett. Etter aml. § 14-4 a kan de som faktisk går timene kreve det uansett.',
  }
}
