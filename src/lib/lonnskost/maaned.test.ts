import { describe, it, expect } from 'vitest'
import { byggLonnskost, LONNSKONTI, TIMEPOST, SATSPOST, type Kontolinje } from './maaned'

// =====================================================================
// FASITEN ER PRODUKSJON, IKKE OPPDIKTEDE TALL
//
// St1 Bønes, juli 2026, hentet ut av `regnskapslinjer` 2026-09-05. Den
// samme måneden regnet ut av easy@work-eksporten med Energiavtalens
// satser gir 242 963 — null kroners avvik mot summen under.
//
// En fixture med runde tall ville bestått uansett hvilke konti summen
// tok med. Disse tallene gjør ikke det.
// =====================================================================
const JULI: [string, string, number, number | null][] = [
  ['501', 'Faste lønninger', 47789, 53176],
  ['502', 'Lønnstillegg', 499, 0],
  ['503', 'Timelønn', 140723, 150851],
  ['505', 'Sykelønn', 1113, 0],
  ['508', 'Påløpte feriepenger', 22815, 24290],
  ['540', 'Arb.avg av lønn', 26751, 29276],
  ['541', 'Arb.avg av feriepenger', 3273, 3425],
  ['590', 'Andre personalkostnader', 3859, 5345],
]

const drift = (periode: string): Kontolinje[] =>
  JULI.map(([kode, post, regnskap, budsjett]) => ({
    periode, seksjon: 'driftskostnader', kode, post, regnskap, budsjett,
  }))

const timer = (periode: string, t: number): Kontolinje =>
  ({ periode, seksjon: 'nokkeltall', kode: null, post: TIMEPOST, regnskap: t, budsjett: null })

const sats = (periode: string, v: number): Kontolinje =>
  ({ periode, seksjon: 'nokkeltall', kode: null, post: SATSPOST, regnskap: v, budsjett: null })

const BP_LONN = new Set(['5010', '5012', '5090', '5400', '5401'])

describe('byggLonnskost — avlagt måned', () => {
  const [r] = byggLonnskost(
    [...drift('2026-07-01'), timer('2026-07-01', 653.2), sats('2026-07-01', 216.21)],
    BP_LONN,
  )

  it('summerer de ni kontiene til det regnskapet viser', () => {
    expect(Math.round(r.lonnskostKr)).toBe(242963)
  })

  // KANARIFUGL: 590 er personalkost, ikke lønn. Sniker den seg inn,
  // blir summen 246 822 — et tall som ser like rimelig ut og som ikke
  // lenger stemmer med noe lønnsgrunnlag.
  it('KANARIFUGL: 590 holdes utenfor lønnskosten', () => {
    expect(Math.round(r.lonnskostKr)).not.toBe(246822)
    expect(Math.round(r.andrePersonalKr)).toBe(3859)
  })

  it('deler summen i kontant, feriepenger og AGA', () => {
    expect(Math.round(r.kontantKr)).toBe(190124)
    expect(Math.round(r.feriepengerKr)).toBe(22815)
    expect(Math.round(r.agaKr)).toBe(30024)
    expect(Math.round(r.kontantKr + r.feriepengerKr + r.agaKr)).toBe(r.lonnskostKr)
  })

  // Budsjettet ligger på SAMME RAD som regnskapet for en avlagt måned.
  // Ingen kodemapping trengs, og de to kan ikke skli fra hverandre.
  it('leser budsjettet fra regnskapsraden selv', () => {
    expect(r.budsjettKilde).toBe('st1_maaned')
    expect(Math.round(r.budsjettKr!)).toBe(261018)
  })

  it('leser St1s timetall og snittsats, og regner dem ikke', () => {
    expect(r.timer).toBe(653.2)
    expect(r.snittsats).toBe(216.21)
  })

  // KANARIFUGL FOR EN BROEK SOM IKKE ER GYLDIG.
  //
  // Foerste utgave viste «loennskost per time» = hele loennskosten delt
  // paa timeloennstimene. Telleren har fastloenn i seg, nevneren ingen
  // fastloenntimer. Paa Boenes juli 2026 ga det 372 kr - mot St1s
  // 216,21 og konto 503 delt paa de samme timene, 215.
  //
  // Faller denne, er noen i ferd med aa regne den ut igjen.
  it('KANARIFUGL: satsen er IKKE loennskost delt paa timene', () => {
    expect(Math.round(242963 / 653.2)).toBe(372)
    expect(r.snittsats).not.toBeCloseTo(242963 / 653.2, 0)
    // Den ligger derimot under EN krone fra konto 503 delt paa de samme
    // timene: 215,43 mot St1s 216,21. De 78 oerene er St1s eget
    // regnestykke - noekkeltallet heter «ink overtid» - og er nettopp
    // grunnen til at vi leser deres tall i stedet for aa lage vaart.
    expect(Math.abs(r.snittsats! - 140723 / 653.2)).toBeLessThan(1)
  })

  it('staar tom naar noekkeltallene mangler', () => {
    const [u] = byggLonnskost(drift('2026-07-01'), BP_LONN)
    expect(u.timer).toBeNull()
    expect(u.snittsats).toBeNull()
  })
})

