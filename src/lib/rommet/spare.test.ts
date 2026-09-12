import { describe, expect, it } from 'vitest'
import {
  erLeverandor, finnSparefunn, leverandornokkel, omfang,
  type Bilagsrad, type Omsetningsrad, type Stasjon,
} from './spare'

// Tall og navn her er fra Kelsars egne bilag, februar 2025 – juli 2026.

const STASJONER: Stasjon[] = [
  { id: 'lone', navn: 'St1 Lone', butikknummer: '4177' },
  { id: 'varden', navn: 'St1 Varden', butikknummer: '9145' },
  { id: 'dale', navn: 'St1 Dale', butikknummer: '4185' },
]

const b = (over: Partial<Bilagsrad>): Bilagsrad => ({
  stasjon_id: 'lone', periode: '2026-07-01', begrep: 'renhold',
  tekst: 'ASKO VEST AS', belop_kr: 1000, antall: 1, ...over,
})

const oms = (id: string, kr: number, maaned = '2026-07-01'): Omsetningsrad =>
  ({ stasjon_id: id, maaned, omsetning_kr: kr })

describe('erLeverandor', () => {
  it('godtar et navn du kan ringe', () => {
    expect(erLeverandor('ASKO VEST AS')).toBe(true)
    expect(erLeverandor('Elis Norge AS')).toBe(true)
    expect(erLeverandor('Tommys Hage & Anlegg')).toBe(true)
  })

  it('KANARI: regnskapsfoererens samleposter er ikke leverandoerer', () => {
    // «Inngående faktura» er Azets' samlepost. Blir den et funn, ber
    // planen butikksjefen ringe en bokføringskonvensjon.
    expect(erLeverandor('Inngående faktura')).toBe(false)
    expect(erLeverandor('Utgående faktura')).toBe(false)
    expect(erLeverandor('Differanse')).toBe(false)
    expect(erLeverandor('Korreksjon av avd.')).toBe(false)
    expect(erLeverandor('Betalt med bankkort')).toBe(false)
  })

  it('KANARI: fakturanummer og perioder er ikke navn', () => {
    // Ekte tekster fra Kelsars bilag.
    expect(erLeverandor('512313573244')).toBe(false)
    expect(erLeverandor('01.07.2026 30.09.2026')).toBe(false)
    expect(erLeverandor('512-30106992-6')).toBe(false)
    expect(erLeverandor('Filimport ST1')).toBe(false)
  })
})

describe('leverandornokkel', () => {
  it('samme leverandoer skrevet ulikt blir én', () => {
    expect(leverandornokkel('ASKO VEST AS')).toBe(leverandornokkel('Asko Vest'))
    expect(leverandornokkel('WashTec Bilvask AS')).toBe(leverandornokkel('WASHTEC BILVASK'))
  })

  it('KANARI: to ULIKE leverandoerer blir ikke én', () => {
    // Uten denne kunne normaliseringen vaert saa aggressiv at alt ble
    // samme rad - og da er hvert «funn» en sum av tilfeldigheter.
    expect(leverandornokkel('ASKO VEST AS')).not.toBe(leverandornokkel('Elis Norge AS'))
    expect(leverandornokkel('Ragn-Sells AS')).not.toBe(leverandornokkel('Franzefoss Gjenvinning'))
  })
})

