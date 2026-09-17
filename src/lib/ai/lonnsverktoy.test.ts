import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { VERKTOY, verktoyForRolle, VERKTOY_ETIKETT } from './verktoy'
import { hentLonnskostVerktoy, hentLonnsromVerktoy, tilRomrad } from './lonnsverktoy'

// =====================================================================
// AI-EN SKAL HENTE SANNHETEN, IKKE REKONSTRUERE DEN
//
// Vaktene her er delt i to:
//
//   1  KATALOGEN. Finnes det i det hele tatt en råvei inn til
//      lønnsdataene? Så lenge det ikke gjør det, KAN ikke modellen
//      rekonstruere A1 — uansett hva prompten sier. Det er en
//      strukturell garanti, ikke en instruks.
//
//   2  SEMANTIKKEN. Bærer verktøyene Sentiqas egne skiller videre —
//      minst mot beregnet, anslått mot fasit, manglende mot null?
// =====================================================================

const a1 = hentLonnskostVerktoy.schema
const rom = hentLonnsromVerktoy.schema
const beskrivelse = (s: { description?: string }) => (s.description ?? '').toLowerCase()

describe('katalogen — ingen råvei til lønnsdataene', () => {
  it('A1-tabellene har INGEN egne verktøy', () => {
    // Uten dette kunne modellen hentet `lonnsregister` og `basisvakt`
    // raatt og bygget A1 selv - og et tall bygget slik ser helt riktig
    // ut. Garantien er at veien ikke finnes, ikke at den er frarådet.
    const navn = Object.keys(VERKTOY)
    for (const raa of ['lonnsregister', 'basisvakt', 'ansatt_avtale', 'lonnsart_ansatt']) {
      expect(navn, raa).not.toContain(`hent_${raa}`)
      expect(navn, raa).not.toContain(raa)
    }
  })

  it('de to nye verktøyene er registrert og har etikett', () => {
    expect(VERKTOY.hent_lonnskost).toBe(hentLonnskostVerktoy)
    expect(VERKTOY.hent_lonnsrom).toBe(hentLonnsromVerktoy)
    // Uten etikett faller kildelista tilbake paa det raa navnet.
    expect(VERKTOY_ETIKETT.hent_lonnskost).toBeTruthy()
    expect(VERKTOY_ETIKETT.hent_lonnsrom).toBeTruthy()
  })

  it('begge er LESEVERKTØY — ikke admin-gatet, RLS avgjør', () => {
    expect(hentLonnskostVerktoy.kunAdmin).toBeUndefined()
    expect(hentLonnsromVerktoy.kunAdmin).toBeUndefined()
    // Butikksjefen skal se dem; RLS avgjør HVILKE stasjoner hun får.
    const forButikksjef = verktoyForRolle(false).map((v) => v.name)
    expect(forButikksjef).toContain('hent_lonnskost')
    expect(forButikksjef).toContain('hent_lonnsrom')
  })
})

describe('beskrivelsene sier hva modellen ikke får lov til', () => {
  it('A1 forbyr rekonstruksjon eksplisitt', () => {
    expect(beskrivelse(a1)).toContain('aldri')
    expect(beskrivelse(a1)).toMatch(/regn aldri|aldri.*selv/)
  })

  it('A1 forklarer at `minst` er en NEDRE GRENSE', () => {
    expect(beskrivelse(a1)).toContain('nedre grense')
    expect(beskrivelse(a1)).toContain('høyere')
  })

  it('A1 forbyr å kalle manglende grunnlag for 0', () => {
    expect(beskrivelse(a1)).toMatch(/ikke si 0|aldri.*0/)
  })

  it('A1 sier at overtid ikke er med', () => {
    expect(beskrivelse(a1)).toContain('overtid')
  })

  it('rommet forbyr å regne BP-lønn delt på BP-brutto selv', () => {
    expect(beskrivelse(rom)).toContain('aldri')
    expect(beskrivelse(rom)).toContain('kalibrering')
  })

  it('rommet forklarer PLAN / PROGNOSE / FASIT', () => {
    const b = beskrivelse(rom)
    expect(b).toContain('planen')
    expect(b).toContain('prognose')
    expect(b).toContain('fasit')
    expect(b).toContain('anslaatt')
  })
})

