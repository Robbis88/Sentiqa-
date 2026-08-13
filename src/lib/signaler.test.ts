import { describe, expect, test } from 'vitest'
import {
  avdelingsSignaler, klyngebilde, poengFor, rangerSignaler,
  type RaaSignal, type Stasjonsrapport,
} from './signaler'

const s = (o: Partial<RaaSignal>): RaaSignal => ({
  id: 'x', merke: 'Salg', tittel: 'T', detalj: 'd', niva: 'folg', lenke: '/', ...o,
})

describe('rangering', () => {
  test('alvor slaar kroner', () => {
    // En krenkelse uten kronebelop skal fortsatt ligge over et stort tap.
    const r = rangerSignaler([
      s({ id: 'tap', niva: 'folg', konsekvensKr: -250000, tittel: 'Stort tap' }),
      s({ id: 'krenk', niva: 'kritisk', tittel: 'Krenkelse' }),
    ])
    expect(r[0].id).toBe('krenk')
  })

  test('kroner demper seg — ti ganger belopet gir ikke ti ganger poeng', () => {
    const liten = poengFor(s({ niva: 'folg', konsekvensKr: -10000 }))
    const stor = poengFor(s({ niva: 'folg', konsekvensKr: -100000 }))
    expect(stor).toBeGreaterThan(liten)
    expect(stor).toBeLessThan(liten * 2)
  })

  test('varighet skiller to like store funn', () => {
    const r = rangerSignaler([
      s({ id: 'endag', konsekvensKr: -8000, dager: 1 }),
      s({ id: 'firedager', konsekvensKr: -8000, dager: 4 }),
    ])
    expect(r[0].id).toBe('firedager')
  })

  test('rangeringen er stabil naar poengene er like', () => {
    const a = rangerSignaler([s({ id: '1', tittel: 'B' }), s({ id: '2', tittel: 'A' })])
    const b = rangerSignaler([s({ id: '2', tittel: 'A' }), s({ id: '1', tittel: 'B' })])
    expect(a.map((x) => x.id)).toEqual(b.map((x) => x.id))
  })
})

describe('avdelingssignaler', () => {
  const butikk = { omsetning: 366188, omsetningIfjor: 115887 } // +216 %

  test('fanger kategorien som gaar motsatt vei av butikken', () => {
    const r = avdelingsSignaler({
      ...butikk,
      avdelinger: [{ kode: '190', navn: 'Fritidsartikler', omsetning: 5500, ifjor: 14840, vekstPst: -63 }],
    })
    expect(r).toHaveLength(1)
    expect(r[0].niva).toBe('folg')
    expect(r[0].detalj).toContain('motsatt vei')
  })

  test('kritisk naar den er baade stor i kroner og alene om retningen', () => {
    const r = avdelingsSignaler({
      ...butikk,
      avdelinger: [{ kode: '170', navn: 'Butikk', omsetning: 12000, ifjor: 24000, vekstPst: -50 }],
    })
    expect(r[0].niva).toBe('kritisk')
  })

  test('en kategori som folger butikken ned er ikke et signal', () => {
    // Butikken faller 30 %, kategorien faller 32 % — den folger med.
    const r = avdelingsSignaler({
      omsetning: 70000, omsetningIfjor: 100000,
      avdelinger: [{ kode: '120', navn: 'Mat', omsetning: 34000, ifjor: 50000, vekstPst: -32 }],
    })
    expect(r).toEqual([])
  })

  test('vekst varsles aldri', () => {
    const r = avdelingsSignaler({
      ...butikk,
      avdelinger: [{ kode: '120', navn: 'Mat', omsetning: 80000, ifjor: 20000, vekstPst: 300 }],
    })
    expect(r).toEqual([])
  })

  test('smaa belop slipper ikke gjennom uansett prosent', () => {
    // −95 % ser dramatisk ut, men det er 950 kr.
    const r = avdelingsSignaler({
      ...butikk,
      avdelinger: [{ kode: '250', navn: 'Pant', omsetning: 50, ifjor: 1000, vekstPst: -95 }],
    })
    expect(r).toEqual([])
  })

  test('smaa fjorarstall gir ikke signal — prosenten er ustabil', () => {
    const r = avdelingsSignaler({
      ...butikk,
      avdelinger: [{ kode: '211', navn: 'Selvvask', omsetning: 100, ifjor: 4000, vekstPst: -97 }],
    })
    expect(r).toEqual([])
  })
})

