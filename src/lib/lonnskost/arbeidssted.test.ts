import { describe, expect, it } from 'vitest'
import { beregnArbeidssted, type Prisregister } from './arbeidssted'
import { minutterMellom, type Basisstempling } from '@/lib/parsere/basiseksport'
import type { Ansattrad } from '@/lib/parsere/lonnsgrunnlag'

// Navn og numre er byttet ut. Formen er ekte: en ansatt med
// hovedlokasjon Lone som jobber på Bønes er nøyaktig tilfellet som
// bommet med -10,9 % i den gamle modellen.
//
// LENGDEN REGNES AV `minutterMellom`, IKKE AV EN KOPI I TESTEN.
// Første utgave hadde sin egen lille utregning her. Da ville en endring
// i produksjonens døgnhåndtering kunne gå ubemerket: testen og koden
// ville vært uenige om hva fixturen betyr, og begge kunne vært gale
// samtidig.

const BONES = 'St1 - Bønes'
const LONE = 'St1 - Lone'
const MND = '2026-07'

const st = (
  p: { dato: string; fraTid: string; tilTid: string } & Partial<Basisstempling>,
): Basisstempling => ({
  ansattNr: '308',
  ansattNavn: 'A B',
  fraDato: p.fraDato ?? p.dato,
  betalt: true,
  lokasjon: BONES,
  ...p,
  minutter: minutterMellom(p.fraDato ?? p.dato, p.fraTid, p.tilTid),
})

const ansatt = (nr: string, timesats: number, hovedlokasjon: string, navn = 'A B'): Ansattrad =>
  ({ ansattNr: nr, ansattNavn: navn, timesats, hovedlokasjon })

/** Et register som dekker juli 2026. */
const reg = (ansatte: Ansattrad[]): Prisregister =>
  ({ fraDato: '2026-07-01', tilDato: '2026-07-31', ansatte })

const kjor = (p: Partial<Parameters<typeof beregnArbeidssted>[0]> & {
  stemplinger: Basisstempling[]
  registre: Prisregister[]
}) => beregnArbeidssted({ maaned: MND, avvik: [], ...p })

describe('beregnArbeidssted — kryssarbeid', () => {
  it('fører innlånte timer på stasjonen de ble jobbet på', () => {
    // BEVISET. Den gamle modellen leste bare Bønes' eget lønnsgrunnlag,
    // der denne ansatte står med NULL timer fordi hovedlokasjonen er
    // Lone. Timene forsvant, og lønnsrommet ble for stort.
    const [b] = kjor({
      stemplinger: [st({ ansattNr: '1104265', dato: '2026-07-01', fraTid: '10:00', tilTid: '16:00' })],
      registre: [reg([ansatt('1104265', 138, LONE)])],
    })
    expect(b.lokasjon).toBe(BONES)
    expect(b.timer).toBe(6)
    expect(b.konto503Kr).toBe(828)
    expect(b.innlaantKr).toBe(828)
    expect(b.innlaanteNr).toEqual(['1104265'])
    expect(b.datagrunnlag).toBe('komplett')
  })

  it('kan ikke falle tilbake til den gamle feilen', () => {
    // KANARIFUGL mot -10,9 %-regresjonen.
    const [b] = kjor({
      stemplinger: [
        st({ ansattNr: '1104265', dato: '2026-07-01', fraTid: '10:00', tilTid: '16:00' }),
        st({ ansattNr: '308', dato: '2026-07-01', fraTid: '10:00', tilTid: '16:00' }),
      ],
      registre: [reg([ansatt('1104265', 138, LONE), ansatt('308', 200, BONES)])],
    })
    expect(b.innlaantKr).toBeGreaterThan(0)
    expect(b.konto503Kr).toBeGreaterThan(b.innlaantKr)
  })

  it('lar ALDRI arbeidsstedet falle tilbake til hovedlokasjonen', () => {
    // INVARIANT, ikke et enkelttilfelle. Uansett hvilken hjemstasjon den
    // ansatte har, er gruppen den lokasjonen Basis-raden oppgir.
    for (const hjem of [BONES, LONE, 'St1 - Dale', 'St1 - Varden', '']) {
      const ut = kjor({
        stemplinger: [st({ ansattNr: '9', dato: '2026-07-01', fraTid: '10:00', tilTid: '16:00', lokasjon: 'St1 - Varden' })],
        registre: [reg([ansatt('9', 100, hjem)])],
      })
      expect(ut).toHaveLength(1)
      expect(ut[0].lokasjon, `hjemstasjon ${hjem || '(tom)'}`).toBe('St1 - Varden')
    }
  })

  it('deler på lokasjon, ikke på fil', () => {
    const ut = kjor({
      stemplinger: [
        st({ dato: '2026-07-01', fraTid: '10:00', tilTid: '16:00', lokasjon: BONES }),
        st({ dato: '2026-07-01', fraTid: '10:00', tilTid: '16:00', lokasjon: LONE }),
      ],
      registre: [reg([ansatt('308', 200, BONES)])],
    })
    expect(ut.map((x) => x.lokasjon).sort()).toEqual([BONES, LONE])
  })
})