describe('skjemaene', () => {
  it('tar stasjoner og måned, ikke en fri spørring', () => {
    for (const s of [a1, rom]) {
      const props = (s.input_schema as { properties: Record<string, unknown> }).properties
      expect(Object.keys(props).sort()).toEqual(['maaned', 'stasjoner'])
    }
  })

  it('ingen av dem tar en stasjons-UUID — bare butikknummer/navn', () => {
    // En UUID ville latt modellen gjette seg til en stasjon utenfor
    // scopet. `velgStasjoner` matcher mot det RLS ga.
    for (const s of [a1, rom]) {
      const props = JSON.stringify((s.input_schema as object))
      expect(props.toLowerCase()).not.toContain('uuid')
    }
  })
})

describe('systemprompten', () => {
  const prompten = () => readFileSync('src/lib/ai/assistent.ts', 'utf8')

  it('ber IKKE lenger modellen regne selv', () => {
    const kilde = prompten()
    expect(kilde).not.toContain('regn selv når svaret krever det')
  })

  it('peker på motorene for de tallene som har en', () => {
    const kilde = prompten()
    expect(kilde).toContain('EIER SENTIQA SVARET')
    for (const verktoy of [
      'hent_lonnskost', 'hent_lonnsrom', 'hent_bp_status',
      'hent_timeregnskap', 'forventet_salg',
    ]) expect(kilde, verktoy).toContain(verktoy)
  })

  it('tillater fortsatt ufarlig presentasjonsregning', () => {
    // Grensen gaar ved REKONSTRUKSJON, ikke ved aritmetikk. Uten dette
    // ville modellen sluttet aa summere to stasjoner den har hentet.
    const kilde = prompten()
    expect(kilde).toContain('DU KAN FORTSATT REGNE FOR Å PRESENTERE')
  })

  it('krever at proveniensen følger med ut', () => {
    const kilde = prompten()
    expect(kilde).toContain('PROVENIENSEN FØLGER MED UT')
    expect(kilde).toContain('ALDRI at det er 0')
  })
})

// =====================================================================
// ROLLEBEVIS — VERKTØYET UTVIDER ALDRI STASJONSSETTET
//
// `hentScope` leser `stasjoner` gjennom RLS. Testene under beviser at
// verktøyet ikke har noen ANNEN vei til en stasjon: ber brukeren om en
// stasjon som ikke kom tilbake fra den spørringen, blir den stående i
// `utenfor_tilgang` uten en eneste rad.
// =====================================================================

type FakeRad = { id: string; butikknummer: string; navn: string; stasjonstype: string | null }

function fakeKlient(stasjoner: FakeRad[], spurte: string[]) {
  return {
    from(tabell: string) {
      spurte.push(tabell)
      const q = {
        select: () => q,
        is: () => q,
        eq: () => q,
        in: () => q,
        order: () => q,
        overrideTypes: () => Promise.resolve({ data: stasjoner, error: null }),
        range: () => Promise.resolve({ data: [], error: null }),
        then: (r: (v: unknown) => unknown) => r({ data: stasjoner, error: null }),
      }
      return q
    },
    rpc: () => Promise.resolve({ data: [], error: null }),
  } as never
}

const BRUKER = (rolle: string) => ({ rolle, id: 'u1', epost: 'x@y.no' }) as never

