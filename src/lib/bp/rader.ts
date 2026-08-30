import type { BpStasjon } from '@/lib/parsere/typer'

// =====================================================================
// FRA PARSET BP TIL `bp_linje`-RADER
//
// Ligger her og ikke i importoeren fordi den er REN, og fordi den maa
// kunne brukes av testen som beviser at de to veiene inn i analysen gir
// samme svar:
//
//   fila  -> parseBp/parseBp25 -> summer()        (ved import)
//   fila  -> disse radene -> basen -> hentAarstall()  (ved lesing)
//
// Ligger radbyggingen inne i importoeren, maa testen skrive den av - og
// da beviser den at kopien stemmer med seg selv, ikke at de to veiene
// moetes.
// =====================================================================

export type Bplinje = {
  maned: number
  seksjon: 'omsetning' | 'varekost' | 'kostnad'
  kode: string
  post: string
  belop_kr: number
}

/**
 * Linjene for en stasjons aargang.
 *
 * Nuller hoppes over. En budsjettlinje paa 0 kr er ikke et budsjett -
 * den er en varegruppe St1 ikke har satt tall paa - og tas de med,
 * vokser tabellen med rader ingen leser.
 */
export function bpLinjer(s: BpStasjon): Bplinje[] {
  const ut: Bplinje[] = []
  for (const m of s.maaneder) {
    for (const k of m.kategorier) {
      if (k.salgKr) {
        ut.push({ maned: m.maned, seksjon: 'omsetning', kode: k.kode, post: k.post, belop_kr: k.salgKr })
      }
      if (k.varekostKr) {
        ut.push({ maned: m.maned, seksjon: 'varekost', kode: k.kode, post: k.post, belop_kr: k.varekostKr })
      }
    }
    for (const k of m.konti) {
      if (k.belopKr) {
        ut.push({ maned: m.maned, seksjon: 'kostnad', kode: k.kode, post: k.post, belop_kr: k.belopKr })
      }
    }
  }
  return ut
}