describe('klyngebilde — stasjonen eller markedet', () => {
  const st = (navn: string, omsetning: number, ifjor: number): Stasjonsrapport =>
    ({ stasjonId: navn, navn, omsetning, omsetningIfjor: ifjor })

  test('faller alle stasjonene, er det EN sak om markedet — ikke fem', () => {
    const k = klyngebilde([
      st('Bones', 90000, 100000), st('Dale', 180000, 200000),
      st('Lone', 72000, 80000), st('Varden', 108000, 120000),
    ])
    expect(k.signaler).toHaveLength(1)
    expect(k.signaler[0].merke).toBe('Marked')
    expect(k.signaler[0].detalj).toContain('felles for hele klyngen')
  })

  test('faller en mens de andre ligger flatt, er det stasjonen', () => {
    const k = klyngebilde([
      st('Bones', 100000, 100000), st('Dale', 140000, 200000),
      st('Lone', 80000, 80000), st('Varden', 120000, 120000),
    ])
    const stasjon = k.signaler.filter((s) => s.merke === 'Stasjon')
    expect(stasjon).toHaveLength(1)
    expect(stasjon[0].tittel).toBe('Dale')
    expect(k.signaler.some((s) => s.merke === 'Marked')).toBe(false)
  })

  test('residualen maaler avstanden til klyngens utvikling, ikke til i fjor', () => {
    // Klyngen vokser 10 %. Dale staar stille: 200 000 mot forventet 220 000.
    const k = klyngebilde([
      st('Bones', 110000, 100000), st('Dale', 200000, 200000),
      st('Lone', 88000, 80000), st('Varden', 132000, 120000),
    ])
    const dale = k.rader.find((r) => r.navn === 'Dale')!
    expect(Math.round(dale.residualKr)).toBe(-20000)
    expect(Math.round(dale.avvikPp)).toBe(-10)
  })

  test('en stasjon som vokser mindre enn klyngen, men fortsatt vokser, fanges', () => {
    // Alle vokser, men Dale henger 25 pp etter. Det er fortsatt en sak.
    const k = klyngebilde([
      st('Bones', 150000, 100000), st('Dale', 250000, 200000),
      st('Lone', 120000, 80000), st('Varden', 180000, 120000),
    ])
    const dale = k.signaler.find((s) => s.tittel === 'Dale')
    expect(dale).toBeDefined()
    expect(dale!.detalj).toContain('under der stasjonen')
  })

  test('radene sorteres verst forst', () => {
    const k = klyngebilde([
      st('Bones', 120000, 100000), st('Dale', 160000, 200000), st('Lone', 84000, 80000),
    ])
    expect(k.rader[0].navn).toBe('Dale')
    expect(k.rader[0].avvikPp).toBeLessThan(k.rader[1].avvikPp)
  })

  test('smaa avvik i kroner blir ikke sak selv om prosenten spriker', () => {
    const k = klyngebilde([
      st('Stor', 220000, 200000), st('Bitteliten', 900, 1000),
    ])
    expect(k.signaler.filter((s) => s.merke === 'Stasjon')).toEqual([])
  })

  test('taaler tom liste og stasjoner uten fjorarstall', () => {
    expect(klyngebilde([]).rader).toEqual([])
    const k = klyngebilde([st('Ny', 50000, 0)])
    expect(k.rader).toEqual([])
    expect(k.signaler).toEqual([])
  })
})

test('en enslig stasjon har ingen maalestokk og gir ingen stasjonssignal', () => {
  const k = klyngebilde([
    { stasjonId: 'a', navn: 'Alene', omsetning: 50000, omsetningIfjor: 100000 },
  ])
  expect(k.rader[0].avvikPp).toBe(0)
  expect(k.signaler.filter((s) => s.merke === 'Stasjon')).toEqual([])
})
