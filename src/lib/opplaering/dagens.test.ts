import { describe, it, expect } from 'vitest'
import {
  klokkeslett, tidsrom, dagensOpplaering, fremdrift,
  type Skiftrad, type Perioderad,
} from './dagens'

// =====================================================================
// Kontrakten: skift-kalenderen er utloeseren.
//
// Nettbrettet spoer ikke «finnes det opplaering?» - det spoer «finnes
// det et skift i dag, paa min stasjon, i en periode som ikke er
// fullfoert?». Tre ledd, og alle tre maa stemme.
// =====================================================================

const skift = (o: Partial<Skiftrad>): Skiftrad => ({
  id: 'sk-1', periode_id: 'p-1', dato: '2026-08-29',
  start_tid: null, slutt_tid: null, ...o,
})

const periode = (o: Partial<Perioderad>): Perioderad => ({
  id: 'p-1', stasjon_id: 'st-1', ansatt_navn: 'Kari Nyansatt',
  start_dato: '2026-08-25', fullfort_tid: null, ...o,
})

describe('klokkeslett', () => {
  it('klipper bort sekundene Postgres sender', () => {
    expect(klokkeslett('16:00:00')).toBe('16:00')
    expect(klokkeslett('23:30:00')).toBe('23:30')
  })

  it('ingen tid er ingen tid', () => {
    expect(klokkeslett(null)).toBeNull()
    expect(klokkeslett('')).toBeNull()
  })
})

describe('tidsrom', () => {
  it('setter sammen begge endene', () => {
    expect(tidsrom('16:00:00', '23:00:00')).toBe('16:00–23:00')
  })

  it('uten tider gjelder skiftet hele dagen', () => {
    expect(tidsrom(null, null)).toBeNull()
  })

  // BEGGE ELLER INGEN. Databasen har samme skranke, saa dette skal ikke
  // kunne skje - men «16:00–» ser ut som en feil i dataene og ikke som
  // «hele dagen», og det er en daarligere loegn enn ingenting.
  it('et halvt tidsrom er ikke et tidsrom', () => {
    expect(tidsrom('16:00:00', null)).toBeNull()
    expect(tidsrom(null, '23:00:00')).toBeNull()
  })
})

describe('dagensOpplaering', () => {
  const idag = '2026-08-29'

  it('finner skiftet som staar paa dagens dato', () => {
    const ut = dagensOpplaering([skift({})], [periode({})], 'st-1', idag)
    expect(ut).toHaveLength(1)
    expect(ut[0].ansattNavn).toBe('Kari Nyansatt')
    expect(ut[0].periodeId).toBe('p-1')
  })

  it('viser tidsrommet naar det er satt', () => {
    const ut = dagensOpplaering(
      [skift({ start_tid: '16:00:00', slutt_tid: '23:00:00' })],
      [periode({})], 'st-1', idag)
    expect(ut[0].tidsrom).toBe('16:00–23:00')
  })

  it('uten tider staar tidsrommet tomt - skiftet gjelder hele dagen', () => {
    expect(dagensOpplaering([skift({})], [periode({})], 'st-1', idag)[0].tidsrom)
      .toBeNull()
  })

  it('i gaar og i morgen er ikke i dag', () => {
    const ut = dagensOpplaering([
      skift({ id: 'a', dato: '2026-08-28' }),
      skift({ id: 'b', dato: '2026-08-30' }),
    ], [periode({})], 'st-1', idag)
    expect(ut).toEqual([])
  })

  // AV-BRYTEREN. Markerer butikksjefen perioden som fullfoert,
  // forsvinner sjekklista med én gang - ogsaa om det ligger flere skift
  // igjen i kalenderen. En opplaering som er erklaert ferdig skal ikke
  // fortsette aa be om haker.
  it('en fullfoert periode forsvinner, selv med skift igjen', () => {
    const ut = dagensOpplaering(
      [skift({})],
      [periode({ fullfort_tid: '2026-08-28T10:00:00Z' })],
      'st-1', idag)
    expect(ut).toEqual([])
  })

  it('nabostasjonens opplaering hoerer ikke hjemme her', () => {
    const ut = dagensOpplaering(
      [skift({})], [periode({ stasjon_id: 'st-2' })], 'st-1', idag)
    expect(ut).toEqual([])
  })

  it('et skift uten periode faller bort i stedet for aa krasje', () => {
    expect(dagensOpplaering([skift({ periode_id: 'borte' })], [periode({})], 'st-1', idag))
      .toEqual([])
  })

  it('to opplaeringer samme dag staar i fast rekkefoelge', () => {
    const ut = dagensOpplaering([
      skift({ id: 'a', periode_id: 'p-1' }),
      skift({ id: 'b', periode_id: 'p-2' }),
    ], [
      periode({ id: 'p-1', ansatt_navn: 'Ola' }),
      periode({ id: 'p-2', ansatt_navn: 'Anne' }),
    ], 'st-1', idag)
    expect(ut.map((x) => x.ansattNavn)).toEqual(['Anne', 'Ola'])
  })

  // KANARIFUGL. Alle paastandene over er «forsvinner»-paastander, og de
  // ville vaert groenne ogsaa om funksjonen alltid returnerte tomt. En
  // vakt som ikke ser noe, ser noeyaktig ut som en som ikke finner noe.
  it('KANARIFUGL: den finner faktisk noe naar alt stemmer', () => {
    const ut = dagensOpplaering([skift({})], [periode({})], 'st-1', idag)
    expect(ut.length).toBeGreaterThan(0)
  })
})

// =====================================================================
// FREMDRIFT OVER 100 % ER IKKE EN FREMDRIFT
// =====================================================================

describe('fremdrift', () => {
  const aktive = new Set(['o-1', 'o-2', 'o-3', 'o-4'])

  it('teller haker mot aktive oppgaver', () => {
    const f = fremdrift(['o-1', 'o-2'], aktive)
    expect(f.gjort).toBe(2)
    expect(f.totalt).toBe(4)
    expect(f.andel).toBe(0.5)
  })

  // Deaktiverer admin en oppgave noen alt har huket av, ville en teller
  // over ALLE rader gitt 3 av 2. Telleren og nevneren maa se paa det
  // samme utvalget - ellers aapner ogsaa «ferdig»-knappen for tidlig.
  it('en hake paa en deaktivert oppgave teller ikke', () => {
    const f = fremdrift(['o-1', 'o-2', 'utgaatt'], aktive)
    expect(f.gjort).toBe(2)
    expect(f.andel).toBeLessThanOrEqual(1)
  })

  it('ingen oppgaver gir ingen andel, ikke 0 %', () => {
    expect(fremdrift([], new Set()).andel).toBeNull()
  })

  it('alt gjort er 100 %', () => {
    expect(fremdrift(['o-1', 'o-2', 'o-3', 'o-4'], aktive).andel).toBe(1)
  })

  it('ingenting gjort mot ekte oppgaver ER 0 - det er et svar', () => {
    expect(fremdrift([], aktive).andel).toBe(0)
  })
})
