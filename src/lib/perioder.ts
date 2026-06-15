// Grupperer regnskapsperioder (ISO-dato, første i mnd) på ÅR for nedtrekksvelgeren.
// Hvert år får evt. «Hittil i år» øverst + hver måned for seg — så 2025 og 2026
// aldri blandes. Verdi = 'YYYY-MM' (enkeltmåned) eller 'YYYY-hittil' (hittil i år).
const mnd = new Intl.DateTimeFormat('nb-NO', { month: 'long', timeZone: 'Europe/Oslo' })

export function manedNavn(iso: string): string {
  const n = mnd.format(new Date(`${iso}T12:00:00Z`))
  return n.charAt(0).toUpperCase() + n.slice(1)
}

export type PeriodeGruppe = { aar: string; valg: { verdi: string; navn: string }[] }

export function byggPeriodeGrupper(perioder: string[], medHittil: boolean): PeriodeGruppe[] {
  const perAar = new Map<string, string[]>()
  for (const p of perioder) {
    const aar = p.slice(0, 4)
    const l = perAar.get(aar) ?? []
    l.push(p)
    perAar.set(aar, l)
  }
  return [...perAar.entries()]
    .sort((a, b) => b[0].localeCompare(a[0])) // nyeste år først
    .map(([aar, ps]) => ({
      aar,
      valg: [
        ...(medHittil ? [{ verdi: `${aar}-hittil`, navn: 'Hittil i år' }] : []),
        ...[...ps].sort((a, b) => b.localeCompare(a)).map((p) => ({ verdi: p.slice(0, 7), navn: manedNavn(p) })),
      ],
    }))
}
