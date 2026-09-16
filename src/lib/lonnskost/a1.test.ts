import { describe, expect, it } from 'vitest'
import { a1ForStasjonsmaaned, beregnA1 } from './a1'
import type { Arbeidsrad, Arbeidstidsmaaned } from './arbeidstid'
import type { Kilder, MedBeggeKilder, Registerrad } from './kilder'
import type { Avtalerad, Avtaleoppslag } from './prisbarhet'

// =====================================================================
// A1-MOTOREN
//
// Alt her er målt mot ekte easy@work-filer 2026-09-16. Filene ligger
// utenfor git, så observasjonene er skrevet inn med kilden nevnt.
//
//   Bønes august 2026, i MINUTTER (intervallet, ikke Easys Lengde):
//     41 926 betalte  =  36 362 lokalt + 1 484 kryss + 4 080 uten register
//     13 personer: 10 lokale, 2 kryss (1104265, 1104270), 1 uten (1004)
//
//   Carmen  1104265  register Lone 138 time, arbeidet Bønes
//   Julian  1104270  register Lone 188,63 time, arbeidet Bønes
//   Sandra  118      juli 48 736 maaned · august 285 time + fastlonn 2026-09-08
//   1018             register Bønes Marietta 239,33 · Basis Varden Andre Fjørstad
// =====================================================================

const BONES = 'sss-0000-0000-0000-00000000b001'
const LONE = 'sss-0000-0000-0000-00000000e001'

const rad = (o: Partial<Arbeidsrad> = {}): Arbeidsrad => ({
  stasjonId: BONES, kildeMaaned: '2026-08', lokasjon: 'St1 - Bønes',
  ansattNr: '1009', ansattNavn: 'Ola Nordmann',
  dato: '2026-08-03', fraDato: '2026-08-03', fraTid: '07:00', tilTid: '15:00',
  minutter: 480, lengdeTimer: 8, betalt: true, avvikGrunn: null,
  importJobbId: 'jobb-1', ...o,
})

const reg = (o: Partial<Registerrad> = {}): Registerrad => ({
  stasjonId: BONES, ansattNr: '1009', navn: 'Ola Nordmann',
  timesats: 210, betalingsfrekvens: 'time', ...o,
})

const CARMEN_REG = reg({
  stasjonId: LONE, ansattNr: '1104265', navn: 'Carmen Valentina Toro', timesats: 138,
})
const JULIAN_REG = reg({
  stasjonId: LONE, ansattNr: '1104270', navn: 'Julian Toro', timesats: 188.63,
})

const arbeidstid = (rader: Arbeidsrad[]): Arbeidstidsmaaned => {
  const betalte = rader.filter((r) => r.betalt)
  return {
    maaned: '2026-08',
    rader,
    prisbareMinutter: betalte.filter((r) => !r.avvikGrunn)
      .reduce((s, r) => s + r.minutter, 0),
    avvisteMinutter: betalte.filter((r) => r.avvikGrunn)
      .reduce((s, r) => s + r.minutter, 0),
    betalteMinutter: betalte.reduce((s, r) => s + r.minutter, 0),
    personer: [...new Set(betalte.map((r) => r.ansattNr))].sort(),
  }
}

const kilder = (rader: Arbeidsrad[], egne: Registerrad[], kryss: Registerrad[] = []):
MedBeggeKilder => ({
  status: 'begge',
  stasjonId: BONES,
  maaned: '2026-08',
  arbeidstid: arbeidstid(rader),
  register: { maaned: '2026-08', egne, kryss, uslaatteNumre: [] },
})

const INGEN_AVTALER: Avtaleoppslag = () => null
const avtalene = (...r: ({ stasjonId: string; ansattNr: string } & Avtalerad)[]):
Avtaleoppslag => (s, n) => {
  const t = r.find((x) => x.stasjonId === s && x.ansattNr === n)
  return t ? { lonnsform: t.lonnsform, sistSatt: t.sistSatt } : null
}

// ---------------------------------------------------------------------
// BEVARINGEN, målt fra RADENE og ikke fra motorens egne summer.
// Regner vi kontrollen av de samme feltene motoren rapporterer, måler
// den ingenting.
const bevaring = (ut: ReturnType<typeof beregnA1>) => {
  const per = (slag: string) => ut.rader
    .filter((v) => v.utfall.slag === slag)
    .reduce((s, v) => s + v.rad.minutter, 0)
  return {
    betalte: ut.rader.filter((v) => v.utfall.slag !== 'ubetalt')
      .reduce((s, v) => s + v.rad.minutter, 0),
    prisede: per('priset'),
    forklarte: per('forklart'),
    uprisede: per('upriset'),
    ubetalte: per('ubetalt'),
  }
}

