import { describe, expect, test } from 'vitest'
import {
  avdelingsSignaler, ferskhet, klyngebilde, poengFor, rangerSignaler,
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

// =====================================================================
// HVA SORTERINGEN FAKTISK LOVER.
//
// Forsiden sto med merkelappen «Viktigst overst» over lista. Det er en
// paastand om nivaarekkefolge, og motoren gir den ikke. Regnestykket er
// hele forklaringen:
//
//   grunnpoeng   kritisk 1000   folg 300   info 50
//   kroner       + inntil 400   (kvadratrot-dempet)
//   dager        + inntil 200
//
//   kritisk  [1000 .. 1600]
//   folg     [ 300 ..  900]
//   info     [  50 ..  650]
//
// Kritisk kan derfor ALDRI tapes av noe under - 1000 er over begge tak.
// Men info og folg OVERLAPPER: et info-funn med stort utslag og lang
// varighet naar 650, og et nakent folg-funn ligger paa 300.
//
// Det er ikke en feil. Det er hele poenget med aa la konsekvens og
// varighet telle: en orientering som har kostet 90 000 kroner i fire
// dager ER viktigere enn en «folg med» det ikke staar noe bak. Feilen
// laa i merkelappen, som lovte noe annet enn motoren gjor.
//
// I dag baerer ingen info-kilde hverken kroner eller dager, saa
// omslaget skjer ikke med de dataene som finnes. Testene under maaler
// KONTRAKTEN, ikke dagens data - nettopp fordi det er kontrakten
// merkelappen paastod noe om.
// =====================================================================
describe('hva rekkefolgen lover', () => {
  const MAKS = { kroner: 400, dager: 200 }
  const ekstremt = { konsekvensKr: -100_000_000, dager: 9999 }

  test('kritisk kan ikke tapes av noe under', () => {
    const kritiskLavest = poengFor(s({ niva: 'kritisk' }))
    const folgHoyest = poengFor(s({ niva: 'folg', ...ekstremt }))
    const infoHoyest = poengFor(s({ niva: 'info', ...ekstremt }))
    expect(folgHoyest).toBeLessThan(kritiskLavest)
    expect(infoHoyest).toBeLessThan(kritiskLavest)

    // Og maalt gjennom sorteringen, ikke bare gjennom poengene.
    const r = rangerSignaler([
      s({ id: 'folg', niva: 'folg', ...ekstremt }),
      s({ id: 'info', niva: 'info', ...ekstremt }),
      s({ id: 'kritisk', niva: 'kritisk' }),
    ])
    expect(r[0].id).toBe('kritisk')
  })

  test('men info KAN gaa foran folg - og det er med vilje', () => {
    const r = rangerSignaler([
      s({ id: 'nakent-folg', niva: 'folg' }),
      s({ id: 'tungt-info', niva: 'info', konsekvensKr: -90000, dager: 4 }),
    ])
    // Endrer noen dette til at nivaaet alltid vinner, skal DENNE testen
    // feile - og da skal merkelappen paa forsiden endres tilbake i
    // samme slengen. De to henger sammen.
    expect(r[0].id).toBe('tungt-info')
  })

  // KANARIFUGL. Grensene over er regnet ut fra takene i `poengFor`.
  // Endres et tak uten at nivaaene endres, kan overlappet forsvinne
  // eller vokse - og da er kommentaren over og merkelappen paa forsiden
  // ikke lenger sanne. Dette er tallene de hviler paa.
  test('takene er de som er regnet med', () => {
    const nakent = poengFor(s({ niva: 'folg' }))
    expect(poengFor(s({ niva: 'folg', konsekvensKr: -100_000_000 })) - nakent).toBe(MAKS.kroner)
    expect(poengFor(s({ niva: 'folg', dager: 9999 })) - nakent).toBe(MAKS.dager)
    expect(poengFor(s({ niva: 'kritisk' }))).toBe(1000)
    expect(poengFor(s({ niva: 'folg' }))).toBe(300)
    expect(poengFor(s({ niva: 'info' }))).toBe(50)
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

describe('ferskhet', () => {
  test('en dag gammelt er normalt, ikke et avvik', () => {
    // Salgsdata kommer alltid dagen etter.
    expect(ferskhet('2026-08-13', '2026-08-14').nivaa).toBe('fersk')
    expect(ferskhet('2026-08-13', '2026-08-14').tekst).toBe('')
  })

  test('to og tre dager er sent', () => {
    expect(ferskhet('2026-08-12', '2026-08-14').nivaa).toBe('sen')
    expect(ferskhet('2026-08-11', '2026-08-14').nivaa).toBe('sen')
  })

  test('over tre dager sier at importen har stoppet', () => {
    const f = ferskhet('2026-08-09', '2026-08-14')
    expect(f.nivaa).toBe('gammel')
    expect(f.dager).toBe(5)
    expect(f.tekst).toContain('stoppet')
  })
})
