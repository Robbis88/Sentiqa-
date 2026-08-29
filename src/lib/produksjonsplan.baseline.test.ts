import { describe, it, expect } from 'vitest'
import { readFileSync, readdirSync, statSync } from 'node:fs'
import { join } from 'node:path'
import {
  lagProduksjonsplan, leggTilDager, PRODUKSJON_KODER, type SalgsPunkt,
} from './produksjonsplan'

// =====================================================================
// BASELINE FØR SEMANTISK KODEMAPPING
//
// `PRODUKSJON_KODER` skal snart slutte å være åtte hardkodede St1-koder
// og bli en mapping per retailer. Kravet er at **Kelsars plan er
// identisk før og etter**.
//
// Beviset er todelt, fordi arbeidet er todelt:
//
//   motoren     `lagProduksjonsplan` er ren og ser aldri kodene.
//               Denne fila fester hva den svarer.
//   utvalget    begge kallstedene filtrerer i SPØRRINGEN.
//               `supabase/tests/baseline_drivstoff.sql` fester hvilke
//               rader som velges.
//
// Er begge uendret, er planen uendret. Denne fila dekker den første
// halvdelen — og bare den. **Grønn her beviser ikke at Kelsars plan er
// lik; den beviser at motoren ikke ble rørt underveis.**
//
// ---------------------------------------------------------------------
// SKREVET FØR ENDRINGEN, MED VILJE
//
// En gullbilde-test som lages etter et refaktoreringsarbeid fester det
// som allerede skjedde. Da beviser den ingenting om hva som ble endret.
// Denne kjørte grønn mot koden slik den sto da mappingen ennå ikke
// fantes.
// =====================================================================

const MAAL = '2026-06-17'   // onsdag
const SISTE = '2026-06-16'  // siste dag med faktisk salg

/**
 * Fiksturen er valgt for å TREFFE logikken, ikke bare for å fylle den.
 *
 * Tre forsøk måtte til. Et kort fjorvindu ga `trendfaktor` mot taket
 * 1.6; et vindu der fjor- og nyligsummen tilfeldigvis var like ga
 * nøyaktig 1.0. Begge ville bestått som gullbilde og likevel målt
 * nesten ingenting — trenden er KJEDEBRED (`trendNaa / trendFjor` over
 * alle varer, klemt til 0.6–1.6), så den er blind for at enkeltvarer
 * flytter seg hver sin vei.
 *
 * Nå gir den 1.23: innenfor klemmen, ulik 1, og følsom for endringer i
 * begge vinduene.
 */
const VARER = [
  { varenavn: 'Baguette skinke/ost', kode: '1201', navn: 'Baguetter', fjor: 14, nylig: 20 },
  { varenavn: 'Kanelsnurr',          kode: '1216', navn: 'Bakst',     fjor: 22, nylig: 24 },
  { varenavn: 'Pizzasnurr',          kode: '1217', navn: 'Varmmat',   fjor: 9,  nylig: 15 },
  { varenavn: 'Wienerpolse',         kode: '1219', navn: 'Polser',    fjor: 31, nylig: 32 },
]

function fikstur(): SalgsPunkt[] {
  const ut: SalgsPunkt[] = []
  for (const v of VARER) {
    // Sammenhengende fjorvindu som dekker BÅDE medianvinduet (±2 uker
    // rundt fjorårets måldag) og trendens sammenligningsvindu, uten
    // overlappende datoer som ville dublert antallene.
    for (let d = -391; d <= -360; d++) {
      ut.push({ dato: leggTilDager(SISTE, d), varenavn: v.varenavn,
        varegruppeKode: v.kode, varegruppeNavn: v.navn,
        antall: v.fjor + ((d + 391) % 5) - 2 })
    }
    for (let d = -27; d <= 0; d++) {
      ut.push({ dato: leggTilDager(SISTE, d), varenavn: v.varenavn,
        varegruppeKode: v.kode, varegruppeNavn: v.navn,
        antall: v.nylig + ((d + 27) % 5) - 2 })
    }
  }
  // Uten fjorårshistorikk → 'ny'. Uten den ville flagglogikken vært ufestet.
  for (let d = -9; d <= 0; d++) {
    ut.push({ dato: leggTilDager(SISTE, d), varenavn: 'Focaccia tomat',
      varegruppeKode: '1202', varegruppeNavn: 'Baguetter', antall: 6 + ((d + 9) % 3) })
  }
  // Svært tynt datagrunnlag → 'fa_data'.
  for (const d of [-380, -376, -372, -5, -1]) {
    ut.push({ dato: leggTilDager(SISTE, d), varenavn: 'Croissant mandel',
      varegruppeKode: '1218', varegruppeNavn: 'Bakst', antall: 4 })
  }
  return ut
}

