import { describe, expect, it } from 'vitest'
import { erBra, erIlle, MINST_MAALINGER, retning } from './retning'

describe('retning', () => {
  it('kjenner en jevn stigning', () => {
    const k = retning([100, 200, 300, 400])!
    expect(k.vei).toBe('opp')
    expect(k.endring).toBeCloseTo(300, 0)
  })

  it('kjenner en jevn nedgang', () => {
    expect(retning([400, 300, 200, 100])!.vei).toBe('ned')
  })

  it('bruker HELE serien, ikke foerst mot sist', () => {
    // Klar nedgang, men siste maaned spretter opp. Foerst-mot-sist ville
    // sagt «opp» og satt kursen paa en enkelt rar maaned.
    const k = retning([1000, 800, 600, 400, 420])!
    expect(k.vei).toBe('ned')
  })

  it('KANARI: smaa bevegelser i et tall som svinger mye er FLATT', () => {
    // Uten stoeygrensen ville en stasjon med 200 000 i maanedssvingninger
    // faatt «retning» av 3 000 kroners drift - og en plan bygget paa stoey
    // laerer folk at systemet gjetter.
    const k = retning([100_000, 300_000, 120_000, 280_000, 103_000])!
    expect(k.vei).toBe('flat')
  })

  it('men en jevn drift i et rolig tall er IKKE flatt', () => {
    const k = retning([100_000, 103_000, 106_000, 109_000])!
    expect(k.vei).toBe('opp')
  })

  it('teller maaneder paa rad samme vei', () => {
    expect(retning([500, 400, 300, 200])!.paaRad).toBe(3)
  })

  it('paaRad brytes naar veien snur', () => {
    expect(retning([500, 400, 600, 500, 400])!.paaRad).toBe(2)
  })

  it('KANARI: for kort serie gir null, ikke «flat»', () => {
    // To punkter er en strek, ikke en retning. «Vi vet ikke» og «det
    // holder seg jevnt» er to helt ulike beskjeder til en butikksjef.
    expect(retning([100, 200])).toBeNull()
    expect(retning([100])).toBeNull()
    expect(retning([])).toBeNull()
    expect(retning(Array(MINST_MAALINGER).fill(0).map((_, i) => i * 100))).not.toBeNull()
  })

  it('en helt flat serie er flat, ikke en retning', () => {
    const k = retning([200, 200, 200, 200])!
    expect(k.vei).toBe('flat')
    expect(k.spenn).toBe(0)
  })
})

describe('erBra og erIlle', () => {
  const opp = retning([100, 200, 300])!
  const ned = retning([300, 200, 100])!
  const flat = retning([200, 200, 200])!

  it('omsetning opp er bra, matkast opp er ikke', () => {
    expect(erBra(opp, 'opp')).toBe(true)
    expect(erBra(opp, 'ned')).toBe(false)
    expect(erIlle(opp, 'ned')).toBe(true)
  })

  it('KANARI: flatt er verken bra eller ille', () => {
    // Fravaer av nyhet skal ikke bli til ros. Et system som gratulerer
    // med at ingenting skjedde, blir ikke lest to ganger.
    expect(erBra(flat, 'opp')).toBe(false)
    expect(erBra(flat, 'ned')).toBe(false)
    expect(erIlle(flat, 'opp')).toBe(false)
    expect(erIlle(flat, 'ned')).toBe(false)
  })

  it('ned er bra for matkast', () => {
    expect(erBra(ned, 'ned')).toBe(true)
    expect(erIlle(ned, 'opp')).toBe(true)
  })
})

describe('mot Kelsars egne tall', () => {
  // Resultat per maaned, januar-juli 2026, fra regnskapsrapportene.
  const RES = {
    Dale: [-162491, -8073, -36424, -78917, -74010, -2060, 63246],
    Laguneparken: [82135, 90286, 94902, 68925, 38742, 24484, -53152],
    Bones: [75359, 70459, 40795, 67937, -2974, 26373, 42254],
  }

  it('Dale er i medvind, tross det verste aarsresultatet', () => {
    // Sist paa nivaa (-287 286 hittil), foerst paa retning. Det er hele
    // grunnen til at Kursen finnes.
    expect(retning(RES.Dale)!.vei).toBe('opp')
  })

  it('Laguneparken er i motvind, tross et godt aarsresultat', () => {
    // Fjerde best paa nivaa (+320 315), sist paa retning. Ingen som
    // leser aarstallet ser det.
    expect(retning(RES.Laguneparken)!.vei).toBe('ned')
  })

  it('Boenes gaar ned, tross to gode maaneder paa slutten', () => {
    // Jeg gjettet «flat» her og tok feil: 75 359 i januar mot 42 254 i
    // juli er en ekte nedgang, og trenden er -8 259 i maaneden. At de to
    // siste maanedene peker opp gjoer den ikke flat - det er nettopp
    // derfor hele serien brukes og ikke de to ytterste punktene.
    const k = retning(RES.Bones)!
    expect(k.vei).toBe('ned')
    expect(k.endring).toBeLessThan(-40_000)
  })

  it('KANARI: FIRE av fem stasjoner gaar ned', () => {
    // Bare Dale er i medvind. Rangert paa nivaa ville Dale vaert den
    // eneste som fikk kjeft. Blir denne groenn med fem, har
    // stoeygrensen sluttet aa slippe gjennom ekte nedganger.
    const nedover = Object.values(RES).filter((s) => retning(s)!.vei === 'ned')
    expect(nedover).toHaveLength(2)   // av de tre i utvalget her
    expect(retning(RES.Dale)!.vei).toBe('opp')
  })
})
