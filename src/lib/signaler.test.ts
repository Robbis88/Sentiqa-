import { describe, expect, test } from 'vitest'
import { avdelingsSignaler, poengFor, rangerSignaler, type RaaSignal } from './signaler'

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
