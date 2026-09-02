// =====================================================================
// EN BP-MÅNED SOM BLE HOPPET OVER SKAL SES
//
// `lagreBp` skriver ikke `bp_*`-linjer for måneder som alt er avlagt i
// regnskapet. Det er RIKTIG: en avlagt måned bærer sitt eget budsjett,
// og det er det kjeden måler mot — en senere revisjon av BP-en kan ikke
// endre en lukket måned.
//
// Men det skjedde i stillhet. Importen meldte «parset», radtallet så
// riktig ut, og ingen fikk vite at halve året lå utenfor.
//
// DET ER GRUNNEN TIL AT BP MÅ LASTES OPP FØR REGNSKAPET — en regel som
// bare har bodd i hodet på den som visste. Laster en ny kjede opp i
// motsatt rekkefølge, får de en ramme uten de månedene, og siden ser
// like ferdig ut.
//
// Samme form som `utenEan` og stasjonsdekningen: en stille utelatelse er
// verre enn en synlig merknad.
// =====================================================================

export type Hoppet = { stasjon: string; maaneder: number[] }

const MND = ['januar', 'februar', 'mars', 'april', 'mai', 'juni',
  'juli', 'august', 'september', 'oktober', 'november', 'desember']

/**
 * Merknaden om måneder som ikke fikk BP-linjer, eller null når alle kom med.
 *
 * NAVNGIR MÅNEDENE, IKKE BARE ANTALLET. «6 måneder hoppet over» tvinger
 * leseren til å gjette hvilke, og da blir merknaden noe man ser bort fra
 * — samme grunn som i `stasjonsdekning.ts`.
 *
 * Er ALLE månedene hoppet over for alle stasjoner, sies det med egne ord:
 * da er BP-en i praksis uten virkning, og det er en annen sak enn at et
 * par måneder alt var avlagt.
 */
export function hoppetNotat(hoppede: Hoppet[], maanederIFila: number): string | null {
  const med = hoppede.filter((h) => h.maaneder.length > 0)
  if (med.length === 0) return null

  const alle = maanederIFila > 0 && med.every((h) => h.maaneder.length >= maanederIFila)
  const liste = med
    .slice()
    .sort((a, b) => a.stasjon.localeCompare(b.stasjon))
    .map((h) => {
      const m = h.maaneder.slice().sort((x, y) => x - y).map((n) => MND[n - 1] ?? String(n))
      return `${h.stasjon} (${m.join(', ')})`
    })
    .join(' · ')

  return alle
    ? `Ingen av månedene fikk BP-tall — alle er alt avlagt i regnskapet. `
      + `Regnskapet bærer budsjettet for dem. ${liste}`
    : `Måneder som alt var avlagt beholdt regnskapets eget budsjett: ${liste}. `
      + 'Det er riktig — men last opp BP før regnskapet hvis tallene skal komme fra BP-en.'
}
