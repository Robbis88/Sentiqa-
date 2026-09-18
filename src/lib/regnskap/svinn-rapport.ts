export type SvinnRad = {
  stasjon_id: string | null
  kode: string | null
  navn: string
  salg: number | null
  usynlig_kr: number | null
  kast: number | null
  datastatus?: string | null
}

export type SvinnStatus = 'fullstendig' | 'usikkert' | 'mangler'
export type SvinnKort = { kr: number; prosent: number | null; status: SvinnStatus; sammenligning: string }
export type SvinnAvdeling = SvinnKort & { kode: string | null; navn: string; salg: number; registrert: number; manko: number; overskudd: number; samlet: number | null }

const NAVN: Record<string, string> = { '120': 'Mat', '130': 'Varm drikke', '140': 'Kald drikke', '160': 'Kioskvarer', '170': 'Butikk', '180': 'Tobakk', '190': 'Fritidsartikler', '200': 'Bil', '210': 'Bilvask' }
const MIN_SALG = 1000

export function beregnSvinnRapport(rader: SvinnRad[], sammenlignbart = true) {
  const avdelinger = new Map<string, SvinnAvdeling>()
  for (const r of rader) {
    const kode = r.kode?.slice(0, 3) ?? null
    if (!kode || !NAVN[kode]) continue
    const x = avdelinger.get(kode) ?? { kode, navn: NAVN[kode], salg: 0, registrert: 0, manko: 0, overskudd: 0, samlet: 0, kr: 0, prosent: null, status: 'fullstendig' as SvinnStatus, sammenligning: 'Ikke sammenlignbart' }
    const salg = r.salg ?? 0
    const usynlig = r.usynlig_kr ?? 0
    x.salg += salg
    x.registrert += r.kast ?? 0
    x.manko += Math.max(usynlig, 0)
    x.overskudd += Math.abs(Math.min(usynlig, 0))
    avdelinger.set(kode, x)
  }
  for (const x of avdelinger.values()) {
    x.samlet = x.registrert + x.manko - x.overskudd
    x.kr = x.samlet
    x.prosent = x.salg > MIN_SALG ? (x.samlet / x.salg) * 100 : null
    x.status = x.salg > 0 ? 'fullstendig' : 'usikkert'
    x.sammenligning = sammenlignbart ? 'Sammenlignbart' : 'Ikke sammenlignbart'
  }
  const rows = [...avdelinger.values()]
  const sum = (key: 'registrert' | 'manko' | 'overskudd') => rows.reduce((n, r) => n + r[key], 0)
  const salg = rows.reduce((n, r) => n + r.salg, 0)
  const kort = (kr: number): SvinnKort => ({ kr, prosent: salg > MIN_SALG ? (kr / salg) * 100 : null, status: salg > 0 ? 'fullstendig' : 'usikkert', sammenligning: sammenlignbart ? 'Sammenlignbart' : 'Ikke sammenlignbart' })
  return { avdelinger: rows, registrert: kort(sum('registrert')), manko: kort(sum('manko')), overskudd: kort(sum('overskudd')), salg }
}
