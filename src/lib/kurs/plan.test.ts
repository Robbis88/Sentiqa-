import { describe, expect, it } from 'vitest'
import { BUTIKKSJEF_BEGREP } from '@/lib/regnskap-tilgang'
import type { Satser } from '@/lib/royalty'
import { LOFTESTENGER } from './loftestenger'
import { byggMaanedsplan, type Leverandorrad, type Maanedstall } from './plan'

const SATSER: Satser = { lavSats: 0.1, hoySatsVask: 0.6, pantSats: 0 }

/** Tall formateres med hardt mellomrom. Paastandene skal maale innhold. */
const flat = (t: string) => t.replace(/\s/g, ' ')

function mnd(i: number, over: Partial<Maanedstall> = {}): Maanedstall {
  return {
    maaned: `2026-0${i + 1}-01`,
    omsetningKr: 1_000_000, omsetningBudsjettKr: 1_000_000,
    bruttoKr: 500_000,
    matsalgKr: 400_000, matkastKr: 30_000,
    usynligRestKr: 10_000,
    personalKr: 300_000, personalBudsjettKr: 300_000,
    paavirkbarDriftKr: 40_000, paavirkbarDriftBudsjettKr: 40_000,
    resultatKr: 50_000,
    ...over,
  }
}

/** Seks maaneder der resultatet stiger og matkastet faller. */
const MEDVIND: Maanedstall[] = [0, 1, 2, 3, 4, 5].map((i) =>
  mnd(i, { resultatKr: -60_000 + i * 25_000, matkastKr: 45_000 - i * 3_000,
           personalKr: 300_000 + i * 6_000 }))

/** Seks maaneder der resultatet faller og matkastet stiger. */
const MOTVIND: Maanedstall[] = [0, 1, 2, 3, 4, 5].map((i) =>
  mnd(i, { resultatKr: 90_000 - i * 25_000, matkastKr: 20_000 + i * 4_000,
           paavirkbarDriftKr: 40_000 + i * 2_000 }))

const LEV: Leverandorrad[] = [
  { begrep: 'forbruksmateriell', tekst: 'ASKO VEST AS', belopKr: 29_825, antall: 12 },
  { begrep: 'renhold', tekst: 'Elis Norge AS', belopKr: 11_368, antall: 4 },
  // Leasing: utenfor butikksjefens begreper. Skal ALDRI dukke opp.
  { begrep: 'leie_driftsmidler', tekst: 'DNB Finans AS', belopKr: 233_337, antall: 6 },
  // Ukjent begrep: rad fra skjemaet foer februar 2026.
  { begrep: null, tekst: 'WashTec Bilvask AS', belopKr: 90_885, antall: 3 },
]

describe('byggMaanedsplan — medvind', () => {
  const p = byggMaanedsplan({
    stasjonNavn: 'Dale', historikk: MEDVIND, leverandorer: LEV, satser: SATSER,
  })

  it('kjenner medvind', () => {
    expect(p.dom).toBe('medvind')
  })

  it('bekrefter det som gaar bra OG gir neste loeftestang', () => {
    // «Fortsett saann» er ikke en plan. Det beste tidspunktet aa ta fatt
    // paa noe nytt er naar du allerede vinner.
    expect(p.punkter.map((x) => x.slag)).toEqual(['bekreftelse', 'tiltak'])
    expect(p.punkter[0].loftestang).toBe('matkast')
    expect(p.punkter[1].loftestang).toBe('personal')
  })

  it('ingressen er skrevet ut av tallene', () => {
    // Tallene formateres med HARDT mellomrom (nb-NO). Paastandene
    // normaliserer, ellers maaler de tegnvalg og ikke innhold.
    const i = flat(p.ingress)
    expect(i).toContain('65 000')       // resultatet i juni
    expect(i).toContain('−60 000')      // januar
    expect(i).toMatch(/\+125 000 på 6 måneder/)
  })
})