describe('kildemangel har ingen kroner', () => {
  const uten = (k: Exclude<Kilder, { status: 'begge' }>) =>
    a1ForStasjonsmaaned(k, INGEN_AVTALER)

  it('mangler_register gir ingen kostnadsrad', () => {
    const ut = uten({
      status: 'mangler_register', stasjonId: BONES, maaned: '2026-08',
      arbeidstid: arbeidstid([rad()]), timer: 698.8, personer: 13, kryss: [],
    })
    expect(ut.status).toBe('kildemangel')
    expect(Object.keys(ut)).not.toContain('konto503Kr')
    expect(Object.keys(ut)).not.toContain('minimum503Kr')
  })

  it('mangler_arbeidstid gir ingen kostnadsrad', () => {
    const ut = uten({
      status: 'mangler_arbeidstid', stasjonId: BONES, maaned: '2026-08',
      register: { maaned: '2026-08', egne: [reg()], kryss: [], uslaatteNumre: [] },
    })
    expect(ut.status).toBe('kildemangel')
  })

  it('mangler_begge gir ingen kostnadsrad', () => {
    const ut = uten({ status: 'mangler_begge', stasjonId: BONES, maaned: '2026-08' })
    expect(ut.status).toBe('kildemangel')
  })

  it('ingen av dem sier 0 kr', () => {
    for (const k of [
      { status: 'mangler_begge', stasjonId: BONES, maaned: '2026-08' },
    ] as Exclude<Kilder, { status: 'begge' }>[]) {
      const ut = uten(k)
      expect(JSON.stringify(ut)).not.toContain('503Kr')
    }
  })
})

describe('bevaring av betalte minutter', () => {
  it('alle betalte minutter er gjort rede for', () => {
    const ut = beregnA1(kilder(
      [
        rad({ minutter: 480 }),                                     // priset
        rad({ ansattNr: '118', ansattNavn: 'Sandra', minutter: 300 }), // forklart
        rad({ ansattNr: '9999', ansattNavn: 'Ukjent', minutter: 120 }), // upriset
        rad({ minutter: 30, betalt: false, fraTid: '11:00', tilTid: '11:30' }),
      ],
      [reg(), reg({ ansattNr: '118', navn: 'Sandra', timesats: 48736, betalingsfrekvens: 'maaned' })],
    ), INGEN_AVTALER)

    const b = bevaring(ut)
    expect(b.betalte).toBe(900)
    expect(b.prisede + b.forklarte + b.uprisede).toBe(b.betalte)
    expect(b.prisede).toBe(480)
    expect(b.forklarte).toBe(300)
    expect(b.uprisede).toBe(120)
    expect(b.ubetalte).toBe(30)

    // Motorens egne tall skal si det samme.
    expect(ut.betalteMinutter).toBe(900)
    expect(ut.prisedeMinutter).toBe(480)
    expect(ut.forklarteMinutter).toBe(300)
    expect(ut.uprisedeMinutter).toBe(120)
    expect(ut.ubetalteMinutter).toBe(30)
  })

  it('hver rad har nøyaktig ett utfall', () => {
    const ut = beregnA1(kilder([rad(), rad({ betalt: false })], [reg()]), INGEN_AVTALER)
    for (const v of ut.rader) {
      expect(['priset', 'forklart', 'upriset', 'ubetalt']).toContain(v.utfall.slag)
    }
    expect(ut.rader).toHaveLength(2)
  })

  it('ubetalte minutter står utenfor de betalte', () => {
    const ut = beregnA1(kilder(
      [rad({ minutter: 480 }), rad({ minutter: 30, betalt: false, tilTid: '07:30' })],
      [reg()],
    ), INGEN_AVTALER)
    expect(ut.betalteMinutter).toBe(480)
    expect(ut.ubetalteMinutter).toBe(30)
  })
})

