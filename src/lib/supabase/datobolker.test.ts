import { describe, expect, it, vi } from 'vitest'
import { hentPerDato } from './datobolker'

// =====================================================================
// EN RASKERE HENTING SOM MISTER RADER ER IKKE RASKERE - DEN ER GAL
//
// `/produksjonsplan` regner fjorårets samme ukedag, 28-dagers trend og
// medianer av et helt år med salg. Faller en dag ut, blir planen litt
// dårligere - og ingenting sier fra. Et hull i historikken ser ut som en
// rolig dag.
//
// Derfor er testene her ikke om fart. De er om at settet er DET SAMME.
// =====================================================================

/** Én rad per dag, med datoen som verdi, så hver rad kan spores. */
function fakeKilde(fra: string, til: string, perDag = 1) {
  return (b0: string, b1: string) => {
    const ut: { dato: string; nr: number }[] = []
    for (let d = new Date(`${fra}T00:00:00Z`); ; d.setUTCDate(d.getUTCDate() + 1)) {
      const iso = d.toISOString().slice(0, 10)
      if (iso > til) break
      if (iso >= b0 && iso <= b1) {
        for (let i = 0; i < perDag; i++) ut.push({ dato: iso, nr: i })
      }
    }
    return Promise.resolve({ data: ut, error: null })
  }
}

const dager = (fra: string, til: string) => {
  const ut: string[] = []
  for (let d = new Date(`${fra}T00:00:00Z`); ; d.setUTCDate(d.getUTCDate() + 1)) {
    const iso = d.toISOString().slice(0, 10)
    if (iso > til) break
    ut.push(iso)
  }
  return ut
}