describe('byggMaanedsplan — motvind', () => {
  const p = byggMaanedsplan({
    stasjonNavn: 'Laguneparken', historikk: MOTVIND, leverandorer: LEV, satser: SATSER,
  })

  it('kjenner motvind', () => {
    expect(p.dom).toBe('motvind')
  })

  it('KANARI: gir ÉN ting, ikke fem', () => {
    // En liste med fem tiltak til noen som holder paa aa miste grepet er
    // ikke en plan, det er en anklage.
    expect(p.punkter).toHaveLength(1)
    expect(p.punkter[0].slag).toBe('tiltak')
  })

  it('velger den stoerste, ikke den foerste', () => {
    // Matkast stiger 4 000 i maaneden, drift 2 000. Begge gaar feil vei.
    expect(p.punkter[0].loftestang).toBe('matkast')
  })

  it('gir ingen bekreftelse i motvind', () => {
    expect(p.punkter.some((x) => x.slag === 'bekreftelse')).toBe(false)
  })
})

/** Motvind der DRIFTSLINJA er den stoerste - da slaar leverandoeroppslaget inn. */
const DRIFTVIND: Maanedstall[] = [0, 1, 2, 3, 4, 5].map((i) =>
  mnd(i, { resultatKr: 90_000 - i * 25_000, paavirkbarDriftKr: 40_000 + i * 9_000 }))

describe('grensene planen aldri bryter', () => {
  // DRIFTVIND MAA VAERE MED. Uten den slaar `stoersteLeverandor` aldri
  // inn i det hele tatt - tiltaket blir matkast, og lekkasjetesten
  // bestaar uten aa maale noe.
  //
  // Det oppdaget jeg ved aa injisere regresjonen: jeg fjernet
  // begrepsfilteret, og kanarifuglen forble GROENN. Den som felte var en
  // helt annen test, ved et uhell. En vakt som slutter aa se ser
  // noeyaktig ut som en vakt som ikke finner noe.
  const alle = [
    byggMaanedsplan({ stasjonNavn: 'A', historikk: MEDVIND, leverandorer: LEV, satser: SATSER }),
    byggMaanedsplan({ stasjonNavn: 'B', historikk: MOTVIND, leverandorer: LEV, satser: SATSER }),
    byggMaanedsplan({ stasjonNavn: 'C', historikk: DRIFTVIND, leverandorer: LEV, satser: SATSER }),
  ]

  it('KANARI FOR KANARIFUGLEN: minst én av planene navngir en leverandoer', () => {
    // Gjoer den ikke det, maaler lekkasjetestene under ingenting.
    expect(alle.some((p) => p.punkter.some((x) => x.leverandor))).toBe(true)
  })

  it('KANARI: nevner aldri en leverandoer utenfor butikksjefens begreper', () => {
    // DNB Finans er leasing - `leie_driftsmidler` staar ikke i
    // BUTIKKSJEF_BEGREP, og er nettopp det 628 betydde foer feb 2026.
    for (const p of alle) {
      const tekst = JSON.stringify(p)
      expect(tekst).not.toContain('DNB Finans')
      expect(tekst).not.toContain('leie_driftsmidler')
    }
  })

  it('KANARI: nevner aldri en rad uten begrep', () => {
    // begrep = null betyr «vi kjente ikke igjen paret (kode, navn)»,
    // typisk en rad fra det gamle skjemaet. Ukjent skal vaere skjult.
    for (const p of alle) {
      expect(JSON.stringify(p)).not.toContain('WashTec')
    }
  })

  it('KANARI: bryter aldri opp loenn', () => {
    // Robert: «butikksjefene skal aldri se noe annet enn total
    // loennsbudsjett. aldri budsjett paa fastloenn osv.» Timeloenn ER
    // den ekte loeftestangen og ville gitt et skarpere tiltak - skarpere
    // og forbudt.
    for (const p of alle) {
      const tekst = JSON.stringify(p).toLowerCase()
      expect(tekst).not.toContain('timelønn')
      expect(tekst).not.toContain('fastlønn')
      expect(tekst).not.toContain('sykelønn')
    }
    expect(LOFTESTENGER.find((l) => l.id === 'personal')!.navn)
      .toBe('Personalkostnad mot budsjett')
  })

  it('KANARI: ber aldri om en endring paa noe som er en FOELGE', () => {
    // Uten denne ville lista kunne vokse med en foelge, og planen ville
    // bedt om noe personen ikke raar over - «faa ned 590» betyr i
    // praksis «betal mindre pensjon».
    const spaker = new Set(LOFTESTENGER.filter((l) => l.klasse === 'spak').map((l) => l.id))
    for (const p of alle) {
      for (const punkt of p.punkter) {
        expect(spaker, `${punkt.loftestang} er ikke en spak`).toContain(punkt.loftestang)
      }
    }
  })

  it('KANARI: hver loeftestang finnes i BUTIKKSJEF_BEGREP-verdenen', () => {
    // Uten denne maaler testen over ingenting hvis LOFTESTENGER tømmes.
    expect(LOFTESTENGER.filter((l) => l.klasse === 'spak').length).toBeGreaterThanOrEqual(4)
    expect(BUTIKKSJEF_BEGREP.length).toBeGreaterThan(10)
  })
})