describe('Carmen og Julian — kryssarbeid', () => {
  it('prises på Bønes med Lones sats og telles som innlånt', () => {
    const ut = beregnA1(kilder(
      [rad({ ansattNr: '1104265', ansattNavn: 'Carmen Valentina Toro', minutter: 360 })],
      [reg()], [CARMEN_REG],
    ), INGEN_AVTALER)

    expect(ut.status).toBe('komplett')
    const v = ut.rader[0]
    if (v.utfall.slag !== 'priset') throw new Error('forventet priset')
    expect(v.utfall.timesats).toBe(138)
    expect(v.utfall.innlaant).toBe(true)
    expect(ut.innlaanteNr).toEqual(['1104265'])
  })

  it('KOSTNADSSTEDET er arbeidsstasjonen, ikke registerstasjonen', () => {
    // Den ene forvekslingen som ville sendt Carmens kroner til Lone.
    const ut = beregnA1(kilder(
      [rad({ ansattNr: '1104265', ansattNavn: 'Carmen Valentina Toro' })],
      [reg()], [CARMEN_REG],
    ), INGEN_AVTALER)
    expect(ut.stasjonId).toBe(BONES)
    expect(ut.personer[0].identitet).toMatchObject({ registerStasjonId: LONE })
  })

  it('innlaantKr er en DELMENGDE av 503, ikke et tillegg', () => {
    const ut = beregnA1(kilder(
      [
        rad({ minutter: 480 }),
        rad({ ansattNr: '1104270', ansattNavn: 'Julian Toro', minutter: 480 }),
      ],
      [reg()], [JULIAN_REG],
    ), INGEN_AVTALER)
    if (ut.status !== 'komplett') throw new Error('forventet komplett')
    expect(ut.innlaantKr).toBeGreaterThan(0)
    expect(ut.innlaantKr).toBeLessThan(ut.konto503Kr)
  })

  it('kostnadsstedet er den gatede stasjonen selv når ALLE satser kommer fra Lone', () => {
    // Strukturelt: `beregnA1` regner én stasjonsmåned og tar `stasjonId`
    // fra de gatede kildene. Det finnes ingen gren som kunne valgt
    // registerkandidatens stasjon. Testen låser kontrakten likevel —
    // injeksjonen som forsøkte å bytte den ble en no-op mot fixturen, og
    // en egenskap uten rød injeksjon skal i det minste stå skrevet.
    const ut = beregnA1(kilder(
      [
        rad({ ansattNr: '1104265', ansattNavn: 'Carmen Valentina Toro', minutter: 360 }),
        rad({ ansattNr: '1104270', ansattNavn: 'Julian Toro', minutter: 300 }),
      ],
      [reg({ ansattNr: '1020', navn: 'Ingen vakter her' })],
      [CARMEN_REG, JULIAN_REG],
    ), INGEN_AVTALER)
    expect(ut.stasjonId).toBe(BONES)
    expect(ut.innlaanteNr).toEqual(['1104265', '1104270'])
    for (const v of ut.rader) {
      if (v.utfall.slag === 'priset') expect(v.utfall.innlaant).toBe(true)
    }
  })

  it('månedssummen er summen av radene OGSÅ når noen er innlånt', () => {
    // Injeksjonen som la `innlaantKr` oppå 503 kom tilbake grønn:
    // «delmengde»-testen holdt fortsatt, og avrundingstesten hadde bare
    // lokale rader. Dobbelttellingen var usynlig. Denne blander dem.
    const ut = beregnA1(kilder(
      [
        rad({ minutter: 480 }),
        rad({ ansattNr: '1104265', ansattNavn: 'Carmen Valentina Toro', minutter: 360 }),
      ],
      [reg()], [CARMEN_REG],
    ), INGEN_AVTALER)
    if (ut.status !== 'komplett') throw new Error('forventet komplett')

    const fraRader = ut.rader.reduce(
      (sum, v) => v.utfall.slag === 'priset'
        ? Math.round((sum + v.utfall.belopKr) * 100) / 100
        : sum,
      0,
    )
    expect(ut.konto503Kr).toBe(fraRader)

    const innlaantFraRader = ut.rader.reduce(
      (sum, v) => v.utfall.slag === 'priset' && v.utfall.innlaant
        ? Math.round((sum + v.utfall.belopKr) * 100) / 100
        : sum,
      0,
    )
    expect(ut.innlaantKr).toBe(innlaantFraRader)
    expect(ut.innlaantKr).toBeLessThan(ut.konto503Kr)
  })

  it('en lokal person er ikke innlånt', () => {
    const ut = beregnA1(kilder([rad()], [reg()]), INGEN_AVTALER)
    expect(ut.innlaantKr).toBe(0)
    expect(ut.innlaanteNr).toEqual([])
  })
})

describe('satsens proveniens', () => {
  it('prisbarheten peker på DEN GATEDE registermåneden', () => {
    // Her — og bare her — kunne en julisats priset august. Ingenting i
    // suiten sjekket `kilde` før injeksjonen «registermaaneden hentes fra
    // arbeidsraden» kom tilbake grønn.
    const ut = beregnA1(kilder([rad()], [reg()]), INGEN_AVTALER)
    expect(ut.personer[0].prisbarhet).toMatchObject({
      status: 'prisbar', timesats: 210, kilde: { stasjonId: BONES, maaned: '2026-08' },
    })
  })

  it('kryssatsens proveniens peker på LONE, ikke på arbeidsstedet', () => {
    const ut = beregnA1(kilder(
      [rad({ ansattNr: '1104265', ansattNavn: 'Carmen Valentina Toro' })],
      [reg()], [CARMEN_REG],
    ), INGEN_AVTALER)
    expect(ut.personer[0].prisbarhet).toMatchObject({
      kilde: { stasjonId: LONE, maaned: '2026-08' },
    })
  })

  it('anvendtBakover er false når avtalen er satt FØR månedens utgang', () => {
    // Grensen går på månedens siste dag, og den regnes av den gatede
    // måneden. Er måneden feil, flytter grensen seg.
    const ut = beregnA1(kilder(
      [rad({ ansattNr: '118', ansattNavn: 'Sandra', minutter: 480 })],
      [reg({ ansattNr: '118', navn: 'Sandra', timesats: 285 })],
    ), avtalene({
      stasjonId: BONES, ansattNr: '118', lonnsform: 'fastlonn', sistSatt: '2026-08-31',
    }))
    const v = ut.rader[0]
    if (v.utfall.slag !== 'forklart') throw new Error('forventet forklart')
    if (v.utfall.prisbarhet.status !== 'fastlonn_klassifisert') throw new Error('feil')
    expect(v.utfall.prisbarhet.anvendtBakover).toBe(false)
  })
})