describe('beregnArbeidssted — måneden', () => {
  it('nekter et lønnsgrunnlag fra feil måned', () => {
    // DEN FEILEN ER GJORT ÉN GANG ALLEREDE, i måletestens eget oppslag.
    // Aprilsatsen priset juli, og resultatet ble BEDRE enn det var.
    expect(() => beregnArbeidssted({
      maaned: '2026-07',
      avvik: [],
      stemplinger: [st({ dato: '2026-07-01', fraTid: '10:00', tilTid: '16:00' })],
      registre: [{ fraDato: '2026-04-01', tilDato: '2026-04-30', ansatte: [ansatt('308', 143.34, BONES)] }],
    })).toThrow(/kan ikke prise 2026-07/)
  })

  it('godtar et flermånedsregister som omslutter måneden', () => {
    const [b] = beregnArbeidssted({
      maaned: '2026-07',
      avvik: [],
      stemplinger: [st({ dato: '2026-07-01', fraTid: '10:00', tilTid: '16:00' })],
      registre: [{ fraDato: '2026-01-01', tilDato: '2026-07-31', ansatte: [ansatt('308', 200, BONES)] }],
    })
    expect(b.konto503Kr).toBe(1200)
  })

  it('ser bort fra stemplinger utenfor måneden', () => {
    const [b] = kjor({
      stemplinger: [
        st({ dato: '2026-07-01', fraTid: '10:00', tilTid: '16:00' }),
        st({ dato: '2026-06-01', fraTid: '10:00', tilTid: '16:00' }),
      ],
      registre: [reg([ansatt('308', 200, BONES)])],
    })
    expect(b.timer).toBe(6)
  })

  it('krever minst ett lønnsgrunnlag', () => {
    expect(() => beregnArbeidssted({
      maaned: '2026-07', avvik: [], registre: [],
      stemplinger: [st({ dato: '2026-07-01', fraTid: '10:00', tilTid: '16:00' })],
    })).toThrow(/Ingen lønnsgrunnlag/)
  })
})

describe('beregnArbeidssted — dubletter', () => {
  it('teller samme vakt én gang om fila lastes to ganger', () => {
    // Å DOBLE LØNNSKOSTEN ER VERRE ENN Å MISTE DEN: et for høyt tall ser
    // ut som en dyr måned, ikke som en feil.
    const v = st({ dato: '2026-07-01', fraTid: '10:00', tilTid: '16:00' })
    const [b] = kjor({
      stemplinger: [v, { ...v }],
      registre: [reg([ansatt('308', 200, BONES)])],
    })
    expect(b.timer).toBe(6)
    expect(b.konto503Kr).toBe(1200)
    expect(b.dubletter).toBe(1)
  })

  it('teller to ekte vakter samme dag som to', () => {
    // KANARIFUGL mot et dublettvern som tar for mye. Nøkkelen er
    // stasjon + ansatt + STARTDATO + starttid.
    const [b] = kjor({
      stemplinger: [
        st({ dato: '2026-07-01', fraTid: '08:00', tilTid: '12:00' }),
        st({ dato: '2026-07-01', fraTid: '16:00', tilTid: '20:00' }),
      ],
      registre: [reg([ansatt('308', 200, BONES)])],
    })
    expect(b.timer).toBe(8)
    expect(b.dubletter).toBe(0)
  })

  it('slår ALDRI sammen to døgnhaler med samme forretningsdato', () => {
    // MÅLT i Dales fil, 31. juli 2026: samme ansatt har to rader som
    // begge starter 00:00. Den ene er halen av vakten fra 30. juli, den
    // andre halen av vakten fra 31. juli — «1 august 2026 00:00» i
    // «Fra». To forskjellige arbeidsøkter.
    //
    // Første dublettnøkkel brukte forretningsdatoen og spiste den ene.
    // 0,93 timer forsvant, og avviket for Dale juli så BEDRE ut. Et
    // dublettvern som sletter ekte data er verre enn ingen.
    const [b] = kjor({
      stemplinger: [
        st({ dato: '2026-07-31', fraDato: '2026-07-31', fraTid: '00:00', tilTid: '00:12' }),
        st({ dato: '2026-07-31', fraDato: '2026-08-01', fraTid: '00:00', tilTid: '00:55' }),
      ],
      registre: [reg([ansatt('308', 200, BONES)])],
    })
    expect(b.dubletter).toBe(0)
    expect(b.timer).toBeCloseTo(0.2 + 0.92, 2)
  })

  it('holder samme ansatt på to stasjoner fra hverandre', () => {
    const ut = kjor({
      stemplinger: [
        st({ dato: '2026-07-01', fraTid: '08:00', tilTid: '12:00', lokasjon: BONES }),
        st({ dato: '2026-07-01', fraTid: '08:00', tilTid: '12:00', lokasjon: LONE }),
      ],
      registre: [reg([ansatt('308', 200, BONES)])],
    })
    expect(ut).toHaveLength(2)
    expect(ut.every((x) => x.dubletter === 0)).toBe(true)
  })
})

