import { describe, expect, it } from 'vitest'
import {
  aarseffekt, fremdrift, gyldigSpenn, kanSettesSomMaal, IKKE_MAALBARE, MAALKONTRAKT,
  type Maalgrunnlag,
} from './kontrakt'
import { LOFTESTENGER, loftestang, type LoftestangId } from '@/lib/kurs/loftestenger'
import { verdiAvGevinst } from '@/lib/royalty'

// =====================================================================
// Grunnlaget er Lones, slik det sto 2026-09-14.
//
// EKTE TALL MED VILJE. En kontrakt proevd mot 100 og 200 kan vaere
// riktig og likevel gi et svar som er tolv ganger for stort uten at noen
// ser det. 14,2 millioner og 37,7 % gjoer feilen synlig.
// =====================================================================
const SATSER = { lavSats: 0.10, hoySatsVask: 0.60, pantSats: 0 }

const LONE: Maalgrunnlag = {
  omsetningKr: 14_200_000,
  bruttoKr: 5_353_400, // 37,7 %
  satser: SATSER,
}

describe('kontrakten dekker loeftestengene, og bare spakene', () => {
  it('har én post per LoftestangId, hverken mer eller mindre', () => {
    const iKontrakten = Object.keys(MAALKONTRAKT).sort()
    const iListen = LOFTESTENGER.map((l) => l.id).sort()
    expect(iKontrakten).toEqual(iListen)
  })

  it('hver post peker paa seg selv', () => {
    for (const [id, k] of Object.entries(MAALKONTRAKT)) {
      expect(k.loftestang, `posten ${id} peker paa ${k.loftestang}`).toBe(id)
    }
  })

  it('alle fem er spaker, og kan derfor bli maal', () => {
    for (const l of LOFTESTENGER) expect(kanSettesSomMaal(l), l.id).toBe(true)
  })

  // =================================================================
  // KANARIFUGL
  // =================================================================
  //
  // Alle fem loeftestengene er spaker i dag, saa testen over ville
  // bestaatt ogsaa med `kanSettesSomMaal = () => true`. Regelen maa
  // proeves mot en klasse som ikke finnes i lista.
  it('KANARIFUGL: en folge eller fast kan ALDRI bli maal', () => {
    for (const klasse of IKKE_MAALBARE) {
      expect(kanSettesSomMaal({ klasse }), klasse).toBe(false)
    }
    expect(IKKE_MAALBARE).toHaveLength(2)
  })
})

describe('enhetene, og de to som ikke er opplagte', () => {
  it('loenn maales som andel av brutto, ikke i kroner mot BP', () => {
    // BP-loenna er fast, men rommet beveger seg med brutto. Et maal i
    // kroner mot BP blir meningsloest naar brutto faller - noeyaktig
    // feilen `lonnskost/rom.ts` finnes for aa hindre.
    expect(MAALKONTRAKT.personal.enhet).toBe('andel_av_brutto')
  })

  it('paavirkbar drift maales i kroner, ikke normalisert per omsetning', () => {
    // Ellers ville et omsetningsfall «oppnaadd» kostnadsmaalet.
    expect(MAALKONTRAKT.paavirkbar_drift.enhet).toBe('kr_aar')
  })

  it('matkast og usynlig svinn maales i prosent av omsetning', () => {
    expect(MAALKONTRAKT.matkast.enhet).toBe('pst_av_oms')
    expect(MAALKONTRAKT.usynlig_rest.enhet).toBe('pst_av_oms')
  })

  it('matkast forankres i St1s eget kastbudsjett, foerst', () => {
    expect(MAALKONTRAKT.matkast.anker[0]).toBe('kastbudsjett')
  })
})

describe('prognosekilder — det som IKKE kan vises tidlig', () => {
  it('usynlig svinn har ingen tidlig kilde, og det er en egenskap', () => {
    // Per definisjon differansen regnskapet avdekker. Et tidlig tall her
    // ville vaert funnet paa fordi det hadde sett pent ut.
    expect(MAALKONTRAKT.usynlig_rest.prognosekilder).toEqual([])
  })

  it('paavirkbar drift har heller ingen — ingen faktura leses foer regnskapet', () => {
    expect(MAALKONTRAKT.paavirkbar_drift.prognosekilder).toEqual([])
  })

  it('de tre andre HAR en tidlig kilde', () => {
    for (const id of ['matkast', 'personal', 'omsetning'] as LoftestangId[]) {
      expect(MAALKONTRAKT[id].prognosekilder.length, id).toBeGreaterThan(0)
    }
  })

  it('hver post sier hva fasit krever', () => {
    for (const [id, k] of Object.entries(MAALKONTRAKT)) {
      expect(k.fasitkrav.length, id).toBeGreaterThan(10)
    }
  })
})

