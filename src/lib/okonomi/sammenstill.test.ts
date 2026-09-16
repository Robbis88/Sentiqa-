import { describe, expect, it } from 'vitest'
import { byggMaanedsbilde, maanederMedBilde, standardmaaned, type Bildegrunnlag } from './sammenstill'
import { hvaBoerJegViteNaa } from './vite'
import type { Lonnsrom } from '@/lib/lonnskost/rom'
import type { Maanedslonn } from '@/lib/lonnskost/maaned'
import type { EasyatworkMaaned } from '@/lib/lonnskost/easyatwork'
import type { Lonnsbilde } from '@/lib/lonnskost/hent'

// =====================================================================
// NEGATIVE VAKTER FOR SAMMENSTILLINGEN
// =====================================================================
//
// Alle sammen er formet etter samme spørsmål: HVA SER RIKTIG UT NÅR DET
// ER GALT?
//
// En manglende royalty som står som «0 kr» ser ut som en stasjon uten
// royalty. En anslått brutto merket `fasit` ser ut som et avstemt tall.
// Et lønnsrom regnet av et anslag, merket `fasit`, ser ut som en grense
// noen kan stole på. Ingen av dem gir en feilmelding.
//
// `naa` er ALLTID et argument her, aldri `new Date()` inne i en regel.
// En test som leser klokka måler noe annet i morgen.
// =====================================================================

const NAA = new Date('2026-09-16T10:00:00Z')
const ANDEL = 383285 / 1201000

const ROM = (o: Partial<Lonnsrom> = {}): Lonnsrom => ({
  maaned: '2026-08',
  bruttoKr: 1201000,
  anslaatt: false,
  lonnsandel: ANDEL,
  romKr: 383285,
  bpLonnKr: 383285,
  kalibrering: 1,
  ekstraSvinnKr: 0,
  omsetningKr: 4200000,
  svinnKr: 0,
  bilvaskBruttoKr: 0,
  ...o,
})

const MAANED = (o: Partial<Maanedslonn> = {}): Maanedslonn => ({
  maaned: '2026-08',
  avlagt: true,
  kontantKr: 300000,
  feriepengerKr: 40000,
  agaKr: 50000,
  lonnskostKr: 390000,
  niva: { styringskostKr: 380000, ovrigLonnKr: 10000, ukjenteKonti: [] },
  andrePersonalKr: 0,
  budsjettKr: 383285,
  budsjettKilde: null,
  bpBudsjettKr: 383285,
  timer: 1200,
  snittsats: null,
  linjer: [],
  ...o,
})

const EA = (o: Partial<EasyatworkMaaned> = {}): EasyatworkMaaned => ({
  maaned: '2026-08',
  timer: 1200,
  kontantKr: 290000,
  perKonto: { '501': 100000, '503': 190000 },
  feriepengerKr: 38000,
  pensjonKr: 0,
  agaKr: 43000,
  lonnskostKr: 371000,
  ukjenteArter: [],
  sykelonnFraMaaned: null,
  // EASY@WORK-EKSPORTEN HAR BARE TIMELOENNEDE. Fastloenna legges paa av
  // `medFastlonn` — 0 her betyr «ingen fastloennet paa stasjonen», ikke
  // «vi vet ikke». Testene under maaler ikke fastloennen.
  fastlonnKr: 0,
  fastlonnFraMaaned: null,
  fastlonnKilde: null,
  ...o,
})

function grunnlag(o: {
  rom?: Lonnsrom[]
  maaneder?: Maanedslonn[]
  easyatwork?: EasyatworkMaaned[]
  fasit?: Bildegrunnlag['fasit']
  salgsdager?: Map<string, number>
  bilvaskUker?: Lonnsbilde['bilvaskUker']
} = {}): Bildegrunnlag {
  return {
    stasjonId: 's1',
    salgsdager: o.salgsdager ?? new Map([['2026-08', 31]]),
    fasit: o.fasit ?? new Map(),
    lonnsbilde: {
      maaneder: o.maaneder ?? [MAANED()],
      ukjenteKoder: [],
      easyatwork: o.easyatwork ?? [EA()],
      sykelonn: { moenster: 'samme_maaned', maalte: 0, forsinkede: 0 },
      rom: o.rom ?? [ROM()],
      bilvaskUker: o.bilvaskUker ?? [],
      fastlonnMaaneder: [],
      ansatte: [],
      ansatteMaaned: null,
    } as unknown as Lonnsbilde,
  }
}

