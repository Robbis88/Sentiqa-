import { describe, it, expect } from 'vitest'
import { zipSync, strToU8 } from 'fflate'
import { ParserFeil } from './felles'
import {
  butikknummer,
  lesBilagsbuffer,
  summerPerLeverandor,
  type Bilagslinje,
} from './bilagsbuffer'

// =====================================================================
// Pivotbufferen, bygget som den ser ut i Kelsars regnskapsfil.
// =====================================================================

const FELT = ['Butikk', 'Rapportlinje', 'Konto', 'Periode', 'Tekst', 'Beløp']

const DELTE: Record<string, string[]> = {
  Butikk: ['4177 ST1 Lone', '9145 ST1 Varden', '9900 Admin'],
  Rapportlinje: ['627 Renhold', '633 Forbruksmateriell'],
  Konto: ['6270 Renhold', '6570 Forbruksmateriell'],
  Periode: ['202606', '202607'],
}

function definisjon(felt = FELT): string {
  const f = felt.map((n) => {
    const d = DELTE[n]
    if (!d) return `<cacheField name="${n}" numFmtId="0"><sharedItems/></cacheField>`
    const items = d.map((v) => `<s v="${v}"/>`).join('')
    return `<cacheField name="${n}" numFmtId="0"><sharedItems count="${d.length}">${items}</sharedItems></cacheField>`
  }).join('')
  return `<?xml version="1.0"?><pivotCacheDefinition><cacheFields count="${felt.length}">${f}</cacheFields></pivotCacheDefinition>`
}

/** En rad: indekser i delte felter, inline for tekst og beløp. */
function r(butikk: number, linje: number, konto: number, periode: number, tekst: string, belop: number): string {
  return `<r><x v="${butikk}"/><x v="${linje}"/><x v="${konto}"/><x v="${periode}"/>`
    + `<s v="${tekst}"/><n v="${belop}"/></r>`
}

const RADER = [
  r(0, 0, 0, 1, 'ASKO VEST AS', 12000),
  r(0, 0, 0, 1, 'ASKO VEST AS', 5825),
  r(0, 0, 0, 1, 'Elis Norge AS', 3400),
  r(1, 0, 0, 1, 'ASKO VEST AS', 7207),
  r(0, 1, 1, 0, 'ASKO VEST AS', 9100),
  r(2, 0, 0, 1, 'Vask utearealer', 22050),
].join('')

function bok(rader = RADER, def = definisjon(), medBuffer = true): Uint8Array {
  const filer: Record<string, Uint8Array> = {
    'xl/workbook.xml': strToU8('<?xml version="1.0"?><workbook><sheets/></workbook>'),
  }
  if (medBuffer) {
    filer['xl/pivotCache/pivotCacheDefinition1.xml'] = strToU8(def)
    filer['xl/pivotCache/pivotCacheRecords1.xml'] =
      strToU8(`<?xml version="1.0"?><pivotCacheRecords>${rader}</pivotCacheRecords>`)
  }
  return zipSync(filer)
}

function les(data: Uint8Array): { linjer: Bilagslinje[]; meta: ReturnType<typeof lesBilagsbuffer> } {
  const linjer: Bilagslinje[] = []
  const meta = lesBilagsbuffer(data, (l) => linjer.push(l))
  return { linjer, meta }
}