describe('aarseffekt', () => {
  it('matkast 3,90 % -> 3,10 % er 0,80 pp av aarsomsetningen', () => {
    const kr = aarseffekt(
      { loftestang: 'matkast', startverdi: 3.90, maalverdi: 3.10 }, LONE,
    )
    expect(kr).toBeCloseTo(113_600, 0)
  })

  it('en svinngevinst beholdes i sin helhet — royalty tar ingenting', () => {
    // Omsetningen er uendret, og royalty regnes av omsetning.
    const medRoyalty = aarseffekt(
      { loftestang: 'matkast', startverdi: 3.90, maalverdi: 3.10 }, LONE,
    )
    const utenRoyalty = aarseffekt(
      { loftestang: 'matkast', startverdi: 3.90, maalverdi: 3.10 },
      { ...LONE, satser: { lavSats: 0, hoySatsVask: 0, pantSats: 0 } },
    )
    expect(medRoyalty).toBe(utenRoyalty)
  })

  it('loenn 36,4 % -> 34,5 % av brutto er 1,9 prosentpoeng av bruttoen', () => {
    const kr = aarseffekt(
      { loftestang: 'personal', startverdi: 0.364, maalverdi: 0.345 }, LONE,
    )
    expect(kr).toBeCloseTo(0.019 * LONE.bruttoKr, 0)
  })

  it('omsetning er den ENESTE som betaler royalty', () => {
    const vekst = 284_000
    const kr = aarseffekt(
      { loftestang: 'omsetning', startverdi: 14_200_000, maalverdi: 14_200_000 + vekst },
      LONE,
    )
    const margin = LONE.bruttoKr / LONE.omsetningKr
    expect(kr).toBeCloseTo(vekst * margin - vekst * SATSER.lavSats, 0)
    // Og den er mindre enn den samme veksten uten royalty.
    expect(kr).toBeLessThan(vekst * margin)
  })

  it('vask over kassa er dyrere enn vask paa app', () => {
    const spenn = { loftestang: 'omsetning' as const, startverdi: 0, maalverdi: 100_000 }
    const kasse = aarseffekt(spenn, { ...LONE, kanal: 'vask_kasse' })
    const app = aarseffekt(spenn, { ...LONE, kanal: 'vask_app' })
    expect(kasse).toBeLessThan(app)
  })

  it('paavirkbar drift i kroner gaar rett gjennom', () => {
    const kr = aarseffekt(
      { loftestang: 'paavirkbar_drift', startverdi: 480_000, maalverdi: 432_000 }, LONE,
    )
    expect(kr).toBeCloseTo(48_000, 0)
  })

  // =================================================================
  // ET MAAL I FEIL RETNING HAR INGEN AARSGEVINST
  // =================================================================
  //
  // Her sto det motsatte: «retningen spiller ingen rolle for beloepet».
  // `aarseffekt` gjorde `Math.abs`, og da fikk 3,10 -> 3,90 samme
  // +113 600 som 3,90 -> 3,10.
  //
  // Det er ikke en visningsfeil. Tallet fryses som `aarseffekt_kr` naar
  // maalet settes (E8), og et lagret gevinstpotensial for et maal som
  // gaar bakover er en loegn ingen senere kan se at var det.
  it('kaster i stedet for aa gjoere et feilrettet maal positivt', () => {
    expect(() => aarseffekt(
      { loftestang: 'matkast', startverdi: 3.10, maalverdi: 3.90 }, LONE,
    )).toThrow(/Ugyldig maalspenn/)
  })

  it('kaster ogsaa naar omsetning peker nedover', () => {
    expect(() => aarseffekt(
      { loftestang: 'omsetning', startverdi: 14_200_000, maalverdi: 13_000_000 }, LONE,
    )).toThrow(/skal opp/)
  })

  it('kaster paa et spenn uten spenn', () => {
    expect(() => aarseffekt(
      { loftestang: 'matkast', startverdi: 3.10, maalverdi: 3.10 }, LONE,
    )).toThrow(/uten spenn/)
  })

  // =================================================================
  // KANARIFUGL
  // =================================================================
  it('KANARIFUGL: den kaster ikke paa det som ER riktig vei', () => {
    // Uten denne ville `aarseffekt = () => { throw }` bestaatt hver
    // kast-test over.
    expect(() => aarseffekt(
      { loftestang: 'matkast', startverdi: 3.90, maalverdi: 3.10 }, LONE,
    )).not.toThrow()
    expect(() => aarseffekt(
      { loftestang: 'omsetning', startverdi: 14_200_000, maalverdi: 14_484_000 }, LONE,
    )).not.toThrow()
  })
})