const FASIT = (o: Partial<{ omsetningKr: number | null; paavirkbarDriftKr: number | null; royaltyKr: number | null }> = {}) =>
  new Map([['2026-08', {
    omsetningKr: 4200000, paavirkbarDriftKr: 96000, royaltyKr: 420000, ...o,
  }]])

// =====================================================================
describe('mangler blir aldri 0', () => {
  it('royalty og paavirkbar drift staar som `mangler` naar regnskapet ikke har dem', () => {
    const b = byggMaanedsbilde(grunnlag({ fasit: FASIT({ royaltyKr: null, paavirkbarDriftKr: null }) }),
      { maaned: '2026-08', rolle: 'retailer_admin', naa: NAA })!

    expect(b.bilde.royalty.verdi).toBeNull()
    expect(b.bilde.royalty.kilde).toBe('mangler')
    expect(b.bilde.paavirkbarDrift.verdi).toBeNull()
    expect(b.bilde.paavirkbarDrift.kilde).toBe('mangler')
  })

  it('EN FASITRAD BRUKES IKKE PAA EN MAANED SOM IKKE ER AVLAGT', () => {
    // =================================================================
    // `v_kurs_maanedstall` HAR `coalesce(..., 0)` PAA HVERT KRONEFELT
    // =================================================================
    //
    // Raden finnes naar stasjonsmaaneden har regnskapslinjer i det hele
    // tatt - og da staar omsetning, paavirkbar drift og resultat som 0
    // hvis ingen av linjene traff filteret. Null kroner og «ingen tall»
    // ser like ut i viewet.
    //
    // `byggMaanedsbilde` leser derfor fasiten BARE naar maaneden er
    // avlagt. Uten det ville en aapen maaned meldt 0 kr i paavirkbar
    // drift som om det var maalt - og et hull ville sett ut som god
    // kostnadskontroll.
    const g = grunnlag({
      maaneder: [MAANED({ avlagt: false, niva: null })],
      fasit: FASIT({ omsetningKr: 0, paavirkbarDriftKr: 0, royaltyKr: 0 }),
    })
    const b = byggMaanedsbilde(g, { maaned: '2026-08', rolle: 'retailer_admin', naa: NAA })!

    expect(b.avlagt).toBe(false)
    expect(b.bilde.paavirkbarDrift.verdi).toBeNull()
    expect(b.bilde.royalty.verdi).toBeNull()
    // Omsetningen faller tilbake paa de daglige salgsfilene - som er en
    // PROGNOSE, ikke fasitens 0.
    expect(b.bilde.omsetning.kilde).toBe('prognose')
    expect(b.bilde.omsetning.verdi).toBe(4200000)
  })

  it('en maaned uten loennsfil har ikke loenn 0', () => {
    const b = byggMaanedsbilde(
      grunnlag({ maaneder: [MAANED({ avlagt: false, niva: null })], easyatwork: [] }),
      { maaned: '2026-08', rolle: 'retailer_admin', naa: NAA },
    )!
    expect(b.bilde.lonn.verdi).toBeNull()
    expect(b.bilde.lonn.kilde).toBe('mangler')
    expect(b.bilde.styringsavvik.avvik.kroner).toBeNull()
  })

  it('DEKNINGEN SIER FRA at loennsfila mangler, og sier det ÉN gang', () => {
    // =================================================================
    // «FILA ER IKKE KOMMET» ER EN ANNEN BESKJED ENN «TALLET MANGLER»
    // =================================================================
    //
    // Den foerste har en vei videre: eksporten finnes dagen etter
    // maaneden. Den andre er bare et hull. `dekning.lonnsfil` er det
    // eneste stedet forskjellen staar, og `vite.ts` leser den - baade
    // for aa SI det, og for aa la vaere aa si det to ganger.
    //
    // En injeksjon som satte `lonnsfil: true` uansett kom groenn tilbake
    // foer denne testen fantes: ingen maalte flagget.
    const uten = byggMaanedsbilde(
      grunnlag({ maaneder: [MAANED({ avlagt: false, niva: null })], easyatwork: [] }),
      { maaned: '2026-08', rolle: 'retailer_admin', naa: NAA },
    )!
    expect(uten.bilde.dekning.lonnsfil).toBe(false)
    const sagt = hvaBoerJegViteNaa(uten.bilde).map((b) => b.tittel)
    expect(sagt.some((t) => /lønnsfila er ikke kommet/i.test(t))).toBe(true)
    // OG IKKE TO GANGER. `styringsavvik` svarer «Lønnstallet er ikke
    // kommet ennå.» paa sitt vis; `vite.ts` lar den ligge naar dekningen
    // alt har forklart den. Én kjensgjerning, én stemme.
    expect(sagt.filter((t) => /ikke kommet/i.test(t))).toHaveLength(1)

    const med = byggMaanedsbilde(
      grunnlag({ maaneder: [MAANED({ avlagt: false, niva: null })] }),
      { maaned: '2026-08', rolle: 'retailer_admin', naa: NAA },
    )!
    expect(med.bilde.dekning.lonnsfil).toBe(true)
    expect(hvaBoerJegViteNaa(med.bilde).map((b) => b.tittel)
      .some((t) => /lønnsfila/i.test(t))).toBe(false)
  })
})

