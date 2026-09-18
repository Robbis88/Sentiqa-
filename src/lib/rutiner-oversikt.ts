import 'server-only'

export const OVERLAPP_TOLERANSE_MINUTTER = 60

export type Forventning = {
  id: string
  retailer_id: string
  stasjon_id: string
  rutine_id: string
  skjema_id: string
  dato: string
  vakttype: string
  skjema_navn: string | null
  rutine_tittel: string
  forventet_start: string
  forventet_slutt: string
  paakrevd_bilde: boolean
}

export type Utforing = {
  rutine_id: string
  stasjon_id: string
  dato: string
  utfort_tid: string
  ansatt_id: string | null
  bilde_sti?: string | null
}

export type RutineStatus = 'Gjennomført' | 'Mangler' | 'For sent' | 'Ikke registrert'

export type Detaljrad = Forventning & {
  status: RutineStatus
  frist_iso: string
  gjennomfort_tid: string | null
  ansatt_id: string | null
  ansatt_navn: string
  bilde_sti: string | null
  kommentar: string | null
}

function lokalTidTilDate(dato: string, klokke: string): Date {
  const [h, m] = klokke.slice(0, 5).split(':').map(Number)
  const lokalSomUtc = Date.UTC(Number(dato.slice(0, 4)), Number(dato.slice(5, 7)) - 1, Number(dato.slice(8, 10)), h || 0, m || 0)
  let kandidat = new Date(lokalSomUtc)
  for (let i = 0; i < 2; i++) {
    const deler = new Intl.DateTimeFormat('en-US', { timeZone: 'Europe/Oslo', timeZoneName: 'shortOffset' }).formatToParts(kandidat)
    const offset = deler.find((d) => d.type === 'timeZoneName')?.value ?? 'GMT+0'
    const match = offset.match(/GMT([+-])(\d{1,2})(?::(\d{2}))?/) 
    const minutter = match ? (Number(match[2]) * 60 + Number(match[3] ?? 0)) * (match[1] === '-' ? -1 : 1) : 0
    kandidat = new Date(lokalSomUtc - minutter * 60_000)
  }
  return kandidat
}

export function fristFor(f: Forventning, toleranseMinutter = OVERLAPP_TOLERANSE_MINUTTER): Date {
  const slutt = lokalTidTilDate(f.dato, f.forventet_slutt)
  const startMin = Number(f.forventet_start.slice(0, 2)) * 60 + Number(f.forventet_start.slice(3, 5))
  const sluttMin = Number(f.forventet_slutt.slice(0, 2)) * 60 + Number(f.forventet_slutt.slice(3, 5))
  const sluttDato = sluttMin < startMin ? new Date(slutt.getTime() + 86_400_000) : slutt
  return new Date(sluttDato.getTime() + toleranseMinutter * 60_000)
}

export function klassifiser(f: Forventning, u: Utforing | null, naa: Date, ansatte: Map<string, string>, toleranseMinutter = OVERLAPP_TOLERANSE_MINUTTER): Detaljrad {
  const frist = fristFor(f, toleranseMinutter)
  const utfort = u ? new Date(u.utfort_tid) : null
  const fremtidig = frist > naa
  let status: RutineStatus
  if (!u && !fremtidig) status = 'Mangler'
  else if (!u) status = 'Mangler'
  else if (utfort! > frist) status = 'For sent'
  else if (!u.ansatt_id || !ansatte.has(u.ansatt_id)) status = 'Ikke registrert'
  else status = 'Gjennomført'
  return { ...f, status, frist_iso: frist.toISOString(), gjennomfort_tid: u?.utfort_tid ?? null, ansatt_id: u?.ansatt_id ?? null, ansatt_navn: u?.ansatt_id ? (ansatte.get(u.ansatt_id) ?? 'Ikke registrert') : 'Ikke registrert', bilde_sti: u?.bilde_sti ?? null, kommentar: null }
}

export type Oversikt = {
  rader: Detaljrad[]
  forventet: number
  utfort: number
  prosent: number
  topputforere: { id: string; navn: string; antall: number }[]
  utenRegistrertMedarbeider: number
  vanligsteMangler: { navn: string; antall: number }[]
  perVakt: { vakt: string; forventet: number; utfort: number; prosent: number }[]
  perDag: { dato: string; forventet: number; utfort: number; prosent: number }[]
}

export function byggOversikt(forventninger: Forventning[], utforinger: Utforing[], kommentarer: Map<string, string>, ansatte: Map<string, string>, naa = new Date(), toleranseMinutter = OVERLAPP_TOLERANSE_MINUTTER): Oversikt {
  const utforing = new Map(utforinger.map((u) => [`${u.rutine_id}|${u.dato}`, u]))
  const rader = forventninger.map((f) => { const r = klassifiser(f, utforing.get(`${f.rutine_id}|${f.dato}`) ?? null, naa, ansatte, toleranseMinutter); r.kommentar = kommentarer.get(`${f.rutine_id}|${f.dato}`) ?? null; return r })
  return summerRader(rader, ansatte, naa)
}

export function summerRader(rader: Detaljrad[], ansatte: Map<string, string>, naa = new Date()): Oversikt {
  const tellForventet = (r: Detaljrad) => r.status !== 'Mangler' || new Date(r.frist_iso) <= naa
  const tellMed = (r: Detaljrad) => tellForventet(r) && (r.status === 'Gjennomført' || r.status === 'Ikke registrert' || r.status === 'For sent')
  const tellRader = rader.filter(tellForventet)
  const utfort = rader.filter(tellMed).length
  const tellere = new Map<string, number>()
  for (const r of rader) if (tellMed(r) && r.ansatt_id && ansatte.has(r.ansatt_id)) tellere.set(r.ansatt_id, (tellere.get(r.ansatt_id) ?? 0) + 1)
  const topputforere = [...tellere.entries()].map(([id, antall]) => ({ id, navn: ansatte.get(id)!, antall })).sort((a, b) => b.antall - a.antall || a.navn.localeCompare(b.navn, 'nb')).slice(0, 3)
  const grupper = (key: (r: Detaljrad) => string) => {
    const m = new Map<string, { forventet: number; utfort: number }>()
    for (const r of tellRader) { const k = key(r); const x = m.get(k) ?? { forventet: 0, utfort: 0 }; x.forventet++; if (tellMed(r)) x.utfort++; m.set(k, x) }
    return m
  }
  const perVakt = [...grupper((r) => r.vakttype)].map(([vakt, x]) => ({ vakt, ...x, prosent: x.forventet ? Math.round(x.utfort / x.forventet * 100) : 0 }))
  const perDag = [...grupper((r) => r.dato)].sort(([a], [b]) => a.localeCompare(b)).map(([dato, x]) => ({ dato, ...x, prosent: x.forventet ? Math.round(x.utfort / x.forventet * 100) : 0 }))
  const mangler = new Map<string, number>(); for (const r of tellRader) if (r.status === 'Mangler') mangler.set(r.rutine_tittel, (mangler.get(r.rutine_tittel) ?? 0) + 1)
  return { rader, forventet: tellRader.length, utfort, prosent: tellRader.length ? Math.round(utfort / tellRader.length * 100) : 0, topputforere, utenRegistrertMedarbeider: rader.filter((r) => r.ansatt_id === null && tellMed(r)).length, vanligsteMangler: [...mangler.entries()].map(([navn, antall]) => ({ navn, antall })).sort((a, b) => b.antall - a.antall).slice(0, 5), perVakt, perDag }
}