describe('beregnArbeidssted — datagrunnlag', () => {
  it('melder minimum når en timelønnet ikke kan kobles', () => {
    const [b] = kjor({
      stemplinger: [
        st({ ansattNr: '308', dato: '2026-07-01', fraTid: '10:00', tilTid: '16:00' }),
        st({ ansattNr: '9999', ansattNavn: 'C D', dato: '2026-07-02', fraTid: '08:00', tilTid: '16:00' }),
      ],
      registre: [reg([ansatt('308', 200, BONES)])],
    })
    expect(b.datagrunnlag).toBe('minimum')
    expect(b.ukoblede).toEqual([{ ansattNr: '9999', ansattNavn: 'C D', timer: 8 }])
    expect(b.konto503Kr).toBe(1200)
  })

  it('melder minimum når broa er tvetydig', () => {
    // Både 1013 og 11013 finnes. Da er broa gal — velger vi det ene, kan
    // timene bli priset med en annen persons sats.
    const [b] = kjor({
      stemplinger: [st({ ansattNr: '1013', ansattNavn: 'E F', dato: '2026-07-01', fraTid: '08:00', tilTid: '16:00' })],
      registre: [reg([ansatt('1013', 100, BONES), ansatt('11013', 300, BONES)])],
    })
    expect(b.datagrunnlag).toBe('minimum')
    expect(b.tvetydige).toEqual([{ ansattNr: '1013', ansattNavn: 'E F', timer: 8 }])
    expect(b.konto503Kr).toBe(0)
  })

  it('melder minimum når en vakt ble avvist av parseren', () => {
    const [b] = kjor({
      stemplinger: [st({ dato: '2026-07-01', fraTid: '10:00', tilTid: '16:00' })],
      registre: [reg([ansatt('308', 200, BONES)])],
      avvik: [{
        grunn: 'lengde', ansattNr: '1009', ansattNavn: 'G H', dato: '2026-07-05',
        fraTid: '09:10', tilTid: '11:00', lokasjon: BONES, lengde: 25.82, intervallTimer: 1.83,
      }],
    })
    expect(b.datagrunnlag).toBe('minimum')
    expect(b.uavklarteVakter).toHaveLength(1)
  })

  it('henger en avvist rad UTEN lokasjon på hver stasjon i måneden', () => {
    // EN TIME INGEN VET HVOR HØRER HJEMME MÅ IKKE KUNNE FORSVINNE.
    // Uten dette ville begge stasjonene vist «komplett» mens timene lå
    // uplassert i parserens avviksliste.
    const ut = kjor({
      stemplinger: [
        st({ dato: '2026-07-01', fraTid: '10:00', tilTid: '16:00', lokasjon: BONES }),
        st({ dato: '2026-07-01', fraTid: '10:00', tilTid: '16:00', lokasjon: LONE }),
      ],
      registre: [reg([ansatt('308', 200, BONES)])],
      avvik: [{
        grunn: 'lokasjon', ansattNr: '1009', ansattNavn: 'G H', dato: '2026-07-05',
        fraTid: '09:00', tilTid: '17:00', lokasjon: '', lengde: 8, intervallTimer: 8,
      }],
    })
    expect(ut).toHaveLength(2)
    expect(ut.every((x) => x.datagrunnlag === 'minimum')).toBe(true)
    expect(ut.every((x) => x.uavklarteVakter.length === 1)).toBe(true)
  })

  it('samler en ukoblet person én gang, ikke én per vakt', () => {
    const [b] = kjor({
      stemplinger: [
        st({ ansattNr: '9999', dato: '2026-07-01', fraTid: '08:00', tilTid: '16:00' }),
        st({ ansattNr: '9999', dato: '2026-07-02', fraTid: '08:00', tilTid: '16:00' }),
      ],
      registre: [reg([ansatt('308', 200, BONES)])],
    })
    expect(b.ukoblede).toHaveLength(1)
    expect(b.ukoblede[0].timer).toBe(16)
  })

  it('er komplett når alle er koblet', () => {
    const [b] = kjor({
      stemplinger: [st({ dato: '2026-07-01', fraTid: '10:00', tilTid: '16:00' })],
      registre: [reg([ansatt('308', 200, BONES)])],
    })
    expect(b.datagrunnlag).toBe('komplett')
    expect(b.ukoblede).toEqual([])
    expect(b.tvetydige).toEqual([])
    expect(b.uavklarteVakter).toEqual([])
  })

  it('bærer med seg hva som ikke er med', () => {
    const [b] = kjor({
      stemplinger: [st({ dato: '2026-07-01', fraTid: '10:00', tilTid: '16:00' })],
      registre: [reg([ansatt('308', 200, BONES)])],
    })
    expect(b.ikkeMed.join(' ')).toMatch(/overtid/i)
    expect(b.ikkeMed.join(' ')).toMatch(/fastlønn/i)
  })
})