describe('lesBilagsbuffer', () => {
  it('leser alle radene med leverandørnavn', () => {
    const { linjer, meta } = les(bok())
    expect(meta?.antall).toBe(6)
    expect(linjer[0]).toEqual({
      butikk: '4177 ST1 Lone',
      rapportlinje: '627 Renhold',
      konto: '6270 Renhold',
      periode: '202607',
      tekst: 'ASKO VEST AS',
      belopKr: 12000,
    })
  })

  it('rapporterer hvilke perioder fila bærer', () => {
    // Det er dette som gjoer at en enkelt maanedsfil viser seg aa baere
    // tolv maaneder.
    const { meta } = les(bok())
    expect(meta?.perioder).toEqual(['202606', '202607'])
  })

  it('gir null naar fila ikke har en pivotbuffer', () => {
    const { meta } = les(bok(RADER, definisjon(), false))
    expect(meta).toBeNull()
  })

  it('tar med admin, som ikke er en stasjon', () => {
    const { linjer } = les(bok())
    const adm = linjer.filter((l) => l.butikk === '9900 Admin')
    expect(adm).toHaveLength(1)
    expect(adm[0].tekst).toBe('Vask utearealer')
  })

  // ---- KANARIFUGLENE ------------------------------------------------
  //
  // Det finnes INGEN feltnavn i radene. Rekkefoelgen er hele koblingen,
  // og et felt som faller ut forskyver alt etter seg: beloepet blir en
  // dato, og tallene ser fortsatt ut som tall.

  it('KANARI: en rad med feil antall felter felles, ikke tolkes', () => {
    const kort = `<r><x v="0"/><x v="0"/><x v="0"/><x v="0"/><s v="ASKO"/></r>`
    expect(() => les(bok(kort))).toThrow(ParserFeil)
    expect(() => les(bok(kort))).toThrow(/Rekkef/)
  })

  it('KANARI: et manglende felt i definisjonen felles med navnet sitt', () => {
    const utenTekst = definisjon(FELT.filter((f) => f !== 'Tekst'))
    expect(() => les(bok(RADER, utenTekst))).toThrow(/Tekst/)
  })

  it('KANARI: feltrekkefoelgen leses av definisjonen, ikke antatt', () => {
    // Bytter om Konto og Periode i definisjonen OG i radene. Leses
    // posisjonen av navnet, gaar det bra; antas den, bytter kontoen og
    // perioden plass uten at noe roper.
    const byttet = ['Butikk', 'Rapportlinje', 'Periode', 'Konto', 'Tekst', 'Beløp']
    const def = definisjon(byttet)
    const rad = `<r><x v="0"/><x v="0"/><x v="1"/><x v="0"/><s v="ASKO VEST AS"/><n v="12000"/></r>`
    const { linjer } = les(bok(rad, def))
    expect(linjer[0].periode).toBe('202607')
    expect(linjer[0].konto).toBe('6270 Renhold')
  })
})

describe('summerPerLeverandor', () => {
  it('slaar sammen samme leverandoer paa samme konto og maaned', () => {
    const { linjer } = les(bok())
    const sum = summerPerLeverandor(linjer)
    const lone = sum.find((s) =>
      s.butikk === '4177 ST1 Lone' && s.tekst === 'ASKO VEST AS' && s.periode === '202607')
    expect(lone!.belopKr).toBe(17825)
    expect(lone!.antall).toBe(2)
  })

  it('antall er et eget signal, ikke pynt', () => {
    // Fire fakturaer fra samme leverandoer er en avtale, atten er en vane.
    const { linjer } = les(bok())
    expect(summerPerLeverandor(linjer).every((s) => s.antall >= 1)).toBe(true)
  })

  it('holder stasjonene fra hverandre — det er hele poenget', () => {
    // «ASKO Vest 17 825 paa Lone mot Vardens 7 207» er forskjellen
    // mellom en rapport og en plan.
    const sum = summerPerLeverandor(les(bok()).linjer)
    const asko = sum.filter((s) => s.tekst === 'ASKO VEST AS' && s.periode === '202607')
    expect(asko.map((s) => [s.butikk, s.belopKr]).sort()).toEqual([
      ['4177 ST1 Lone', 17825],
      ['9145 ST1 Varden', 7207],
    ])
  })

  it('skiller paa konto, ikke bare paa leverandoer', () => {
    // ASKO leverer BAADE renhold og forbruksmateriell. Slaas de sammen,
    // forsvinner nettopp funnet som gjorde de to linjene interessante.
    const sum = summerPerLeverandor(les(bok()).linjer)
    const asko = sum.filter((s) => s.tekst === 'ASKO VEST AS' && s.butikk === '4177 ST1 Lone')
    expect(asko.map((s) => s.konto).sort()).toEqual(['6270 Renhold', '6570 Forbruksmateriell'])
  })

  it('rader uten tekst slaas ikke sammen med en navngitt leverandoer', () => {
    const rad = r(0, 0, 0, 1, '', 500) + r(0, 0, 0, 1, 'ASKO VEST AS', 100)
    const sum = summerPerLeverandor(les(bok(rad)).linjer)
    expect(sum).toHaveLength(2)
    expect(sum.find((s) => s.tekst === '(uten tekst)')!.belopKr).toBe(500)
  })
})

describe('butikknummer', () => {
  it('tar nummeret foran navnet', () => {
    expect(butikknummer('4177 ST1 Lone')).toBe('4177')
    expect(butikknummer('9900 Admin')).toBe('9900')
  })
  it('gir null naar det ikke er et nummer der', () => {
    expect(butikknummer('Uten nummer')).toBeNull()
  })
})