// =====================================================================
// GYLDIGHETEN, FOER NOE FRYSES
// =====================================================================
//
// `fremdrift` leste `loftestang().god` riktig hele tiden; `aarseffekt`
// gjorde det ikke. To syn paa samme sannhet i samme fil er ett for mye.
// Porten staar her, ved skrivingen.
// =====================================================================
describe('gyldigSpenn — retningen er loeftestangens, ikke fortegnet', () => {
  const dom = (loftestang: LoftestangId, startverdi: number, maalverdi: number) =>
    gyldigSpenn({ loftestang, startverdi, maalverdi })

  it('matkast NED er gyldig', () => {
    expect(loftestang('matkast').god).toBe('ned')
    expect(dom('matkast', 3.90, 3.10)).toEqual({ gyldig: true })
  })

  it('matkast OPP er ugyldig, og sier hvorfor', () => {
    const d = dom('matkast', 3.10, 3.90)
    expect(d.gyldig).toBe(false)
    expect(d.gyldig === false && d.grunn).toMatch(/skal ned/)
  })

  it('omsetning OPP er gyldig', () => {
    expect(loftestang('omsetning').god).toBe('opp')
    expect(dom('omsetning', 14_200_000, 14_484_000)).toEqual({ gyldig: true })
  })

  it('omsetning NED er ugyldig', () => {
    const d = dom('omsetning', 14_200_000, 13_900_000)
    expect(d.gyldig).toBe(false)
    expect(d.gyldig === false && d.grunn).toMatch(/skal opp/)
  })

  it('start lik maal er ugyldig for alle fem', () => {
    for (const l of LOFTESTENGER) {
      const d = dom(l.id, 100, 100)
      expect(d.gyldig, l.id).toBe(false)
      expect(d.gyldig === false && d.grunn, l.id).toMatch(/uten spenn/)
    }
  })

  it('et tall som ikke er et tall er ugyldig', () => {
    // `NaN !== NaN`, og hver sammenligning mot NaN er usann. Uten denne
    // ville et uleselig skjemafelt passert og gitt NaN kroner i aaret.
    expect(dom('matkast', Number.NaN, 3.10).gyldig).toBe(false)
    expect(dom('matkast', 3.90, Number.NaN).gyldig).toBe(false)
    expect(dom('matkast', 3.90, Number.POSITIVE_INFINITY).gyldig).toBe(false)
  })

  // =================================================================
  // KANARIFUGL
  // =================================================================
  it('KANARIFUGL: den godtar faktisk de riktige, for hver av de fem', () => {
    // Uten denne ville `gyldigSpenn = () => ({gyldig:false})` bestaatt
    // hver ugyldighetstest over.
    for (const l of LOFTESTENGER) {
      const riktigVei = l.god === 'ned' ? dom(l.id, 100, 90) : dom(l.id, 100, 110)
      expect(riktigVei, l.id).toEqual({ gyldig: true })
    }
  })
})

