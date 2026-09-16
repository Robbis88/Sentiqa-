import 'server-only'
import type { SupabaseClient } from '@supabase/supabase-js'
import type {
  Ansattregister, AnsattUtenSats, Betalingsfrekvens,
} from '@/lib/parsere/lonnsgrunnlag'
import { hentAlle } from '@/lib/supabase/sider'

// =====================================================================
// REGISTERET: hvem easy@work kjente, og hva de kostet per time.
//
// ---------------------------------------------------------------------
// HVORFOR DEN FINNES
//
// `beregnArbeidssted` priser timer fra Basis Export, og trenger en sats
// per ansatt. Satsen står i lønnsgrunnlaget — og ble KASTET ved import:
// `lesLonnsgrunnlag` bruker den til å regne `belop_kr` og skriver den
// aldri. Motoren kunne derfor bare kjøre på filer i hånden, aldri på
// det som ligger i basen.
//
// `0218` ga satsen et sted å bo. Denne fila leser den ut igjen i den
// formen motoren allerede tar (`Ansattregister`), så koblingen ikke
// krever at motoren endres.
//
// ---------------------------------------------------------------------
// ET REGISTER ER EN KILDEOBSERVASJON, IKKE HR-MASTERDATA
//
// Raden sier hva EN FIL FOR EN STASJON I EN MÅNED oppga. Den sier ikke
// hva som er sant om ansettelsesforholdet. Derfor leses den alltid med
// måneden i hånden: målt over de 23 kontrollfilene endret satsen seg
// for 1 av 70 personer i løpet av sju måneder (Dale, 143,34 → 185,58
// mellom mai og juni 2026). Sjelden er ikke aldri, og en julisats som
// priser april gir et tall som ser helt normalt ut.
//
// ---------------------------------------------------------------------
// OPPSLAGET GÅR PÅ TVERS AV STASJONER, MED VILJE
//
// Carmen står i Lones julifil med 0 timer og sats 138, samtidig som hun
// jobbet 79,82 timer på Bønes. Skal Bønes' timer prises, må Bønes få
// lese Lones registerrad. Det er nettopp derfor `0218` har indeksen
// `(ansatt_nr, kilde_maaned)` og ikke bare den unike nøkkelen.
// =====================================================================

type Klient = SupabaseClient

const MAANED = /^\d{4}-\d{2}$/

/** Hva én stasjons fil oppga om én person i én måned. */
export type Registerrad = {
  stasjonId: string
  ansattNr: string
  navn: string
  /** `null` = fila navnga personen, men oppga ingen brukbar sats. */
  timesats: number | null
  /**
   * Enheten paa `timesats`, slik easy@work oppga den for maaneden.
   *
   * `null` betyr UKJENT - enten en rad skrevet foer `0220`, eller en
   * verdi kilden ga som vi ikke kjenner igjen. Aldri det samme som
   * `time`.
   */
  betalingsfrekvens: Betalingsfrekvens | null
}

/**
 * Samme nummer, to ulike svar — fra to stasjoner, i samme måned.
 *
 * ---------------------------------------------------------------------
 * RETTET 2026-09-16: 1018 ER IKKE ET EKSEMPEL PÅ DETTE
 *
 * Her sto det at nummer 1018 «MÅLT I PRODUKSJON» pekte på Andre
 * Fjørstad (Varden) og Marietta Iacovou (Bønes) i juli 2026. Nummeret
 * peker faktisk på to personer — men ikke på den måten denne typen
 * fanger, og ikke i denne tabellen.
 *
 * Målt mot produksjon 2026-09-16 har `lonnsregister` NULL rader på
 * 1018; registeret inneholder bare Lone. Målt mot de 27 ekte
 * lønnsgrunnlagene finnes 1018 på ÉN stasjon — Bønes, Marietta, 239,33.
 * Det er Basis Export som fører 1018 som «Andre Fjørstad» på Varden i
 * juli, med 54,50 timer.
 *
 * Motsetningen går altså mellom REGISTERET og BASIS, ikke mellom to
 * registerrader, og `tvetydige` treffer den derfor aldri. Vetoet som
 * fanger den bor i `lonnskost/identitet.ts` og heter `motstrid('navn')`.
 *
 * Fenomenet denne typen beskriver — samme nummer i to stasjoners
 * register, samme måned — er ALDRI observert i de 27 filene. Den er en
 * vakt uten kanarifugl, og det skal stå skrevet til den får en.
 *
 * `ansatt_nr` er uansett en kildereferanse, ikke en personidentitet.
 */
export type Tvetydig = {
  ansattNr: string
  kandidater: Registerrad[]
}

export type Registerhenting = {
  /**
   * Til motoren, i den formen den allerede tar.
   *
   * `null` når måneden ikke har noe register i det hele tatt. Da skal
   * `beregnArbeidssted` få NULL registre og kaste sin egen feil — et
   * TOMT register ville prist ingenting og rapportert hver eneste time
   * som ukoblet, altså sett ut som en stasjon uten ansatte.
   */
  register: Ansattregister | null
  /**
   * Numre to stasjoner oppga ULIKT for samme måned.
   *
   * De er holdt UTE av `register.ansatte`. En sats valgt på måfå ville
   * gitt Andres timer Mariettas pris — og resultatet melder seg selv
   * som `komplett`. Uprisbar er synlig; feilpriset er det ikke.
   */
  tvetydige: Tvetydig[]
}

