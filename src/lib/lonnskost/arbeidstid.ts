import 'server-only'
import type { SupabaseClient } from '@supabase/supabase-js'
import { hentAlle } from '@/lib/supabase/sider'

// =====================================================================
// ARBEIDSTIDEN: hva easy@work så at folk faktisk gjorde.
//
// `basisvakt` (0219) er Easys egen observasjon av arbeidstid, bevart
// per stasjonsmåned. Denne fila leser den ut igjen. Den regner ingenting
// og forkaster ingenting.
//
// ---------------------------------------------------------------------
// LESEREN ER IKKE STEDET DER ARBEID FORSVINNER
//
// Fire regler, og ingen av dem er forhandlingsbare:
//
//   AVVISTE RADER RETURNERES. `avvik_grunn != null` filtreres ALDRI
//   bort. En vakt parseren ikke kunne lese er en ukjent kostnad, ikke
//   fravær av kostnad. B2d gjør måneden `minimum` på grunnlag av dem —
//   men bare hvis den får se dem.
//
//   UBETALTE RADER RETURNERES OGSÅ, med `betalt` intakt. Pause og
//   ubetalt tid er ikke kostnad og skal ikke prises, men totalene for
//   måneden skal kunne vises. Filtreringen hører hjemme der beslutningen
//   tas, ikke her.
//
//   DØGNKRYSS BEHOLDER BEGGE DATOENE. `dato` er forretningsdatoen —
//   det er slik kronefila grupperer, og de to må være enige for at
//   målingen skal bety noe. `fraDato` er datoen arbeidet BEGYNTE, og
//   det er den tilleggsfordelingen skal bruke. Målt: 28 døgnkryssende
//   rader, 13 av 193 på Laguneparken august = 6,7 %.
//
//   MINUTTER ER GRUNNLAGET, `lengde_timer` ER OBSERVASJONEN. Låst etter
//   måling over fem kontrollmåneder: de to er ikke til å skille fra
//   hverandre (største bom 2,280 % mot 2,270 %), og da vinner
//   intervallet fordi det kan etterprøves mot klokkeslettene.
//
// ---------------------------------------------------------------------
// SIDER, IKKE ETT KALL
//
// PostgREST kutter ved tusen rader uten å feile og uten noe i svaret som
// sier at det var mer. Laguneparken august alene er 193 rader; en kjede
// med fem stasjoner i en travel måned passerer tusen uten at noen legger
// merke til det. Et avkortet grunnlag ser ut som en rolig måned.
// =====================================================================

type Klient = SupabaseClient

const MAANED = /^\d{4}-\d{2}$/

/** Én rad fra `basisvakt`, uendret. */
export type Arbeidsrad = {
  /** Stasjonen hvis FIL bar raden. Tenantnøkkelen. */
  stasjonId: string
  kildeMaaned: string
  /**
   * Arbeidsstedet slik raden oppgir det, f.eks. «St1 - Bønes».
   *
   * Kan avvike fra `stasjonId` — det er hele grunnen til at `basisvakt`
   * finnes. Carmen står i Lones fil og arbeidet på Bønes.
   */
  lokasjon: string
  ansattNr: string
  ansattNavn: string
  /** Forretningsdatoen: den Easy fører vakten på. */
  dato: string
  /** Datoen arbeidet BEGYNTE. Lik `dato` for alt annet enn døgnkryss. */
  fraDato: string
  fraTid: string
  tilTid: string
  /** Intervallet. BEREGNINGSGRUNNLAGET. */
  minutter: number
  /** Easys eget timetall. Kildeobservasjon og kontroll, aldri grunnlag. */
  lengdeTimer: number | null
  betalt: boolean
  /** `null` = brukbar vakt. Ellers er raden ikke prisbar arbeidstid. */
  avvikGrunn: 'lengde' | 'lokasjon' | null
  /** Proveniens: hvilken import som skrev raden. */
  importJobbId: string | null
}