describe('byggLonnskost — refundert sykelønn', () => {
  // 506 er lagret NEGATIVT, slik regnskapet fører den. Den skal legges
  // til som de andre. Trekkes den fra, teller refusjonen dobbelt.
  it('legger til 506, som allerede er negativ', () => {
    const med: Kontolinje[] = [
      ...drift('2026-06-01'),
      { periode: '2026-06-01', seksjon: 'driftskostnader', kode: '506', post: 'Refundert sykelønn', regnskap: -5000, budsjett: 0 },
    ]
    const [r] = byggLonnskost(med, BP_LONN)
    expect(Math.round(r.lonnskostKr)).toBe(242963 - 5000)
  })
})

describe('byggLonnskost — åpen måned', () => {
  // BP-radene bærer budsjettet i `budsjett` og har `regnskap: 0`.
  const bp = (kode: string, post: string, budsjett: number): Kontolinje =>
    ({ periode: '2026-08-01', seksjon: 'bp_kostnad', kode, post, regnskap: 0, budsjett })

  const [r] = byggLonnskost([
    bp('5010', 'Fast lønn', 52500),
    bp('5012', 'Timelønn', 150000),
    bp('5090', 'Feriepenger', 24300),
    bp('5400', 'Arbeidsgiveravgift', 29300),
    bp('6510', 'Verktøy', 4000),
  ], BP_LONN)

  it('bruker BP-budsjettet når måneden ikke er avlagt', () => {
    expect(r.avlagt).toBe(false)
    expect(r.budsjettKilde).toBe('bp')
    expect(Math.round(r.budsjettKr!)).toBe(256100)
  })

  // KANARIFUGL: BP-en har hele kontoplanen. Tas alt med, blir
  // «lønnskost» summen av strøm, leie og verktøy også.
  it('KANARIFUGL: bare lønnskontiene fra BP-en telles', () => {
    expect(r.linjer.map((l) => l.kode)).toEqual(['5010', '5012', '5090', '5400'])
    expect(r.linjer.some((l) => l.kode === '6510')).toBe(false)
  })
})

describe('byggLonnskost — de to kildene', () => {
  // BP-importen hopper over avlagte måneder, så en måned har enten det
  // ene budsjettet eller det andre. Skulle begge finnes, er regnskapet
  // det som gjelder: det er målt, BP-en er planlagt.
  it('lar regnskapet vinne om begge finnes for samme måned', () => {
    const begge: Kontolinje[] = [
      ...drift('2026-07-01'),
      { periode: '2026-07-01', seksjon: 'bp_kostnad', kode: '5012', post: 'Timelønn', regnskap: 0, budsjett: 999999 },
    ]
    const [r] = byggLonnskost(begge, BP_LONN)
    expect(r.avlagt).toBe(true)
    expect(r.budsjettKilde).toBe('st1_maaned')
    expect(r.budsjettKr).toBeLessThan(999999)
  })

  it('sorterer nyeste måned først', () => {
    const r = byggLonnskost([...drift('2026-05-01'), ...drift('2026-07-01')], BP_LONN)
    expect(r.map((x) => x.maaned)).toEqual(['2026-07', '2026-05'])
  })
})

