// =====================================================================
// ER DAGENS TALL RIMELIG?
//
// 25. august 2026 ble importert for Laguneparken med 8 rader og 676 kr.
// Nabotirsdagene lå på 37 000–39 000. Dagen fantes, statusen var grønn,
// stasjonen og datoen var riktige, og 97 % av radene manglet.
//
// Ingenting i Sentiqa kunne se det:
//
//   /dekning        ser at dagen FINNES, ikke hva den inneholder
//   importloggen    sa «parset», for parsingen gikk fint
//   dublettsjekken  regner 8 rader som en vellykket import
//
// Det ble oppdaget fordi Robert sammenlignet en månedsfil fra St1 mot
// Sentiqa for hånd. Uten den fila hadde de 44 578 kronene ligget der.
//
// ---------------------------------------------------------------------
// HVORFOR UKEDAGSMEDIAN, OG IKKE FJORÅRET
//
// Mot fjoråret er for støyende: kampanjer, vær, helligdager og
// prisendringer flytter en enkeltdag 30–40 % helt legitimt. En vakt som
// roper hver 17. mai blir slått av.
//
// Stasjonens egen median for SAMME UKEDAG er langt strammere. Målt på
// Laguneparken i august 2026:
//
//   tirsdager   38 974 · 38 388 · 37 158        spredning under 5 %
//   søndager    92 376 · 74 315 · 91 659 ·
//               108 273 · 101 430              spredning ca. ±20 %
//
// Søndagene er 2,5× en tirsdag. Hadde vi sammenlignet mot ukesnittet,
// ville hver søndag sett ut som et avvik og hver tirsdag som normal —
// og en halvert tirsdag ville druknet.
//
// Median og ikke gjennomsnitt: nettopp en ødelagt dag som 25. august
// skal ikke få lov til å dra grunnlaget ned for de neste.
// ---------------------------------------------------------------------

/** Én dag med butikkomsetning for én stasjon. */
export type Dag = { dato: string; kroner: number }

export type Funn = {
  dato: string
  kroner: number
  median: number
  /** Negativt = under medianen. -0.98 betyr 98 % lavere. */
  avvik: number
  slag: 'for_lavt' | 'for_hoyt'
  grunnlag: number
  tekst: string
}

/**
 * Under dette regnes dagen som mistenkelig lav.
 *
 * 0,5 = halvparten av medianen. Robert foreslo 50 %, og målingene over
 * viser at det er trygt: den strammeste ukedagen varierer under 5 %, den
 * løseste rundt 20 %. Ekte stengt eller halv dag er sjeldent, og skal
 * uansett kvitteres — ikke skjules.
 */
const FOR_LAVT = 0.5

/**
 * Over dette er dagen mistenkelig høy.
 *
 * Den fanger en annen ekte feil: Salgsstatistikk kan lastes ned som en
 * MÅNEDSFIL («Dato: 01.08.2026 - 31.08.2026»), og importøren leser første
 * dato i den linja. Hele måneden ville da havnet på 1. august — omtrent
 * 30 ganger en normal dag. 4× er langt over enhver ekte topp (den
 * travleste søndagen i august lå 2,5× over en tirsdag) og godt under 30×.
 */
const FOR_HOYT = 4

/** Færre enn dette å sammenligne med, og vi vet for lite til å dømme. */
const MINSTE_GRUNNLAG = 3

/** Hvor mange uker bakover vi ser etter samme ukedag. */
export const UKER_TILBAKE = 8

function median(tall: number[]): number {
  const s = [...tall].sort((a, b) => a - b)
  const m = Math.floor(s.length / 2)
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2
}

const ukedag = (iso: string) => new Date(`${iso}T12:00:00Z`).getUTCDay()

const kr = new Intl.NumberFormat('nb-NO', { maximumFractionDigits: 0 })
const UKEDAGSNAVN = ['søndag', 'mandag', 'tirsdag', 'onsdag', 'torsdag', 'fredag', 'lørdag']

/**
 * Vurderer én dag mot stasjonens egne tidligere dager med samme ukedag.
 *
 * `historikk` skal være dager FØR `dag` — funksjonen filtrerer selv, men
 * kallstedet bør ikke sende framtiden inn og håpe.
 *
 * Returnerer `null` når det ikke er noe å si fra om: dagen er normal,
 * eller grunnlaget er for tynt til å ha en mening.
 */
export function vurderDag(dag: Dag, historikk: Dag[]): Funn | null {
  const d = ukedag(dag.dato)
  const sammenlignbare = historikk
    .filter((h) => h.dato < dag.dato && ukedag(h.dato) === d)
    .sort((a, b) => (a.dato < b.dato ? 1 : -1))
    .slice(0, UKER_TILBAKE)

  // FOR TYNT GRUNNLAG ER IKKE ET FUNN.
  //
  // En ny stasjon, eller de første ukene etter oppstart, har ingenting
  // å sammenligne med. Å rope da ville gjort vakten til støy akkurat
  // når noen setter opp Sentiqa for første gang — og det er da folk
  // bestemmer seg for om varsler er verdt å lese.
  if (sammenlignbare.length < MINSTE_GRUNNLAG) return null

  const m = median(sammenlignbare.map((h) => h.kroner))
  if (m <= 0) return null

  const forhold = dag.kroner / m
  const avvik = forhold - 1

  if (forhold >= FOR_LAVT && forhold <= FOR_HOYT) return null

  const navn = UKEDAGSNAVN[d]
  const pst = Math.round(Math.abs(avvik) * 100)
  const felles = `${dag.dato}: ${kr.format(Math.round(dag.kroner))} kr mot `
    + `${kr.format(Math.round(m))} kr, som er medianen for de siste `
    + `${sammenlignbare.length} ${navn}ene.`

  return {
    dato: dag.dato,
    kroner: dag.kroner,
    median: m,
    avvik,
    grunnlag: sammenlignbare.length,
    slag: forhold < FOR_LAVT ? 'for_lavt' : 'for_hoyt',
    tekst: forhold < FOR_LAVT
      ? `${pst} % lavere enn normalt. ${felles} Sjekk om hele filen kom inn.`
      : `${pst} % høyere enn normalt. ${felles} Sjekk om dagen er `
        + 'importert to ganger, eller om en månedsfil er lastet opp på én dato.',
  }
}

/** Vurderer flere dager samtidig — hver mot historikken før seg. */
export function vurderDager(dager: Dag[], historikk: Dag[]): Funn[] {
  const alle = [...historikk, ...dager]
  return dager
    .map((d) => vurderDag(d, alle))
    .filter((f): f is Funn => f !== null)
}
