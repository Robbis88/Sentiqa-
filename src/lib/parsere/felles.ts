import ExcelJS, { type CellValue } from 'exceljs'

// Laster en xlsx fra Buffer/ArrayBuffer. Sentraliserer casten som ellers
// trengs pga. drift mellom @types/node sin Buffer<ArrayBufferLike> og exceljs.
export async function lastArbeidsbok(
  data: Buffer | ArrayBuffer,
): Promise<ExcelJS.Workbook> {
  const wb = new ExcelJS.Workbook()
  await wb.xlsx.load(data as unknown as Parameters<typeof wb.xlsx.load>[0])
  return wb
}

// Trekker ut en ren primitivverdi fra en exceljs-celle (håndterer rik tekst,
// formler og hyperlenker som ellers blir "[object Object]").
export function celletekst(v: CellValue): string {
  if (v === null || v === undefined) return ''
  if (typeof v === 'object') {
    if ('richText' in v && Array.isArray(v.richText)) {
      return v.richText.map((t) => t.text).join('')
    }
    if ('result' in v) return String((v as { result: unknown }).result ?? '')
    if ('text' in v) return String((v as { text: unknown }).text ?? '')
    if (v instanceof Date) return v.toISOString().slice(0, 10)
  }
  return String(v)
}

// Tolker et tall fra en celle. Tomt/ugyldig → 0. Støtter både ekte tall og
// strenger med komma-desimal (norsk eksport varierer).
export function celletall(v: CellValue): number {
  if (typeof v === 'number') return v
  if (v && typeof v === 'object' && 'result' in v) {
    const r = (v as { result: unknown }).result
    if (typeof r === 'number') return r
  }
  const s = celletekst(v).trim().replace(/\s/g, '')
  if (s === '') return 0
  // 1.234,56 → 1234.56  |  1234.56 → 1234.56
  const normalisert = s.includes(',') ? s.replace(/\./g, '').replace(',', '.') : s
  const n = Number.parseFloat(normalisert)
  return Number.isFinite(n) ? n : 0
}

// Henter første dato på formen DD.MM.YYYY fra en streng → ISO yyyy-mm-dd.
export function forsteDatoIso(tekst: string): string | null {
  const m = tekst.match(/(\d{2})\.(\d{2})\.(\d{4})/)
  if (!m) return null
  const [, dd, mm, yyyy] = m
  return `${yyyy}-${mm}-${dd}`
}

// Deler "120 MAT" → { kode: '120', navn: 'MAT' }. Tåler manglende navn.
export function kodeOgNavn(tekst: string): { kode: string | null; navn: string | null } {
  const m = tekst.match(/^\s*(\d+)\s*(.*)$/)
  if (!m) return { kode: null, navn: tekst.trim() || null }
  return { kode: m[1], navn: m[2].trim() || null }
}