describe('Sandra — måned og fastlønn er forklart, ikke 0 kr', () => {
  it('juli: maanedslonn gir forklart og ikke minimum', () => {
    const ut = beregnA1({
      ...kilder(
        [rad({ ansattNr: '118', ansattNavn: 'Sandra Schütz Schnelle', minutter: 480 })],
        [reg({ ansattNr: '118', navn: 'Sandra Schütz Schnelle', timesats: 48736, betalingsfrekvens: 'maaned' })],
      ),
    }, INGEN_AVTALER)

    expect(ut.status).toBe('komplett')
    expect(ut.forklarteMinutter).toBe(480)
    expect(ut.prisedeMinutter).toBe(0)
    const v = ut.rader[0]
    if (v.utfall.slag !== 'forklart') throw new Error('forventet forklart')
    expect(v.utfall.grunn).toBe('maanedslonn')
  })

  it('august: fastlonn_klassifisert med anvendtBakover', () => {
    const ut = beregnA1(kilder(
      [rad({ ansattNr: '118', ansattNavn: 'Sandra Schütz Schnelle', minutter: 480 })],
      [reg({ ansattNr: '118', navn: 'Sandra Schütz Schnelle', timesats: 285 })],
    ), avtalene({
      stasjonId: BONES, ansattNr: '118', lonnsform: 'fastlonn', sistSatt: '2026-09-08',
    }))

    const v = ut.rader[0]
    if (v.utfall.slag !== 'forklart') throw new Error('forventet forklart')
    expect(v.utfall.grunn).toBe('fastlonn_klassifisert')
    if (v.utfall.prisbarhet.status !== 'fastlonn_klassifisert') throw new Error('feil')
    expect(v.utfall.prisbarhet.anvendtBakover).toBe(true)
    expect(v.utfall.prisbarhet.easyObservasjon).toEqual({
      betalingsfrekvens: 'time', timesats: 285,
    })
  })

  it('forklart arbeid presenteres ALDRI som 0 kr lønn', () => {
    // Timene skal være synlige og årsaken lesbar. De bidrar bare ikke
    // til den timeberegnede 503-komponenten.
    const ut = beregnA1(kilder(
      [rad({ ansattNr: '118', ansattNavn: 'Sandra', minutter: 480 })],
      [reg({ ansattNr: '118', navn: 'Sandra', timesats: 48736, betalingsfrekvens: 'maaned' })],
    ), INGEN_AVTALER)
    expect(ut.personer[0].betalteMinutter).toBe(480)
    expect(ut.personer[0].forklarteMinutter).toBe(480)
    expect(ut.personer[0].prisbarhet).toMatchObject({ status: 'maanedslonn', belop: 48736 })
  })
})

describe('1018 — identitetskonflikten stopper prisingen', () => {
  it('Andre Fjørstad blir upriset, ikke priset med Mariettas sats', () => {
    const ut = beregnA1(kilder(
      [rad({ ansattNr: '1018', ansattNavn: 'Andre Fjørstad', minutter: 480 })],
      [reg({ ansattNr: '1018', navn: 'Marietta Iacovou', timesats: 239.33 })],
    ), INGEN_AVTALER)

    expect(ut.status).toBe('minimum')
    if (ut.status !== 'minimum') return
    expect(ut.minimum503Kr).toBe(0)
    expect(ut.upriset[0].grunn).toBe('motstrid_navn')
    expect(ut.uprisedeMinutter).toBe(480)
  })

  it('Marietta selv kobles helt normalt i samme måned', () => {
    const ut = beregnA1(kilder(
      [rad({ ansattNr: '1018', ansattNavn: 'Marietta Iacovou', minutter: 480 })],
      [reg({ ansattNr: '1018', navn: 'Marietta Iacovou', timesats: 239.33 })],
    ), INGEN_AVTALER)
    expect(ut.status).toBe('komplett')
  })

  it('en motstrid når ALDRI prisberegningen', () => {
    const ut = beregnA1(kilder(
      [rad({ ansattNr: '1018', ansattNavn: 'Andre Fjørstad' })],
      [reg({ ansattNr: '1018', navn: 'Marietta Iacovou', timesats: 239.33 })],
    ), INGEN_AVTALER)
    expect(ut.personer[0].prisbarhet).toBeNull()
    expect(ut.personer[0].belopKr).toBe(0)
  })
})

