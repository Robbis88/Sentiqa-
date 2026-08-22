import { describe, expect, test } from 'vitest'
import {
  dagerMellom, fjorSlutt, kortDato, minusDager, sammenlikn, summer, ukedag, vinduer,
} from './vekst-ifjor'

const dag = (dato: string, verdi: number | null) => ({ dato, verdi })

describe('datoregning', () => {
  test('regner på strenger, ikke på lokal tid', () => {
    // `new Date('2026-08-17T00:00:00')` leses som LOKAL midnatt, og
    // `toISOString()` etterpå gir ett døgn feil øst for UTC. Kjører
    // produksjon på UTC, virker feilen der og feiler bare lokalt.
    expect(minusDager('2026-08-17', 364)).toBe('2025-08-18')
    expect(minusDager('2026-01-01', 1)).toBe('2025-12-31')
    // Over en skuddårsgrense.
    expect(minusDager('2024-03-01', 1)).toBe('2024-02-29')
  })

  test('364 dager gir samme ukedag', () => {
    for (const d of ['2026-08-17', '2026-01-15', '2026-12-01']) {
      expect(ukedag(minusDager(d, 364)), d).toBe(ukedag(d))
    }
  })

  test('dagerMellom teller hele døgn', () => {
    expect(dagerMellom('2026-08-01', '2026-08-17')).toBe(16)
    expect(dagerMellom('2026-08-17', '2026-08-17')).toBe(0)
  })
})

describe('53-ukers-unntaket', () => {
  test('31. desember faller ikke tilbake på samme år', () => {
    // 2026-12-31 minus 364 = 2026-01-01 — samme kalenderår, altså
    // ubrukelig som «i fjor». Da skal 371 brukes.
    expect(minusDager('2026-12-31', 364)).toBe('2026-01-01')
    expect(fjorSlutt('2026-12-31')).toBe('2025-12-25')
    // Fortsatt samme ukedag.
    expect(ukedag('2026-12-31')).toBe(ukedag('2025-12-25'))
  })

  test('en vanlig dato bruker 364', () => {
    expect(fjorSlutt('2026-08-17')).toBe('2025-08-18')
  })
})

describe('vinduene', () => {
  test('fjorårsvinduet bygges BAKFRA, med samme lengde', () => {
    // DEN KRITISKE. Brukes 364-regelen på begge ender i romjula, får
    // vinduene ulik lengde og 31 dager sammenliknes med 24.
    const v = vinduer('2026-12-31', '2026-12-01')
    expect(v.iAar).toEqual({ fra: '2026-12-01', til: '2026-12-31' })
    expect(v.iFjor.til).toBe('2025-12-25')
    expect(dagerMellom(v.iFjor.fra, v.iFjor.til))
      .toBe(dagerMellom(v.iAar.fra, v.iAar.til))

    // Regelen på startdatoen ville gitt 2025-12-02, altså 23 dager.
    expect(v.iFjor.fra).not.toBe(minusDager('2026-12-01', 364))
    expect(v.iFjor.fra).toBe('2025-11-25')
  })

  test('lengden er alltid lik', () => {
    for (const [siste, start] of [
      ['2026-08-17', '2026-08-01'], ['2026-01-05', '2026-01-01'],
      ['2026-12-31', '2026-12-01'], ['2026-03-01', '2026-03-01'],
    ]) {
      const v = vinduer(siste, start)
      expect(dagerMellom(v.iFjor.fra, v.iFjor.til), `${siste} / ${start}`)
        .toBe(dagerMellom(v.iAar.fra, v.iAar.til))
    }
  })

  test('henger importen etter, klippes starten til siste salgsdag', () => {
    // Siste salgsdag i forrige måned: uten klippingen blir vinduet tomt
    // og widgeten viser 0 mot 0.
    const v = vinduer('2026-07-30', '2026-08-01')
    expect(v.iAar).toEqual({ fra: '2026-07-30', til: '2026-07-30' })
    expect(dagerMellom(v.iFjor.fra, v.iFjor.til)).toBe(0)
  })
})