describe('leverandoeren i tiltaket', () => {
  it('navngir den stoerste naar driftslinja er tiltaket', () => {
    const drift: Maanedstall[] = [0, 1, 2, 3, 4, 5].map((i) =>
      mnd(i, { resultatKr: 90_000 - i * 25_000, paavirkbarDriftKr: 40_000 + i * 9_000 }))
    const p = byggMaanedsplan({
      stasjonNavn: 'Lone', historikk: drift, leverandorer: LEV, satser: SATSER,
    })
    expect(p.punkter[0].loftestang).toBe('paavirkbar_drift')
    expect(p.punkter[0].leverandor).toBe('ASKO VEST AS')
    expect(flat(p.punkter[0].tekst)).toContain('29 825')
  })

  it('respekterer klasseFor: WashTec er en foelge, ikke en spak', () => {
    // Paa en stasjon med vask er 634 vaskemaskinen. Paa Dale er den
    // kjoel og bygg. Klassen avgjoeres per stasjon, av hvem fakturaen
    // kom fra.
    const drift: Maanedstall[] = [0, 1, 2, 3, 4, 5].map((i) =>
      mnd(i, { resultatKr: 90_000 - i * 25_000, paavirkbarDriftKr: 40_000 + i * 9_000 }))
    const medWashTec: Leverandorrad[] = [
      { begrep: 'rep_vedlikehold', tekst: 'WashTec Bilvask AS', belopKr: 90_885, antall: 3 },
      { begrep: 'forbruksmateriell', tekst: 'ASKO VEST AS', belopKr: 29_825, antall: 12 },
    ]
    const p = byggMaanedsplan(
      { stasjonNavn: 'Varden', historikk: drift, leverandorer: medWashTec, satser: SATSER },
      { klasseFor: (r) => (r.tekst.includes('WashTec') ? 'folge' : 'spak') },
    )
    expect(p.punkter[0].leverandor).toBe('ASKO VEST AS')
    expect(JSON.stringify(p)).not.toContain('WashTec')
  })
})

describe('uten royaltysatser', () => {
  const p = byggMaanedsplan({
    stasjonNavn: 'Ny kjede', historikk: MOTVIND, leverandorer: LEV, satser: null,
  })

  it('KANARI: viser INGEN kroneverdier, og sier hvorfor', () => {
    // Feiler lukket. Et tall uten satser ville vaert bruttofortjeneste
    // utgitt for netto - og det er en stoerre feil enn aa la vaere.
    expect(p.punkter.every((x) => x.kronerIAret === null)).toBe(true)
    expect(p.merknad).toMatch(/royaltysatser/)
  })

  it('men planen finnes likevel — retningen trenger ingen satser', () => {
    expect(p.dom).toBe('motvind')
    expect(p.punkter).toHaveLength(1)
  })
})

describe('kort historikk', () => {
  it('gir «flat» og ingen bekreftelse naar retningen ikke kan vites', () => {
    const p = byggMaanedsplan({
      stasjonNavn: 'Fersk', historikk: [mnd(0), mnd(1)], leverandorer: [], satser: SATSER,
    })
    expect(p.dom).toBe('flat')
    expect(p.punkter.some((x) => x.slag === 'bekreftelse')).toBe(false)
  })
})
