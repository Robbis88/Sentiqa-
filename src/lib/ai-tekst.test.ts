import { describe, it, expect } from 'vitest'
import { biter, blokker } from './ai-tekst'

// Ordrett fra skjermbildet 2026-08-24, der svaret sto som ett avsnitt
// med markdown i klartekst.
const EKTE = `⚠️ **Merk:** Regnskapet returnerer kun konsoliderte tall.

### Salg – siste tilgjengelige dag

- Varden: 72 236 kr, 1 450 kunder
- Bønes: 48 901 kr, 1 016 kunder

Varden omsetter **~48 %** mer enn Bønes.`

describe('biter — utheving', () => {
  it('deler ut **uthevet**', () => {
    expect(biter('Dale er **28 %** over budsjett')).toEqual([
      { type: 'tekst', verdi: 'Dale er ' },
      { type: 'uthevet', verdi: '28 %' },
      { type: 'tekst', verdi: ' over budsjett' },
    ])
  })

  it('takler utheving først og sist', () => {
    expect(biter('**Merk:** noe')[0]).toEqual({ type: 'uthevet', verdi: 'Merk:' })
    expect(biter('noe **her**').at(-1)).toEqual({ type: 'uthevet', verdi: 'her' })
  })

  it('lar ubalanserte stjerner stå som tegn', () => {
    expect(biter('2 ** 3 = 8')).toEqual([{ type: 'tekst', verdi: '2 ** 3 = 8' }])
  })

  it('lar tomt par stå', () => {
    expect(biter('a **** b').map((b) => b.verdi).join('')).toBe('a **** b')
  })

  it('mister aldri tegn', () => {
    for (const s of ['**a**b**c**', 'a**b', '****', 'ingen stjerner', '**']) {
      expect(biter(s).map((b) => b.verdi).join('').replace(/\*/g, ''))
        .toBe(s.replace(/\*/g, ''))
    }
  })
})

describe('blokker', () => {
  it('deler avsnitt på tom linje', () => {
    const b = blokker('Ett.\n\nTo.')
    expect(b).toHaveLength(2)
    expect(b[0]).toMatchObject({ type: 'avsnitt' })
  })

  it('samler etterfølgende punkter til én liste', () => {
    const b = blokker('- a\n- b\n- c')
    expect(b).toHaveLength(1)
    expect(b[0]).toMatchObject({ type: 'liste' })
    expect((b[0] as { punkter: unknown[] }).punkter).toHaveLength(3)
  })

  it('godtar -, * og • som punkt', () => {
    for (const tegn of ['-', '*', '•']) {
      expect(blokker(`${tegn} noe`)[0].type).toBe('liste')
    }
  })

  it('skiller liste fra avsnittet over og under', () => {
    expect(blokker('Innledning\n- a\n- b\nAvslutning').map((x) => x.type))
      .toEqual(['avsnitt', 'liste', 'avsnitt'])
  })

  it('gjør overskrift til en uthevet linje, ikke firkanter', () => {
    const b = blokker('### Salg')
    expect(b[0]).toEqual({ type: 'avsnitt', biter: [{ type: 'uthevet', verdi: 'Salg' }] })
  })

  it('slår sammen linjer i samme avsnitt', () => {
    const b = blokker('Én setning\nsom brekker.')
    expect(b).toHaveLength(1)
    expect((b[0] as { biter: { verdi: string }[] }).biter[0].verdi).toBe('Én setning som brekker.')
  })

  it('gir ingen blokker for tom tekst', () => {
    expect(blokker('')).toEqual([])
    expect(blokker('\n\n  \n')).toEqual([])
  })

  it('tegner det ekte svaret som avsnitt, overskrift og liste', () => {
    expect(blokker(EKTE).map((b) => b.type)).toEqual(['avsnitt', 'avsnitt', 'liste', 'avsnitt'])
  })

  // KANARIFUGL: parseren skal aldri miste innhold. Ryker en gren, er det
  // en setning som forsvinner ut av svaret — og et svar som mangler en
  // setning ser like riktig ut som ett som ikke gjør det.
  it('kanarifugl: all synlig tekst overlever', () => {
    const ord = blokker(EKTE)
      .flatMap((b) => (b.type === 'liste' ? b.punkter.flat() : b.biter))
      .map((x) => x.verdi)
      .join(' ')
    for (const s of ['Merk:', 'Varden', '72 236 kr', 'Bønes', '48 901 kr', '~48 %', 'Salg']) {
      expect(ord, `mistet «${s}»`).toContain(s)
    }
  })

  it('kanarifugl: ingen markdown-tegn står igjen som tekst', () => {
    const ord = blokker(EKTE)
      .flatMap((b) => (b.type === 'liste' ? b.punkter.flat() : b.biter))
      .map((x) => x.verdi)
      .join(' ')
    expect(ord).not.toContain('**')
    expect(ord).not.toContain('###')
  })
})