describe('rollebevis', () => {
  it('butikksjef som spør om en annen stasjon får INGEN data om den', async () => {
    const spurte: string[] = []
    const svar = await hentLonnskostVerktoy.kjor(
      { stasjoner: ['9145'] },   // Varden - ikke i hennes sett
      {
        supabase: fakeKlient(
          [{ id: 'b1', butikknummer: '9467', navn: 'Bønes', stasjonstype: null }], spurte,
        ),
        bruker: BRUKER('butikksjef'),
      },
    ) as { scope: { utenfor_tilgang: string[]; besvart: string[] }; data: unknown[] }

    expect(svar.scope.utenfor_tilgang).toContain('9145')
    expect(svar.scope.besvart).toEqual([])
    expect(svar.data).toEqual([])
  })

  it('stasjonssettet kommer KUN fra `stasjoner`-spørringen', async () => {
    const spurte: string[] = []
    await hentLonnskostVerktoy.kjor({ stasjoner: ['9999'] }, {
      supabase: fakeKlient([], spurte),
      bruker: BRUKER('retailer_admin'),
    })
    // Fant ingen stasjoner -> ingen videre oppslag i det hele tatt.
    expect(spurte).toEqual(['stasjoner'])
  })

  it('samme gjelder lønnsrommet', async () => {
    const spurte: string[] = []
    const svar = await hentLonnsromVerktoy.kjor({ stasjoner: ['4177'] }, {
      supabase: fakeKlient(
        [{ id: 'b1', butikknummer: '9467', navn: 'Bønes', stasjonstype: null }], spurte,
      ),
      bruker: BRUKER('butikksjef'),
    }) as { scope: { utenfor_tilgang: string[] }; data: unknown[] }
    expect(svar.scope.utenfor_tilgang).toContain('4177')
    expect(svar.data).toEqual([])
  })

  it('en ugyldig månedsform gir feil, ikke et gjettet svar', async () => {
    const spurte: string[] = []
    const svar = await hentLonnskostVerktoy.kjor({ maaned: 'august' }, {
      supabase: fakeKlient(
        [{ id: 'b1', butikknummer: '9467', navn: 'Bønes', stasjonstype: null }], spurte,
      ),
      bruker: BRUKER('retailer_admin'),
    }) as { status: string; data: unknown[] }
    expect(svar.status).toBe('feil')
    expect(svar.data).toEqual([])
  })
})

// =====================================================================
// SEMANTIKKEN I UTDATAENE — IKKE BARE I BESKRIVELSEN
//
// Injeksjonene «minimum presenteres som beregnet» og «rommet mister
// anslaatt-flagget» kom GROENNE tilbake: beskrivelsene lovte skillet,
// men ingenting sjekket at kartleggingen faktisk bar det videre. Et
// velformulert svar med feil tall er rødt.
//
// Klienten under gir motoren ekte nok rader til at den regner.
// =====================================================================

type Rad = Record<string, unknown>

function motorKlient(vakter: Rad[], register: Rad[]) {
  const stasjoner = [{ id: 'b1', butikknummer: '9467', navn: 'Bønes', stasjonstype: null }]
  return {
    from(tabell: string) {
      const kilde = tabell === 'stasjoner' ? stasjoner
        : tabell === 'basisvakt' ? vakter
          : tabell === 'lonnsregister' ? register
            : []
      let rader = [...kilde] as Rad[]
      const q = {
        select: () => q,
        is: () => q,
        order: () => q,
        eq: (kol: string, v: unknown) => { rader = rader.filter((r) => r[kol] === v); return q },
        in: (kol: string, v: unknown[]) => { rader = rader.filter((r) => v.includes(r[kol])); return q },
        overrideTypes: () => Promise.resolve({ data: rader, error: null }),
        range: (a: number, b: number) =>
          Promise.resolve({ data: rader.slice(a, b + 1), error: null }),
        then: (r: (v: unknown) => unknown) => r({ data: rader, error: null }),
      }
      return q
    },
    rpc: () => Promise.resolve({ data: [], error: null }),
  } as never
}

const vakt = (o: Rad = {}): Rad => ({
  stasjon_id: 'b1', kilde_maaned: '2026-08', lokasjon: 'St1 - Bønes',
  ansatt_nr: '1009', ansatt_navn: 'Lars', dato: '2026-08-03', fra_dato: '2026-08-03',
  fra_tid: '07:00', til_tid: '15:00', minutter: 480, lengde_timer: 8,
  betalt: true, avvik_grunn: null, import_jobb_id: null, ...o,
})

const regrad = (o: Rad = {}): Rad => ({
  stasjon_id: 'b1', kilde_maaned: '2026-08', ansatt_nr: '1009',
  navn: 'Lars', timesats: 210, betalingsfrekvens: 'time', ...o,
})

