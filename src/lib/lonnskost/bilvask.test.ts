import { describe, expect, it } from 'vitest'
import { BILVASK_BRUTTOANDEL, bruttoPerMaaned, ukensDager } from './bilvask'

// =====================================================================
// EN UKE SOM HAVNER I FEIL MAANED SER UT SOM SESONG
//
// Uke 26 kan ligge halvt i juni og halvt i juli. Lagres den som «juli»,
// mister juni sin del og juli faar for mye - i to maaneder paa rad, i
// motsatt retning. Ingen ville sett det som en feil; det ville sett ut
// som at juni var svak og juli sterk.
// =====================================================================

describe('ukensDager', () => {
  it('gir sju datoer, mandag til søndag', () => {
    const d = ukensDager(2026, 36)
    expect(d).toHaveLength(7)
    expect(new Date(`${d[0]}T00:00:00Z`).getUTCDay()).toBe(1) // mandag
    expect(new Date(`${d[6]}T00:00:00Z`).getUTCDay()).toBe(0) // soendag
  })

  it('gir sammenhengende dager', () => {
    const d = ukensDager(2026, 14)
    for (let i = 1; i < d.length; i++) {
      const f = new Date(`${d[i - 1]}T00:00:00Z`)
      f.setUTCDate(f.getUTCDate() + 1)
      expect(d[i]).toBe(f.toISOString().slice(0, 10))
    }
  })

  // ISO-UKE, IKKE «UKE SOM STARTER 1. JANUAR». Uke 1 er uka som
  // inneholder aarets foerste torsdag, og den kan begynne i desember
  // aaret foer. En uke som teller fra nyttaar ville forskjoevet hele
  // aaret med inntil tre dager.
  it('lar uke 1 begynne i desember når året krever det', () => {
    // 2026-01-01 er en torsdag, saa uke 1 starter mandag 2025-12-29.
    expect(ukensDager(2026, 1)[0]).toBe('2025-12-29')
    expect(ukensDager(2026, 1)).toContain('2026-01-01')
  })

  it('plasserer 4. januar i uke 1, hvilket år det enn er', () => {
    for (const ar of [2024, 2025, 2026, 2027, 2028]) {
      expect(ukensDager(ar, 1)).toContain(`${ar}-01-04`)
    }
  })
})

describe('bruttoPerMaaned', () => {
  // KANARI MOT EN HALV RETTELSE.
  //
  // Andelen sto paa 0,75 og var feil, men den er fristende aa «rette»
  // tilbake med det ene halve argumentet: oekonomisk ER bruttoandelen av
  // de 90 kronene bare 42-71 %, fordi saapen koster ~10,5 % av
  // KASSEPRISEN (249-499) og ikke av utbetalingen.
  //
  // Men modulen maaler ikke sannheten - den skal treffe det regnskapet
  // vil vise naar maaneden avlegges, og regnskapet foerer
  // `21014 MASKINVASK APP` med 100 % bruttofortjeneste: saapen havner paa
  // kasselinja 21010. Maalt paa Kelsar jan-jul 2026: salg 1 206 107,
  // brutto 1 206 107.
  //
  // Settes den til noe annet enn 1 uten at foeringen i regnskapet er
  // endret, slutter lonnsrommet aa stemme med fasiten det maales mot.
  it('legger inn hele beloepet, fordi regnskapet foerer app-linja med 100 % brutto', () => {
    const m = bruttoPerMaaned([{ ar: 2026, uke: 36, belopKr: 7000 }])
    expect([...m.values()].reduce((a, b) => a + b, 0)).toBeCloseTo(7000, 2)
    expect(BILVASK_BRUTTOANDEL).toBe(1)
    // Ikke 0,75 - og heller ikke den oekonomiske sannheten.
    expect(BILVASK_BRUTTOANDEL).not.toBe(0.75)
    expect(BILVASK_BRUTTOANDEL).toBeGreaterThan(0.75)
  })

  // ===================================================================
  // SKJOETEN ER HELE POENGET
  //
  // Uke 40 i 2026 gaar 28. september til 4. oktober: fire dager i
  // september, tre i oktober. Beloepet skal deles i det forholdet - ikke
  // legges i den ene maaneden.
  // ===================================================================
  it('deler en uke som krysser månedsskiftet, etter dager', () => {
    const dager = ukensDager(2026, 40)
    const iSep = dager.filter((d) => d.startsWith('2026-09')).length
    const iOkt = dager.filter((d) => d.startsWith('2026-10')).length
    expect(iSep + iOkt).toBe(7)
    expect(iSep).toBeGreaterThan(0)
    expect(iOkt).toBeGreaterThan(0)

    const m = bruttoPerMaaned([{ ar: 2026, uke: 40, belopKr: 7000 }])
    expect(m.get('2026-09')).toBeCloseTo((7000 / 7) * iSep, 2)
    expect(m.get('2026-10')).toBeCloseTo((7000 / 7) * iOkt, 2)
  })

  it('deler også over årsskiftet', () => {
    const m = bruttoPerMaaned([{ ar: 2026, uke: 1, belopKr: 7000 }])
    // Uke 1 i 2026 starter 2025-12-29: tre dager i desember, fire i januar.
    expect(m.get('2025-12')).toBeCloseTo((7000 / 7) * 3, 2)
    expect(m.get('2026-01')).toBeCloseTo((7000 / 7) * 4, 2)
  })

  // INGEN KRONER I SKJOETENE. Summen over alle maaneder skal alltid vaere
  // beloepet ganget med andelen - uansett hvor ukene faller.
  it('mister ingen kroner uansett hvor ukene ligger', () => {
    const uker = Array.from({ length: 52 }, (_, i) => ({
      ar: 2026, uke: i + 1, belopKr: 8010,
    }))
    const m = bruttoPerMaaned(uker)
    const sum = [...m.values()].reduce((a, b) => a + b, 0)
    expect(sum).toBeCloseTo(52 * 8010 * BILVASK_BRUTTOANDEL, 0)
  })

  it('summerer flere uker i samme måned', () => {
    // Uke 35 og 36 i 2026 ligger begge helt i august/september.
    const m = bruttoPerMaaned([
      { ar: 2026, uke: 35, belopKr: 4860 },
      { ar: 2026, uke: 36, belopKr: 3960 },
    ])
    const sum = [...m.values()].reduce((a, b) => a + b, 0)
    expect(sum).toBeCloseTo((4860 + 3960) * BILVASK_BRUTTOANDEL, 2)
  })

  it('gir tomt kart uten uker', () => {
    expect(bruttoPerMaaned([]).size).toBe(0)
  })
})
