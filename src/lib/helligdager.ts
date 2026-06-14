// Norske helligdager (røde dager) — deterministisk, ingen API. Bevegelige
// høytider regnes fra påskedag (Meeus/Gauss computus). Brukes til å la
// produksjonsplan/salgsprognose treffe selve fjor-helligdagen i stedet for
// vanlige naboukedager, og til å vise hvilken rød dag mål-dagen er.

function isoFra(year: number, month: number, day: number): string {
  return `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`
}
function leggTil(iso: string, n: number): string {
  const d = new Date(`${iso}T12:00:00Z`)
  d.setUTCDate(d.getUTCDate() + n)
  return d.toISOString().slice(0, 10)
}

// Påskedag (1. påskedag) for et gitt år — gregoriansk computus.
function paaskedag(year: number): string {
  const a = year % 19
  const b = Math.floor(year / 100)
  const c = year % 100
  const d = Math.floor(b / 4)
  const e = b % 4
  const f = Math.floor((b + 8) / 25)
  const g = Math.floor((b - f + 1) / 3)
  const h = (19 * a + b - d - g + 15) % 30
  const i = Math.floor(c / 4)
  const k = c % 4
  const l = (32 + 2 * e + 2 * i - h - k) % 7
  const m = Math.floor((a + 11 * h + 22 * l) / 451)
  const maaned = Math.floor((h + l - 7 * m + 114) / 31) // 3 = mars, 4 = april
  const dag = ((h + l - 7 * m + 114) % 31) + 1
  return isoFra(year, maaned, dag)
}

// Alle helligdager i et år → ISO-dato ⇒ navn.
function helligdagerForAar(year: number): Map<string, string> {
  const p = paaskedag(year)
  const m = new Map<string, string>()
  m.set(isoFra(year, 1, 1), '1. nyttårsdag')
  m.set(leggTil(p, -3), 'Skjærtorsdag')
  m.set(leggTil(p, -2), 'Langfredag')
  m.set(p, '1. påskedag')
  m.set(leggTil(p, 1), '2. påskedag')
  m.set(isoFra(year, 5, 1), 'Arbeidernes dag')
  m.set(isoFra(year, 5, 17), 'Grunnlovsdagen')
  m.set(leggTil(p, 39), 'Kristi himmelfartsdag')
  m.set(leggTil(p, 49), '1. pinsedag')
  m.set(leggTil(p, 50), '2. pinsedag')
  m.set(isoFra(year, 12, 25), '1. juledag')
  m.set(isoFra(year, 12, 26), '2. juledag')
  return m
}

const cache = new Map<number, Map<string, string>>()
function forAar(year: number): Map<string, string> {
  let m = cache.get(year)
  if (!m) { m = helligdagerForAar(year); cache.set(year, m) }
  return m
}

/** Navnet på helligdagen for en ISO-dato (YYYY-MM-DD), eller null. */
export function helligdagNavn(iso: string): string | null {
  const year = Number(iso.slice(0, 4))
  if (!year) return null
  return forAar(year).get(iso) ?? null
}

/** Er ISO-datoen en norsk helligdag (rød dag)? Søndager regnes ikke som helligdag her. */
export function erHelligdag(iso: string): boolean {
  return helligdagNavn(iso) !== null
}