describe('summering og dagtelling', () => {
  test('teller bare dager som faktisk har rader', () => {
    const rader = [dag('2026-08-01', 100), dag('2026-08-03', 50)]
    const s = summer(rader, { fra: '2026-08-01', til: '2026-08-05' })
    expect(s.kr).toBe(150)
    expect(s.dager, 'to datoer med rader, ikke fem').toBe(2)
  })

  test('null teller som null kroner, men som en dag', () => {
    const s = summer([dag('2026-08-01', null)], { fra: '2026-08-01', til: '2026-08-01' })
    expect(s.kr).toBe(0)
    expect(s.dager).toBe(1)
  })
})

describe('sammenlikningen', () => {
  const rader = [
    dag('2026-08-16', 19182.4), dag('2026-08-17', 100),
    dag('2025-08-17', 18022.4), dag('2025-08-18', 60),
  ]

  test('avrunder FØR subtraksjon', () => {
    // 19 182,4 − 18 022,4 = 1 160,0 på rå tall. Rundes hver for seg
    // FØRST, blir det 19 182 − 18 022 = 1 160 — og det er det skjermen
    // viser. Regnes differansen av de rå tallene og rundes til slutt,
    // kan skjermen vise 19 182 − 18 022 = 1 161, og brukeren som
    // kontrollregner mister tillit til hele modulen.
    const s = sammenlikn(
      [dag('2026-08-17', 19182.4), dag('2025-08-18', 18022.4)],
      '2026-08-17', '2026-08-17',
    )
    expect(s.iAar).toBe(19182)
    expect(s.iFjor).toBe(18022)
    expect(s.diff, 'skal være differansen av de VISTE tallene').toBe(1160)
    expect(s.iAar - s.iFjor).toBe(s.diff)
  })

  test('flagger dager fjoråret mangler', () => {
    // Summering over rader som ikke finnes gir 0, ikke feil. Var
    // butikken stengt i fjor, ser veksten strålende ut uten grunn.
    const s = sammenlikn(
      [dag('2026-08-16', 100), dag('2026-08-17', 100), dag('2025-08-18', 50)],
      '2026-08-17', '2026-08-16',
    )
    expect(s.dagerIAar).toBe(2)
    expect(s.dagerIFjor).toBe(1)
    expect(s.manglerDager).toBe(1)
  })

  test('mangler ingenting når begge vinduene er fulle', () => {
    const s = sammenlikn(rader, '2026-08-17', '2026-08-16')
    expect(s.manglerDager).toBe(0)
  })

  test('null i fjor gir ingen prosent, ikke uendelig', () => {
    const s = sammenlikn([dag('2026-08-17', 500)], '2026-08-17', '2026-08-17')
    expect(s.iFjor).toBe(0)
    expect(s.pct, 'ikke +100 % og ikke ∞').toBeNull()
    expect(s.diff).toBe(500)
  })

  test('prosenten har én desimal', () => {
    const s = sammenlikn(
      [dag('2026-08-17', 110), dag('2025-08-18', 100)],
      '2026-08-17', '2026-08-17',
    )
    expect(s.pct).toBe(10)
  })
})

describe('etiketter utledes av dataene', () => {
  test('ukedagen hardkodes aldri', () => {
    // «torsdag mot torsdag» sto som fast tekst. Den var riktig den dagen
    // koden ble skrevet, og feil resten av uka.
    expect(ukedag('2026-08-17')).toBe('mandag')
    expect(ukedag('2026-08-15')).toBe('lørdag')
    expect(ukedag('2026-08-16')).toBe('søndag')
  })

  test('kortdato til vindusetiketten', () => {
    expect(kortDato('2025-08-18')).toBe('18.08.25')
  })
})
