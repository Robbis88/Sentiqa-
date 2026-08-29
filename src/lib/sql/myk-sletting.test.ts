import { describe, it, expect } from 'vitest'
import { readFileSync, readdirSync, statSync } from 'node:fs'
import { join } from 'node:path'

// =====================================================================
// SPOERRINGENE HAANDHEVER LIVSSYKLUS, RLS HAANDHEVER TENANT
//
// `slettet_tid` sto i SELECT-policyene på nitten tabeller, og gjorde to
// jobber: skjulte slettede rader, og blokkerte sin egen soft delete. En
// UPDATE som SETTER `slettet_tid` fikk 42501, fordi den nye raden ikke
// lenger var synlig for den som skrev den.
//
// Ingen kunne slette et målekort fra mai til 2026-08-29.
//
// `0154` tok vilkåret ut av policyene. Da er spørringene det eneste som
// skiller slettet fra ikke-slettet — og en glemt `.is('slettet_tid',
// null)` viser slettede rader i en liste, uten at noe sier fra.
//
// ---------------------------------------------------------------------
// HVORFOR EN VAKT OG IKKE BARE EN OPPRYDDING
//
// 62 av 80 lesninger filtrerte allerede da regelen ble skrevet. Den var
// altså praksis, bare ikke håndhevet — og en praksis uten vakt forfaller
// stille. De femten som manglet ble rettet samtidig; denne fila er det
// som gjør at nummer seksten ikke slipper inn.
// =====================================================================

/** Tabellene `0154` tok `slettet_tid` ut av SELECT-policyen på. */
const UTEN_POLICYVERN = [
  'malekort', 'ansatte', 'rutiner', 'rutineskjemaer', 'oppgaver',
  'sjekkpunkter', 'konkurranser', 'merker', 'lenker', 'kunnskap',
  'anvisninger', 'arrangementer', 'kalender_kilder', 'ik_kontrollpunkter',
  'puls_runde', 'puls_sporsmal', 'opplaering_oppgave', 'plattform_innlegg',
  'tablet_meldinger',
]

const SRC = join(process.cwd(), 'src')

function kildefiler(katalog: string): string[] {
  const ut: string[] = []
  for (const navn of readdirSync(katalog)) {
    const sti = join(katalog, navn)
    if (statSync(sti).isDirectory()) ut.push(...kildefiler(sti))
    else if (/\.tsx?$/.test(navn) && !/\.test\.tsx?$/.test(navn)) ut.push(sti)
  }
  return ut
}

/**
 * Lesninger mot tabellen som ikke filtrerer bort slettede rader.
 *
 * VINDUET ER FIRE LINJER, ikke bare linja selv: kjeden brytes over flere
 * linjer i det meste av kodebasen, og en sjekk på samme linje ville meldt
 * nesten hver eneste lesning.
 *
 * Skrivinger hoppes over — `.insert(...).select('id')` er ikke en
 * lesning som trenger filter, og det var nettopp den formen som ga en
 * falsk positiv da hullene ble talt første gang.
 */
export function ufiltrerteLesninger(kilde: string, tabell: string): number[] {
  const linjer = kilde.split('\n')
  const ut: number[] = []
  let fra = 0
  for (;;) {
    const i = kilde.indexOf(`.from('${tabell}')`, fra)
    if (i < 0) break
    fra = i + 1
    const lnr = kilde.slice(0, i).split('\n').length - 1
    const vindu = linjer.slice(lnr, lnr + 4).join('\n')
    if (!/\.select\(/.test(vindu)) continue
    if (/\.(insert|upsert|update|delete)\(/.test(vindu)) continue
    if (/slettet_tid/.test(vindu)) continue
    ut.push(lnr + 1)
  }
  return ut
}

const treff = kildefiler(SRC).flatMap((f) => {
  const kilde = readFileSync(f, 'utf8')
  return UTEN_POLICYVERN.flatMap((t) =>
    ufiltrerteLesninger(kilde, t).map(
      (l) => `${f.slice(SRC.length + 1).replace(/\\/g, '/')}:${l}  (${t})`))
})

describe('lesninger mot tabeller uten policyvern', () => {
  it('filtrerer alle bort slettede rader selv', () => {
    expect(
      treff,
      'En lesning uten `.is(\'slettet_tid\', null)`:\n' + treff.join('\n') + '\n\n'
      + 'Policyen filtrerer dem ikke lenger — den ble tatt ut i 0154 fordi '
      + 'den blokkerte sin egen soft delete. Etter det er spørringen det '
      + 'eneste som skiller slettet fra ikke-slettet.',
    ).toEqual([])
  })

  it('KANARIFUGL: den kjenner igjen en lesning uten filter', () => {
    // Slutter mønsteret å treffe, blir lista tom — og «ingen hull» ser
    // nøyaktig ut som «alt er ryddet».
    expect(ufiltrerteLesninger(
      "const { data } = await supabase.from('ansatte').select('id, navn')", 'ansatte'))
      .toEqual([1])
  })

  it('KANARIFUGL: den godtar en som filtrerer', () => {
    expect(ufiltrerteLesninger(
      "supabase.from('ansatte').select('id')\n  .is('slettet_tid', null)", 'ansatte'))
      .toEqual([])
  })

  it('KANARIFUGL: en skriving er ikke en lesning', () => {
    // `.insert(...).select('id')` returnerer den nye raden. Den trenger
    // ikke filter, og ga en falsk positiv første gang hullene ble talt.
    expect(ufiltrerteLesninger(
      "supabase.from('malekort').insert({ navn })\n  .select('id')", 'malekort'))
      .toEqual([])
  })

  it('KANARIFUGL: den leser en kodebase som finnes', () => {
    expect(kildefiler(SRC).length).toBeGreaterThan(100)
  })
})

describe('0154 dekker de samme tabellene som vakten', () => {
  it('hver tabell i lista faar en ny policy i migrasjonen', () => {
    // Uten dette kunne lista her og migrasjonen skilt lag: en tabell
    // fjernet fra 0154 ville fortsatt krevd filter i hver spørring, og en
    // tabell lagt til i 0154 ville stått uten vakt.
    const sql = readFileSync(
      join(process.cwd(), 'supabase/migrations/0154_myk_sletting_virker.sql'), 'utf8')
    const iMigrasjonen = [...sql.matchAll(/^create policy \S+ on public\.(\w+)/gm)]
      .map((m) => m[1])
    expect(iMigrasjonen.sort()).toEqual([...UTEN_POLICYVERN].sort())
  })
})