describe('beregnArbeidssted — fastlønn', () => {
  it('priser ikke en fastlønnet, men teller timene', () => {
    const [b] = kjor({
      stemplinger: [st({ ansattNr: '1004', dato: '2026-07-01', fraTid: '08:00', tilTid: '16:00' })],
      registre: [reg([ansatt('308', 200, BONES)])],
      fastlonnede: new Set(['1004']),
    })
    expect(b.konto503Kr).toBe(0)
    expect(b.fastlonnTimer).toBe(8)
    expect(b.datagrunnlag).toBe('komplett')
    expect(b.ukoblede).toEqual([])
  })

  it('utleder ALDRI fastlønn av manglende sats', () => {
    // KANARIFUGL. I august hadde sju ansatte ingen sats; fem av dem var
    // timelønnede med feil nummer. Hadde «ingen sats = fastlønn» vært
    // regelen, ville 160 timer blitt gratis i stillhet.
    const [b] = kjor({
      stemplinger: [st({ ansattNr: '1013', dato: '2026-07-01', fraTid: '08:00', tilTid: '16:00' })],
      registre: [reg([ansatt('308', 200, BONES)])],
    })
    expect(b.fastlonnTimer).toBe(0)
    expect(b.datagrunnlag).toBe('minimum')
    expect(b.ukoblede).toHaveLength(1)
  })
})

describe('beregnArbeidssted — timene', () => {
  it('priser ikke pause og ubetalt tid', () => {
    const [b] = kjor({
      stemplinger: [
        st({ dato: '2026-07-01', fraTid: '10:00', tilTid: '16:00' }),
        st({ dato: '2026-07-01', fraTid: '12:00', tilTid: '12:30', betalt: false }),
      ],
      registre: [reg([ansatt('308', 200, BONES)])],
    })
    expect(b.timer).toBe(6)
  })

  it('legger vakten i forretningsdatoens måned, men regner tillegg av startdatoen', () => {
    // MÅLT: forretningsdato 31. juli, arbeidet 1. august 00:00-00:55.
    // Måneden må være juli — det er slik kronefila grupperer. Tillegget
    // må være lørdagsnatt, for 1. august 2026 er en lørdag.
    const [b] = kjor({
      stemplinger: [st({
        dato: '2026-07-31', fraDato: '2026-08-01', fraTid: '00:00', tilTid: '00:55',
      })],
      registre: [reg([ansatt('308', 200, BONES)])],
    })
    expect(b.maaned).toBe('2026-07')
    expect(b.perArt['1431']?.timer).toBeCloseTo(0.92, 2)
  })
})
