import { describe, it, expect } from 'vitest'
import { nettMotposter, erMotpost, MOTPOSTER } from './regnskap-varsler'

// =====================================================================
// FIXTUREN ER BOENES, JULI 2026 - EKTE TALL FRA BASEN
//
// Varsellista viste bare de positive medlemmene. Maskinvask sto som
// roedt varsel paa 7 964 kr mens gruppa hadde 14 628 kr i OVERSKUDD, og
// kaffe sto oeverst hver maaned paa et tall som var mer enn halvert av
// sin egen motpost.
// =====================================================================
const BOENES = 'b0-1'

const JULI = [
  // Varm drikke: kaffen forsvinner fra lageret, utdelingen slaas inn paa
  // lojalitet. Te ligger i samme avdeling og er gratis paa samme maate.
  { stasjon_id: BOENES, kode: '13010', navn: '13010 KAFFE', salg: 11730, usynlig_kr: 8783 },
  { stasjon_id: BOENES, kode: '13011', navn: '13011 KAFFELOJALITET', salg: 2443, usynlig_kr: -5328 },
  { stasjon_id: BOENES, kode: '13012', navn: '13012 TE', salg: 1200, usynlig_kr: -900 },
  // Vask: appen selger, maskinen forbruker.
  { stasjon_id: BOENES, kode: '21010', navn: '21010 MASKINVASK', salg: 152287, usynlig_kr: 7964 },
  { stasjon_id: BOENES, kode: '21014', navn: '21014 MASKINVASK APP', salg: 22592, usynlig_kr: -22592 },
  // En vanlig varegruppe, som IKKE motposterer noe.
  { stasjon_id: BOENES, kode: '16014', navn: '16014 ISKREM', salg: 53209, usynlig_kr: 1526 },
]

describe('motposter', () => {
  it('KANARIFUGL: maskinvask er et OVERSKUDD naar paret leses samlet', () => {
    // Dette er hele funnet. +7 964 alene ble et roedt varsel; samlet er
    // gruppa 14 628 kr i pluss, og det er ingenting aa gjoere noe med.
    const vask = nettMotposter(JULI).find((g) => g.avdeling === '210')
    expect(vask, 'vaskegruppa ble ikke dannet').toBeDefined()
    expect(Math.round(vask!.kr)).toBe(-14628)
    expect(vask!.kr, 'gruppa maa vaere negativ, ellers varsles den').toBeLessThan(0)
  })

  it('KANARIFUGL: te trekkes fra kaffen sammen med lojaliteten', () => {
    // Robert: «te skal ogsaa inn der som en motpost — folk kan ta te
    // gratis ogsaa». Grupperes det bare paa de to kjente kodene, blir
    // kaffe staaende 900 kr for hoeyt.
    const kaffe = nettMotposter(JULI).find((g) => g.avdeling === '130')
    expect(kaffe, 'kaffegruppa ble ikke dannet').toBeDefined()
    expect(Math.round(kaffe!.kr)).toBe(8783 - 5328 - 900)
    expect(kaffe!.navn).toMatch(/te/i)
  })

  it('en vanlig varegruppe roeres ikke', () => {
    // Nettingen skal gjelde de to bekreftede avdelingene og ingen andre.
    // Ellers kunne en ekte manko skjules av et urelatert overskudd.
    const grupper = nettMotposter(JULI)
    expect(grupper.map((g) => g.avdeling).sort()).toEqual(['130', '210'])
    expect(erMotpost('16014')).toBe(false)
    expect(erMotpost('13010')).toBe(true)
    expect(erMotpost(null)).toBe(false)
  })

  it('prosenten regnes av gruppens samlede salg', () => {
    const kaffe = nettMotposter(JULI).find((g) => g.avdeling === '130')!
    expect(kaffe.salg).toBe(11730 + 2443 + 1200)
    expect(Math.round(kaffe.pst)).toBe(Math.round((2555 / 15373) * 100))
  })

  it('KANARIFUGL: kartet dekker begge avdelingene Robert bekreftet', () => {
    // Faller en av dem ut, blir medlemmene vurdert hver for seg igjen -
    // og da er vi tilbake til roedt varsel paa en gruppe i overskudd,
    // uten at noen test hadde sagt fra.
    expect(Object.keys(MOTPOSTER).sort()).toEqual(['130', '210'])
  })

  it('to stasjoner blandes ikke', () => {
    const to = [
      ...JULI,
      { stasjon_id: 'lone-1', kode: '13010', navn: '13010 KAFFE', salg: 5000, usynlig_kr: 4000 },
    ]
    const kaffe = nettMotposter(to).filter((g) => g.avdeling === '130')
    expect(kaffe).toHaveLength(2)
    expect(kaffe.find((g) => g.stasjonId === 'lone-1')!.kr).toBe(4000)
  })

  it('tom salgssum gir ingen deling paa null', () => {
    const utenSalg = [
      { stasjon_id: BOENES, kode: '13010', navn: 'KAFFE', salg: 0, usynlig_kr: 500 },
    ]
    expect(nettMotposter(utenSalg)[0].pst).toBe(0)
  })
})
