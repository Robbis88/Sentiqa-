import { describe, expect, it } from 'vitest'
import {
  avgjorIdentitet, navnSierImot,
  type Registerkandidat,
} from './identitet'

// =====================================================================
// KANARIFUGLENE ER MÅLT, IKKE FUNNET PÅ
//
// Tallene under er lest ut av de ekte easy@work-filene 2026-09-16 (27
// lønnsgrunnlag, 8 Basis Export). Filene selv ligger utenfor git — de
// bærer navngitte ansatte med lønn — så observasjonen er skrevet inn
// her i stedet, med kilden nevnt.
//
// 1018 er PRODUKSJONSSJEKKET og finnes IKKE i produksjon: registeret
// har null rader på nummeret, og Varden juli finnes ikke i `basisvakt`.
// Kanarifuglen er derfor TESTBEVIST mot ekte råfiler, ikke
// produksjonsbevist. Vi konstruerer ikke data for å gjøre den grønn.
// =====================================================================

const LONE = '11111111-1111-1111-1111-111111111111'
const BONES = '22222222-2222-2222-2222-222222222222'
const VARDEN = '33333333-3333-3333-3333-333333333333'

/** Et register som svarer slik `hentRegister` gjør: på tvers av stasjoner. */
const registeret = (...rader: Registerkandidat[]) =>
  (nr: string) => rader.filter((r) => r.ansattNr === nr)

const CARMEN: Registerkandidat = {
  ansattNr: '1104265', navn: 'Carmen Valentina Toro', stasjonId: LONE,
}
const MARIETTA: Registerkandidat = {
  ansattNr: '1018', navn: 'Marietta Iacovou', stasjonId: BONES,
}

describe('avgjorIdentitet — kanarifuglene', () => {
  it('Carmen kobles på tvers av stasjoner', () => {
    // MÅLT: Basis Bønes juli 2026 har 1104265 med 79,82 timer, mens
    // registerraden bare finnes i LONES fil. Lønnsgrunnlaget lister
    // stasjonens egne ansatte, ikke alle som jobbet der.
    const svar = avgjorIdentitet(
      { ansattNr: '1104265', ansattNavn: 'Carmen Valentina Toro' },
      registeret(CARMEN, MARIETTA),
    )
    expect(svar).toEqual({
      status: 'koblet',
      lonnsnr: '1104265',
      registerStasjonId: LONE,
      kilde: 'direkte',
    })
  })

  it('1018 på Varden stoppes av navnevetoet', () => {
    // MÅLT: Basis Varden juli 2026 fører 1018 som «Andre Fjørstad» med
    // 54,50 timer. Registeret kjenner 1018 bare som Marietta Iacovou på
    // Bønes, 239,33. Uten vetoet prises Andres timer med Mariettas sats.
    const svar = avgjorIdentitet(
      { ansattNr: '1018', ansattNavn: 'Andre Fjørstad' },
      registeret(MARIETTA),
    )
    expect(svar.status).toBe('motstrid')
    if (svar.status !== 'motstrid') return
    expect(svar.grunn).toBe('navn')
    expect(svar.kandidater).toEqual([MARIETTA])
  })

  it('1018 på Bønes kobles helt normalt i samme måned', () => {
    // Vetoet skal treffe OBSERVASJONEN, ikke nummeret. Marietta jobber
    // 25,76 timer på Bønes samme juli; de timene skal prises.
    const svar = avgjorIdentitet(
      { ansattNr: '1018', ansattNavn: 'Marietta Iacovou' },
      registeret(MARIETTA),
    )
    expect(svar).toEqual({
      status: 'koblet',
      lonnsnr: '1018',
      registerStasjonId: BONES,
      kilde: 'direkte',
    })
  })

  it('to registerkandidater blir kollisjon, ikke et valg', () => {
    const ogsaaVarden: Registerkandidat = {
      ansattNr: '1018', navn: 'Andre Fjørstad', stasjonId: VARDEN,
    }
    const svar = avgjorIdentitet(
      { ansattNr: '1018', ansattNavn: 'Andre Fjørstad' },
      registeret(MARIETTA, ogsaaVarden),
    )
    expect(svar.status).toBe('motstrid')
    if (svar.status !== 'motstrid') return
    expect(svar.grunn).toBe('kollisjon')
    expect(svar.kandidater).toHaveLength(2)
  })

  it('navnet bryter ALDRI en kollisjon, selv når det bare passer på den ene', () => {
    // Dette er forskjellen på et veto og en nøkkel. Navnet peker rett på
    // den ene kandidaten — og svaret er likevel motstrid. Lot vi navnet
    // velge, ville det vært en positiv nøkkel med et annet navn.
    const ogsaaVarden: Registerkandidat = {
      ansattNr: '1018', navn: 'Andre Fjørstad', stasjonId: VARDEN,
    }
    const svar = avgjorIdentitet(
      { ansattNr: '1018', ansattNavn: 'Andre Fjørstad' },
      registeret(MARIETTA, ogsaaVarden),
    )
    expect(svar.status).not.toBe('koblet')
  })
})

