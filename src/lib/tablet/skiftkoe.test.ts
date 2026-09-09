import { describe, expect, it } from 'vitest'
import { osloNaa } from '../rutineskjema'
import { skiftkoe, vaktenNaa, type Rutine, type Skift } from './skiftkoe'

// =====================================================================
// Tallene her er Bønes sine, fra 2026-09-09.
//
// Morgen 04:00–15:00 har 36 rutiner, kveld 15:00–24:00 har 19. Klokka
// 15:20 er BEGGE aktive — overlappen på ±60 minutter — og flata summerte
// dem til 55 i én haug.
// =====================================================================

const MORGEN: Skift = { id: 'm', tid_start: '04:00', tid_slutt: '15:00', ukedager: [] }
const KVELD: Skift = { id: 'k', tid_start: '15:00', tid_slutt: '24:00', ukedager: [] }
const NATT: Skift = { id: 'n', tid_start: '22:00', tid_slutt: '06:00', ukedager: [] }

const rutiner = (skjema: string, n: number, fra = '2020-01-01'): Rutine[] =>
  Array.from({ length: n }, (_, i) => ({
    id: `${skjema}${i}`, skjema_id: skjema, ukedager: [], opprettet_dato: fra,
  }))

/** Onsdag 2026-09-09, gitt klokkeslett i Oslo. */
const kl = (t: string) => osloNaa(new Date(`2026-09-09T${t}:00+02:00`))

describe('vaktenNaa', () => {
  it('midt i morgenvakta er bare morgen valgt', () => {
    const v = vaktenNaa([MORGEN, KVELD], kl('07:31'))
    expect(v.map((x) => x.skjema.id)).toEqual(['m'])
  })

  it('KJERNEN VINNER OVER NAADEN i overlappen', () => {
    // 15:20: morgen er i naaden (sluttet 15:00, +60 min), kveld er i
    // kjernen. Begge er «aktive» - men bare den ene staar man i.
    const v = vaktenNaa([MORGEN, KVELD], kl('15:20'))
    expect(v.map((x) => x.skjema.id), 'morgen skal ikke telles med').toEqual(['k'])
  })

  it('er ingen i kjernen, telles de aktive', () => {
    // 03:30: morgen starter 04:00, altsaa naaden foer. Ingen kjerne.
    // Da er naaden alt vi har, og den skal ikke gi et tomt svar.
    const v = vaktenNaa([MORGEN], kl('03:30'))
    expect(v.map((x) => x.skjema.id)).toEqual(['m'])
    expect(v[0].vindu.kjerne).toBe(false)
  })

  it('en vakt over midnatt hoerer til dagen den startet', () => {
    const v = vaktenNaa([NATT], kl('01:00'))
    expect(v).toHaveLength(1)
    expect(v[0].vindu.vaktdato, 'natta klokka 01 er gaarsdagens vakt')
      .toBe('2026-09-08')
  })
})

describe('skiftkoe', () => {
  it('teller vakta, ikke doegnet', () => {
    // Boenes klokka 07:31: 36 paa morgen, 19 paa kveld. Koen skal si 36,
    // ikke 55 - og slett ikke 123, som var maanedens etterslep.
    const vakter = vaktenNaa([MORGEN, KVELD], kl('07:31'))
    const alle = [...rutiner('m', 36), ...rutiner('k', 19)]
    const k = skiftkoe(vakter, alle, new Map())
    expect(k.totalt).toBe(36)
    expect(k.igjen).toBe(36)
  })

  it('trekker fra det som er haket av paa vaktdatoen', () => {
    const vakter = vaktenNaa([MORGEN], kl('07:31'))
    const alle = rutiner('m', 36)
    const gjort = new Map([['2026-09-09', new Set(['m0', 'm1', 'm2'])]])
    expect(skiftkoe(vakter, alle, gjort).igjen).toBe(33)
  })

  it('avhukinger paa en ANNEN dato teller ikke', () => {
    // I gaar er ikke i dag. En koe som trakk fra gaarsdagens haker ville
    // sagt «ferdig» paa en vakt ingen hadde begynt paa.
    const vakter = vaktenNaa([MORGEN], kl('07:31'))
    const gjort = new Map([['2026-09-08', new Set(['m0', 'm1'])]])
    expect(skiftkoe(vakter, rutiner('m', 36), gjort).igjen).toBe(36)
  })

  it('nattevakta trekker fra gaarsdagens dato', () => {
    const vakter = vaktenNaa([NATT], kl('01:00'))
    const gjort = new Map([['2026-09-08', new Set(['n0'])]])
    const k = skiftkoe(vakter, rutiner('n', 5), gjort)
    expect(k.igjen).toBe(4)
    expect(k.vaktdatoer).toEqual(['2026-09-08'])
  })

  it('en rutine opprettet etter vakta teller ikke', () => {
    const vakter = vaktenNaa([MORGEN], kl('07:31'))
    const ny = rutiner('m', 1, '2026-09-10')
    expect(skiftkoe(vakter, ny, new Map()).totalt).toBe(0)
  })

  it('rutinens egne ukedager gjelder', () => {
    // 2026-09-09 er en onsdag (ukedag 3).
    const vakter = vaktenNaa([MORGEN], kl('07:31'))
    const bareMandag: Rutine[] = [{
      id: 'x', skjema_id: 'm', ukedager: [1], opprettet_dato: '2020-01-01',
    }]
    expect(skiftkoe(vakter, bareMandag, new Map()).totalt).toBe(0)
  })

  it('ET TOMT SKJEMA ER IKKE EN VAKT', () => {
    // Boenes hadde et «morgen»-skjema 06:00-14:00 med null rutiner ved
    // siden av det ekte. Det skal ikke gi en vaktdato heller.
    const tomt: Skift = { id: 'spoekelse', tid_start: '06:00', tid_slutt: '14:00', ukedager: [] }
    const vakter = vaktenNaa([tomt], kl('07:31'))
    expect(vakter, 'skjemaet ER aktivt - det er rutinene som mangler')
      .toHaveLength(1)
    const k = skiftkoe(vakter, [], new Map())
    expect(k.totalt).toBe(0)
    expect(k.vaktdatoer).toEqual([])
  })

  it('KANARIFUGL: doegnet og vakta er ULIKE tall her', () => {
    // Slutter de aa vaere det - fordi oppsettet endres, eller fordi
    // `vaktenNaa` slutter aa velge - maaler testene over ingenting.
    const alle = [...rutiner('m', 36), ...rutiner('k', 19)]
    const vakt = skiftkoe(vaktenNaa([MORGEN, KVELD], kl('07:31')), alle, new Map())
    expect(vakt.totalt).toBe(36)
    expect(alle.length, 'doegnet').toBe(55)
    expect(vakt.totalt).not.toBe(alle.length)
  })
})
