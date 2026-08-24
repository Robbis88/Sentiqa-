// =====================================================================
// Perioder for AI-verktøyene.
//
// PORT 0: ingen verktøy tok fra–til. Alt var én dag, én måned eller ett
// år, og datoen kom fra `max(dato)` i tabellen framfor fra spørsmålet.
// «Hittil i år» og «denne uka» fantes ikke som spørsmål i det hele tatt.
//
// Her ligger den ene normaliseringen alle verktøyene deler, slik at to
// kilder kan møtes på samme akse og faktisk krysses.
//
// KOMPLETT ER IKKE PYNT. En periode som strekker seg til i dag kan ikke
// vurderes ferdig, og et svar som ikke sier fra om det inviterer til en
// konklusjon dataene ikke bærer.
// =====================================================================

export type Opplosning = 'dag' | 'maaned' | 'aar'

export type Periode = {
  fra: string
  til: string
  opplosning: Opplosning
  komplett: boolean
}

export type Periodeinput = {
  fra?: string
  til?: string
  /** YYYY-MM. Utvides til hele måneden. */
  maaned?: string
  /** YYYY. Utvides til hele året. */
  aar?: string | number
}

const ISO_DATO = /^\d{4}-\d{2}-\d{2}$/
const ISO_MAANED = /^\d{4}-\d{2}$/

/** Dagens dato i Europe/Oslo som YYYY-MM-DD. All tid i Sentiqa er norsk tid. */
export function idagOslo(naa: Date = new Date()): string {
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Oslo' }).format(naa)
}

function sisteDagIMaaned(aar: number, maaned1: number): string {
  // Dag 0 i neste måned = siste dag i denne. UTC hele veien, så vi ikke
  // sklir en dag på sommertid.
  const d = new Date(Date.UTC(aar, maaned1, 0))
  return d.toISOString().slice(0, 10)
}

export function leggTilDager(dato: string, dager: number): string {
  const d = new Date(`${dato}T00:00:00Z`)
  d.setUTCDate(d.getUTCDate() + dager)
  return d.toISOString().slice(0, 10)
}

/**
 * Normaliserer det modellen ba om til en konkret periode, og avgjør om
 * den er ferdig. Returnerer `{ feil }` framfor å gjette når inndata er
 * ubrukelig — et verktøy som gjetter perioden svarer på feil spørsmål.
 */
export function lagPeriode(
  inn: Periodeinput,
  idag: string,
  standard?: Periodeinput,
): Periode | { feil: string } {
  const kilde =
    inn.fra || inn.til || inn.maaned || inn.aar != null ? inn : (standard ?? inn)

  let fra: string
  let til: string
  let opplosning: Opplosning

  if (kilde.aar != null && !kilde.maaned && !kilde.fra) {
    const aar = Number(kilde.aar)
    if (!Number.isInteger(aar) || aar < 2000 || aar > 2100) {
      return { feil: `Ugyldig årstall: ${kilde.aar}` }
    }
    fra = `${aar}-01-01`
    til = `${aar}-12-31`
    opplosning = 'aar'
  } else if (kilde.maaned) {
    if (!ISO_MAANED.test(kilde.maaned)) {
      return { feil: `Ugyldig måned: ${kilde.maaned}. Bruk YYYY-MM.` }
    }
    const [a, m] = kilde.maaned.split('-').map(Number)
    if (m < 1 || m > 12) return { feil: `Ugyldig måned: ${kilde.maaned}.` }
    fra = `${kilde.maaned}-01`
    til = sisteDagIMaaned(a, m)
    opplosning = 'maaned'
  } else {
    fra = kilde.fra ?? kilde.til ?? idag
    til = kilde.til ?? kilde.fra ?? idag
    if (!ISO_DATO.test(fra)) return { feil: `Ugyldig fra-dato: ${fra}. Bruk YYYY-MM-DD.` }
    if (!ISO_DATO.test(til)) return { feil: `Ugyldig til-dato: ${til}. Bruk YYYY-MM-DD.` }
    opplosning = 'dag'
  }

  if (fra > til) return { feil: `fra (${fra}) er etter til (${til}).` }

  // Komplett når hele perioden ligger bak oss. Dagens tall er ikke inne
  // ennå — importen kjører i etterkant — så «til i dag» er ufullstendig.
  return { fra, til, opplosning, komplett: til < idag }
}

/** Månedene en periode dekker, som YYYY-MM-01 — nøkkelen regnskapet bruker. */
export function manederIPeriode(p: Periode): string[] {
  const ut: string[] = []
  const [fraA, fraM] = p.fra.split('-').map(Number)
  const [tilA, tilM] = p.til.split('-').map(Number)
  for (let a = fraA; a <= tilA; a++) {
    const m0 = a === fraA ? fraM : 1
    const m1 = a === tilA ? tilM : 12
    for (let m = m0; m <= m1; m++) ut.push(`${a}-${String(m).padStart(2, '0')}-01`)
  }
  return ut
}

/** Hittil i år fram til i går — standardperioden for «hvordan ligger vi an». */
export function hittilIAar(idag: string): Periode {
  const aar = idag.slice(0, 4)
  const til = leggTilDager(idag, -1)
  return {
    fra: `${aar}-01-01`,
    til: til < `${aar}-01-01` ? `${aar}-01-01` : til,
    opplosning: 'dag',
    komplett: false,
  }
}
