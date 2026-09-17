import { sammeSak, type RegnskapVarsel, type Signalsak, type VarselNiva } from './regnskap-varsler'

// =====================================================================
// FENOMENET: SAMME OBSERVASJON, FLERE STASJONER
// =====================================================================
//
// Eierens forside melder «14 ting å se på», og fem av kortene heter
// «4177 St1 Lone», «4185 St1 Dale» … Stasjonsnavn er ikke en sak. Det er
// en adresse.
//
// Målt i produksjon 2026-09-16, etter at `sak` bevarte strukturen:
//
//   5 av 5   usynlig_manko   varegruppe 160 «160 Kioskvarer»    rod
//   5 av 5   usynlig_manko   varegruppe 140 «140 Kald drikke»   rod/gul
//   5 av 5   synlig_kast     varegruppe 120 «120 Mat»           gul
//   1 av 5   lonn_over_budsjett                                 Dale
//
// Tre av de fem «kritiske» kortene var den samme observasjonen, fordelt
// på fem stasjoner. Og Dales lønn var Dales — ikke kjedens.
//
// Denne fila uttrykker forskjellen. Den forklarer den ikke.
//
// ---------------------------------------------------------------------
// KOMPRIMERING AV OBSERVASJONER, IKKE ÅRSAKSANALYSE
// ---------------------------------------------------------------------
//
// «Kioskvarer · usynlig manko · 5 av 5 stasjoner» er lov.
// «Felles problem i Kioskvarer» er det ikke.
// «Samme årsak på fem stasjoner» er det ikke.
//
// Modellen kan ikke uttrykke de to siste, og det er med vilje: en
// påstand om årsak krever en motor som eier den, og den finnes ikke.
//
// ---------------------------------------------------------------------
// FEM TING DENNE FILA ALDRI GJØR
// ---------------------------------------------------------------------
//
//   1  SUMMERER KRONER. `usynlig_kr` er teknisk addbart, men en
//      kjedesum ville vært et nytt økonomisk tall ingen motor eier — og
//      `nettMotposter` finnes nettopp fordi rå summer villeder. Beløpet
//      blir hos stasjonen, i `underliggende`.
//
//   2  MUTERER ET UNDERLIGGENDE VARSEL. De bæres videre som de er.
//      `nivaa` på aggregatet er en AVLESNING av det høyeste — aldri en
//      oppgradering. En gul stasjon står gul i drilldownen selv om en
//      annen stasjon gjør fenomenet rødt.
//
//   3  LESER TEKST. Identiteten er `sak`, satt av `regnskap-varsler.ts`
//      før tittelen formateres. Stasjonen kommer inn som et felt, ikke
//      som `omfang` parset tilbake.
//
//   4  KREVER FLERE STASJONER. Et fenomen med én stasjon er et gyldig
//      fenomen. «Lønn over budsjett · 1 av 5» er like sant som
//      «Kioskvarer · 5 av 5». Utvalget hører i presentasjonen; en
//      eksistensregel her ville gjort én stasjons problem usynlig i
//      sannhetsmodellen.
//
//   5  RANGERER. Ingen poengformel, ingen terskel, ingen kombinasjon av
//      nivå og utbredelse. `nivaa`, utbredelse og de underliggende
//      tallene er SEPARATE sannheter til noen eksplisitt bestemmer en
//      regel som forener dem.
// =====================================================================

/**
 * Ett varsel, med stasjonen det gjelder.
 *
 * STASJONEN KOMMER INN, DEN UTLEDES IKKE. `RegnskapVarsel.omfang` bærer
 * stasjonsnavnet som tekst, og tekst er ikke en nøkkel — to stasjoner
 * kan hete det samme i to kjeder, og et navn kan endres. Kallstedet
 * kjenner id-en; da skal den følge med.
 */
export type Stasjonsvarsel = {
  stasjonId: string
  stasjonsnavn: string
  varsel: RegnskapVarsel
}

export type Fenomenstasjon = {
  stasjonId: string
  stasjonsnavn: string
  /** Stasjonens EGET nivå. Aldri hevet av aggregatet. */
  nivaa: VarselNiva
}

