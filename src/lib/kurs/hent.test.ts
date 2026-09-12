import { describe, expect, it } from 'vitest'
import { byggHistorikk, klasseFor, MAANEDER_BAKOVER } from './hent'

// =====================================================================
// HVA SOM TESTES HER, OG HVA SOM IKKE GJØR DET LENGER
// =====================================================================
//
// Fram til `0205` gjorde `byggHistorikk` summeringen i TypeScript, og
// denne fila testet aritmetikken: drivstoff utenfor, pant utenfor,
// matkast bare fra 12xxx, bilvask utenfor «usynlig på resten».
//
// Summeringen ligger nå i `v_kurs_maanedstall`, fordi app-laget hentet
// 1 563 rå rader og PostgREST kutter på tusen uten å feile — siste måned
// falt utenfor, og månedsplanene sto med 0 kroner.
//
// **Det er en reell svekkelse av testdekningen, og den skal ikke skjules.**
// Aritmetikken kan ikke kjøres i vitest uten en base. Den er nå dekket
// av to andre ting:
//
//   `src/lib/kurs/viewliste.test.ts`      listene i viewet == listene i koden
//   `supabase/tests/kurs_maanedstall_probe.sql`  viewet mot ekte tall,
//                                         fasit lest ut av julifila
//
// Her står igjen det som fortsatt ER TypeScript: omformingen, sorteringen
// og avkortingsvakten.
// =====================================================================

type Rad = Parameters<typeof byggHistorikk>[0][number]

const r = (over: Partial<Rad>): Rad => ({
  stasjon_id: 's1', maaned: '2026-07-01',
  omsetning_kr: 0, omsetning_budsjett_kr: 0, brutto_kr: 0,
  matsalg_kr: 0, matkast_kr: 0, usynlig_rest_kr: 0,
  personal_kr: 0, personal_budsjett_kr: 0,
  paavirkbar_drift_kr: 0, paavirkbar_drift_budsjett_kr: 0,
  resultat_kr: 0, ...over,
})

describe('byggHistorikk', () => {
  it('omformer hver kolonne til sitt felt', () => {
    // En forskyvning her ville byttet om to tall som begge ser rimelige
    // ut — og da måler Kursen retning på feil størrelse.
    const h = byggHistorikk([r({
      omsetning_kr: 2_027_058, omsetning_budsjett_kr: 2_339_015,
      brutto_kr: 690_000, matsalg_kr: 400_000, matkast_kr: 31_943,
      usynlig_rest_kr: 40_000, personal_kr: 200_000, personal_budsjett_kr: 185_000,
      paavirkbar_drift_kr: 20_000, paavirkbar_drift_budsjett_kr: 17_000,
      resultat_kr: -10_201,
    })])
    expect(h).toHaveLength(1)
    expect(h[0]).toEqual({
      maaned: '2026-07-01',
      omsetningKr: 2_027_058, omsetningBudsjettKr: 2_339_015,
      bruttoKr: 690_000, matsalgKr: 400_000, matkastKr: 31_943,
      usynligRestKr: 40_000, personalKr: 200_000, personalBudsjettKr: 185_000,
      paavirkbarDriftKr: 20_000, paavirkbarDriftBudsjettKr: 17_000,
      resultatKr: -10_201,
    })
  })

  it('sorterer eldste foerst', () => {
    // `retning()` regner lineær trend over serien. Kommer månedene i
    // vilkårlig rekkefølge — og PostgREST gir ingen garanti uten
    // `order` — er stigningstallet meningsløst, og «medvind» tilfeldig.
    const h = byggHistorikk([
      r({ maaned: '2026-07-01', resultat_kr: 3 }),
      r({ maaned: '2026-05-01', resultat_kr: 1 }),
      r({ maaned: '2026-06-01', resultat_kr: 2 }),
    ])
    expect(h.map((x) => x.resultatKr)).toEqual([1, 2, 3])
    expect(h.map((x) => x.maaned)).toEqual(['2026-05-01', '2026-06-01', '2026-07-01'])
  })

  it('taaler datoer med tid paa', () => {
    expect(byggHistorikk([r({ maaned: '2026-07-15T00:00:00Z' })])[0].maaned)
      .toBe('2026-07-01')
  })

  it('null blir 0, ikke NaN', () => {
    // Viewet coalescer selv, men en manglende kolonne i et `select` ville
    // gitt `undefined` — og `undefined - tall` er NaN, som forplanter seg
    // stille gjennom hele serien.
    const h = byggHistorikk([r({ resultat_kr: null, omsetning_kr: null })])
    expect(h[0].resultatKr).toBe(0)
    expect(h[0].omsetningKr).toBe(0)
    expect(Number.isNaN(h[0].omsetningKr)).toBe(false)
  })

  it('KANARI: rekkefoelgen paa inndata endrer ikke resultatet', () => {
    // Uten sorteringen ville denne og testen over gitt ulike svar.
    const rader = [
      r({ maaned: '2026-06-01', resultat_kr: 2 }),
      r({ maaned: '2026-05-01', resultat_kr: 1 }),
    ]
    const a = byggHistorikk(rader).map((x) => x.resultatKr)
    const b = byggHistorikk([...rader].reverse()).map((x) => x.resultatKr)
    expect(a).toEqual(b)
    expect(a).toEqual([1, 2])
  })
})

describe('klasseFor', () => {
  it('maskinleverandoerer er FOELGE', () => {
    // 634 er 82 % WashTec paa stasjonene med vask - maskinen, ikke
    // butikksjefens valg.
    expect(klasseFor({ tekst: 'WashTec Bilvask AS' })).toBe('folge')
    expect(klasseFor({ tekst: 'Epta Refrigeration Norway AS' })).toBe('folge')
  })

  it('varelevrandoerer er SPAK', () => {
    expect(klasseFor({ tekst: 'ASKO VEST AS' })).toBe('spak')
    expect(klasseFor({ tekst: 'Elis Norge AS' })).toBe('spak')
  })

  it('KANARI: en ukjent leverandoer regnes som SPAK, ikke usynlig', () => {
    // Et tiltak som viser seg aa vaere en maskin blir korrigert av et
    // menneske. Motsatt vei ville en ukjent leverandoer blitt usynlig
    // for alltid - og det er den feilen ingen oppdager.
    expect(klasseFor({ tekst: 'Helt Ny Leverandoer AS' })).toBe('spak')
  })
})

describe('vinduet', () => {
  it('ser tolv maaneder bakover', () => {
    // Et helt aar, saa en sesongtopp ikke blir til en retning.
    expect(MAANEDER_BAKOVER).toBe(12)
  })
})
