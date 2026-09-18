/** Kalenderberegning for prøveperiode og binding. Datoene er halvåpne i
 * beregningen: startdato inkluderer, sluttdato er dagen før neste periode. */
export function leggTilMaaneder(iso: string, maaneder: number): string {
  const [y, m, d] = iso.split('-').map(Number)
  const target = new Date(Date.UTC(y, m - 1 + maaneder, 1, 12))
  const sisteDag = new Date(Date.UTC(target.getUTCFullYear(), target.getUTCMonth() + 1, 0, 12)).getUTCDate()
  target.setUTCDate(Math.min(d, sisteDag))
  return target.toISOString().slice(0, 10)
}

export function beregnAvtaledatoer(start: string, trialMaaneder = 2, bindingMaaneder = 12) {
  const trialNeste = leggTilMaaneder(start, trialMaaneder)
  const firstPayment = trialNeste
  const bindingSlutt = leggTilMaaneder(firstPayment, bindingMaaneder)
  return {
    trial_starts_at: start,
    trial_ends_at: leggTilDager(firstPayment, -1),
    first_payment_date: firstPayment,
    commitment_starts_at: firstPayment,
    commitment_ends_at: leggTilDager(bindingSlutt, -1),
  }
}

function leggTilDager(iso: string, antall: number): string {
  const d = new Date(`${iso}T12:00:00Z`)
  d.setUTCDate(d.getUTCDate() + antall)
  return d.toISOString().slice(0, 10)
}
