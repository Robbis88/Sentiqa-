import { describe, expect, test } from 'vitest'
import { readdirSync, readFileSync } from 'node:fs'
import { join } from 'node:path'

// =====================================================================
// Kan migrasjonen i det hele tatt parses?
//
// HVORFOR DENNE FINNES. 0113 lå på utklippstavla, klar til å limes inn i
// produksjon, med en `budsjett`-CTE som hadde mistet hele
// `select … from …`-kroppen sin under en redigering. Igjen sto
// kommentaren og to `and`-linjer uten noe å henge på:
//
//     budsjett as (
//       -- UTELATTE KODER: drivstoff (10), pant (250) …
//       and r.kode not in ('10', '250', '40')
//
// `utelatte-koder.test.ts` var GRØNN på den fila. Den leter etter
// `not in (...)` og fant dem — filteret sto der, det var bare ingen
// spørring rundt det. Testen målte innholdet i en setning som ikke
// fantes.
//
// Feilen ble ikke funnet av noen vakt. Den ble funnet av Postgres, i
// SQL Editor, av mennesket som limte inn.
//
// DENNE VAKTEN ER IKKE EN SQL-PARSER, og skal ikke bli det. Den stiller
// ett spørsmål som er billig å svare på og som fanger nettopp den
// klassen feil en tekstredigering lager: forsvant kroppen ut av en CTE?
// Migrasjoner kjøres manuelt, én gang, mot produksjon. Da er «den kan
// ikke kjøres» noe vi skal vite før innlimingen, ikke etter.
// =====================================================================

const KATALOG = join(process.cwd(), 'supabase', 'migrations')

/**
 * CTE-er i en fil som ikke inneholder et `select`.
 *
 * Kommentarer strippes først — en `select` nevnt i en kommentar er ikke
 * en spørring, og uten strippingen ville nettopp den ødelagte 0113-fila
 * sluppet gjennom på ordet «spørringen» i en kommentar.
 */
export function cteUtenSelect(sql: string): { navn: string, linje: number }[] {
  const linjer = sql.split(/\r?\n/)
  const funn: { navn: string, linje: number }[] = []

  let navn: string | null = null
  let dybde = 0
  let harSelect = false
  let start = 0

  linjer.forEach((rad, i) => {
    const ren = rad.replace(/--.*$/, '')

    if (navn === null) {
      // `budsjett as (` eller `with naa as (` — åpningen alene på linja.
      const m = ren.match(/^\s*(?:with\s+)?([a-z_][a-z0-9_]*)\s+as\s*\(\s*$/i)
      if (m) {
        navn = m[1]
        dybde = 1
        harSelect = false
        start = i + 1
      }
      return
    }

    if (/\bselect\b/i.test(ren)) harSelect = true

    dybde += (ren.match(/\(/g) ?? []).length - (ren.match(/\)/g) ?? []).length
    if (dybde <= 0) {
      if (!harSelect) funn.push({ navn, linje: start })
      navn = null
    }
  })

  return funn
}

describe('migrasjonene kan parses', () => {
  const filer = readdirSync(KATALOG).filter((n) => n.endsWith('.sql')).sort()

  test('det finnes migrasjoner å sjekke', () => {
    // Peker KATALOG feil, blir sløyfa under tom og hele vakten grønn
    // uten å ha sett en eneste fil. En vakt som slutter å se, ser
    // nøyaktig ut som en vakt som ikke finner noe.
    expect(filer.length, `fant ingen .sql i ${KATALOG}`).toBeGreaterThan(100)
  })

  test('KANARIFUGL: den ekte 0113-feilen felles', () => {
    // Dette ER fila som lå på utklippstavla, forkortet. Slutter
    // kontrollen å måle, blir denne grønn og sier fra.
    const odelagt = [
      'create or replace view public.v_bp_status_avdeling as',
      'with naa as (',
      '  select max(dato) as siste_dato from public.v_butikksalg',
      '),',
      'budsjett as (',
      '  -- UTELATTE KODER: drivstoff (10), pant (250) og grand total (40).',
      "  -- utelatte_koder := array['10', '250', '40']",
      "    and r.kode not in ('10', '250', '40')",
      '  group by r.stasjon_id, r.periode, r.kode',
      '),',
      'salg as (',
      '  select v.stasjon_id from public.v_butikksalg v',
      ')',
      'select 1',
    ].join('\n')

    expect(cteUtenSelect(odelagt).map((f) => f.navn)).toEqual(['budsjett'])
  })

  test.each(filer)('%s: hver CTE har en spørring i seg', (fil) => {
    const funn = cteUtenSelect(readFileSync(join(KATALOG, fil), 'utf8'))
    const beskjed = funn
      .map((f) => `  ${fil}:${f.linje}  «${f.navn} as (» har ingen select`)
      .join('\n')

    expect(funn, `\n${beskjed}\n`).toEqual([])
  })
})