describe('hva som gjør måneden minimum', () => {
  const enRad = (o: Partial<Arbeidsrad>, egne: Registerrad[], kryss: Registerrad[] = []) =>
    beregnA1(kilder([rad(o)], egne, kryss), INGEN_AVTALER)

  it('ukjent nummer', () => {
    const ut = enRad({ ansattNr: '9999', ansattNavn: 'Ukjent' }, [reg()])
    expect(ut.status).toBe('minimum')
    if (ut.status === 'minimum') expect(ut.upriset[0].grunn).toBe('ukjent_nummer')
  })

  it('registerkollisjon', () => {
    const ut = enRad({ ansattNr: '1018', ansattNavn: 'Andre Fjørstad' },
      [reg({ ansattNr: '1018', navn: 'Andre Fjørstad', timesats: 200 })],
      [reg({ stasjonId: LONE, ansattNr: '1018', navn: 'Andre Fjørstad', timesats: 190 })])
    expect(ut.status).toBe('minimum')
    if (ut.status === 'minimum') expect(ut.upriset[0].grunn).toBe('motstrid_kollisjon')
  })

  it('brokonflikt', () => {
    const ut = enRad({ ansattNr: '1013', ansattNavn: 'Hasan Gezer' }, [
      reg({ ansattNr: '1013', navn: 'Hasan Gezer', timesats: 200 }),
      reg({ ansattNr: '11013', navn: 'Hasan Gezer', timesats: 200 }),
    ])
    expect(ut.status).toBe('minimum')
    if (ut.status === 'minimum') expect(ut.upriset[0].grunn).toBe('motstrid_bro')
  })

  it('manglende sats', () => {
    const ut = enRad({}, [reg({ timesats: null })])
    expect(ut.status).toBe('minimum')
    if (ut.status === 'minimum') expect(ut.upriset[0].grunn).toBe('mangler_sats')
  })

  it('ukjent enhet — en rad skrevet før 0220', () => {
    const ut = enRad({}, [reg({ betalingsfrekvens: null })])
    expect(ut.status).toBe('minimum')
    if (ut.status === 'minimum') expect(ut.upriset[0].grunn).toBe('ukjent_enhet')
  })

  it('avvist Basis-rad', () => {
    const ut = enRad({ avvikGrunn: 'lengde' }, [reg()])
    expect(ut.status).toBe('minimum')
    if (ut.status === 'minimum') expect(ut.upriset[0].grunn).toBe('avvist_rad')
  })

  it('flere lokasjoner — da prises INGEN rad', () => {
    const ut = beregnA1(kilder(
      [rad(), rad({ lokasjon: 'St1 - Lone', ansattNr: '1020', ansattNavn: 'Annen' })],
      [reg(), reg({ ansattNr: '1020', navn: 'Annen' })],
    ), INGEN_AVTALER)
    expect(ut.status).toBe('minimum')
    if (ut.status !== 'minimum') return
    expect(ut.minimum503Kr).toBe(0)
    expect(ut.uprisedeMinutter).toBe(960)
    expect(ut.lokasjoner).toHaveLength(2)
  })

  it('en ubetalt rad gjør IKKE måneden minimum', () => {
    const ut = beregnA1(kilder(
      [rad(), rad({ betalt: false, fraTid: '15:00', tilTid: '15:30', minutter: 30 })],
      [reg()],
    ), INGEN_AVTALER)
    expect(ut.status).toBe('komplett')
  })
})