// =====================================================================
// ×12-FELLA
// =====================================================================
//
// `kronerIAret()` i `kurs/plan.ts` ganger med 12, og har rett: inputen
// der er en MAANEDSBEVEGELSE. Et maal uttrykkes mot et AARSGRUNNLAG og
// er allerede aarlig.
//
// Blandes de, er feilen tolv ganger - og den ser ut som et stort funn i
// stedet for en feil.
// =====================================================================
describe('x12-fella: maanedlig og aarlig uttrykk gir samme svar', () => {
  it('matkast: 0,80 pp aarlig = samme kroner som maanedsbeloepet x 12', () => {
    const aarlig = aarseffekt(
      { loftestang: 'matkast', startverdi: 3.90, maalverdi: 3.10 }, LONE,
    )

    // Den samme forbedringen, sett som en maanedsbevegelse: 0,80 pp av
    // én maaneds omsetning. Slik `kronerIAret` ville regnet den.
    const perMaaned = (0.80 / 100) * (LONE.omsetningKr / 12)
    const somPlanRegner = verdiAvGevinst({ type: 'margin', kroner: perMaaned }, SATSER) * 12

    expect(aarlig).toBeCloseTo(somPlanRegner, 6)
  })

  it('KANARIFUGL: en x12 i aarseffekt ville brutt likheten', () => {
    // Uten denne kunne testen over bestaatt fordi BEGGE sider var feil.
    const aarlig = aarseffekt(
      { loftestang: 'matkast', startverdi: 3.90, maalverdi: 3.10 }, LONE,
    )
    const perMaaned = (0.80 / 100) * (LONE.omsetningKr / 12)
    expect(aarlig).not.toBeCloseTo(perMaaned * 12 * 12, 0)
    expect(aarlig / perMaaned).toBeCloseTo(12, 6)
  })

  it('loenn: samme likhet paa andel_av_brutto', () => {
    const aarlig = aarseffekt(
      { loftestang: 'personal', startverdi: 0.364, maalverdi: 0.345 }, LONE,
    )
    const perMaaned = 0.019 * (LONE.bruttoKr / 12)
    expect(aarlig).toBeCloseTo(perMaaned * 12, 6)
  })
})

describe('fremdrift', () => {
  const matkast = { loftestang: 'matkast' as const, startverdi: 3.90, maalverdi: 3.10 }

  it('halvveis er halvveis', () => {
    const f = fremdrift(matkast, 3.50)
    expect(f.andel).toBeCloseTo(0.5, 6)
    expect(f.avvik).toBeCloseTo(0.40, 6)
    expect(f.naadd).toBe(false)
  })

  it('paa maalet er naadd', () => {
    const f = fremdrift(matkast, 3.10)
    expect(f.andel).toBeCloseTo(1, 6)
    expect(f.avvik).toBeCloseTo(0, 6)
    expect(f.naadd).toBe(true)
  })

  it('forbi maalet gir negativt avvik og andel over 1', () => {
    const f = fremdrift(matkast, 3.00)
    expect(f.avvik).toBeLessThan(0)
    expect(f.andel).toBeGreaterThan(1)
    expect(f.naadd).toBe(true)
  })

  it('feil vei gir negativ andel, ikke null', () => {
    // Et maal som gaar bakover skal SES. Klemmes det til null, ser en
    // stasjon som blir verre ut som en som staar stille.
    const f = fremdrift(matkast, 4.10)
    expect(f.andel).toBeLessThan(0)
    expect(f.naadd).toBe(false)
  })

  // =================================================================
  // RETNINGEN LESES AV LOEFTESTANGEN
  // =================================================================
  it('omsetning skal OPP, og fremdriften vet det', () => {
    const oms = { loftestang: 'omsetning' as const, startverdi: 14_200_000, maalverdi: 14_484_000 }
    expect(loftestang('omsetning').god).toBe('opp')
    const f = fremdrift(oms, 14_342_000)
    expect(f.andel).toBeCloseTo(0.5, 6)
    expect(f.naadd).toBe(false)
  })

  it('KANARIFUGL: samme tall paa en NED-loeftestang gir motsatt svar', () => {
    // Uten denne kunne `fremdrift` ignorert `god` og likevel bestaatt
    // hver test over, siden matkast og omsetning har ulike tallomraader.
    const nedover = fremdrift(
      { loftestang: 'matkast', startverdi: 10, maalverdi: 8 }, 9,
    )
    const oppover = fremdrift(
      { loftestang: 'omsetning', startverdi: 10, maalverdi: 8 }, 9,
    )
    expect(nedover.andel).toBeCloseTo(0.5, 6)
    expect(oppover.andel).toBeCloseTo(-0.5, 6)
  })

  it('null bredde gir null andel i stedet for aa dele paa null', () => {
    const f = fremdrift({ loftestang: 'matkast', startverdi: 3.10, maalverdi: 3.10 }, 3.10)
    expect(f.andel).toBe(0)
    expect(Number.isFinite(f.andel)).toBe(true)
    expect(f.naadd).toBe(false)
  })
})
