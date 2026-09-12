import { describe, expect, it } from 'vitest'
import { byggHistorikk, klasseFor, MAANEDER_BAKOVER } from './hent'

type Linje = Parameters<typeof byggHistorikk>[0][number]
type Svinn = Parameters<typeof byggHistorikk>[1][number]

const l = (over: Partial<Linje>): Linje => ({
  stasjon_id: 's1', periode: '2026-07-01', seksjon: 'omsetning',
  kode: '120', post: '120 Mat', regnskap: 0, budsjett: 0, ...over,
})
const s = (over: Partial<Svinn>): Svinn => ({
  stasjon_id: 's1', periode: '2026-07-01', kode: '12010',
  kast: 0, usynlig_kr: 0, ...over,
})

describe('byggHistorikk', () => {
  it('leser resultatet fra arkets egen RESULTAT-linje', () => {
    // Ikke utledet av brutto minus driftskostnader: et utledet tall kan
    // drive fra arkets, og da ville «medvind» hvilt paa noe
    // regnskapsfoereren ikke kjenner igjen.
    const h = byggHistorikk([
      l({ seksjon: 'resultat', kode: null, post: 'RESULTAT', regnskap: -10_201 }),
    ], [])
    expect(h[0].resultatKr).toBe(-10_201)
  })

  it('summerer omsetning og matsalg hver for seg', () => {
    const h = byggHistorikk([
      l({ kode: '120', regnskap: 400_000, budsjett: 420_000 }),
      l({ kode: '140', regnskap: 200_000, budsjett: 190_000 }),
    ], [])
    expect(h[0].omsetningKr).toBe(600_000)
    expect(h[0].omsetningBudsjettKr).toBe(610_000)
    expect(h[0].matsalgKr).toBe(400_000)
  })

  it('KANARI: pant teller ikke som omsetning', () => {
    // Pant er gjennomstroemning, ikke butikkens salg - og den betaler
    // heller ingen royalty.
    const h = byggHistorikk([
      l({ kode: '120', regnskap: 100_000 }),
      l({ kode: '250', regnskap: 40_000 }),
    ], [])
    expect(h[0].omsetningKr).toBe(100_000)
  })

  it('skiller personal fra paavirkbar drift', () => {
    const h = byggHistorikk([
      l({ seksjon: 'driftskostnader', kode: '503', regnskap: 180_000, budsjett: 170_000 }),
      l({ seksjon: 'driftskostnader', kode: '590', regnskap: 20_000, budsjett: 15_000 }),
      l({ seksjon: 'driftskostnader', kode: '627', regnskap: 8_000, budsjett: 6_000 }),
      l({ seksjon: 'driftskostnader', kode: '633', regnskap: 12_000, budsjett: 11_000 }),
    ], [])
    expect(h[0].personalKr).toBe(200_000)
    expect(h[0].personalBudsjettKr).toBe(185_000)
    expect(h[0].paavirkbarDriftKr).toBe(20_000)
    expect(h[0].paavirkbarDriftBudsjettKr).toBe(17_000)
  })

  it('KANARI: leie og royalty er IKKE paavirkbar drift', () => {
    // 630 Leie er en avtale, 622 Royalty en kjedeavgift. Havner de i
    // «paavirkbare driftskostnader», ber planen butikksjefen om noe hun
    // ikke raar over.
    const h = byggHistorikk([
      l({ seksjon: 'driftskostnader', kode: '630', regnskap: 200_000 }),
      l({ seksjon: 'driftskostnader', kode: '622', regnskap: 900_000 }),
      l({ seksjon: 'driftskostnader', kode: '623', regnskap: 150_000 }),
      l({ seksjon: 'driftskostnader', kode: '634', regnskap: 90_000 }),
    ], [])
    expect(h[0].paavirkbarDriftKr).toBe(0)
  })

  it('KANARI: bilvask holdes utenfor usynlig paa «resten»', () => {
    // Bilvask er strukturelt negativ - app-omsetningen bokfoeres som
    // overskudd - og ville dratt hele tallet i pluss.
    const h = byggHistorikk([], [
      s({ kode: '21010', usynlig_kr: -900_000 }),
      s({ kode: '16012', usynlig_kr: 40_000 }),
      s({ kode: '12010', usynlig_kr: 5_000 }),
      s({ kode: '25010', usynlig_kr: 15_000 }),
    ])
    expect(h[0].usynligRestKr).toBe(40_000)
  })

  it('matkast summeres bare fra matvaregruppene', () => {
    const h = byggHistorikk([], [
      s({ kode: '12010', kast: 30_000 }),
      s({ kode: '12011', kast: 20_000 }),
      s({ kode: '16012', kast: 5_000 }),
    ])
    expect(h[0].matkastKr).toBe(50_000)
  })

  it('grupperer per maaned og sorterer eldste foerst', () => {
    const h = byggHistorikk([
      l({ periode: '2026-07-01', seksjon: 'resultat', kode: null, regnskap: 3 }),
      l({ periode: '2026-05-01', seksjon: 'resultat', kode: null, regnskap: 1 }),
      l({ periode: '2026-06-01', seksjon: 'resultat', kode: null, regnskap: 2 }),
    ], [])
    expect(h.map((x) => x.resultatKr)).toEqual([1, 2, 3])
    expect(h.map((x) => x.maaned)).toEqual(['2026-05-01', '2026-06-01', '2026-07-01'])
  })

  it('taaler datoer med tid paa', () => {
    const h = byggHistorikk([
      l({ periode: '2026-07-15', seksjon: 'resultat', kode: null, regnskap: 7 }),
    ], [])
    expect(h[0].maaned).toBe('2026-07-01')
  })
})