describe('finnSparefunn', () => {
  it('grupperer paa LEVERANDOER, paa tvers av kontoene', () => {
    // Dette er ASKO-funnet. 627 Renhold og 633 Forbruksmateriell er to
    // kontoer og samme leverandør. Hver linje ser rimelig ut alene.
    const funn = finnSparefunn(
      [
        b({ stasjon_id: 'lone', begrep: 'renhold', belop_kr: 29_825 }),
        b({ stasjon_id: 'lone', begrep: 'forbruksmateriell', belop_kr: 48_077 }),
        b({ stasjon_id: 'varden', begrep: 'renhold', belop_kr: 7_207 }),
        b({ stasjon_id: 'varden', begrep: 'forbruksmateriell', belop_kr: 32_273 }),
      ],
      [oms('lone', 6_250_000), oms('varden', 6_900_000)],
      STASJONER,
    )
    expect(funn).toHaveLength(1)
    expect(funn[0].leverandor).toBe('ASKO VEST AS')
    expect(funn[0].begreper).toEqual(['forbruksmateriell', 'renhold'])
    // 77 902 mot 39 480 — og Lone er den MINSTE av de to.
    expect(funn[0].per.find((p) => p.navn === 'St1 Lone')?.kroner).toBe(77_902)
    expect(funn[0].per.find((p) => p.navn === 'St1 Varden')?.kroner).toBe(39_480)
  })

  it('sammenligner paa andel av omsetning, ikke paa kroner', () => {
    // Laguneparken bruker mer på renhold enn Bønes. Laguneparken er
    // også dobbelt så stor. Kroner mot kroner sier ingenting.
    const funn = finnSparefunn(
      [
        b({ stasjon_id: 'dale', belop_kr: 100_000 }),
        b({ stasjon_id: 'varden', belop_kr: 60_000 }),
      ],
      [oms('dale', 10_000_000), oms('varden', 3_000_000)],
      STASJONER,
    )
    // Dale har DOBBELT saa mange kroner, men halve andelen.
    expect(funn[0].beste?.navn).toBe('St1 Dale')
    expect(funn[0].per[0].navn).toBe('St1 Dale')
    expect(funn[0].per[0].andel).toBeCloseTo(0.01, 5)
    expect(funn[0].per[1].andel).toBeCloseTo(0.02, 5)
  })

  it('KANARI: én stasjon er ingen sammenligning', () => {
    // Et «funn» paa én stasjon er bare et beloep. Slipper det gjennom,
    // fylles lista med tall ingen kan gjoere noe med.
    const funn = finnSparefunn(
      [b({ stasjon_id: 'lone', belop_kr: 500_000 })],
      [oms('lone', 6_000_000)],
      STASJONER,
    )
    expect(funn).toEqual([])
  })

  it('KANARI: vaskemaskinen sammenlignes ikke', () => {
    // `634 Rep` og `630 Leie` er vaskemaskinen, og Dale har ingen vask.
    // Dale blir derfor alltid «billigst», og en naiv sammenligning ber
    // deg jage 1,6 millioner som ikke finnes. Begrepene staar utenfor
    // DRIFT_BEGREP med vilje.
    const funn = finnSparefunn(
      [
        b({ stasjon_id: 'lone', begrep: 'rep_vedlikehold', tekst: 'WashTec Bilvask AS', belop_kr: 45_807 }),
        b({ stasjon_id: 'varden', begrep: 'rep_vedlikehold', tekst: 'WashTec Bilvask AS', belop_kr: 90_885 }),
        b({ stasjon_id: 'lone', begrep: 'leie_driftsmidler', tekst: 'DNB Finans', belop_kr: 234_689 }),
        b({ stasjon_id: 'varden', begrep: 'leie_driftsmidler', tekst: 'DNB Finans', belop_kr: 1_068 }),
      ],
      [oms('lone', 6_000_000), oms('varden', 6_000_000)],
      STASJONER,
    )
    expect(funn).toEqual([])
  })

  it('regner aarseffekt fra det grunnlaget faktisk dekker', () => {
    // To maaneder inn, altsaa x6 til aar. Skaleres det fra ett aar
    // uansett, blir hvert funn seks ganger for lite.
    const funn = finnSparefunn(
      [
        b({ stasjon_id: 'lone', periode: '2026-06-01', belop_kr: 10_000 }),
        b({ stasjon_id: 'lone', periode: '2026-07-01', belop_kr: 10_000 }),
        b({ stasjon_id: 'varden', periode: '2026-06-01', belop_kr: 2_000 }),
        b({ stasjon_id: 'varden', periode: '2026-07-01', belop_kr: 2_000 }),
      ],
      [
        oms('lone', 1_000_000, '2026-06-01'), oms('lone', 1_000_000, '2026-07-01'),
        oms('varden', 1_000_000, '2026-06-01'), oms('varden', 1_000_000, '2026-07-01'),
      ],
      STASJONER,
    )
    expect(funn[0].maaneder).toBe(2)
    // Lone 20 000 mot Vardens andel 4 000 → 16 000 over to maaneder → 96 000/aar.
    expect(funn[0].aarligKr).toBe(96_000)
  })

  it('uten omsetning regnes ingen aarseffekt', () => {
    // Et tall delt paa null er ikke et funn. `null` sier «vi vet ikke»,
    // og det er et annet svar enn 0.
    const funn = finnSparefunn(
      [
        b({ stasjon_id: 'lone', belop_kr: 50_000 }),
        b({ stasjon_id: 'varden', belop_kr: 10_000 }),
      ],
      [],
      STASJONER,
    )
    expect(funn[0].aarligKr).toBeNull()
    expect(funn[0].beste).toBeNull()
    expect(funn[0].per[0].andel).toBeNull()
  })

  it('sorterer paa hva forskjellen er verdt', () => {
    const funn = finnSparefunn(
      [
        b({ tekst: 'Liten AS', stasjon_id: 'lone', belop_kr: 2_000 }),
        b({ tekst: 'Liten AS', stasjon_id: 'varden', belop_kr: 500 }),
        b({ tekst: 'Stor AS', stasjon_id: 'lone', belop_kr: 90_000 }),
        b({ tekst: 'Stor AS', stasjon_id: 'varden', belop_kr: 10_000 }),
      ],
      [oms('lone', 5_000_000), oms('varden', 5_000_000)],
      STASJONER,
    )
    expect(funn.map((f) => f.leverandor)).toEqual(['Stor AS', 'Liten AS'])
  })
})

describe('omfang', () => {
  it('sier hva grunnlaget dekker', () => {
    // Et funn uten omfang er et tall. «11 737 linjer over 18 maaneder»
    // er det som gjoer at man tror paa resten.
    const o = omfang([
      b({ periode: '2025-02-01' }),
      b({ periode: '2026-07-01' }),
      b({ periode: '2026-07-01', tekst: 'Inngående faktura' }),
    ])
    expect(o.linjer).toBe(3)
    expect(o.maaneder).toBe(2)
    expect(o.eldste).toBe('2025-02')
    expect(o.nyeste).toBe('2026-07')
    expect(o.utenNavn).toBe(1)
  })
})