describe('kontolista', () => {
  // Et prefiksfilter (`kode like '5%'`) ville tatt 590 med. Lista er
  // eksplisitt nettopp derfor.
  it('KANARIFUGL: 590 står ikke i lønnskontiene', () => {
    expect(LONNSKONTI).not.toContain('590')
    expect(LONNSKONTI).toHaveLength(9)
  })
})

// =====================================================================
// BP-EN STÅR VED SIDEN AV, IKKE I STEDET FOR
//
// Jeg skrev først at de to budsjettene aldri finnes for samme måned.
// Det var sant om `regnskapslinjer` — der hopper BP-importen over hver
// avlagt måned med vilje. Men `0155` la BP-en inn som sitt eget
// dokument (`bp_linje`), urørt av månedslåsen.
//
// Derfor kan en avlagt måned ha BEGGE, og de svarer på hvert sitt
// spørsmål: hva måneden ble målt mot, og hva St1 lovet for året.
// =====================================================================
describe('byggLonnskost — BP ved siden av St1s månedsbudsjett', () => {
  const bp = (kode: string, budsjett: number): Kontolinje =>
    ({ periode: '2026-07-01', seksjon: 'bp_kostnad', kode, post: `${kode} Kostnader`, regnskap: 0, budsjett })

  const medBegge = [
    ...drift('2026-07-01'),
    bp('5010', 50000), bp('5012', 145000), bp('5090', 23400),
    bp('5400', 27500), bp('5401', 3300),
    // Ikke lønn — skal ikke telle med.
    bp('6510', 4000),
  ]

  it('viser begge budsjettene for en avlagt måned', () => {
    const [r] = byggLonnskost(medBegge, BP_LONN)
    expect(r.avlagt).toBe(true)
    // St1s månedsbudsjett, fra regnskapsraden.
    expect(r.budsjettKilde).toBe('st1_maaned')
    expect(Math.round(r.budsjettKr!)).toBe(261018)
    // BP-en, fra sitt eget dokument.
    expect(Math.round(r.bpBudsjettKr!)).toBe(249200)
  })

  // KANARIFUGL: BP-en har hele kontoplanen. Tas alt med, blir
  // «lønnsbudsjettet» summen av verktøy og strøm også.
  it('KANARIFUGL: bare lønnskontiene teller i BP-summen', () => {
    const [r] = byggLonnskost(medBegge, BP_LONN)
    expect(r.bpBudsjettKr).not.toBe(253200)
  })

  it('lar regnskapet være kilden for det faktiske, uansett', () => {
    const [r] = byggLonnskost(medBegge, BP_LONN)
    expect(Math.round(r.lonnskostKr)).toBe(242963)
  })

  it('står som null når BP-en ikke er importert for året', () => {
    const [r] = byggLonnskost(drift('2026-07-01'), BP_LONN)
    expect(r.bpBudsjettKr).toBeNull()
  })

  // En åpen måned har ingen regnskapslinjer. Da er BP-en både kilden til
  // budsjettet OG tallet i BP-kolonnen — samme tall, to steder, fordi
  // det er det eneste som finnes.
  it('en åpen måned tar budsjettet fra BP-en selv', () => {
    const [r] = byggLonnskost([
      { periode: '2026-09-01', seksjon: 'bp_kostnad', kode: '5012', post: '5012 Kostnader', regnskap: 0, budsjett: 150000 },
    ], BP_LONN)
    expect(r.avlagt).toBe(false)
    expect(r.budsjettKilde).toBe('bp')
    expect(Math.round(r.budsjettKr!)).toBe(150000)
    expect(Math.round(r.bpBudsjettKr!)).toBe(150000)
  })
})
