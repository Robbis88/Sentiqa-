// Prismodell (PROSJEKT.md §4). Pris per stasjon, ikke per hode.
export const PRIS = {
  cluster: 499, // kr/mnd per cluster (retailer)
  stasjon: 249, // kr/mnd per stasjon
  avtalevokter: 199, // premium-tillegg (konfigurerbart)
} as const

export type Prislinje = { navn: string; antall?: number; sum: number }

export function beregnAbonnement(antallStasjoner: number, premiumAvtalevokter: boolean) {
  const linjer: Prislinje[] = [
    { navn: 'Grunnpris (cluster)', sum: PRIS.cluster },
    { navn: 'Stasjoner', antall: antallStasjoner, sum: antallStasjoner * PRIS.stasjon },
  ]
  if (premiumAvtalevokter) linjer.push({ navn: 'Avtalevokter (premium)', sum: PRIS.avtalevokter })
  const maaned = linjer.reduce((a, l) => a + l.sum, 0)
  const aarlig = maaned * 10 // 2 måneder gratis ved årlig forskudd (§4)
  return { linjer, maaned, aarlig }
}