describe('hentPerDato', () => {
  // HELE PERIODEN, HVER DAG, ÉN GANG. Dette er hele poenget: et aar med
  // salg skal komme tilbake komplett, uten hull i bolkeskjoetene og uten
  // dubletter der de moetes.
  it('dekker hele perioden uten hull eller dubletter', async () => {
    const fra = '2025-08-11'
    const til = '2026-09-06' // 392 dager, som paa /produksjonsplan
    const rader = await hentPerDato(fakeKilde(fra, til), fra, til, 30)

    const forventet = dager(fra, til)
    expect(rader).toHaveLength(forventet.length)
    expect(rader.map((r) => r.dato)).toEqual(forventet)
    expect(new Set(rader.map((r) => r.dato)).size).toBe(forventet.length)
  })

  // Rekkefoelgen er kronologisk fordi bolkene er det og `Promise.all`
  // beholder rekkefoelgen. Motoren bryr seg ikke - men den dagen noen
  // legger inn noe som gjoer det, skal dette allerede vaere sant.
  it('beholder kronologisk rekkefølge', async () => {
    const rader = await hentPerDato(fakeKilde('2026-01-01', '2026-03-31'), '2026-01-01', '2026-03-31', 7)
    const datoer = rader.map((r) => r.dato)
    expect([...datoer].sort()).toEqual(datoer)
  })

  it('treffer skjøtene riktig med bolker som ikke går opp', async () => {
    // 10 dager i bolker paa 3: 3+3+3+1.
    const rader = await hentPerDato(fakeKilde('2026-01-01', '2026-01-10'), '2026-01-01', '2026-01-10', 3)
    expect(rader.map((r) => r.dato)).toEqual(dager('2026-01-01', '2026-01-10'))
  })

  it('takler én dag og en tom periode', async () => {
    expect(await hentPerDato(fakeKilde('2026-01-01', '2026-01-01'), '2026-01-01', '2026-01-01', 30))
      .toHaveLength(1)
    expect(await hentPerDato(fakeKilde('2026-01-01', '2026-01-01'), '2026-01-05', '2026-01-01'))
      .toEqual([])
  })

  // ===================================================================
  // TAKET ER DEN FARLIGE DELEN
  //
  // PostgREST kutter paa tusen rader uten aa si fra. En bolk som naar
  // taket kan vaere avkortet - og et avkortet aar ser ut som en rolig
  // periode, ikke som en feil. Samme fella som `.limit(50000)` i 0090,
  // 0166 og 0175.
  // ===================================================================
  it('deler en bolk som treffer taket, i stedet for å svelge den', async () => {
    // 40 dager x 40 rader = 1600. En bolk paa 30 dager gir 1200 -> kappes
    // til 1000 av «serveren». Delingen skal finne alle 1600.
    const kutt = (b0: string, b1: string) => {
      const alle: { dato: string; nr: number }[] = []
      for (const d of dager('2026-01-01', '2026-02-09')) {
        if (d >= b0 && d <= b1) for (let i = 0; i < 40; i++) alle.push({ dato: d, nr: i })
      }
      return Promise.resolve({ data: alle.slice(0, 1000), error: null })
    }
    const rader = await hentPerDato(kutt, '2026-01-01', '2026-02-09', 30)
    expect(rader).toHaveLength(40 * 40)
    // Hver dag skal ha alle sine 40 rader - ikke bare de foerste.
    for (const d of dager('2026-01-01', '2026-02-09')) {
      expect(rader.filter((r) => r.dato === d)).toHaveLength(40)
    }
  })

  // KANARIFUGL. Slutter delingen aa virke, gir denne 1000 i stedet for
  // 1600 - og det er noeyaktig den stille avkortingen vakten finnes for.
  it('KANARIFUGL: uten deling ville svaret vært avkortet', async () => {
    const kutt = (b0: string, b1: string) => {
      const alle: { dato: string; nr: number }[] = []
      for (const d of dager('2026-01-01', '2026-02-09')) {
        if (d >= b0 && d <= b1) for (let i = 0; i < 40; i++) alle.push({ dato: d, nr: i })
      }
      return Promise.resolve({ data: alle.slice(0, 1000), error: null })
    }
    // Én bolk som dekker alt, uten deling: 1000 av 1600.
    const { data } = await kutt('2026-01-01', '2026-02-09')
    expect(data).toHaveLength(1000)
  })

  // En dag som ALENE fyller taket kan ikke deles mindre. Da er det ikke
  // paginering som mangler - det er en spoerring uten avgrensning, og da
  // skal den rope i stedet for aa levere et halvt svar.
  it('kaster når én dag alene fyller taket', async () => {
    const altfor = () => Promise.resolve({
      data: Array.from({ length: 1000 }, (_, i) => ({ dato: '2026-01-01', nr: i })),
      error: null,
    })
    await expect(hentPerDato(altfor, '2026-01-01', '2026-01-02', 2))
      .rejects.toThrow(/mangler en avgrensning/)
  })

  // ET HALVT DATASETT ER VERRE ENN INGEN SIDE: summene ville sett
  // riktige ut og vaert for lave.
  it('kaster ved feil i stedet for å returnere det halve', async () => {
    const feil = () => Promise.resolve({ data: null, error: { message: 'timeout' } })
    await expect(hentPerDato(feil, '2026-01-01', '2026-01-10', 3)).rejects.toThrow(/timeout/)
  })

  it('kjører bolkene i parallell, ikke etter hverandre', async () => {
    let samtidig = 0
    let maks = 0
    const treg = async (b0: string, b1: string) => {
      samtidig++
      maks = Math.max(maks, samtidig)
      await new Promise((r) => setTimeout(r, 5))
      samtidig--
      return { data: [{ dato: b0, nr: 0 }], error: null }
    }
    await hentPerDato(treg, '2026-01-01', '2026-03-31', 7)
    expect(maks).toBeGreaterThan(1)
  })

  it('spør bare om perioden den fikk', async () => {
    const spy = vi.fn((b0: string, b1: string) =>
      Promise.resolve({ data: [{ dato: b0, nr: 0 }], error: null }))
    await hentPerDato(spy, '2026-01-01', '2026-01-31', 10)
    for (const [b0, b1] of spy.mock.calls) {
      expect(b0 >= '2026-01-01').toBe(true)
      expect(b1 <= '2026-01-31').toBe(true)
    }
  })
})