function plan() {
  return lagProduksjonsplan({
    maalDato: MAAL, sisteSalgsdato: SISTE, salg: fikstur(),
    vaerMaal: { temp_maks: 19, nedbor_mm: 0 },
    vaerFjor: { temp_maks: 14, nedbor_mm: 3.2 },
    vaerfolsomhet: 0.5,
  })
}

/** Avlest 2026-08-28, før mappingen fantes. Skal ikke endres av en refaktorering. */
const FASIT = [
  { varenavn: 'Wienerpolse',         kode: '1219', fjorMedian: 32,   nyligSnitt: 31.8, basis: 32,  vf: 1,    tf: 1.23, sf: 1.23, foreslatt: 39, flagg: [] },
  { varenavn: 'Kanelsnurr',          kode: '1216', fjorMedian: 23,   nyligSnitt: 23.8, basis: 23,  vf: 1,    tf: 1.23, sf: 1.23, foreslatt: 28, flagg: [] },
  { varenavn: 'Baguette skinke/ost', kode: '1201', fjorMedian: 15,   nyligSnitt: 19.8, basis: 15,  vf: 1,    tf: 1.23, sf: 1.23, foreslatt: 18, flagg: [] },
  { varenavn: 'Pizzasnurr',          kode: '1217', fjorMedian: 10,   nyligSnitt: 14.8, basis: 10,  vf: 0.95, tf: 1.23, sf: 1.17, foreslatt: 12, flagg: [] },
  { varenavn: 'Focaccia tomat',      kode: '1202', fjorMedian: null, nyligSnitt: 6.9,  basis: 6.9, vf: 1,    tf: 1.23, sf: 1.23, foreslatt: 8,  flagg: ['ny', 'fa_data'] },
  { varenavn: 'Croissant mandel',    kode: '1218', fjorMedian: null, nyligSnitt: 4,    basis: 4,   vf: 1,    tf: 1.23, sf: 1.23, foreslatt: 5,  flagg: ['ny', 'fa_data'] },
]

describe('produksjonsmotoren, festet før kodemappingen', () => {
  it('gir nøyaktig den planen den ga 2026-08-28', () => {
    const p = plan()
    expect(p.advarsler).toEqual([])
    expect(p.forslag.map((f) => f.varenavn)).toEqual(FASIT.map((f) => f.varenavn))
    for (let i = 0; i < FASIT.length; i++) {
      const f = p.forslag[i], v = FASIT[i]
      expect({
        varenavn: f.varenavn, kode: f.varegruppeKode, fjorMedian: f.fjorMedian,
        nyligSnitt: f.nyligSnitt, basis: f.basis, vf: f.vaerfaktor,
        tf: f.trendfaktor, sf: f.samletfaktor, foreslatt: f.foreslatt, flagg: f.flagg,
      }).toEqual(v)
    }
  })

  it('KANARIFUGL: fiksturen treffer faktisk logikken', () => {
    // Et gullbilde av en degenerert plan består like fint som et av en
    // ekte. Uten disse ville en fikstur som slutter å produsere
    // variasjon sett nøyaktig ut som en motor som ikke er endret.
    const p = plan()
    expect(p.forslag.length, 'ingen forslag — fiksturen måler ingenting').toBeGreaterThan(0)

    const tf = p.forslag.map((f) => f.trendfaktor)
    expect(new Set(tf).size, 'trendfaktoren er kjedebred, én verdi ventet').toBe(1)
    expect(tf[0], 'trendfaktor 1.0 = ingen trend målt').not.toBe(1)
    expect(tf[0], 'trendfaktor mot klemmen 0.6/1.6 = fiksturen er for skjev')
      .toBeGreaterThan(0.6)
    expect(tf[0]).toBeLessThan(1.6)

    expect(new Set(p.forslag.map((f) => f.vaerfaktor)).size,
      'alle værfaktorer like — varegruppefølsomheten er ikke truffet').toBeGreaterThan(1)
    expect(p.forslag.some((f) => f.flagg.includes('ny')), 'flagget «ny» er ikke truffet').toBe(true)
    expect(p.forslag.some((f) => f.flagg.includes('fa_data')), 'flagget «fa_data» er ikke truffet').toBe(true)
    expect(p.forslag.some((f) => f.fjorMedian === null), 'fjorMedian null-veien er ikke truffet').toBe(true)
  })
})