const kjorA1 = (vakter: Rad[], register: Rad[]) =>
  hentLonnskostVerktoy.kjor({}, {
    supabase: motorKlient(vakter, register),
    bruker: BRUKER('retailer_admin'),
  }) as Promise<{ data: { sikkerhet: string; kroner: number | null; mangler: string | null }[] }>

describe('utdataene bærer A1-kontrakten videre', () => {
  it('alt priset -> sikkerhet `beregnet` med kroner', async () => {
    const svar = await kjorA1([vakt()], [regrad()])
    expect(svar.data[0].sikkerhet).toBe('beregnet')
    expect(svar.data[0].kroner).toBeGreaterThan(0)
  })

  it('noe upriset -> sikkerhet `minst`, ALDRI `beregnet`', async () => {
    // 9999 finnes ikke i registeret -> upriset -> minimum.
    const svar = await kjorA1(
      [vakt(), vakt({ ansatt_nr: '9999', ansatt_navn: 'Ukjent', dato: '2026-08-04', fra_dato: '2026-08-04' })],
      [regrad()],
    )
    expect(svar.data[0].sikkerhet).toBe('minst')
    expect(svar.data[0].kroner).toBeGreaterThan(0)
  })

  it('manglende register -> `ingen_grunnlag` og kroner er NULL, ikke 0', async () => {
    const svar = await kjorA1([vakt()], [])
    expect(svar.data[0].sikkerhet).toBe('ingen_grunnlag')
    // NULL, ikke 0. En manglende kilde er ikke en stasjon som koster null.
    expect(svar.data[0].kroner).toBeNull()
    expect(svar.data[0].kroner).not.toBe(0)
    expect(svar.data[0].mangler).toContain('lønnsgrunnlaget')
  })

  it('ingen kroner havner i JSON-en når grunnlaget mangler', async () => {
    const svar = await kjorA1([vakt()], [])
    expect(JSON.stringify(svar.data[0])).toContain('"kroner":null')
  })

  it('en måned stasjonen ikke har gir ingen rad — ikke en rad på 0', async () => {
    const svar = await hentLonnskostVerktoy.kjor({ maaned: '2026-01' }, {
      supabase: motorKlient([vakt()], [regrad()]),
      bruker: BRUKER('retailer_admin'),
    }) as { data: unknown[]; scope: { uten_registrering: string[] } }
    expect(svar.data).toEqual([])
    expect(svar.scope.uten_registrering).toContain('9467')
  })
})

describe('rommet mister aldri proveniensen', () => {
  const rom = (o: Record<string, unknown> = {}) => ({
    maaned: '2026-08', bruttoKr: 900000, anslaatt: true, lonnsandel: 0.3,
    romKr: 270000, bpLonnKr: 265000, kalibrering: 1, ekstraSvinnKr: 0,
    omsetningKr: 2000000, svinnKr: 0, bilvaskBruttoKr: 0, ...o,
  }) as never

  it('anslaatt brutto gir `brutto_anslaatt: true` — en PROGNOSE', () => {
    expect(tilRomrad('9467 Bønes', rom(), null).brutto_anslaatt).toBe(true)
  })

  it('brutto lest av regnskapet gir `false` — FASIT', () => {
    expect(tilRomrad('9467 Bønes', rom({ anslaatt: false }), null).brutto_anslaatt).toBe(false)
  })

  it('avlagt måned bæres videre', () => {
    expect(tilRomrad('x', rom(), { avlagt: true, lonnskostKr: 260000 }).avlagt).toBe(true)
    expect(tilRomrad('x', rom(), null).avlagt).toBe(false)
  })

  it('manglende lønnstall er IKKE et avvik på null', () => {
    const r = tilRomrad('x', rom(), null)
    expect(r.avvik_kr).toBeNull()
    expect(r.avvik_kr).not.toBe(0)
    expect(r.avvik_mangler).toBeTruthy()
  })

  it('`bp_lonn_kr` er PLANEN, uendret fra motoren', () => {
    expect(tilRomrad('x', rom({ bpLonnKr: 265000 }), null).bp_lonn_kr).toBe(265000)
  })
})