const sisteDag = (maaned: string): string => {
  const [aar, mnd] = maaned.split('-').map(Number)
  // Dag 0 i neste måned er siste dag i denne. UTC, så en sommertidssone
  // ikke flytter datoen et døgn.
  const d = new Date(Date.UTC(aar, mnd, 0))
  return d.toISOString().slice(0, 10)
}

/**
 * Registeret for én måned, på tvers av stasjonene kalleren ber om.
 *
 * `stasjonIder` snevrer inn, aldri ut: RLS gir butikksjefen sine egne
 * stasjoner og eieren kjeden, og denne lista kan bare velge blant dem.
 * Tom liste betyr «hele kjeden slik RLS ser den».
 */
export async function hentRegister(
  supabase: Klient,
  maaned: string,
  stasjonIder: readonly string[] = [],
): Promise<Registerhenting> {
  if (!MAANED.test(maaned)) {
    throw new Error(`Ugyldig måned «${maaned}». Forventet yyyy-mm.`)
  }

  // SIDER, IKKE ETT KALL. PostgREST kutter ved tusen rader uten feil og
  // uten noe i svaret som sier at det var mer - og et avkortet register
  // ser ut som en stasjon med faerre ansatte, ikke som en feil. Fem
  // stasjoner ganger tjue ansatte er hundre rader i dag; det er nettopp
  // naar det slutter aa vaere sant at dette betyr noe.
  const data = await hentAlle<{
    stasjon_id: string; ansatt_nr: string; navn: string
    timesats: number | string | null; betalingsfrekvens: string | null
  }>(() => {
    const q = supabase
      .from('lonnsregister')
      .select('stasjon_id, ansatt_nr, navn, timesats, betalingsfrekvens')
      .eq('kilde_maaned', maaned)
    return stasjonIder.length > 0 ? q.in('stasjon_id', stasjonIder) : q
  })

  const rader: Registerrad[] = (data ?? []).map((r) => ({
    stasjonId: r.stasjon_id as string,
    ansattNr: r.ansatt_nr as string,
    navn: r.navn as string,
    timesats: r.timesats === null ? null : Number(r.timesats),
    // Basen har et check-constraint paa de to verdiene, saa en annen
    // verdi kan ikke finnes. Sjekken staar likevel: en kolonne kan
    // utvides i en senere migrasjon uten at denne lesingen blir roed.
    betalingsfrekvens: r.betalingsfrekvens === 'time' || r.betalingsfrekvens === 'maaned'
      ? r.betalingsfrekvens
      : null,
  }))
  if (rader.length === 0) return { register: null, tvetydige: [] }

  // Grupper på nummeret. Den unike nøkkelen er (stasjon, måned, nr), så
  // to rader på samme nummer her betyr alltid to STASJONER.
  const perNr = new Map<string, Registerrad[]>()
  for (const r of rader) {
    const liste = perNr.get(r.ansattNr)
    if (liste) liste.push(r)
    else perNr.set(r.ansattNr, [r])
  }

  const ansatte: Ansattregister['ansatte'] = []
  const utenSats: AnsattUtenSats[] = []
  const tvetydige: Tvetydig[] = []

  for (const [ansattNr, kandidater] of perNr) {
    const prisbare = kandidater.filter((k) => k.timesats !== null)

    if (kandidater.length > 1) {
      // Sier stasjonene NØYAKTIG det samme, er det én person som jobber
      // to steder — fenomen D, og helt legitimt. Da er det ikke tvetydig.
      //
      // MERK: grenen er aldri utløst av ekte data. Målt over 27
      // lønnsgrunnlag står ingen nummer i to stasjoners register i samme
      // måned, og produksjonsregisteret har bare Lone. A1-porten i
      // `lonnskost/identitet.ts` velger derfor motsatt — der er to
      // kandidater alltid `motstrid('kollisjon')`. Hvilken av de to som
      // skal gjelde når motoren kobles, avgjøres i B2d; til da er dette
      // urørt med vilje.
      const navn = new Set(kandidater.map((k) => k.navn.trim().toLowerCase()))
      const satser = new Set(kandidater.map((k) => k.timesats))
      if (navn.size > 1 || satser.size > 1) {
        tvetydige.push({ ansattNr, kandidater })
        continue
      }
    }

    if (prisbare.length > 0) {
      const v = prisbare[0]
      ansatte.push({
        ansattNr,
        ansattNavn: v.navn,
        timesats: v.timesats as number,
        betalingsfrekvens: v.betalingsfrekvens,
        // Registeret bærer ikke hovedlokasjon — den hører til fila, og
        // motoren bruker den ikke til å prise. Hjemstasjonen er nettopp
        // det trinn 1 sluttet å lytte til.
        hovedlokasjon: '',
      })
    } else {
      const v = kandidater[0]
      utenSats.push({
        ansattNr,
        ansattNavn: v.navn,
        hovedlokasjon: '',
        raaSats: '',
        betalingsfrekvens: v.betalingsfrekvens,
      })
    }
  }

  return {
    register: {
      fraDato: `${maaned}-01`,
      tilDato: sisteDag(maaned),
      ansatte,
      utenSats,
      konflikter: [],
    },
    tvetydige,
  }
}