describe('tid — minutter, fraDato, døgnkryss', () => {
  it('prisgrunnlaget er minutter, ikke lengdeTimer', () => {
    // Easys eget timetall er observasjon og kontroll. Bønes 2025-12-13:
    // intervallet 1,83 t, fila 25,82 t. Prises lengdeTimer, eksploderer
    // tallet.
    const ut = beregnA1(kilder(
      [rad({ minutter: 110, lengdeTimer: 25.82 })], [reg({ timesats: 100 })],
    ), INGEN_AVTALER)
    if (ut.status !== 'komplett') throw new Error('forventet komplett')
    // 110 min = 1,8333 t x 100 = 183,33
    expect(ut.konto503Kr).toBeCloseTo(183.33, 2)
  })

  it('tillegget regnes av fraDato, ikke av forretningsdatoen', () => {
    // Forretningsdato søndag 31. mai, arbeidet begynte mandag 1. juni
    // 00:00. Mandag natt er 1431 (hverdag 00-06), ikke 1433 (søndag).
    const ut = beregnA1({
      ...kilder(
        [rad({
          kildeMaaned: '2026-05', dato: '2026-05-31', fraDato: '2026-06-01',
          fraTid: '00:00', tilTid: '04:00', minutter: 240,
        })],
        [reg()],
      ),
      maaned: '2026-05',
      register: { maaned: '2026-05', egne: [reg()], kryss: [], uslaatteNumre: [] },
    }, INGEN_AVTALER)
    expect(Object.keys(ut.perArt).sort()).toEqual(['1431', '2'])
    expect(ut.perArt['1431'].timer).toBeCloseTo(4, 2)
  })

  it('en døgnkryssende vakt får arter fra begge døgn', () => {
    const ut = beregnA1({
      ...kilder(
        [rad({
          kildeMaaned: '2026-05', dato: '2026-05-31', fraDato: '2026-05-31',
          fraTid: '22:00', tilTid: '02:00', minutter: 240,
        })],
        [reg()],
      ),
      maaned: '2026-05',
      register: { maaned: '2026-05', egne: [reg()], kryss: [], uslaatteNumre: [] },
    }, INGEN_AVTALER)
    // 31. mai 2026 er en søndag: 22-24 er 1435, 00-02 mandag er 1431.
    expect(Object.keys(ut.perArt).sort()).toEqual(['1431', '1435', '2'])
  })
})

describe('dubletter — kildens egen identitet', () => {
  it('to rader som bare skiller seg på tilTid er TO observasjoner', () => {
    // Den ekte dobbeltstemplingen. Den gamle motorens smalere nøkkel
    // ville kollapset dem og spist ekte arbeid.
    const ut = beregnA1(kilder([
      rad({ fraTid: '07:00', tilTid: '11:00', minutter: 240 }),
      rad({ fraTid: '07:00', tilTid: '15:00', minutter: 480 }),
    ], [reg()]), INGEN_AVTALER)
    expect(ut.dubletter).toBe(0)
    expect(ut.betalteMinutter).toBe(720)
    expect(ut.prisedeMinutter).toBe(720)
    expect(ut.rader.map((v) => v.utfall.slag)).toEqual(['priset', 'priset'])
    expect(ut.status).toBe('komplett')
  })

  it('betalt og ubetalt på samme klokkeslett er to observasjoner', () => {
    const ut = beregnA1(kilder([
      rad({ fraTid: '07:00', tilTid: '11:00', minutter: 240 }),
      rad({ fraTid: '07:00', tilTid: '11:00', minutter: 240, betalt: false }),
    ], [reg()]), INGEN_AVTALER)
    expect(ut.dubletter).toBe(0)
    expect(ut.betalteMinutter).toBe(240)
    expect(ut.ubetalteMinutter).toBe(240)
    expect(ut.rader.map((v) => v.utfall.slag)).toEqual(['priset', 'ubetalt'])
    expect(ut.status).toBe('komplett')
  })

  it('en ekte dublett prises EN gang og gjør måneden minimum', () => {
    // Funnet som utløste rettelsen: første utgave gjorde `continue`, og
    // denne testen sjekket aldri `status`. Måneden kunne melde seg som
    // `komplett` selv om kilden hadde brutt sin egen UNIQUE, og raden
    // fantes ikke i revisjonskjeden i det hele tatt.
    const d = rad({ fraTid: '07:00', tilTid: '15:00', minutter: 480 })
    const ut = beregnA1(kilder([d, { ...d }], [reg({ timesats: 100 })]), INGEN_AVTALER)

    expect(ut.dubletter).toBe(1)
    expect(ut.status).toBe('minimum')
    if (ut.status !== 'minimum') return

    // KILDEN eier universet: begge radene er betalt arbeid.
    expect(ut.betalteMinutter).toBe(960)
    expect(ut.prisedeMinutter).toBe(480)
    expect(ut.uprisedeMinutter).toBe(480)
    expect(ut.forklarteMinutter).toBe(0)

    // Kronene for ÉN rad. Dubletten gir ingen.
    expect(ut.minimum503Kr).toBeCloseTo(800, 2)   // 480 min = 8 t x 100
    expect(ut.upriset[0].grunn).toBe('dublett')
  })

  it('INGEN observasjon forsvinner — begge radene står i revisjonskjeden', () => {
    const d = rad({ fraTid: '07:00', tilTid: '15:00', minutter: 480 })
    const ut = beregnA1(kilder([d, { ...d }], [reg()]), INGEN_AVTALER)
    expect(ut.rader).toHaveLength(2)
    expect(ut.rader[0].utfall.slag).toBe('priset')
    expect(ut.rader[1].utfall.slag).toBe('upriset')
    // Den ORIGINALE raden, ikke en syntetisk erstatning.
    expect(ut.rader[1].rad).toEqual(d)
  })

  it('forretningsdatoen deltar IKKE i identiteten', () => {
    // `dato` er ikke i 0219s unique. To rader som bare skiller seg der
    // er samme kildeobservasjon - og den andre blir dublett.
    const ut = beregnA1(kilder([
      rad({ dato: '2026-08-03' }),
      rad({ dato: '2026-08-04' }),
    ], [reg()]), INGEN_AVTALER)
    expect(ut.dubletter).toBe(1)
    expect(ut.status).toBe('minimum')
  })
})

