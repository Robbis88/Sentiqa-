import { describe, expect, test } from 'vitest'
import {
  dagerMellom, dagsnavn, fjorSlutt, kortDato, minusDager, sammenlikn, summer, ukedag,
  vinduer,
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

describe('nærmeste dag, maks ett steg', () => {
  test('en vanlig dato treffer samme ukedag og nesten samme dato', () => {
    // Robert 2026-08-22: «22.08.2026 måles mot 23.08.2025?» — ja, og det
    // er nettopp det 364-dagersregelen gjør.
    expect(fjorSlutt('2026-08-22')).toBe('2025-08-23')
    expect(ukedag('2026-08-22')).toBe(ukedag('2025-08-23'))
  })

  test('rundt et skuddår blir avstanden to dager, men ukedagen holder', () => {
    // 29. februar ligger imellom. Verdt å vite: «maks 1 dag» er sant i
    // vanlige år, ikke over en skuddårsgrense.
    expect(fjorSlutt('2024-03-01')).toBe('2023-03-03')
    expect(ukedag('2024-03-01')).toBe(ukedag('2023-03-03'))
  })

  test('31. desember tar ETT steg, ikke en hel uke', () => {
    // 364 dager tilbake lander 1. januar SAMME år — ubrukelig.
    expect(minusDager('2026-12-31', 364)).toBe('2026-01-01')

    // Ett steg til gir samme dato året før. 371 ville beholdt ukedagen,
    // men målt nyttårsaften mot 1. juledag — to helt ulike handledager.
    expect(fjorSlutt('2026-12-31')).toBe('2025-12-31')
    expect(fjorSlutt('2026-12-31')).not.toBe(minusDager('2026-12-31', 371))
  })

  test('byttet er bevisst: én ukedag gis opp for å slippe helligdagen', () => {
    // Dette er den eneste dagen i året der ukedagsregelen viker, og det
    // skal stå svart på hvitt i en test — ikke bare i en kommentar.
    expect(ukedag('2026-12-31'), 'nyttårsaften 2026').toBe('torsdag')
    expect(ukedag(fjorSlutt('2026-12-31')), 'nyttårsaften 2025').toBe('onsdag')
    expect(ukedag(minusDager('2026-12-31', 371)), '1. juledag 2025').toBe('torsdag')
  })

  test('30. desember trenger ingen justering', () => {
    // Grensen skal ikke gripe inn en dag for tidlig.
    expect(fjorSlutt('2026-12-30')).toBe('2025-12-31')
    expect(ukedag('2026-12-30')).toBe(ukedag('2025-12-31'))
  })
})

describe('helligdag mot helligdag', () => {
  test('julaften mot julaften, ikke mot nabodagen', () => {
    // Robert: «24 mot 24». −364 ville gitt 25.12.2025 — 1. juledag.
    expect(fjorSlutt('2026-12-24')).toBe('2025-12-24')
    expect(fjorSlutt('2026-12-31')).toBe('2025-12-31')
  })

  test('1. juledag mot 1. juledag, ikke mot 2.', () => {
    // −364 fra 25.12.2026 gir 26.12.2025 — feil helligdag, og en helt
    // annen handledag.
    expect(minusDager('2026-12-25', 364)).toBe('2025-12-26')
    expect(fjorSlutt('2026-12-25')).toBe('2025-12-25')
  })

  test('påsken flytter seg fem uker, og navnet følger med', () => {
    // DEN SOM IKKE KAN LØSES MED DAGSFORSKYVNING. Skjærtorsdag er
    // 2. april i 2026 og 17. april i 2025 — femten dager unna, langt
    // utenfor rekkevidde for ±1 eller ±7.
    expect(fjorSlutt('2026-04-02')).toBe('2025-04-17')
    expect(fjorSlutt('2026-04-03')).toBe('2025-04-18') // langfredag
    expect(fjorSlutt('2026-04-06')).toBe('2025-04-21') // 2. påskedag
  })

  test('17. mai mot 17. mai, selv om ukedagen ikke stemmer', () => {
    // 2026: søndag. 2025: lørdag. Datoen vinner — nasjonaldagen er
    // nasjonaldagen uansett hvilken ukedag den faller på.
    expect(fjorSlutt('2026-05-17')).toBe('2025-05-17')
    expect(ukedag('2026-05-17')).not.toBe(ukedag('2025-05-17'))
  })

  test('en vanlig dag følger fortsatt ukedagen', () => {
    // Helligdagsregelen skal ikke gripe inn ellers: da ville lørdag
    // kunne måles mot fredag, og lørdag er den største dagen i uka.
    expect(fjorSlutt('2026-08-22')).toBe('2025-08-23')
    expect(ukedag('2026-08-22')).toBe(ukedag('2025-08-23'))
  })
})

describe('vinduene', () => {
  test('fjorårsvinduet bygges BAKFRA, med samme lengde', () => {
    // DEN KRITISKE. Brukes 364-regelen på begge ender i romjula, får
    // vinduene ulik lengde og 31 dager sammenliknes med 24.
    const v = vinduer('2026-12-31', '2026-12-01')
    expect(v.iAar).toEqual({ fra: '2026-12-01', til: '2026-12-31' })
    expect(v.iFjor.til).toBe('2025-12-31')
    expect(dagerMellom(v.iFjor.fra, v.iFjor.til))
      .toBe(dagerMellom(v.iAar.fra, v.iAar.til))

    // Regelen på startdatoen ville gitt 2025-12-02, altså 23 dager.
    expect(v.iFjor.fra).not.toBe(minusDager('2026-12-01', 364))
    expect(v.iFjor.fra).toBe('2025-12-01')
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

describe('etiketten sier hvilken regel som ble brukt', () => {
  test('navngir dagen naar den har et navn', () => {
    expect(dagsnavn('2026-05-17')).toBe('Grunnlovsdagen')
    expect(dagsnavn('2026-12-24')).toBe('Julaften')
    expect(dagsnavn('2026-04-02')).toBe('Skjærtorsdag')
  })

  test('en vanlig dag har ikke noe navn, og faar ukedagsteksten', () => {
    // KANARIFUGL: svarer denne med et navn paa en vanlig tirsdag, staar
    // det plutselig helligdagstekst over hver eneste maaling.
    expect(dagsnavn('2026-08-22')).toBeNull()
    expect(dagsnavn('2026-08-18')).toBeNull()
  })

  test('17. mai: uten navnet ville etiketten sett ut som en feil', () => {
    // Soendag mot loerdag. Staar det «samme ukedag» over det, leser
    // brukeren riktig svar som en bug - og det er verre enn ingen tekst.
    expect(ukedag('2026-05-17')).toBe('søndag')
    expect(ukedag(fjorSlutt('2026-05-17'))).toBe('lørdag')
    expect(dagsnavn('2026-05-17'), 'da maa navnet overta teksten').not.toBeNull()
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