describe('klasseFor', () => {
  it('maskinleverandoerer er FOELGE', () => {
    // 634 er 82 % WashTec paa stasjonene med vask - maskinen, ikke
    // butikksjefens valg.
    expect(klasseFor({ tekst: 'WashTec Bilvask AS' })).toBe('folge')
    expect(klasseFor({ tekst: 'Epta Refrigeration Norway AS' })).toBe('folge')
  })

  it('varelevrandoerer er SPAK', () => {
    expect(klasseFor({ tekst: 'ASKO VEST AS' })).toBe('spak')
    expect(klasseFor({ tekst: 'Elis Norge AS' })).toBe('spak')
  })

  it('KANARI: en ukjent leverandoer regnes som SPAK, ikke usynlig', () => {
    // Et tiltak som viser seg aa vaere en maskin blir korrigert av et
    // menneske. Motsatt vei ville en ukjent leverandoer blitt usynlig
    // for alltid - og det er den feilen ingen oppdager.
    expect(klasseFor({ tekst: 'Helt Ny Leverandoer AS' })).toBe('spak')
  })
})

describe('vinduet', () => {
  it('ser tolv maaneder bakover', () => {
    // Et helt aar, saa en sesongtopp ikke blir til en retning.
    expect(MAANEDER_BAKOVER).toBe(12)
  })
})

describe('KANARI: drivstoff og CR-totalen er ikke butikkens omsetning', () => {
  it('drivstoff (10) telles ikke', () => {
    // Drivstoff er ~68 % av omsetningen og betjener seg selv paa pumpa.
    // Telles den med, ville «omsetning mot budsjett» vaert et tall om
    // pumpetrafikk - og bemanningen maalt mot noe butikksjefen ikke
    // rorer. Se AGENTS.md.
    const h = byggHistorikk([
      l({ kode: '120', regnskap: 400_000 }),
      l({ kode: '10', regnskap: 2_000_000 }),
    ], [])
    expect(h[0].omsetningKr).toBe(400_000)
  })

  it('«40 CR» telles ikke - den dobbelteller mot avdelingene', () => {
    const h = byggHistorikk([
      l({ kode: '120', regnskap: 400_000 }),
      l({ kode: '40', regnskap: 900_000 }),
    ], [])
    expect(h[0].omsetningKr).toBe(400_000)
  })

  it('en linje uten kode telles ikke', () => {
    // «Omsetning totalt» og liknende rollups har ingen kode.
    const h = byggHistorikk([
      l({ kode: '120', regnskap: 400_000 }),
      l({ kode: null, regnskap: 900_000 }),
    ], [])
    expect(h[0].omsetningKr).toBe(400_000)
  })
})