describe('avgjorIdentitet — nummeret foreslår', () => {
  it('ukjent nummer blir ukoblet, ikke gjettet', () => {
    expect(avgjorIdentitet(
      { ansattNr: '9999', ansattNavn: 'Carmen Valentina Toro' },
      registeret(CARMEN),
    )).toEqual({ status: 'ukoblet', grunn: 'ukjent_nummer' })
  })

  it('et navn som finnes under et ANNET nummer kobler ingenting', () => {
    // Kanarifuglen for «navn er aldri en positiv nøkkel». Registeret
    // kjenner navnet perfekt; nummeret er bare ikke det samme.
    const svar = avgjorIdentitet(
      { ansattNr: '9999', ansattNavn: 'Carmen Valentina Toro' },
      registeret(CARMEN),
    )
    expect(svar.status).toBe('ukoblet')
  })

  it('broa brukes når bare målet finnes', () => {
    const hasan: Registerkandidat = {
      ansattNr: '11013', navn: 'Hasan Gezer', stasjonId: VARDEN,
    }
    expect(avgjorIdentitet(
      { ansattNr: '1013', ansattNavn: 'Hasan Gezer' },
      registeret(hasan),
    )).toEqual({
      status: 'koblet', lonnsnr: '11013', registerStasjonId: VARDEN, kilde: 'bro',
    })
  })

  it('finnes BÅDE nummeret og broas mål, er broa gal', () => {
    const begge = registeret(
      { ansattNr: '1013', navn: 'Hasan Gezer', stasjonId: VARDEN },
      { ansattNr: '11013', navn: 'Hasan Gezer', stasjonId: VARDEN },
    )
    const svar = avgjorIdentitet({ ansattNr: '1013', ansattNavn: 'Hasan Gezer' }, begge)
    expect(svar.status).toBe('motstrid')
    if (svar.status !== 'motstrid') return
    expect(svar.grunn).toBe('bro')
    expect(svar.kandidater).toHaveLength(2)
  })

  it('broa sjekkes FØR det direkte treffet', () => {
    // Tas det direkte treffet først, blir en gal bro aldri oppdaget.
    const begge = registeret(
      { ansattNr: '1013', navn: 'Hasan Gezer', stasjonId: VARDEN },
      { ansattNr: '11013', navn: 'Hasan Gezer', stasjonId: BONES },
    )
    expect(avgjorIdentitet({ ansattNr: '1013', ansattNavn: 'Hasan Gezer' }, begge).status)
      .not.toBe('koblet')
  })
})

