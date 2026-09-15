import { describe, expect, it } from 'vitest'
import { koble, NUMMERBRO } from './identitet'

const finnes = (...numre: string[]) => (k: string) => numre.includes(k)

describe('koble', () => {
  it('tar nummeret direkte når lønnsgrunnlaget kjenner det', () => {
    expect(koble('1104265', finnes('1104265'))).toEqual({ status: 'koblet', lonnsnr: '1104265' })
  })

  it('bruker broa når numrene spriker', () => {
    // MÅLT august 2026: Basis Export skriver 1013, lønnsgrunnlaget 11013,
    // og begge viser 160,0 timer. Timesammenfallet er beviset — ikke navnet.
    expect(koble('1013', finnes('11013'))).toEqual({ status: 'koblet', lonnsnr: '11013' })
  })

  it('kobler den som ingen regel kunne utledet', () => {
    // KANARIFUGL. 1512 → 1104215 følger ikke mønsteret de fire andre
    // gjør. Erstatter noen tabellen med en strengregel, blir denne rød.
    expect(koble('1512', finnes('1104215'))).toEqual({ status: 'koblet', lonnsnr: '1104215' })
  })

  it('gjetter ALDRI', () => {
    // Nummeret ligner på et som finnes, men står ikke i broa. Da er
    // svaret ukoblet — ikke et forsøk på å ligne seg fram.
    expect(koble('11104265', finnes('1104265'))).toEqual({ status: 'ukoblet' })
    expect(koble('1104265', finnes('11104265'))).toEqual({ status: 'ukoblet' })
  })

  it('melder TVETYDIG når begge kandidatene finnes', () => {
    // Staar baade 1013 og 11013 i loennsgrunnlaget, er broa gal: enten
    // er de to forskjellige personer, eller saa ligger samme person inne
    // to ganger. AA velge det ene ville priset timene med en sats som
    // kan tilhoere noen andre - og sett like riktig ut som en korrekt
    // kobling.
    expect(koble('1013', finnes('1013', '11013')))
      .toEqual({ status: 'tvetydig', kandidater: ['1013', '11013'] })
  })

  it('sjekker tvetydighet FOER det direkte treffet', () => {
    // KANARIFUGL. Tas det direkte treffet foerst, brukes broa aldri naar
    // begge finnes - og en gal bro ville ligget uoppdaget for alltid.
    const svar = koble('1013', finnes('1013', '11013'))
    expect(svar.status).not.toBe('koblet')
  })

  it('melder ukoblet når personen ikke finnes noe sted', () => {
    expect(koble('9999', finnes('1104265'))).toEqual({ status: 'ukoblet' })
  })

  it('godtar fastlønn bare når et menneske har sagt det', () => {
    expect(koble('1004', finnes(), new Set(['1004']))).toEqual({ status: 'fastlonn' })
    expect(koble('1004', finnes())).toEqual({ status: 'ukoblet' })
  })

  it('lar lønnsgrunnlaget slå fastlønnsmerket', () => {
    // Står personen der MED sats, er hen timelønnet uansett hva noen har
    // huket av — og da skal timene prises. Motsatt rekkefølge ville gjort
    // en feilklassifisering til gratis arbeid.
    expect(koble('1013', finnes('11013'), new Set(['1013', '11013'])))
      .toEqual({ status: 'koblet', lonnsnr: '11013' })
  })
})

describe('NUMMERBRO', () => {
  it('er en tabell, ikke en regel', () => {
    // Fire av fem par følger et mønster. Den femte gjør ikke — og det er
    // nettopp derfor dette er data og ikke kode. Blir tabellen tom eller
    // erstattet av en utledning, skal dette bli rødt.
    expect(NUMMERBRO['1512']).toBe('1104215')
    const foelgerMonster = Object.entries(NUMMERBRO)
      .filter(([fra, til]) => til === `1${fra}` || til === `0${fra}`)
    expect(foelgerMonster).toHaveLength(4)
    expect(Object.keys(NUMMERBRO)).toHaveLength(5)
  })

  it('peker aldri to numre til samme ansatt', () => {
    const maal = Object.values(NUMMERBRO)
    expect(new Set(maal).size).toBe(maal.length)
  })

  it('har ingen kjede — et bronummer er aldri selv en nøkkel', () => {
    // En bro som peker videre til en annen bro ville gjort oppslaget
    // avhengig av rekkefølge.
    for (const til of Object.values(NUMMERBRO)) {
      expect(NUMMERBRO[til]).toBeUndefined()
    }
  })
})
