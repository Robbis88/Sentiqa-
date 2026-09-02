import { describe, expect, test } from 'vitest'
import { motBudsjett, storsteAvvik, svaret, type Budsjettlinje, driverne } from './mot-budsjett'

const linje = (post: string, regnskap: number, budsjett: number): Budsjettlinje =>
  ({ post, regnskap, budsjett })

// nb-NO grupperer tusener med hardt mellomrom (U+00A0). Det er riktig i
// utskriften, men uleselig i en testfil — så vi mykner det her framfor å
// skrive tegnet inn i hver eneste forventning.
const lesbar = (s: string | null) => s?.replace(/\s/g, ' ') ?? null

describe('motBudsjett', () => {
  test('sier hvor mange kroner, ikke bare at det avviker', () => {
    const m = motBudsjett(1_818_000, 2_000_000)
    expect(lesbar(m.tekst)).toBe('182 000 kr under budsjett')
  })

  test('over budsjett er bra på inntekt', () => {
    expect(motBudsjett(2_200_000, 2_000_000).bra).toBe(true)
  })

  test('over budsjett er dårlig på kostnad', () => {
    // Samme tall, motsatt dom. Dette er hele grunnen til at flagget finnes.
    expect(motBudsjett(2_200_000, 2_000_000, true).bra).toBe(false)
    expect(motBudsjett(1_800_000, 2_000_000, true).bra).toBe(true)
  })

  test('fortegnet følger pengene selv når dommen snus', () => {
    const kostnad = motBudsjett(2_200_000, 2_000_000, true)
    expect(kostnad.avvik).toBeGreaterThan(0)
    expect(lesbar(kostnad.tekst)).toBe('200 000 kr over budsjett')
    expect(kostnad.bra).toBe(false)
  })

  test('innenfor to prosent er truffet budsjett, ikke en sak', () => {
    const m = motBudsjett(2_010_000, 2_000_000)
    expect(m.tekst).toBe('på budsjett')
    expect(m.bra).toBeNull()
  })

  test('uten budsjett er det ingenting å måle mot', () => {
    const m = motBudsjett(500_000, 0)
    expect(m.tekst).toBeNull()
    expect(m.avvikProsent).toBeNull()
    expect(m.bra).toBeNull()
  })

  test('negativt budsjett snur ikke prosenten', () => {
    // Budsjettert underskudd på 100 000, faktisk underskudd på 150 000.
    // Med budsjettets eget fortegn i nevneren ville dette blitt «+50 %»
    // og sett ut som en seier.
    const m = motBudsjett(-150_000, -100_000)
    expect(m.avvikProsent).toBe(-50)
    expect(m.bra).toBe(false)
    expect(lesbar(m.tekst)).toBe('50 000 kr under budsjett')
  })

  test('null tolkes som null kroner, ikke som krasj', () => {
    expect(motBudsjett(null, null).avvik).toBe(0)
    expect(motBudsjett(null, 1000).avvik).toBe(-1000)
  })
})

describe('storsteAvvik', () => {
  const kostnader = [
    linje('Personalkostnad', 3_090_000, 3_000_000), // +90 000
    linje('Strøm', 70_000, 50_000),                 // +20 000, men +40 %
    linje('Renhold', 40_000, 60_000),               // under budsjett
  ]

  test('måler i kroner, ikke prosent', () => {
    // Strøm avviker mest i prosent, personal mest i kroner. Det er
    // personal som forklarer resultatet.
    expect(storsteAvvik(kostnader, true)).toEqual({ post: 'Personalkostnad', avvik: 90_000 })
  })

  test('ser bare det som gjør bildet verre', () => {
    // Renhold ligger 20 000 under budsjett. Det er ikke en driver.
    const bare = [linje('Renhold', 40_000, 60_000)]
    expect(storsteAvvik(bare, true)).toBeNull()
  })

  test('på inntekt er det svikten som er driveren', () => {
    const omsetning = [
      linje('Kiosk', 900_000, 1_000_000), // −100 000
      linje('Bistro', 520_000, 500_000),
    ]
    expect(storsteAvvik(omsetning)).toEqual({ post: 'Kiosk', avvik: -100_000 })
  })

  test('linjer uten budsjett kan ikke avvike fra det', () => {
    // Uten regelen ville hele beløpet talt som avvik, og en konto ingen
    // har budsjettert ville vunnet hver gang.
    const med = [...kostnader, linje('Ny konto uten budsjett', 400_000, 0)]
    expect(storsteAvvik(med, true)?.post).toBe('Personalkostnad')
  })

  test('summeringslinjer slår ikke sine egne deler', () => {
    const med = [
      linje('Driftskostnader totalt', 3_200_000, 3_000_000),
      ...kostnader,
    ]
    expect(storsteAvvik(med, true)?.post).toBe('Personalkostnad')
  })

  test('tom liste gir ingen driver', () => {
    expect(storsteAvvik([], true)).toBeNull()
  })
})

