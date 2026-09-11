// Royaltysatsene, lest ut av BP-arket «Cluster data».
//
// =====================================================================
// TRE SATSER, OG GRUNNLAGET ER OMSETNING
// =====================================================================
//
// Arket oppgir dem rett ut, i en etikett/verdi-blokk:
//
//   Royalty lav sats (årlig)                 0,10
//   Royalty høy sats (bilvask og selvvask)   0,60
//   Royalty pant                             0
//
// `bp/analyse.ts` sa i en lang kommentar at «den ordinære satsen lar seg
// IKKE regne ut av det filene sier», og at et førsteforsøk som trakk 60 %
// av VASKEMARGINEN fra ga 6,70 % → 9,27 % der avtalen sier 7,75 % → 10,00 %.
//
// Feilen var grunnlaget, ikke metoden: de 60 prosentene er av vaskens
// OMSETNING, ikke av marginen — og bare den delen som selges over kassa.
// Med det grunnlaget går BP-ens egne tall opp på øret:
//
//   0,10 × (Sum CR salg − omsetning vask − omsetning pant)
//        + royalty vask (som arket oppgir direkte)
//        = Sum Royalty
//
// Derfor leser vi ikke bare satsene, men også kontrolltallene, og lar
// `avstemming()` regne differansen. En sats vi ikke kan avstemme er en
// sats vi ikke skal bruke til å fortelle noen hva noe er verdt.
//
// ---------------------------------------------------------------------
// HVORFOR ETIKETT OG IKKE CELLEADRESSE
//
// Samme grunn som i `kontoregister.ts`: en posisjon er en adresse, ikke
// en identitet. St1 har flyttet ting før. Etikettene leses derfor med
// normalisert tekstmatch, og mangler en av dem, returneres `null` — ikke
// et gjettet tall.

import { lesArk, arknavn, type Celleverdi } from './xlsx-rader'

export type BpRoyalty = {
  ar: number | null
  lavSats: number
  hoySatsVask: number
  pantSats: number
  /** BP-ens egne kontrolltall. Gjør satsene etterprøvbare der de står. */
  sumRoyalty: number | null
  sumCrSalg: number | null
  omsetningVask: number | null
  omsetningPant: number | null
  royaltyVask: number | null
}

const norm = (s: string) =>
  s.toLowerCase().replace(/[^\wæøå]+/gu, ' ').trim()

function tall(v: Celleverdi | undefined): number | null {
  if (v === null || v === undefined) return null
  const n = typeof v === 'number' ? v : Number(String(v).replace(/\s/g, '').replace(',', '.'))
  return Number.isFinite(n) ? n : null
}

// Etikettene, normalisert. Skrivevarianter tåles; betydningsforskjeller
// gjør det ikke — derfor eksplisitt liste, ikke fuzzy match.
const ETIKETT: Record<string, keyof BpRoyalty> = {
  'royalty lav sats årlig': 'lavSats',
  'royalty lav sats aarlig': 'lavSats',
  'royalty høy sats bilvask og selvvask': 'hoySatsVask',
  'royalty hoy sats bilvask og selvvask': 'hoySatsVask',
  'royalty høy sats bilvask': 'hoySatsVask',
  'royalty pant': 'pantSats',
  'sum royalty': 'sumRoyalty',
  'sum cr salg': 'sumCrSalg',
  'hvorav omsetning bilvask og selvvask': 'omsetningVask',
  'hvorav omsetning bilvask': 'omsetningVask',
  'hvorav omsetning pant': 'omsetningPant',
  'hvorav royalty bilvask og selvvask': 'royaltyVask',
  'hvorav royalty bilvask': 'royaltyVask',
}

/**
 * Leser satsene. Returnerer `null` når arket ikke finnes, eller når en av
 * de tre satsene mangler — en delvis lest sats er verre enn ingen.
 */
export function lesRoyaltysatser(data: Uint8Array | ArrayBuffer): BpRoyalty | null {
  if (!arknavn(data).some((n) => /cluster\s*data/i.test(n))) return null

  const funnet = new Map<keyof BpRoyalty, number>()
  let ar: number | null = null

  lesArk(data, (n) => /cluster\s*data/i.test(n), (rad) => {
    // Etikett/verdi ligger i kolonne 2 og 3. «År» ligger for seg selv i
    // kolonne 7/8, sammen med selskapsnavn og klientid.
    for (const [iEtikett, iVerdi] of [[2, 3], [7, 8]] as const) {
      const e = rad.celler.get(iEtikett)
      if (typeof e !== 'string') continue
      const n = norm(e)
      if (n === 'år' || n === 'aar' || n === 'ar') {
        const v = tall(rad.celler.get(iVerdi))
        if (v && v > 2000 && v < 2100) ar = Math.round(v)
        continue
      }
      const felt = ETIKETT[n]
      if (!felt || funnet.has(felt)) continue
      const v = tall(rad.celler.get(iVerdi))
      if (v !== null) funnet.set(felt, v)
    }
  })

  const lav = funnet.get('lavSats')
  const hoy = funnet.get('hoySatsVask')
  const pant = funnet.get('pantSats')
  if (lav === undefined || hoy === undefined || pant === undefined) return null

  return {
    ar,
    lavSats: rund(lav),
    hoySatsVask: rund(hoy),
    pantSats: rund(pant),
    sumRoyalty: funnet.get('sumRoyalty') ?? null,
    sumCrSalg: funnet.get('sumCrSalg') ?? null,
    omsetningVask: funnet.get('omsetningVask') ?? null,
    omsetningPant: funnet.get('omsetningPant') ?? null,
    royaltyVask: funnet.get('royaltyVask') ?? null,
  }
}

// Arket regner satsene ut av formler og leverer 0.10000000000000159.
// Fem desimaler er langt mer enn en royaltysats har, og kolonnen i basen
// er numeric(6,5).
const rund = (x: number) => Math.round(x * 1e5) / 1e5

export type Avstemming = {
  /** Royalty regnet ut av satsene og BP-ens egne grunnlagstall. */
  beregnet: number
  /** Det BP selv sier. */
  oppgitt: number
  avvikKr: number
  avvikPst: number
  /** Under 1 % regnes som avstemt. */
  stemmer: boolean
}

/**
 * Regner royaltyen ut av satsene og sammenligner med BP-ens egen sum.
 *
 * Dette er beviset paa at vi har forstatt grunnlaget, og det er derfor
 * kontrolltallene lagres sammen med satsene: en sats som ikke lar seg
 * avstemme skal ikke brukes til aa fortelle noen hva noe er verdt.
 *
 * Returnerer `null` naar kontrolltallene mangler — da har vi satsene, men
 * ingen maate aa proeve dem paa, og det skal sies i stedet for aa
 * antydes.
 */
export function avstemming(r: BpRoyalty): Avstemming | null {
  if (
    r.sumRoyalty === null || r.sumCrSalg === null ||
    r.omsetningVask === null || r.omsetningPant === null ||
    r.royaltyVask === null
  ) return null

  const ordinaert = r.sumCrSalg - r.omsetningVask - r.omsetningPant
  const beregnet = ordinaert * r.lavSats + r.royaltyVask + r.omsetningPant * r.pantSats
  const avvikKr = beregnet - r.sumRoyalty
  const avvikPst = r.sumRoyalty === 0 ? 0 : (avvikKr / r.sumRoyalty) * 100
  return {
    beregnet,
    oppgitt: r.sumRoyalty,
    avvikKr,
    avvikPst,
    stemmer: Math.abs(avvikPst) < 1,
  }
}
