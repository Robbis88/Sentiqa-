// Felles formatering. All tidsvisning i Europe/Oslo (§18), tall i nb-NO.
export const kr = new Intl.NumberFormat('nb-NO', {
  style: 'currency',
  currency: 'NOK',
  maximumFractionDigits: 0,
})
export const tall = new Intl.NumberFormat('nb-NO', { maximumFractionDigits: 0 })
export const prosent = new Intl.NumberFormat('nb-NO', {
  style: 'percent',
  maximumFractionDigits: 1,
})

export const datoLang = new Intl.DateTimeFormat('nb-NO', {
  dateStyle: 'long',
  timeZone: 'Europe/Oslo',
})
export const manedAar = new Intl.DateTimeFormat('nb-NO', {
  month: 'long',
  year: 'numeric',
  timeZone: 'Europe/Oslo',
})

// Dagens dato i Oslo-tid som 'YYYY-MM-DD' (tidligere duplisert mange steder).
export function iDag(): string {
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Oslo' }).format(new Date())
}

// «a, b og c». Setninger som ramser opp datasett eller signaler skal lese
// som norsk, ikke som en kommaliste med hengende «og».
export function ramsOpp(ord: string[]): string {
  if (ord.length <= 1) return ord[0] ?? ''
  return `${ord.slice(0, -1).join(', ')} og ${ord[ord.length - 1]}`
}

// Grønn/gul/rød på avvik mot budsjett (§12). Høyere = bedre (omsetning/brutto).
export function avviksKlasse(indexPct: number): 'gronn' | 'gul' | 'rod' {
  if (indexPct >= -2) return 'gronn'
  if (indexPct >= -10) return 'gul'
  return 'rod'
}