// =====================================================================
describe('en prognose presenteres aldri som fasit', () => {
  it('anslaatt brutto gir prognose paa BAADE brutto og loennsrom', () => {
    const b = byggMaanedsbilde(
      grunnlag({
        rom: [ROM({ anslaatt: true })],
        maaneder: [MAANED({ avlagt: false, niva: null })],
      }),
      { maaned: '2026-08', rolle: 'retailer_admin', naa: NAA },
    )!
    expect(b.bilde.brutto.kilde).toBe('prognose')
    // ROMMET ER LIKE ANSLAATT SOM BRUTTOEN DET ER REGNET AV.
    expect(b.bilde.lonnsrom.kilde).toBe('prognose')
    expect(b.bilde.lonnsrom.grunn).toContain('anslått brutto')
  })

  it('styringsavviket arver den SVAKESTE kilden, ikke den sterkeste', () => {
    // Avlagt brutto, men loennstallet er easy@work. Lov 2: avviket er et
    // anslag, uansett hvor sikker bruttoen er.
    const b = byggMaanedsbilde(
      grunnlag({
        rom: [ROM({ anslaatt: false })],
        maaneder: [MAANED({ avlagt: false, niva: null })],
      }),
      { maaned: '2026-08', rolle: 'retailer_admin', naa: NAA },
    )!
    expect(b.bilde.lonnsrom.kilde).toBe('fasit')
    expect(b.bilde.styringsavvik.kilde).not.toBe('fasit')
  })

  it('BP-loenna er ALLTID `plan`, aldri faktisk', () => {
    for (const avlagt of [true, false]) {
      const b = byggMaanedsbilde(
        grunnlag({ maaneder: [MAANED({ avlagt, niva: avlagt ? MAANED().niva : null })] }),
        { maaned: '2026-08', rolle: 'retailer_admin', naa: NAA },
      )!
      expect(b.bilde.bpLonn.kilde).toBe('plan')
    }
  })
})

// =====================================================================
describe('rollen skjermes, og skjerming er ikke en mangel', () => {
  it('butikksjefen ser royalty som `skjult`, ikke som `mangler`', () => {
    const b = byggMaanedsbilde(grunnlag({ fasit: FASIT() }),
      { maaned: '2026-08', rolle: 'butikksjef', naa: NAA })!
    expect(b.bilde.royalty.kilde).toBe('skjult')
    // Og skjermingen skal ikke senke sikkerheten paa et ellers avstemt
    // bilde. Tilgang er ikke datakvalitet.
    expect(b.bilde.sikkerhet).toBe('hoy')
  })

  it('eieren ser royaltyen som fasit', () => {
    const b = byggMaanedsbilde(grunnlag({ fasit: FASIT() }),
      { maaned: '2026-08', rolle: 'retailer_admin', naa: NAA })!
    expect(b.bilde.royalty.kilde).toBe('fasit')
    expect(b.bilde.royalty.verdi).toBe(420000)
  })
})

