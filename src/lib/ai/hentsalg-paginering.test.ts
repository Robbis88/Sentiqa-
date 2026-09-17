import { describe, expect, it } from 'vitest'
import { hentSalg } from './forventetverktoy'

// =====================================================================
// PAGINERING OVER EN NØKKEL SOM IKKE ER UNIK, MISTER RADER I STILLHET
// =====================================================================
//
// `hentSalg` henter historikken AI-assistenten svarer fra. Den sider
// 1 000 rader om gangen med `.range()`. Sorterer den bare på `dato`,
// er nøkkelen ikke unik når flere stasjoner spørres samtidig — og
// Postgres står da fritt til å ordne de uavgjorte radene ulikt mellom
// to spørringer. Rader på sidegrensen faller ut eller kommer dobbelt.
//
// DET SER IKKE UT SOM EN FEIL. Ingen exception, ingen tom respons —
// bare et litt annet tall. Det var nøyaktig denne feilen som gjorde
// hb2-målingen ureproduserbar: 1 % av radene forsvant, spredt og
// tilfeldig, og forvrengte kvalitetsklassifiseringen per stasjon.
//
// ---------------------------------------------------------------------
// HVORFOR EN FALSK KLIENT, OG IKKE EN LEVENDE KJØRING
// ---------------------------------------------------------------------
//
// En live-test ville krevd legitimasjon, og uten den ville den hoppet
// over og meldt grønt — en vakt som ikke ser, ser ut som en vakt som
// ikke finner noe. Denne kjører alltid.
//
// Den falske klienten SERVERER bare rader. Sideløkka, sidestørrelsen og
// stoppvilkåret er produksjonens egne: testen kaller `hentSalg`, ikke
// en kopi av pagineringen. At sidegrensen er produksjonens bevises ved
// at første side ber om nøyaktig `[0, 999]`.
// =====================================================================

type Rad = {
  stasjon_id: string; dato: string; ean: string; antall: number | null
  varegruppe_kode: string | null; varegruppe_navn: string | null
}

const STASJONER = ['s1', 's2', 's3']
const DAGER = 400
const EAN = '5000112636833'

/**
 * 1 200 rader: 400 datoer × 3 stasjoner. Hver dato har tre rader, så
 * `dato` alene gir grupper på tre.
 *
 * Med 1 000 rader per side treffer grensen MIDT I en gruppe: datoen med
 * indeks 333 ligger på 999, 1000 og 1001. Det er der rader forsvinner.
 */
function lagRader(): Rad[] {
  const ut: Rad[] = []
  for (let i = 0; i < DAGER; i++) {
    const dato = new Date(Date.UTC(2026, 0, 1) + i * 86_400_000).toISOString().slice(0, 10)
    for (const s of STASJONER) {
      ut.push({
        stasjon_id: s, dato, ean: EAN, antall: 1,
        varegruppe_kode: '120', varegruppe_navn: 'Kaffe',
      })
    }
  }
  return ut
}

/**
 * Postgres' frihet ved uavgjort, gjort deterministisk.
 *
 * Radene sorteres etter de kolonnene spørringen FAKTISK ba om. Rader
 * som er like på alle de kolonnene utgjør en gruppe, og hver gruppe
 * roteres med sidetelleren. Ingen tilfeldighet — men to spørringer med
 * samme ikke-unike nøkkel får ulik rekkefølge, som i basen.
 *
 * Er nøkkelen unik, er hver gruppe på én rad og rotasjonen er identitet.
 * Da er dette en helt vanlig, stabil sortering.
 */
function sorterSomPostgres(rader: Rad[], kolonner: string[], fro: number): Rad[] {
  const noekkel = (r: Rad) => JSON.stringify(kolonner.map((k) => String(r[k as keyof Rad])))
  const sortert = [...rader].sort((a, b) => {
    const x = noekkel(a); const y = noekkel(b)
    return x < y ? -1 : x > y ? 1 : 0
  })
  const ut: Rad[] = []
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

function lagKlient(alle: Rad[]) {
  let sider = 0
  let ordrer: string[] = []
  const omraader: [number, number][] = []

  function bygger() {
    const mine: string[] = []
    const q = {
      select: () => q,
      eq: () => q,
      in: () => q,
      gte: () => q,
      lte: () => q,
      order: (kolonne: string) => { mine.push(kolonne); return q },
      range: (fra: number, til: number) => {
        sider++
        ordrer = [...mine]
        omraader.push([fra, til])
        const data = sorterSomPostgres(alle, mine, sider).slice(fra, til + 1)
        return { overrideTypes: () => Promise.resolve({ data }) }
      },
    }
    return q
  }

  // Testdobbel. `Klient` er hele SupabaseClient-typen; her trengs bare
  // kjeden `hentSalg` faktisk bruker.
  const klient = { from: () => bygger() } as unknown as Parameters<typeof hentSalg>[0]
  return { klient, tall: () => ({ sider, ordrer, omraader }) }
}

describe('hentSalg — stabil paginering over flere stasjoner', () => {
  it('feil på side to gir aldri en prognose basert bare på side én', async () => {
    let offset = 0
    const q = {
      select: () => q, eq: () => q, in: () => q, gte: () => q, lte: () => q, order: () => q,
      range: (fra: number) => { offset = fra; return q },
      overrideTypes: async () => offset === 0 ? { data: lagRader().slice(0, 1000), error: null }
        : { data: null, error: { message: 'statement timeout' } },
    }
    await expect(hentSalg({ from: () => q } as unknown as Parameters<typeof hentSalg>[0], STASJONER, EAN, '2026-01-01', '2027-12-31')).rejects.toThrow('statement timeout')
  })
  it('henter alle sidene uten tap og uten duplikater', async () => {
    const alle = lagRader()
    const { klient, tall } = lagKlient(alle)

    const ut = await hentSalg(klient, STASJONER, EAN, '2026-01-01', '2027-12-31')
    const { sider, ordrer, omraader } = tall()

    // 1  Sorteringen som ble bedt om, er entydig. `ean` er låst med
    //    .eq(), så (dato, stasjon_id) er den minste unike nøkkelen.
    expect(ordrer).toEqual(['dato', 'stasjon_id'])

    // 2  Ingen tap: alle 1 200 radene kom med.
    expect(ut.length).toBe(alle.length)

    // 3  Ingen duplikater: (stasjon_id, dato) er unik per rad.
    const noekler = new Set(ut.map((r) => `${r.stasjonId}|${r.dato}`))
    expect(noekler.size).toBe(alle.length)

    // 4  Riktig innhold, ikke bare riktig antall.
    const fasit = alle.map((r) => `${r.stasjon_id}|${r.dato}`).sort()
    expect([...noekler].sort()).toEqual(fasit)

    // 5  KANARIFUGL. Uten denne ville et datasett under 1 000 rader gjort
    //    testen grønn uten å røre sidegrensen — og da måler den ingenting.
    //    `[0, 999]` beviser samtidig at sidestørrelsen er produksjonens
    //    egen, ikke en konstant i testen.
    expect(sider).toBeGreaterThanOrEqual(2)
    expect(omraader[0]).toEqual([0, 999])
  })
})