export type Fenomen = {
  /**
   * Hva slags observasjon dette er.
   *
   * `null` når varselet manglet struktur — se `Signalsak`. Et slikt
   * fenomen har alltid nøyaktig én stasjon: `sammeSak(null, null)` er
   * usann, så to ukjente slås aldri sammen til én haug som ser ut som
   * ett fenomen.
   */
  sak: Signalsak | null
  /** Stasjonene som har den, i den rekkefølgen de kom inn. */
  stasjoner: Fenomenstasjon[]
  /**
   * Hvor mange stasjoner brukeren i det hele tatt ser.
   *
   * RLS-POPULASJONEN, IKKE KJEDEN. «5 av 5» må bety det samme for den
   * som leser det. En butikksjef med to tildelte stasjoner har `2` her,
   * og hennes «2 av 2» er like sant som eierens «5 av 5» — de svarer
   * bare på hver sin populasjon.
   */
  avTotalt: number
  /**
   * Høyeste nivå blant de underliggende.
   *
   * EN AVLESNING, IKKE EN OPPGRADERING. `stasjoner[i].nivaa` og
   * `underliggende[i].nivaa` står urørt; er én stasjon rød og fire gule,
   * er fenomenet rødt og de fire fortsatt gule.
   */
  nivaa: VarselNiva
  /** Varslene som ble slått sammen, uendret. */
  underliggende: RegnskapVarsel[]
}

/** `rod` slår `gul`. Det finnes ikke flere nivåer. */
const verst = (a: VarselNiva, b: VarselNiva): VarselNiva =>
  (a === 'rod' || b === 'rod' ? 'rod' : 'gul')

/**
 * Samme observasjon på tvers av stasjonene brukeren ser.
 *
 * REKKEFØLGEN ER INNGANGENS, IKKE EN RANGERING. Fenomenene kommer ut i
 * den rekkefølgen sakene første gang ble sett. Skal de rangeres, gjør
 * kallstedet det — og da må det være en bevisst regel, ikke et biprodukt
 * av hvilken stasjon som ble lest først.
 *
 * @param varsler stasjonsvarsler. Selskapsvarsler (`omfang: 'Selskap'`)
 *   hører ikke hjemme her: de har ingen stasjon, og `avTotalt` ville
 *   vært meningsløs for dem.
 * @param avTotalt brukerens autoriserte stasjoner. Fra `mine_stasjoner()`
 *   gjennom kallstedet — aldri kjedens totale antall.
 */
export function byggFenomener(
  varsler: readonly Stasjonsvarsel[],
  avTotalt: number,
): Fenomen[] {
  const ut: Fenomen[] = []

  for (const { stasjonId, stasjonsnavn, varsel } of varsler) {
    // `sammeSak` er `regnskap-varsler.ts` sin. Den gjentas ikke her —
    // én sammenligning, ett sted. `null` matcher aldri noe, heller ikke
    // en annen `null`, så et varsel uten struktur får alltid sitt eget
    // fenomen.
    const f = varsel.sak === null
      ? undefined
      : ut.find((x) => sammeSak(x.sak, varsel.sak))

    if (f) {
      f.stasjoner.push({ stasjonId, stasjonsnavn, nivaa: varsel.nivaa })
      f.underliggende.push(varsel)
      f.nivaa = verst(f.nivaa, varsel.nivaa)
      continue
    }

    ut.push({
      sak: varsel.sak,
      stasjoner: [{ stasjonId, stasjonsnavn, nivaa: varsel.nivaa }],
      avTotalt,
      nivaa: varsel.nivaa,
      underliggende: [varsel],
    })
  }

  return ut
}

/**
 * Utbredelsen, som tekst — «5 av 5 stasjoner».
 *
 * =====================================================================
 * UTBREDELSE ER IKKE ALVOR
 * =====================================================================
 *
 * «5 av 5» er ny og viktig informasjon, og den er fristende å lese som
 * «verre». Den er det ikke: et gult fenomen på fem stasjoner er ikke
 * automatisk viktigere enn et rødt på én. `nivaa` og utbredelse er to
 * sannheter, og de forenes ikke her.
 *
 * Funksjonen formaterer. Den dømmer ikke.
 *
 * ---------------------------------------------------------------------
 * ÉN AV ÉN ER IKKE EN OPPLYSNING
 * ---------------------------------------------------------------------
 *
 * Har brukeren bare én stasjon, er «1 av 1 stasjoner» støy som later som
 * den er innsikt — og butikksjefens flate skal ikke bli et kjedebilde
 * med én rad. Da er svaret `null`, og kallstedet skriver ingenting.
 */
export function utbredelse(f: Fenomen): string | null {
  if (f.avTotalt <= 1) return null
  return `${f.stasjoner.length} av ${f.avTotalt} stasjoner`
}
