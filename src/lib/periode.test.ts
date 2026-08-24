import { describe, it, expect } from 'vitest'
import {
  erMaaned, maanedNokkel, delMaaned, lesMaaned, maanedenTil,
  flyttMaaned, maanederRundt, maanederI,
} from './periode'

// =====================================================================
// Kontrakten: ett navn, én betydning.
//
// Foer denne fila betydde `?maned=` to ulike ting. `Number('2026-03-01')`
// er NaN, saa en lenke fra /svinn limt inn paa /lonn falt stille tilbake
// til standardmaaneden og viste trygt fram feil tall. Den stillheten er
// det viktigste denne fila fjerner.
// =====================================================================

describe('erMaaned', () => {
  it('godtar bare foerste i maaneden', () => {
    expect(erMaaned('2026-03-01')).toBe(true)
    expect(erMaaned('2026-03-17')).toBe(false)
    expect(erMaaned('2026-03')).toBe(false)
    expect(erMaaned('3')).toBe(false)
    expect(erMaaned(3)).toBe(false)
    expect(erMaaned(null)).toBe(false)
  })
})

describe('maanedNokkel og delMaaned', () => {
  it('gaar begge veier', () => {
    expect(maanedNokkel(2026, 3)).toBe('2026-03-01')
    expect(maanedNokkel(2026, 12)).toBe('2026-12-01')
    expect(delMaaned('2026-03-01')).toEqual({ ar: 2026, maned: 3 })
  })

  it('maaneden er 1-12, slik mennesker teller', () => {
    // Ikke 0-11 som i Date. Blandes de to, blir januar til desember
    // aaret foer - og det ser ut som et tall, ikke som en feil.
    expect(delMaaned(maanedNokkel(2026, 1))).toEqual({ ar: 2026, maned: 1 })
  })

  it('kaster paa noe som ikke er en maaned', () => {
    expect(() => delMaaned('2026-03-17')).toThrow()
  })
})

describe('lesMaaned', () => {
  const standard = '2026-08-01'

  it('leser ISO', () => {
    expect(lesMaaned({ maned: '2026-03-01' }, standard)).toBe('2026-03-01')
  })

  it('moeter «2026-03» halvveis', () => {
    expect(lesMaaned({ maned: '2026-03' }, standard)).toBe('2026-03-01')
  })

  // DEN GAMLE FORMEN HAR LIGGET I BOKMERKER. AA bare slutte aa forstaa
  // den ville gjort at en gammel lenke stille viste en annen maaned enn
  // den lovet - nettopp feilen denne fila finnes for aa fjerne.
  it('forstaar fortsatt ?maned=3&ar=2026', () => {
    expect(lesMaaned({ maned: '3', ar: '2026' }, standard)).toBe('2026-03-01')
    expect(lesMaaned({ maned: '12', ar: '2025' }, standard)).toBe('2025-12-01')
  })

  it('ISO vinner naar begge staar der', () => {
    expect(lesMaaned({ maned: '2026-03-01', ar: '2019' }, standard)).toBe('2026-03-01')
  })

  it('et maanedstall uten aar er ikke nok', () => {
    expect(lesMaaned({ maned: '3' }, standard)).toBe(standard)
  })

  it('avviser maanedstall utenfor 1-12', () => {
    expect(lesMaaned({ maned: '0', ar: '2026' }, standard)).toBe(standard)
    expect(lesMaaned({ maned: '13', ar: '2026' }, standard)).toBe(standard)
  })

  it('faller tilbake paa soppel', () => {
    expect(lesMaaned({}, standard)).toBe(standard)
    expect(lesMaaned({ maned: '' }, standard)).toBe(standard)
    expect(lesMaaned({ maned: 'mars' }, standard)).toBe(standard)
    // `\d{2}` i regexen godtok denne. En maaned som ikke finnes gikk
    // rett gjennom og ble baaret videre som om den var gyldig.
    expect(lesMaaned({ maned: '2026-13-01' }, standard)).toBe(standard)
    expect(lesMaaned({ maned: '2026-00-01' }, standard)).toBe(standard)
    expect(erMaaned('2026-13-01')).toBe(false)
  })

  // KANARIFUGL. Dette er selve feilen som fantes: en ISO-maaned sendt
  // til en side som leste `Number(maned)` ga NaN, falt tilbake, og viste
  // en annen maaned enn lenka lovet - uten et ord om det.
  it('en ISO-maaned faller ALDRI tilbake til standarden', () => {
    for (const m of ['2025-01-01', '2026-06-01', '2026-12-01']) {
      expect(lesMaaned({ maned: m }, standard)).toBe(m)
      expect(lesMaaned({ maned: m }, standard)).not.toBe(standard)
    }
  })
})

describe('maanedenTil', () => {
  it('finner maaneden en dato ligger i', () => {
    expect(maanedenTil('2026-03-17')).toBe('2026-03-01')
    expect(maanedenTil('2026-03-01')).toBe('2026-03-01')
    expect(maanedenTil(new Date(Date.UTC(2026, 2, 31)))).toBe('2026-03-01')
  })
})

describe('flyttMaaned', () => {
  it('flytter over aarsskiftet begge veier', () => {
    expect(flyttMaaned('2026-01-01', -1)).toBe('2025-12-01')
    expect(flyttMaaned('2025-12-01', 1)).toBe('2026-01-01')
    expect(flyttMaaned('2026-03-01', 12)).toBe('2027-03-01')
    expect(flyttMaaned('2026-03-01', -14)).toBe('2025-01-01')
  })

  it('null flytter ingenting', () => {
    expect(flyttMaaned('2026-03-01', 0)).toBe('2026-03-01')
  })
})

describe('maanederRundt', () => {
  it('gir nyeste foerst, med baade fortid og framtid', () => {
    expect(maanederRundt('2026-03-01', 2, 1)).toEqual([
      '2026-04-01', '2026-03-01', '2026-02-01', '2026-01-01',
    ])
  })

  it('bare bakover er ogsaa gyldig', () => {
    expect(maanederRundt('2026-03-01', 2, 0)).toEqual([
      '2026-03-01', '2026-02-01', '2026-01-01',
    ])
  })

  // /bemanning planlegger NESTE maaned, og den har per definisjon ingen
  // rader ennaa. Uten framtid i lista kan sida ikke gjoere jobben sin.
  it('framtiden er med naar sida planlegger', () => {
    expect(maanederRundt('2026-03-01', 0, 2)[0]).toBe('2026-05-01')
  })
})

describe('maanederI', () => {
  it('gir distinkte maaneder fra data, nyeste foerst', () => {
    expect(maanederI([
      { maned: '2026-06-01' }, { maned: '2026-08-01' }, { maned: '2026-06-01' },
    ])).toEqual(['2026-08-01', '2026-06-01'])
  })

  it('siler bort noe som ikke er en maaned', () => {
    expect(maanederI([{ maned: '2026-06-17' }, { maned: '2026-06-01' }]))
      .toEqual(['2026-06-01'])
  })
})