describe('utvalget, etter at det ble konfigurasjon', () => {
  it('er de åtte St1-kodene', () => {
    expect(PRODUKSJON_KODER).toEqual(
      ['1201', '1202', '1203', '1216', '1217', '1218', '1219', '1221'])
  })

  it('og 0152 backfiller NØYAKTIG de samme åtte', () => {
    // Konstanten leses ikke lenger av noen spørring — den er seedet
    // migrasjonen fyller Kelsars mapping med. Da må de to holdes i takt,
    // ellers har vi to sannheter om hva en produksjonsvare er: den i
    // koden og den i basen. Denne påstanden er sammenføyningen.
    const sql = readFileSync(
      join(process.cwd(), 'supabase/migrations/0152_semantisk_kodemapping.sql'), 'utf8')
    const m = sql.match(/unnest\(array\[([^\]]+)\]\)/)
    expect(m, 'fant ikke produksjonsbackfillen i 0152').not.toBeNull()
    const iMigrasjonen = m![1].split(',').map((k) => k.trim().replace(/'/g, ''))
    expect(iMigrasjonen).toEqual(PRODUKSJON_KODER)
  })

  it('leses ikke lenger av noen spørring', () => {
    // Sto i to kallsteder til `0152`. Blir konstanten tatt i bruk igjen,
    // har noen omgått mappingen — og da får den kjeden Kelsars koder
    // uansett hva som står i konfigurasjonen.
    // Kommentarer teller ikke. `produksjonskoder.ts` forklarer hva den
    // erstattet, og `produksjonsplan.ts` eksporterer den — en omtale er
    // ikke et kall, samme skille som `funksjoner.ts` gjør.
    const treff = kildefiler(join(process.cwd(), 'src'))
      .filter((f) => !/produksjonsplan\.ts$|produksjonskoder\.ts$/.test(f.replace(/\\/g, '/')))
      .filter((f) => /PRODUKSJON_KODER/.test(readFileSync(f, 'utf8')))
      .map((f) => f.replace(/\\/g, '/').split('/src/')[1])
    expect(treff, 'PRODUKSJON_KODER brukes igjen i en spørring').toEqual([])
  })

  it('mappingen leses fra nøyaktig to steder', () => {
    // SKRALLEN FLYTTET MED. Samme regel som før, nytt kallnavn: kommer et
    // tredje sted til, må også det håndtere `ikke_konfigurert` — og et
    // kallsted som glemmer det gir en troverdig tom plan. `0075`-formen.
    const treff = kildefiler(join(process.cwd(), 'src'))
      .filter((f) => !f.endsWith('produksjonskoder.ts'))
      .filter((f) => /hentProduksjonskoder/.test(readFileSync(f, 'utf8')))
      .map((f) => f.replace(/\\/g, '/').split('/src/')[1])
    expect(treff.sort(), 'nytt kallsted for produksjonsmappingen').toEqual([
      'app/(beskyttet)/produksjonsplan/page.tsx',
      'lib/backtest.ts',
    ])
  })

  it('og begge håndterer ikke_konfigurert', () => {
    // Det er ikke nok å kalle helperen. Kaller du den og ignorerer
    // statusen, filtrerer du på en tom liste og er akkurat like ille
    // stilt som før.
    for (const f of ['app/(beskyttet)/produksjonsplan/page.tsx', 'lib/backtest.ts']) {
      const kilde = readFileSync(join(process.cwd(), 'src', f), 'utf8')
      expect(kilde, `${f} sjekker ikke ikke_konfigurert`).toMatch(/ikke_konfigurert/)
    }
  })

  it('KANARIFUGL: filsøket leser en kodebase som finnes', () => {
    expect(kildefiler(join(process.cwd(), 'src')).length).toBeGreaterThan(100)
  })
})

function kildefiler(katalog: string): string[] {
  const ut: string[] = []
  for (const navn of readdirSync(katalog)) {
    const sti = join(katalog, navn)
    if (statSync(sti).isDirectory()) ut.push(...kildefiler(sti))
    else if (/\.tsx?$/.test(navn) && !/\.test\.tsx?$/.test(navn)) ut.push(sti)
  }
  return ut
}