describe('dubletter — dataintegritet og økonomi er to akser', () => {
  // K2. Reproduksjonen fra Vercel Agent Review på cb8fdfc.
  //
  // Første utgave klassifiserte enhver dublett som `upriset('dublett')`.
  // En UBETALT dublett ble dermed talt som betalt arbeid, og den
  // eksterne bevaringsvakten kastet: «kilden ga 480 betalte minutter,
  // motoren saa 510». Hele stasjonsmåneden ble en exception i stedet for
  // et resultat.
  it('K2 — en UBETALT dublett kaster ikke og gjør ikke måneden minimum', () => {
    const u = rad({ betalt: false, minutter: 30, fraTid: '11:00', tilTid: '11:30' })
    const k = kilder([rad({ minutter: 480 }), u, { ...u }], [reg()])
    const ut = beregnA1(k, INGEN_AVTALER)

    expect(k.arbeidstid.betalteMinutter).toBe(480)
    expect(ut.betalteMinutter).toBe(480)
    expect(ut.prisedeMinutter).toBe(480)
    expect(ut.uprisedeMinutter).toBe(0)
    expect(ut.ubetalteMinutter).toBe(60)
    expect(ut.dubletter).toBe(1)
    expect(ut.status).toBe('komplett')

    // Begge ubetalte observasjonene skal stå i revisjonskjeden.
    expect(ut.rader).toHaveLength(3)
    expect(ut.rader.map((v) => v.utfall.slag)).toEqual(['priset', 'ubetalt', 'ubetalt'])
  })

  it('K3 — bare ubetalte dubletter blir ikke minimum av dubletten alene', () => {
    // Kildekontrakten tillater fixturen: `MedBeggeKilder` krever at
    // stasjonen HAR arbeidstidsrader og egne registerrader, ikke at noen
    // av radene er betalte. `hentArbeidstid` returnerer `null` først når
    // måneden ikke har én eneste rad.
    const u = rad({ betalt: false, minutter: 30, fraTid: '11:00', tilTid: '11:30' })
    const ut = beregnA1(kilder([u, { ...u }], [reg()]), INGEN_AVTALER)

    expect(ut.dubletter).toBe(1)
    expect(ut.betalteMinutter).toBe(0)
    expect(ut.uprisedeMinutter).toBe(0)
    expect(ut.ubetalteMinutter).toBe(60)
    expect(ut.status).toBe('komplett')
  })

  it('dubletter teller brudd på radidentiteten, uansett betaltstatus', () => {
    const b = rad({ minutter: 480 })
    const u = rad({ betalt: false, minutter: 30, fraTid: '11:00', tilTid: '11:30' })
    const ut = beregnA1(kilder([b, { ...b }, u, { ...u }], [reg()]), INGEN_AVTALER)
    expect(ut.dubletter).toBe(2)
    // Men bare den BETALTE gir økonomisk usikkerhet.
    expect(ut.uprisedeMinutter).toBe(480)
    expect(ut.status).toBe('minimum')
  })
})

describe('source-conservation — kilden eier universet', () => {
  it('motorens betalteMinutter er lik leserens', () => {
    // Motoren faar ikke selv definere mengden den deretter beviser at
    // den har bevart. `arbeidstid.betalteMinutter` er fasiten.
    const d = rad({ fraTid: '07:00', tilTid: '15:00', minutter: 480 })
    const k = kilder([
      d, { ...d },
      rad({ ansattNr: '9999', ansattNavn: 'Ukjent', minutter: 120 }),
      rad({ minutter: 30, betalt: false, fraTid: '16:00', tilTid: '16:30' }),
    ], [reg()])
    const ut = beregnA1(k, INGEN_AVTALER)
    expect(ut.betalteMinutter).toBe(k.arbeidstid.betalteMinutter)
    expect(ut.betalteMinutter).toBe(1080)
    expect(ut.prisedeMinutter + ut.forklarteMinutter + ut.uprisedeMinutter)
      .toBe(ut.betalteMinutter)
  })

  it('kaster hvis leserens tall og motorens ikke stemmer', () => {
    // Fixturen lyver med vilje: leseren paastaar flere betalte minutter
    // enn radene faktisk baerer. Da skal motoren rope, ikke regne.
    const k = kilder([rad({ minutter: 480 })], [reg()])
    const lognaktig = {
      ...k,
      arbeidstid: { ...k.arbeidstid, betalteMinutter: 600 },
    }
    expect(() => beregnA1(lognaktig, INGEN_AVTALER))
      .toThrow(/mistet minutter foer fordelingen/)
  })
})

