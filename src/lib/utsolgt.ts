// Mulig utsolgt-deteksjon. RPC-en utsolgt_kandidater gir oss kun FASTE varer
// (jevn selger, snitt >= 1,5 pr salgsdag). Her finner vi «hull»: 0 salg i minst
// to sammenhengende dager, omkranset av tilnærmet normalt salg før OG etter —
// signaturen til en utsolgt-/glemt-bestilling-situasjon (varen kom tilbake på
// normalen, så den var ikke utgått). Ren logikk → enhetstestbar.
import { leggTilDager } from './produksjonsplan'

export type Kandidatrad = { ean: string; varenavn: string | null; dato: string; antall: number | null; omsetning: number | null }
export type UtsolgtHendelse = {
  ean: string
  varenavn: string
  fra: string
  til: string
  dager: number
  snitt: number        // normalt antall pr salgsdag
  tapt_kr: number      // estimert tapt omsetning i hullet
}

const MIN_HULL = 2          // minst så mange 0-dager på rad
const BRACKET_ANDEL = 0.6   // dagen før/etter må være >= 60 % av normalen

// Bygger datolista for vinduet (eldst → nyest), dagene RPC-en dekker.
function vindusdager(idag: string, antallDager: number): string[] {
  const ut: string[] = []
  for (let i = antallDager; i >= 1; i--) ut.push(leggTilDager(idag, -i))
  return ut
}

export function finnUtsolgt(rader: Kandidatrad[], idag: string, antallDager = 35): UtsolgtHendelse[] {
  const dager = vindusdager(idag, antallDager)
  // Grupper pr vare.
  const perVare = new Map<string, { varenavn: string; antall: Map<string, number>; oms: Map<string, number> }>()
  for (const r of rader) {
    let v = perVare.get(r.ean)
    if (!v) { v = { varenavn: r.varenavn ?? r.ean, antall: new Map(), oms: new Map() }; perVare.set(r.ean, v) }
    if (r.varenavn && v.varenavn === r.ean) v.varenavn = r.varenavn
    v.antall.set(r.dato, (v.antall.get(r.dato) ?? 0) + (r.antall ?? 0))
    v.oms.set(r.dato, (v.oms.get(r.dato) ?? 0) + (r.omsetning ?? 0))
  }

  const hendelser: UtsolgtHendelse[] = []
  for (const [ean, v] of perVare.entries()) {
    // Normal: snitt + enhetspris over salgsdagene.
    let sumAnt = 0, sumOms = 0, salgsdager = 0
    for (const d of dager) {
      const a = v.antall.get(d) ?? 0
      if (a > 0) { sumAnt += a; sumOms += v.oms.get(d) ?? 0; salgsdager++ }
    }
    if (salgsdager < MIN_HULL) continue
    const normal = sumAnt / salgsdager
    const enhetspris = sumAnt > 0 ? sumOms / sumAnt : 0
    const bracket = normal * BRACKET_ANDEL

    // Serie over hele vinduet (0 der det ikke solgte).
    const serie = dager.map((d) => v.antall.get(d) ?? 0)
    let i = 0
    while (i < serie.length) {
      if (serie[i] === 0) {
        let j = i
        while (j < serie.length && serie[j] === 0) j++
        const lengde = j - i
        const for_ = i > 0 ? serie[i - 1] : null
        const etter = j < serie.length ? serie[j] : null
        // Hull >= 2 dager, omkranset av tilnærmet normalt salg (ikke kant av vindu).
        if (lengde >= MIN_HULL && for_ != null && etter != null && for_ >= bracket && etter >= bracket) {
          hendelser.push({
            ean, varenavn: v.varenavn,
            fra: dager[i], til: dager[j - 1], dager: lengde,
            snitt: Math.round(normal * 10) / 10,
            tapt_kr: Math.round(normal * lengde * enhetspris),
          })
        }
        i = j
      } else i++
    }
  }

  // Størst tap først.
  return hendelser.sort((a, b) => b.tapt_kr - a.tapt_kr)
}
