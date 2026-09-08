import { readFileSync, readdirSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, it } from 'vitest'

// =====================================================================
// LISTA ER BUNDET. KALLSTEDENE VAR DET IKKE.
//
// `utelatte-koder.test.ts` binder `SKJUL_OMS_KODER` i TypeScript til det
// samme filteret i `v_bp_status_avdeling`. Den er god, og den var grønn
// hele tiden — for den ser bare på lista, ikke på hvem som bruker den.
//
// Forsiden gjorde dette:
//
//     if (!kode || kode === '40') continue
//
// Bare rollupen ble luket. Drivstoff (10) og pant (250) sto igjen i
// `r.oms.total`, som er nevneren i lønnsprosenten. Drivstoff er ~68 %
// av omsetningen, så prosenten ble omtrent tre ganger for lav — og
// terskelen på 32 % kunne aldri slå ut. Standardfanen «Omsetning ·
// Total» rangerte stasjonene etter pumpevolum.
//
// Alle de fem andre konsumentene av de samme radene brukte
// `SKJUL_OMS_KODER`. Det var ett sted som gikk sin egen vei, og
// ingenting sa fra.
//
// ---------------------------------------------------------------------
// HVA DENNE MÅLER
//
// Filer som leser `regnskapslinjer` (eller BP-seksjonene) OG summerer
// per kode, skal referere til `SKJUL_OMS_KODER` eller `UTELAT_KODER`.
// Den beviser ikke at filteret er riktig plassert — bare at noen har
// tatt stilling til det. En egen liste med de samme kodene teller også,
// men da skal `utelatte-koder.test.ts` binde den.
//
// Feiler hvis tallet VOKSER. Det er noen fra før som leser
// `regnskapslinjer` uten å summere omsetning; de er ufarlige og står i
// fasiten.
// =====================================================================

/**
 * Kjente steder, hvert med en SKREVET begrunnelse for hvorfor de tar
 * kodene et annet sted. En fasit som bare er en liste sier at noen har
 * sett den; en med begrunnelse sier hva de saa.
 */
type Fasit = { utenFilter: Record<string, string> }

const ROT = process.cwd()
const FASIT = join(ROT, 'src', 'lib', 'regnskap', 'kodefasit.json')

function tsFiler(mappe: string): string[] {
  const ut: string[] = []
  for (const rad of readdirSync(mappe, { withFileTypes: true })) {
    const sti = join(mappe, rad.name)
    if (rad.isDirectory()) ut.push(...tsFiler(sti))
    else if (/\.tsx?$/.test(rad.name) && !/\.test\.tsx?$/.test(rad.name)) ut.push(sti)
  }
  return ut
}

/**
 * Leser fila omsetningslinjer og summerer dem uten å ta stilling til
 * hvilke koder som skal utelates?
 */
export function utenKodefilter(kilde: string): boolean {
  // Leser den omsetning fra regnskapslinjer i det hele tatt?
  const leser = /from\(['"`]regnskapslinjer['"`]\)/.test(kilde)
    && /'omsetning'|'bp_omsetning'|'bruttofortjeneste'|'bp_bruttofortjeneste'/.test(kilde)
  if (!leser) return false
  // Summerer den? En ren opplisting per rad er ikke en sum.
  const summerer = /\breduce\(|\+=|\bsum\b/.test(kilde)
  if (!summerer) return false
  // Har noen tatt stilling til kodene?
  return !/SKJUL_OMS_KODER|UTELAT_KODER/.test(kilde)
}

// SKRÅSTREK, IKKE BAKSTREK. Fasiten leses av CI på Linux og av meg på
// Windows. Med `path.sep` i nøklene ville den matchet på én av dem og
// vært tom på den andre — og en fasit som ikke matcher noe gir en grønn
// vakt som ikke ser noe.
const filer = tsFiler(join(ROT, 'src'))
  .map((f) => ({ f: f.replace(ROT, '').replace(/\\/g, '/'), kilde: readFileSync(f, 'utf8') }))
const naa = filer.filter(({ kilde }) => utenKodefilter(kilde)).map(({ f }) => f)

describe('målingen forstår det den teller', () => {
  const grunn = "await sb.from('regnskapslinjer').select('kode').in('seksjon', ['omsetning'])\n"

  it('ser en sum uten kodefilter', () => {
    expect(utenKodefilter(`${grunn}const t = rader.reduce((a, r) => a + r.regnskap, 0)`)).toBe(true)
  })

  it('ser ikke en sum som filtrerer', () => {
    expect(utenKodefilter(
      `${grunn}for (const r of rader) { if (SKJUL_OMS_KODER.has(r.kode)) continue }\n`
      + 'const t = rader.reduce((a, r) => a + r.regnskap, 0)',
    )).toBe(false)
  })

  it('ser ikke en fil som bare lister radene', () => {
    expect(utenKodefilter(`${grunn}return rader.map((r) => r.post)`)).toBe(false)
  })

  it('ser ikke en fil som ikke rører regnskapslinjer', () => {
    expect(utenKodefilter("await sb.from('daglig_salg').select('*')\nconst t = x.reduce(...)")).toBe(false)
  })

  // KANARIFUGL: den ekte regresjonen, ordrett slik den sto på forsiden.
  it('ville sett feilen som faktisk sto der', () => {
    expect(utenKodefilter(
      `${grunn}const kode = (l.kode ?? '').trim()\n`
      + "if (!kode || kode === '40') continue\n"
      + 'sum += l.regnskap',
    )).toBe(true)
  })
})

describe('kodefilteret på kallstedene', () => {
  it('den ser fortsatt filene', () => {
    expect(filer.length, 'fant ingen .ts-filer under src/').toBeGreaterThan(300)
    // Og den ser faktisk noen som LESER regnskapslinjer — ellers måler
    // den ingenting uansett hva fasiten sier.
    const lesere = filer.filter(({ kilde }) => /from\(['"`]regnskapslinjer['"`]\)/.test(kilde))
    expect(lesere.length, 'ingen fil leser regnskapslinjer — regexen treffer ikke')
      .toBeGreaterThan(3)
  })

  it('ingen nye summerer omsetning uten å ta stilling til kodene', () => {
    const fasit = JSON.parse(readFileSync(FASIT, 'utf8')) as Fasit
    const nye = naa.filter((f) => !(f in fasit.utenFilter))
    expect(
      nye,
      'Denne fila summerer omsetning fra `regnskapslinjer` uten å nevne '
      + '`SKJUL_OMS_KODER` eller `UTELAT_KODER`.\n\n'
      + 'Drivstoff (10) er ~68 % av omsetningen og pant (250) er gjennomgang; '
      + '«40 CR» er St1-totalen som dobbelteller mot sine egne avdelinger. '
      + 'Blir de med, er tallet ikke butikkens.\n\n'
      + `Nye:\n  ${nye.join('\n  ')}`,
    ).toEqual([])
  })

  it('fasiten følger med når en fil ryddes', () => {
    const fasit = JSON.parse(readFileSync(FASIT, 'utf8')) as Fasit
    const ryddet = Object.keys(fasit.utenFilter).filter((f) => !naa.includes(f))
    expect(
      ryddet,
      'Disse er ryddet, men står fortsatt i fasiten. Ta dem ut, ellers kan '
      + `de komme tilbake uten at noe blir rødt:\n  ${ryddet.join('\n  ')}`,
    ).toEqual([])
  })
})