// =====================================================================
describe('maanedsvalget er den samme regelen som foer', () => {
  it('standardmaaned tar nyeste maaned med rom eller brutto, ikke nyeste med loennsfil', () => {
    const g = grunnlag({
      rom: [
        ROM({ maaned: '2026-09', bruttoKr: 600000, romKr: 190000, anslaatt: true }),
        ROM({ maaned: '2026-08' }),
      ],
      maaneder: [MAANED({ maaned: '2026-08' })],
      easyatwork: [EA({ maaned: '2026-08' })],
    })
    // September har verken regnskap eller loennsfil - og det er nettopp
    // den maaneden som har mest aa fortelle.
    expect(standardmaaned(g)).toBe('2026-09')
  })

  it('hopper over en maaned uten baade rom og brutto', () => {
    const g = grunnlag({
      rom: [
        ROM({ maaned: '2026-09', bruttoKr: null, romKr: null, bpLonnKr: null }),
        ROM({ maaned: '2026-08' }),
      ],
    })
    expect(standardmaaned(g)).toBe('2026-08')
  })

  it('VELGEREN TILBYR INGEN MAANED SOM IKKE KAN VISES', () => {
    // =================================================================
    // BP-EN DEKKER HELE AARET, OGSAA MAANEDER SOM IKKE HAR VAERT
    // =================================================================
    //
    // Maalt mot produksjon 2026-09-16: seksten maaneder per stasjon, til
    // og med 2026-12. `byggLonnskost` skriver en rad for hver
    // BP-budsjettmaaned, og den gamle unionen tok dem med. Velgeren
    // tilboed altsaa oktober, november og desember - som alle endte i
    // «Ingen ramme for desember 2026».
    const g = grunnlag({
      rom: [
        // Framtidige BP-maaneder: budsjett finnes, brutto gjoer ikke.
        ROM({ maaned: '2026-12', bruttoKr: null, romKr: null }),
        ROM({ maaned: '2026-11', bruttoKr: null, romKr: null }),
        ROM({ maaned: '2026-09', bruttoKr: 600000, romKr: 190000, anslaatt: true }),
        ROM({ maaned: '2026-08' }),
      ],
      maaneder: [MAANED({ maaned: '2026-12' }), MAANED({ maaned: '2026-08' })],
      easyatwork: [EA({ maaned: '2026-08' })],
    })
    expect(maanederMedBilde(g)).toEqual(['2026-09', '2026-08'])
  })

  it('HVER maaned lista tilbyr gir faktisk et bilde', () => {
    // Invarianten, ikke et eksempel. En liste som lover noe den ikke
    // har, laerer folk aa ikke stole paa den.
    const g = grunnlag({
      rom: [
        ROM({ maaned: '2026-12', bruttoKr: null, romKr: null }),
        ROM({ maaned: '2026-09', bruttoKr: 600000, romKr: 190000, anslaatt: true }),
        ROM({ maaned: '2026-08' }),
      ],
    })
    const lista = maanederMedBilde(g)
    expect(lista.length).toBeGreaterThan(0)
    for (const m of lista) {
      expect(byggMaanedsbilde(g, { maaned: m, rolle: 'retailer_admin', naa: NAA }),
        `velgeren tilbyr ${m}, men siden kan ikke tegne den`).not.toBeNull()
    }
  })

  it('standardmaaneden staar ALLTID i sin egen velger', () => {
    // To regler ville latt standardvalget falle utenfor lista - og da
    // viser velgeren én maaned mens siden viser en annen.
    const g = grunnlag({
      rom: [
        ROM({ maaned: '2026-12', bruttoKr: null, romKr: null }),
        ROM({ maaned: '2026-09', bruttoKr: 600000, romKr: 190000, anslaatt: true }),
        ROM({ maaned: '2026-08' }),
      ],
    })
    expect(maanederMedBilde(g)[0]).toBe(standardmaaned(g))
  })

  it('en maaned uten rom gir null bilde, ikke et bilde fullt av mangler', () => {
    expect(byggMaanedsbilde(grunnlag(), {
      maaned: '2025-01', rolle: 'retailer_admin', naa: NAA,
    })).toBeNull()
  })
})

// =====================================================================
describe('dekningen teller bare det maaneden KAN ha', () => {
  it('en stasjon uten bilvask venter ingen bilvaskuker', () => {
    const b = byggMaanedsbilde(grunnlag({ bilvaskUker: [] }),
      { maaned: '2026-08', rolle: 'retailer_admin', naa: NAA })!
    expect(b.bilde.dekning.mangler.join(' ')).not.toContain('bilvask')
  })

  it('en avlagt maaned melder ingen mangler - regnskapet er fasit', () => {
    const b = byggMaanedsbilde(
      grunnlag({ salgsdager: new Map([['2026-08', 3]]) }),
      { maaned: '2026-08', rolle: 'retailer_admin', naa: NAA },
    )!
    expect(b.bilde.dekning.regnskap).toBe(true)
    expect(b.bilde.dekning.mangler).toEqual([])
  })

  it('en aapen maaned melder manglende salgsdager, og retningen paa feilen', () => {
    const b = byggMaanedsbilde(
      grunnlag({
        maaneder: [MAANED({ avlagt: false, niva: null })],
        salgsdager: new Map([['2026-08', 3]]),
      }),
      { maaned: '2026-08', rolle: 'retailer_admin', naa: NAA },
    )!
    expect(b.bilde.dekning.mangler.length).toBeGreaterThan(0)
    expect(b.bilde.dekning.retningPaaFeil).toBe('for_lavt')
  })
})