describe('navnSierImot — vetoet', () => {
  it('sier imot bare når ingen ledd er felles', () => {
    expect(navnSierImot('Andre Fjørstad', 'Marietta Iacovou')).toBe(true)
    expect(navnSierImot('Marietta Iacovou', 'Marietta Iacovou')).toBe(false)
  })

  it('ett felles ledd er nok til å la være å nekte', () => {
    // Vetoet er ensrettet: felles ledd er ikke bevis for samme person,
    // bare fravær av motbevis.
    expect(navnSierImot('Carmen Toro', 'Carmen Valentina Toro')).toBe(false)
    expect(navnSierImot('Toro, Carmen', 'Carmen Valentina Toro')).toBe(false)
  })

  // HVERT PAR HAR BARE ETT LEDD, MED VILJE.
  //
  // Første utgave brukte «Andre Fjørstad» mot «Andre Fjorstad». De to
  // deler «andre», så testen bestod selv om ø-foldingen ble slått av —
  // den målte fornavnet, ikke regelen. En injeksjon som fjernet
  // foldingen ble grønn. Med ett ledd finnes det ingen annen vei.
  it('folder ø, så skrivemåten ikke blir et veto', () => {
    expect(navnSierImot('Fjørstad', 'Fjorstad')).toBe(false)
  })

  it('folder æ', () => {
    expect(navnSierImot('Kjærsti', 'Kjaersti')).toBe(false)
  })

  it('folder diakritiske tegn', () => {
    expect(navnSierImot('Håkon', 'Hakon')).toBe(false)
    expect(navnSierImot('Renée', 'Renee')).toBe(false)
  })

  it('en delt mellominitial hindrer IKKE et veto', () => {
    // «E» er ikke et navn. Uten leddlengden ville et delt initial gjort
    // to fremmede til mulig samme person.
    expect(navnSierImot('Stig E. Litlehamar', 'Elin E. Nordbø')).toBe(true)
  })

  it('MANGLENDE navn er fravær, ikke motstrid', () => {
    // Samme lærdom som blank betalingsfrekvens i B1: en tom verdi er
    // ikke en påstand om noe annet. Ville dette vært et veto, ville hver
    // rad uten navn blitt uprisbar.
    expect(navnSierImot('', 'Marietta Iacovou')).toBe(false)
    expect(navnSierImot('Marietta Iacovou', '')).toBe(false)
    expect(navnSierImot('   ', 'Marietta Iacovou')).toBe(false)
    expect(navnSierImot('-', 'Marietta Iacovou')).toBe(false)
  })

  it('tomt navn på observasjonen stopper ikke koblingen', () => {
    expect(avgjorIdentitet({ ansattNr: '1018', ansattNavn: '' }, registeret(MARIETTA)))
      .toEqual({
        status: 'koblet', lonnsnr: '1018', registerStasjonId: BONES, kilde: 'direkte',
      })
  })
})

describe('avgjorIdentitet — formen på svaret', () => {
  it('motstrid bærer en forklaring et menneske kan lese', () => {
    const svar = avgjorIdentitet(
      { ansattNr: '1018', ansattNavn: 'Andre Fjørstad' },
      registeret(MARIETTA),
    )
    if (svar.status !== 'motstrid') throw new Error('forventet motstrid')
    expect(svar.forklaring).toContain('Andre Fjørstad')
    expect(svar.forklaring).toContain('Marietta Iacovou')
  })

  it('koblet bærer stasjonen registerraden kom fra', () => {
    // Det er dette feltet som senere avgjør om kronene er innlånt — og
    // det er en nøkkel, ikke fritekst slik `hovedlokasjon` er.
    const svar = avgjorIdentitet(
      { ansattNr: '1104265', ansattNavn: 'Carmen Valentina Toro' },
      registeret(CARMEN),
    )
    if (svar.status !== 'koblet') throw new Error('forventet koblet')
    expect(svar.registerStasjonId).toBe(LONE)
  })

  it('nummeret trimmes før oppslag', () => {
    expect(avgjorIdentitet(
      { ansattNr: '  1018  ', ansattNavn: 'Marietta Iacovou' },
      registeret(MARIETTA),
    ).status).toBe('koblet')
  })

  it('identiteten vet ingenting om fastlønn eller sats', () => {
    // De tre aksene blandes ikke. Tar denne fila imot en klassifisering,
    // kan en avtalerad gjøre en motstridende person «håndtert» før
    // identiteten er avgjort. `ansatt_avtale` har 18 rader i produksjon,
    // på to av fem stasjoner, 8 av dem med null i lonnsform.
    expect(avgjorIdentitet.length).toBe(2)
  })
})
