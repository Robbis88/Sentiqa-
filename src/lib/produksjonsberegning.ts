import { effektivProsent, medMargin, startAntall } from './produksjonsplan'
import type { PlanForslag } from './produksjonsplan'

export type LagretPlanlinje = {
  id?: string
  varenavn: string
  planlagt: number | null
  start_antall: number | null
  ekskludert?: boolean | null
}

export type MarginAvvik = {
  varegruppe_kode: string
  margin_prosent: number | null
  start_prosent: number | null
}

export type ProduksjonsResultat = {
  varenavn: string
  varegruppeKode: string | null
  varegruppeNavn: string | null
  forventetSalg: number
  foreslattProduksjon: number
  anbefaltProduksjon: number
  anbefaltStartantall: number
  planlagtAntall: number
  publisertAntall: number | null
  manuellPlan: boolean
  ekskludert: boolean
  kalibreringFaktor: number
  marginProsent: number
  startProsent: number
  flagg: PlanForslag['forslag'][number]['flagg']
  forklaring: PlanForslag['forslag'][number]['forklaring'] & {
    kalibreringFaktor: number
    modellForslag: number
    manuellPlan: boolean
    startAntall: number
  }
}

export type BeregnetProduksjonsPlan = {
  produkter: ProduksjonsResultat[]
  summer: {
    forventetSalg: number
    anbefaltProduksjon: number
    anbefaltStartantall: number
    publisertAntall: number | null
  }
}

/**
 * Felles etterbehandling for produksjonssiden og andre lesere av planen.
 * `plan` kommer direkte fra lagProduksjonsplan(); denne funksjonen gjør kun
 * den eksisterende kalibreringen, marginen, startandelen og planavviket.
 */
export function beregnProduksjonsresultat(
  plan: PlanForslag,
  opts: {
    kalibrering?: Map<string, number>
    standardMargin?: number | null
    standardStart?: number | null
    avvik?: Map<string, MarginAvvik>
    lagrede?: Map<string, LagretPlanlinje>
  } = {},
): BeregnetProduksjonsPlan {
  const kalibrering = opts.kalibrering ?? new Map<string, number>()
  const avvik = opts.avvik ?? new Map<string, MarginAvvik>()
  const lagrede = opts.lagrede ?? new Map<string, LagretPlanlinje>()
  const produkter = plan.forslag.map((f) => {
    const lagret = lagrede.get(f.varenavn)
    const korr = kalibrering.get(f.varegruppeKode ?? '') ?? 1
    const modellForslag = Math.max(0, Math.round(f.foreslatt * korr))
    const gruppeAvvik = avvik.get(f.varegruppeKode ?? '')
    const marginProsent = effektivProsent(opts.standardMargin, gruppeAvvik?.margin_prosent)
    const startProsent = effektivProsent(opts.standardStart, gruppeAvvik?.start_prosent)
    const anbefaltProduksjon = medMargin(modellForslag, marginProsent)
    const planlagtAntall = lagret?.planlagt ?? anbefaltProduksjon
    const anbefaltStartantall = lagret?.start_antall ?? startAntall(planlagtAntall, startProsent)
    const manuellPlan = lagret?.planlagt != null && lagret.planlagt !== modellForslag
    return {
      varenavn: f.varenavn,
      varegruppeKode: f.varegruppeKode,
      varegruppeNavn: f.varegruppeNavn,
      forventetSalg: f.forklaring.avrundetForslag,
      foreslattProduksjon: modellForslag,
      anbefaltProduksjon,
      anbefaltStartantall,
      planlagtAntall,
      publisertAntall: lagret?.planlagt ?? null,
      manuellPlan,
      ekskludert: lagret?.ekskludert ?? false,
      kalibreringFaktor: korr,
      marginProsent,
      startProsent,
      flagg: f.flagg,
      forklaring: {
        ...f.forklaring,
        kalibreringFaktor: korr,
        modellForslag,
        manuellPlan,
        startAntall: anbefaltStartantall,
      },
    }
  })
  return {
    produkter,
    summer: {
      forventetSalg: produkter.reduce((sum, p) => sum + p.forventetSalg, 0),
      anbefaltProduksjon: produkter.reduce((sum, p) => sum + p.anbefaltProduksjon, 0),
      anbefaltStartantall: produkter.reduce((sum, p) => sum + p.anbefaltStartantall, 0),
      publisertAntall: produkter.some((p) => p.publisertAntall != null)
        ? produkter.reduce((sum, p) => sum + (p.publisertAntall ?? 0), 0)
        : null,
    },
  }
}