export type Arbeidstidsmaaned = {
  maaned: string
  /** Alt, uten filtrering. Avviste og ubetalte inkludert. */
  rader: Arbeidsrad[]
  /** Minutter som er betalt OG uten avvik. Det B2d senere kan prise. */
  prisbareMinutter: number
  /** Betalte minutter på rader med `avvik_grunn`. Kjent, ikke prisbart. */
  avvisteMinutter: number
  /** Betalte minutter totalt, uansett avvik. */
  betalteMinutter: number
  /** Unike ansattnumre som har minst én betalt rad. */
  personer: string[]
}

// EN LITERAL, IKKE EN SAMMENSATT STRENG. supabase-js utleder radtypen av
// select-lista, og en `'a, ' + 'b'` gjoer den til GenericStringError.
const VELG = 'stasjon_id, kilde_maaned, lokasjon, ansatt_nr, ansatt_navn, dato, fra_dato, fra_tid, til_tid, minutter, lengde_timer, betalt, avvik_grunn, import_jobb_id'

const avvik = (v: unknown): Arbeidsrad['avvikGrunn'] =>
  v === 'lengde' || v === 'lokasjon' ? v : null

/**
 * Arbeidstiden for én måned, på tvers av stasjonene kalleren ber om.
 *
 * `null` når måneden ikke har én eneste rad. Et TOMT objekt ville sett
 * ut som en stasjon der ingen jobbet, og det er noe annet enn en
 * stasjon vi ikke har arbeidstid for.
 *
 * `stasjonIder` snevrer inn, aldri ut: RLS gir butikksjefen sine egne
 * stasjoner og eieren kjeden, og denne lista kan bare velge blant dem.
 */
export async function hentArbeidstid(
  supabase: Klient,
  maaned: string,
  stasjonIder: readonly string[] = [],
): Promise<Arbeidstidsmaaned | null> {
  if (!MAANED.test(maaned)) {
    throw new Error(`Ugyldig måned «${maaned}». Forventet yyyy-mm.`)
  }

  type Raa = {
    stasjon_id: string; kilde_maaned: string; lokasjon: string
    ansatt_nr: string; ansatt_navn: string; dato: string
    fra_dato: string; fra_tid: string; til_tid: string
    minutter: number; lengde_timer: number | string | null
    betalt: boolean; avvik_grunn: string | null; import_jobb_id: string | null
  }
  const data = await hentAlle<Raa>(() => {
    const q = supabase
      .from('basisvakt')
      .select(VELG)
      .eq('kilde_maaned', maaned)
    return stasjonIder.length > 0 ? q.in('stasjon_id', stasjonIder) : q
  })

  const rader: Arbeidsrad[] = (data ?? []).map((r) => ({
    stasjonId: r.stasjon_id,
    kildeMaaned: r.kilde_maaned,
    lokasjon: r.lokasjon,
    ansattNr: r.ansatt_nr,
    ansattNavn: r.ansatt_navn,
    dato: String(r.dato).slice(0, 10),
    fraDato: String(r.fra_dato).slice(0, 10),
    fraTid: String(r.fra_tid).slice(0, 5),
    tilTid: String(r.til_tid).slice(0, 5),
    minutter: Number(r.minutter),
    lengdeTimer: r.lengde_timer === null || r.lengde_timer === undefined
      ? null
      : Number(r.lengde_timer),
    betalt: r.betalt === true,
    avvikGrunn: avvik(r.avvik_grunn),
    importJobbId: r.import_jobb_id ?? null,
  }))

  if (rader.length === 0) return null

  let prisbare = 0
  let avviste = 0
  let betalte = 0
  const personer = new Set<string>()
  for (const r of rader) {
    if (!r.betalt) continue
    betalte += r.minutter
    personer.add(r.ansattNr)
    if (r.avvikGrunn === null) prisbare += r.minutter
    else avviste += r.minutter
  }

  return {
    maaned,
    rader,
    prisbareMinutter: prisbare,
    avvisteMinutter: avviste,
    betalteMinutter: betalte,
    personer: [...personer].sort(),
  }
}