describe('en åpen måned har ingen faktisk lønn', () => {
  const rom = () => ({
    maaned: '2026-08', bruttoKr: 328081.2802730017, anslaatt: true,
    lonnsandel: 0.729, romKr: 239145.93743195687, bpLonnKr: 244412.89694656563,
    kalibrering: 1, ekstraSvinnKr: 9881.691430281058,
    omsetningKr: 2000000, svinnKr: 0, bilvaskBruttoKr: 0,
  }) as never

  it('IKKE avlagt -> faktisk_lonn_kr er null, aldri budsjettallet', () => {
    // Maalt i produksjon 2026-09-16: foerste utgave ga `faktisk_lonn_kr`
    // = `bp_lonn_kr` paa kronen for en aapen maaned. Planen merket som
    // faktisk, i samme rad som avviket sa at loennstallet manglet.
    const r = tilRomrad('9467 Bønes', rom(), { avlagt: false, lonnskostKr: 244412.89694656563 })
    expect(r.avlagt).toBe(false)
    expect(r.faktisk_lonn_kr).toBeNull()
    expect(r.faktisk_lonn_kr).not.toBe(r.bp_lonn_kr)
  })

  it('avlagt -> faktisk_lonn_kr bæres videre', () => {
    const r = tilRomrad('x', rom(), { avlagt: true, lonnskostKr: 251000.5 })
    expect(r.faktisk_lonn_kr).toBe(251000.5)
  })

  it('kroner rundes til øre — ingen 17-sifret falsk presisjon', () => {
    const r = tilRomrad('x', rom(), null)
    for (const v of [r.bp_lonn_kr, r.lonnsrom_kr, r.brutto_kr, r.ekstra_svinn_kr]) {
      expect(String(v), String(v)).not.toMatch(/\.\d{3,}/)
    }
    expect(r.bp_lonn_kr).toBe(244412.9)
    expect(r.ekstra_svinn_kr).toBe(9881.69)
  })
})

describe('alvor er ingen dom uten grunnlag', () => {
  const rom = (o: Record<string, unknown> = {}) => ({
    maaned: '2026-08', bruttoKr: 328081.28, anslaatt: true, lonnsandel: 0.729,
    romKr: 239145.94, bpLonnKr: 244412.9, kalibrering: 1, ekstraSvinnKr: 0,
    omsetningKr: 2000000, svinnKr: 0, bilvaskBruttoKr: 0, ...o,
  }) as never

  it('manglende lønnstall gir alvor NULL, ikke «normal»', () => {
    // Motorens `tomt()` gir `alvor: 'normal'` i FEM ulike «lar seg ikke
    // regne»-tilfeller. Sendt raatt videre kunne modellen sagt at
    // loennskostnaden ser normal ut i en maaned uten loennstall.
    const r = tilRomrad('9467 Bønes', rom(), { avlagt: false })
    expect(r.avvik_mangler).toBeTruthy()
    expect(r.alvor).toBeNull()
    expect(r.alvor).not.toBe('normal')
  })

  it('uten BP-rom gir alvor NULL', () => {
    const r = tilRomrad('x', rom({ romKr: null }), { avlagt: true, lonnskostKr: 100 })
    expect(r.avvik_mangler).toBeTruthy()
    expect(r.alvor).toBeNull()
  })

  it('MED grunnlag bæres dommen videre', () => {
    const r = tilRomrad('x', rom(), {
      avlagt: true, lonnskostKr: 200000, niva: { styringskostKr: 200000 },
    })
    expect(r.avvik_mangler).toBeNull()
    expect(r.alvor).toBe('normal')
    expect(r.avvik_kr).toBeLessThan(0)
  })

  it('et ekte overforbruk gir handling, ikke normal', () => {
    const r = tilRomrad('x', rom(), {
      avlagt: true, lonnskostKr: 300000, niva: { styringskostKr: 300000 },
    })
    expect(r.alvor).toBe('handling')
  })
})
