import type { Rapporttype } from '@/lib/parsere/typer'

// =====================================================================
// EN FIL MED FIRE AV FEM STASJONER SER HELT FRISK UT
//
// 26. og 27. august 2026 manglet Laguneparken i St1s egne eksporter -
// baade 0018 Kassererstatistikk og 0603 Timesalg. Rapportene var BESTILT
// for alle fem butikknumrene; svaret inneholdt fire.
//
// Importen hadde ingenting aa reagere paa. Fila var gyldig, parseren fant
// stasjonene den fant, radene ble lagret, og jobben meldte «parset». Den
// eneste feilen var noe som IKKE var der.
//
// `umatchet` fanger det motsatte tilfellet - en stasjon i fila vi ikke
// kjenner - og har gjort det lenge. Dette er speilbildet, og det er det
// farligste av de to: en ukjent stasjon roper, en manglende tier.
//
// HVORFOR IKKE SPERRE FILA. St1 sender ofte hele klyngen, og en kjede kan
// ha en stasjon som var stengt. En import som nekter aa fullfoere ville
// stoppet fire riktige stasjoner for aa markere den femte. Merknaden er
// nok - `/dekning` er stedet som teller dager.
//
// GJELDER BARE DATASETT SOM KOMMER EN FIL PER DAG. Samme tre som
// `v_datohull` (migrasjon 0159): regnskapet er maanedlig, BP-en aarlig, og
// svinn foeres naar noe kastes. For dem er en stasjon uten rader normalt.
// =====================================================================

export type Stasjon = { id: string; navn: string; butikknummer: string }

/**
 * Rapporttypene der ALLE stasjoner skal vaere med i hver fil.
 *
 * Speiler `datasett`-lista i migrasjon 0159. Faller en type ut her, blir
 * den heller ikke maalt - derfor har `stasjonsdekning.test.ts` en
 * kanarifugl paa at lista ikke er tom.
 */
export const DAGLIGE: readonly Rapporttype[] = [
  'st1_salgsstatistikk',
  'st1_salesperhour_inneute',
  'st1_cashierstats',
]

export const erDaglig = (t: Rapporttype): boolean => DAGLIGE.includes(t)

/**
 * Stasjonene kjeden har, men som ikke fikk en eneste rad fra denne fila.
 *
 * `truffet` er stasjons-id-ene lagringen faktisk skrev noe for. Tom liste
 * betyr at ingen traff, og da er alle savnet — det er riktig, men den
 * saken fanges allerede av at `antallRader` er null.
 */
export function manglendeStasjoner(truffet: Iterable<string>, kjente: Stasjon[]): Stasjon[] {
  const har = new Set(truffet)
  return kjente.filter((s) => !har.has(s.id))
}

/**
 * Merknaden, eller null naar alt er med.
 *
 * NAVN OG NUMMER, IKKE ET ANTALL. «1 stasjon mangler» tvinger den som
 * leser til å gjette hvilken, og da blir merknaden noe man ser bort fra.
 */
export function dekningsnotat(mangler: Stasjon[]): string | null {
  if (mangler.length === 0) return null
  const liste = mangler
    .slice()
    .sort((a, b) => a.butikknummer.localeCompare(b.butikknummer))
    .map((s) => `${s.navn} (${s.butikknummer})`)
    .join(', ')
  const ord = mangler.length === 1 ? 'stasjon' : 'stasjoner'
  return `${mangler.length} ${ord} ikke med i fila: ${liste}. `
    + 'Sjekk om rapporten ble hentet for alle stasjoner.'
}
