import { describe, expect, it } from 'vitest'
import { hentTreff, SIDE, type TreffRad } from './hent-treff'

// =====================================================================
// `prognose_treff` HAR FLERE RADER PER DATO — ALLTID
// =====================================================================
//
// Nøkkelen er `unique (stasjon_id, type, dato, kategori)`. Stasjonen er
// låst med .eq(), så én dato bærer én rad per (type, kategori) — to
// typer ganger kategoriene. `dato` alene er derfor aldri unik her, og
// `.range()` over en ustabil ordning mister rader i stillhet.
//
// Det ville ikke sett ut som en feil. Treffsikkerheten per kategori
// ville bare vært regnet på et litt annet radsett enn den skulle.
//
// Samme form som `hentsalg-paginering.test.ts`: den falske klienten
// serverer bare rader, mens løkka, sidestørrelsen og stoppvilkåret er
// produksjonens egne.
// =====================================================================

const TYPER: TreffRad['type'][] = ['produksjonsplan', 'salgsprognose']
const KATEGORIER = ['*', '1201', '1202']
const DAGER = 200
const STASJON = 'st-1'

/**
 * 1 200 rader: 200 datoer × 2 typer × 3 kategorier = 6 rader per dato.
 *
 * Med 1 000 rader per side treffer grensen MIDT I en gruppe: datoen med
 * indeks 166 ligger på 996–1001, altså på tvers av 999/1000.
 */
function lagRader(): TreffRad[] {
  const ut: TreffRad[] = []
  for (let i = 0; i < DAGER; i++) {
    const dato = new Date(Date.UTC(2026, 0, 1) + i * 86_400_000).toISOString().slice(0, 10)
    for (const type of TYPER) {
      for (const kategori of KATEGORIER) {
        ut.push({ type, dato, kategori, forventet: 10, faktisk: 9, treff: 90 })
      }
    }
  }
  return ut
}

/** Postgres' frihet ved uavgjort, gjort deterministisk. Se hentsalg-testen. */
function sorterSomPostgres(rader: TreffRad[], kolonner: string[], fro: number): TreffRad[] {
  const noekkel = (r: TreffRad) =>
    JSON.stringify(kolonner.map((k) => String(r[k as keyof TreffRad])))
  const sortert = [...rader].sort((a, b) => {
    const x = noekkel(a); const y = noekkel(b)
    return x < y ? -1 : x > y ? 1 : 0
  })
  const ut: TreffRad[] = []
  let i = 0
  while (i < sortert.length) {
    let j = i
    while (j < sortert.length && noekkel(sortert[j]) === noekkel(sortert[i])) j++
    const gruppe = sortert.slice(i, j)
    const skift = gruppe.length > 1 ? fro % gruppe.length : 0
    ut.push(...gruppe.slice(skift), ...gruppe.slice(0, skift))
    i = j
  }
  return ut
}

function lagKlient(alle: TreffRad[]) {
  let sider = 0
  let ordrer: string[] = []
  const omraader: [number, number][] = []

  function bygger() {
    const mine: string[] = []
    const q = {
      select: () => q,
      eq: () => q,
      order: (kolonne: string) => { mine.push(kolonne); return q },
      range: (fra: number, til: number) => {
        sider++
        ordrer = [...mine]
        omraader.push([fra, til])
        const data = sorterSomPostgres(alle, mine, sider).slice(fra, til + 1)
        return { overrideTypes: () => Promise.resolve({ data, error: null }) }
      },
    }
    return q
  }

  // Testdobbel: bare kjeden `hentTreff` faktisk bruker.
  const klient = { from: () => bygger() } as unknown as Parameters<typeof hentTreff>[0]
  return { klient, tall: () => ({ sider, ordrer, omraader }) }
}

describe('hentTreff — stabil paginering over flere typer og kategorier', () => {
  it('henter alle sidene uten tap og uten duplikater', async () => {
    const alle = lagRader()
    const { klient, tall } = lagKlient(alle)

    const ut = await hentTreff(klient, STASJON)
    const { sider, ordrer, omraader } = tall()

    // 1  Entydig sortering. Stasjonen er låst med .eq(), så
    //    (dato, type, kategori) er den minste unike nøkkelen.
    expect(ordrer).toEqual(['dato', 'type', 'kategori'])

    // 2  Ingen tap.
    expect(ut.length).toBe(alle.length)

    // 3  Ingen duplikater.
    const noekler = new Set(ut.map((r) => `${r.type}|${r.dato}|${r.kategori}`))
    expect(noekler.size).toBe(alle.length)

    // 4  Riktig innhold, ikke bare riktig antall.
    const fasit = alle.map((r) => `${r.type}|${r.dato}|${r.kategori}`).sort()
    expect([...noekler].sort()).toEqual(fasit)

    // 5  KANARIFUGL: sidegrensen ble faktisk krysset, og sidestørrelsen
    //    er produksjonens egen.
    expect(sider).toBeGreaterThanOrEqual(2)
    expect(omraader[0]).toEqual([0, SIDE - 1])
  })
})