describe('svaret', () => {
  test('nevner driveren når hovedtallet er dårligere enn budsjett', () => {
    const s = svaret('Resultat', motBudsjett(1_818_000, 2_000_000), { post: 'Personalkostnad', avvik: 90_000 })
    expect(lesbar(s)).toBe('Resultat ligger 182 000 kr under budsjett. Personalkostnad drar mest')
  })

  test('nevner ingen driver når vi ligger bedre enn budsjett', () => {
    // «Over budsjett, og X drar mest» er selvmotsigende.
    const s = svaret('Resultat', motBudsjett(2_200_000, 2_000_000), { post: 'Personalkostnad', avvik: 90_000 })
    expect(lesbar(s)).toBe('Resultat ligger 200 000 kr over budsjett')
  })

  test('uten budsjett påstår vi ingenting', () => {
    expect(svaret('Resultat', motBudsjett(500_000, 0), null)).toBeNull()
  })
})

// =====================================================================
// «RESULTATET LIGGER 41 000 UNDER» BESVARES IKKE AV ETT NAVN
//
// `storsteAvvik` gir den ene verste, og i svarsetningen er én nok. Men
// leseren vil vite hva de 41 000 BESTAAR AV - som regel to-tre linjer.
// `driverne` er den lista, og den maales i KRONER: 40 % over paa en
// konto til 5 000 kr er 2 000 kr, mens 3 % over paa personal kan vaere
// hele forklaringen.
// =====================================================================
describe('driverne', () => {
  const kost = [
    { post: 'Personal', regnskap: 291500, budsjett: 258500 },   // +33 000
    { post: 'Strøm', regnskap: 31200, budsjett: 27100 },        //  +4 100
    { post: 'Renhold', regnskap: 18400, budsjett: 15000 },      //  +3 400
    { post: 'Rekvisita', regnskap: 8100, budsjett: 9500 },      //  under - redder
    { post: 'Driftskostnader totalt', regnskap: 349200, budsjett: 310100 },
  ]

  test('KANARIFUGL: størst i kroner først, ikke i prosent', () => {
    // Renhold er 22,7 % over, personal bare 12,8 % - men personal er
    // ti ganger så mange kroner. En liste sortert paa prosent ville
    // pekt paa renhold, og det er feil sted aa lete.
    const d = driverne(kost, true)
    expect(d[0].post).toBe('Personal')
    expect(d[0].avvik).toBe(33000)
    expect(d.map((x) => x.post)).toEqual(['Personal', 'Strøm', 'Renhold'])
  })

  test('summeringslinja er ikke en driver', () => {
    // «Driftskostnader totalt» er delene lagt sammen og ville alltid
    // slaatt hver enkelt av dem.
    expect(driverne(kost, true).map((d) => d.post)).not.toContain('Driftskostnader totalt')
  })

  test('det som REDDER resultatet er ikke med', () => {
    // Spoersmaalet er «hva drar». En linje under budsjett drar ingenting.
    expect(driverne(kost, true).map((d) => d.post)).not.toContain('Rekvisita')
  })

  test('paa inntektssiden er det linjene UNDER budsjett som drar', () => {
    const oms = [
      { post: 'Mat', regnskap: 400000, budsjett: 430000 },   // -30 000
      { post: 'Vask', regnskap: 160000, budsjett: 150000 },  // over - redder
    ]
    const d = driverne(oms)
    expect(d.map((x) => x.post)).toEqual(['Mat'])
    expect(d[0].avvik).toBe(-30000)
  })

  test('linjer uten budsjett kan ikke avvike fra noe', () => {
    expect(driverne([{ post: 'Ukjent', regnskap: 9000, budsjett: 0 }], true)).toEqual([])
  })

  test('antallet kan begrenses, og standarden er tre', () => {
    expect(driverne(kost, true)).toHaveLength(3)
    expect(driverne(kost, true, 1)).toHaveLength(1)
  })

  test('KANARIFUGL: den foerste er den samme som storsteAvvik gir', () => {
    // De to maa vaere enige. Sier setningen oeverst «Personal drar mest»
    // mens lista under starter et annet sted, er sida i strid med seg selv.
    const en = storsteAvvik(kost, true)
    expect(driverne(kost, true)[0]).toEqual(en)
  })
})