describe('forbeholdene følger tallet', () => {
  it('overtid og 1410 står alltid i forbehold', () => {
    const ut = beregnA1(kilder([rad()], [reg()]), INGEN_AVTALER)
    expect(ut.forbehold).toHaveLength(2)
    expect(ut.forbehold[0]).toMatch(/96 og 97/)
    expect(ut.forbehold[1]).toMatch(/1410/)
  })

  it('forbeholdene gjør IKKE måneden minimum', () => {
    // De er modellbegrensninger, ikke mangler i denne beregningen. Gjorde
    // de måneden minimum, ville ingen måned noen gang vært komplett.
    const ut = beregnA1(kilder([rad()], [reg()]), INGEN_AVTALER)
    expect(ut.status).toBe('komplett')
    expect(ut.forbehold.length).toBeGreaterThan(0)
  })

  it('1410-forbeholdet nevner de tre aftenene som ikke er modellert', () => {
    const ut = beregnA1(kilder([rad()], [reg()]), INGEN_AVTALER)
    expect(ut.forbehold[1]).toMatch(/Påskeaften, julaften og nyttårsaften/)
  })
})

describe('avrunding', () => {
  it('beløpet er rundet til øre', () => {
    const ut = beregnA1(kilder(
      [rad({ minutter: 437 })], [reg({ timesats: 188.63 })],
    ), INGEN_AVTALER)
    if (ut.status !== 'komplett') throw new Error('forventet komplett')
    expect(ut.konto503Kr).toBe(Math.round(ut.konto503Kr * 100) / 100)
  })

  it('månedssummen er summen av radenes beløp', () => {
    // Avrundingen skjer per rad og akkumuleres — replikert fra
    // arbeidssted.ts for å holde -0,402 %-målingen sammenlignbar.
    const ut = beregnA1(kilder([
      rad({ fraTid: '07:00', tilTid: '11:00', minutter: 240 }),
      rad({ fraTid: '12:00', tilTid: '19:00', minutter: 420 }),
    ], [reg({ timesats: 188.63 })]), INGEN_AVTALER)
    if (ut.status !== 'komplett') throw new Error('forventet komplett')
    const fraRader = ut.rader.reduce(
      (s, v) => v.utfall.slag === 'priset' ? Math.round((s + v.utfall.belopKr) * 100) / 100 : s,
      0,
    )
    expect(ut.konto503Kr).toBe(fraRader)
  })
})

describe('personresultatet', () => {
  it('samler flere vakter på én person', () => {
    const ut = beregnA1(kilder([
      rad({ fraTid: '07:00', tilTid: '11:00', minutter: 240 }),
      rad({ fraTid: '12:00', tilTid: '16:00', minutter: 240 }),
    ], [reg()]), INGEN_AVTALER)
    expect(ut.personer).toHaveLength(1)
    expect(ut.personer[0].betalteMinutter).toBe(480)
    expect(ut.personer[0].prisedeMinutter).toBe(480)
  })

  it('bærer navnet fra BASIS EXPORT, ikke fra registeret', () => {
    // Registeret kan si noe annet — og det er nettopp det navnevetoet
    // handler om. Personresultatet skal vise det observasjonen sa.
    const ut = beregnA1(kilder(
      [rad({ ansattNavn: 'Ola N.' })], [reg({ navn: 'Ola Nordmann' })],
    ), INGEN_AVTALER)
    expect(ut.personer[0].navn).toBe('Ola N.')
  })

  it('personsummene summerer til månedssummene', () => {
    const ut = beregnA1(kilder([
      rad({ minutter: 480 }),
      rad({ ansattNr: '1104265', ansattNavn: 'Carmen Valentina Toro', minutter: 360 }),
      rad({ ansattNr: '9999', ansattNavn: 'Ukjent', minutter: 120 }),
    ], [reg()], [CARMEN_REG]), INGEN_AVTALER)
    const sum = (f: 'betalteMinutter' | 'prisedeMinutter' | 'uprisedeMinutter') =>
      ut.personer.reduce((s, p) => s + p[f], 0)
    expect(sum('betalteMinutter')).toBe(ut.betalteMinutter)
    expect(sum('prisedeMinutter')).toBe(ut.prisedeMinutter)
    expect(sum('uprisedeMinutter')).toBe(ut.uprisedeMinutter)
  })
})
