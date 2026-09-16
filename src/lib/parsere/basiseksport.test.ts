import { describe, expect, it } from 'vitest'
import { erBasiseksportFil, lesBasiseksport, minutterMellom, norskDato } from './basiseksport'
import { erLonnsgrunnlagFil } from './lonnsgrunnlag'

// Formen er hentet fra ekte eksporter (sju filer, fem stasjoner,
// 2025-01 → 2026-08), men navn og numre er byttet ut. Lønn og timer per
// navngitt person er personopplysninger og hører ikke hjemme i et repo.
const TOPP = 'Forretningsdato,Stemplingsnummer,Ansatt,Type,Fra,Til,Lengde,Akkumulert,"Siden forrige",Lokasjon'

const rad = (
  dato: string, nr: string, navn: string, type: string,
  fra: string, til: string, lengde: string, lok = 'St1 - Bønes',
) => `" ${dato} ",${nr},"${navn}","${type}"," ${fra}"," ${til}",${lengde},${lengde},0,"${lok}"`

const fil = (...rader: string[]) => [TOPP, ...rader].join('\n')

describe('erBasiseksportFil', () => {
  it('kjenner igjen Basis Export', () => {
    expect(erBasiseksportFil(fil(rad('1 juli 2026', '308', 'A B', 'Betalt tid', '12:00', '18:00', '6')))).toBe(true)
  })

  it('tar ikke lønnsgrunnlaget, som deler Stemplingsnummer', () => {
    // KANARIFUGL. De to eksportene har `Stemplingsnummer` felles. Faller
    // skillet, leses lønnsgrunnlaget som stemplinger og hver dagslinje
    // blir en vakt — timene ville tredoblet seg uten at noe ble rødt.
    const lonnsgrunnlag = [
      'Periode,,,',
      'Stemplingsnummer,Ansatt,Lønn,Betalingsfrekvens,Lokasjon,Hovedlokasjon,Dato,Timer',
      '308,"A B",138,Måned,St1 - Bønes,St1 - Bønes,2026-07-01,6',
    ].join('\n')
    expect(erBasiseksportFil(lonnsgrunnlag)).toBe(false)
    expect(erLonnsgrunnlagFil(lonnsgrunnlag)).toBe(true)
  })
})

describe('lesBasiseksport', () => {
  it('leser arbeidsstedet per rad, ikke per fil', () => {
    // HELE POENGET MED FILA. Kommer det en gang en samleeksport, skal
    // ikke den ene stasjonens timer havne på den andre fordi den sto
    // øverst.
    const r = lesBasiseksport(fil(
      rad('1 juli 2026', '308', 'A B', 'Betalt tid', '12:00', '18:00', '6', 'St1 - Bønes'),
      rad('1 juli 2026', '411', 'C D', 'Betalt tid', '12:00', '18:00', '6', 'St1 - Lone'),
    ))
    expect(r.lokasjoner).toEqual(['St1 - Bønes', 'St1 - Lone'])
    expect(r.stemplinger.map((s) => s.lokasjon)).toEqual(['St1 - Bønes', 'St1 - Lone'])
  })

  it('tolker «Til 00:00» som slutten av døgnet', () => {
    const [s] = lesBasiseksport(fil(
      rad('23 juli 2026', '308', 'A B', 'Betalt tid', '18:00', '00:00', '6'),
    )).stemplinger
    expect(s.minutter).toBe(360)
  })

  it('tar hele datoen i «Fra» når vakten krysser døgnet', () => {
    // MÅLT: fire slike rader i Dales fil. Forretningsdatoen er 31. juli,
    // arbeidet skjedde 1. august. Leser man bare klokkeslettet, blir det
    // NaN — eller verre, riktig timetall på feil ukedag.
    const [s] = lesBasiseksport(fil(
      rad('31 juli 2026', '308', 'A B', 'Betalt tid', '1 august 2026 00:00', '00:55', '0.92'),
    )).stemplinger
    expect(s.dato).toBe('2026-07-31')
    expect(s.fraDato).toBe('2026-08-01')
    expect(s.fraTid).toBe('00:00')
    expect(s.minutter).toBe(55)
  })

  it('skiller betalt tid fra pause', () => {
    const r = lesBasiseksport(fil(
      rad('1 juli 2026', '308', 'A B', 'Betalt tid', '12:00', '18:00', '6'),
      rad('1 juli 2026', '308', 'A B', 'Pause', '15:00', '15:30', '0.5'),
    ))
    expect(r.stemplinger.map((s) => s.betalt)).toEqual([true, false])
  })

  it('melder fra når «Lengde» ikke stemmer med intervallet', () => {
    // MÅLT: én rad av 7 943 — «09:10–11:00» med Lengde 25,82, altså
    // nøyaktig ett døgn for mye. En glemt utstempling.
    //
    // Den skal verken prises eller gjettes på: 25 timers arbeid ville
    // vært kostnad som ikke finnes, og å anta hvilken dag vakten
    // egentlig startet ville vært en slutning dataene ikke bærer.
    const r = lesBasiseksport(fil(
      rad('13 desember 2025', '1009', 'A B', 'Betalt tid', '09:10', '11:00', '25.82'),
      rad('13 desember 2025', '1018', 'C D', 'Betalt tid', '12:00', '18:00', '6'),
    ))
    expect(r.avvik).toHaveLength(1)
    expect(r.avvik[0]).toMatchObject({ ansattNr: '1009', lengde: 25.82, intervallTimer: 1.83 })
    // Og den er IKKE med blant stemplingene som skal prises.
    expect(r.stemplinger.map((s) => s.ansattNr)).toEqual(['1018'])
  })

  it('godtar at klokkeslettene er kuttet til hele minutt', () => {
    // KANARIFUGL for toleransen. `Fra`/`Til` mangler sekundene mens
    // `Lengde` har dem: 12:06:__–18:00 står som «12:06» og Lengde 5,88.
    // Blir toleransen strammet til under to minutter, blir denne rød og
    // hver fil full av falske avvik.
    const r = lesBasiseksport(fil(
      rad('4 januar 2025', '308', 'A B', 'Betalt tid', '12:06', '18:00', '5.88'),
    ))
    expect(r.avvik).toEqual([])
    expect(r.stemplinger).toHaveLength(1)
  })

  it('leser en stempling uten lengde som null, ikke som et døgn', () => {
    // MÅLT: «16:00–16:00» med Lengde 0,01 og «05:00–05:00» med Lengde 0.
    // En regel som sa «slutt ≤ start betyr neste døgn» gjorde dem til 24
    // timer hver.
    const [s] = lesBasiseksport(fil(
      rad('19 juli 2025', '308', 'A B', 'Betalt tid', '16:00', '16:00', '0.01'),
    )).stemplinger
    expect(s.minutter).toBe(0)
  })

  it('avviser en rad uten arbeidssted', () => {
    // ARBEIDSSTEDET ER HELE POENGET MED FILA. En tom lokasjon ville
    // blitt sin egen «stasjon»: timene havnet i en gruppe ingen ser paa,
    // mens den ekte stasjonen saa komplett ut. Nettopp det hullet er
    // grunnen til at modulen finnes.
    const r = lesBasiseksport(fil(
      rad('1 juli 2026', '308', 'A B', 'Betalt tid', '12:00', '18:00', '6', ''),
      rad('1 juli 2026', '411', 'C D', 'Betalt tid', '12:00', '18:00', '6', 'St1 - Lone'),
    ))
    expect(r.avvik).toHaveLength(1)
    expect(r.avvik[0].grunn).toBe('lokasjon')
    expect(r.stemplinger.map((s) => s.ansattNr)).toEqual(['411'])
  })

  it('kaster på et umulig klokkeslett i stedet for å regne det om', () => {
    // «12:75» slapp gjennom foerste utgave og ble til 13:15 i
    // `Date.UTC`, som regner over av seg selv. En umulig verdi ble et
    // troverdig tidspunkt en time for sent, uten at noe ble roedt.
    expect(() => lesBasiseksport(fil(
      rad('1 juli 2026', '308', 'A B', 'Betalt tid', '12:75', '18:00', '5.25'),
    ))).toThrow(/Ugyldig «Fra»/)
    expect(() => lesBasiseksport(fil(
      rad('1 juli 2026', '308', 'A B', 'Betalt tid', '12:00', '25:00', '6'),
    ))).toThrow(/Ugyldig «Til»/)
  })

  it('kaster på en ugyldig dato i stedet for å hoppe over raden', () => {
    expect(() => lesBasiseksport(fil(
      rad('32 hundedag 2026', '308', 'A B', 'Betalt tid', '12:00', '18:00', '6'),
    ))).toThrow(/forretningsdato/i)
  })

  it('kaster når fila ikke har en eneste stempling', () => {
    expect(() => lesBasiseksport(TOPP)).toThrow(/ingen stemplinger/)
  })
})

describe('norskDato', () => {
  it('tolker månedsnavn', () => {
    expect(norskDato(' 1 juli 2026 ')).toBe('2026-07-01')
    expect(norskDato('31 desember 2025')).toBe('2025-12-31')
  })
  it('gir null for noe som ikke er en dato', () => {
    expect(norskDato('12:00')).toBeNull()
    expect(norskDato('1 hundedag 2026')).toBeNull()
  })
})

describe('minutterMellom', () => {
  it('krysser midnatt', () => {
    expect(minutterMellom('2026-07-23', '22:57', '07:00')).toBe(483)
  })
  it('teller et vanlig intervall', () => {
    expect(minutterMellom('2026-07-23', '12:00', '18:00')).toBe(360)
  })
})

// =====================================================================
// FELTENE `basisvakt` TRENGER, SOM MOTOREN IKKE LESER
//
// `0219` bevarer Easy@Works observasjon, ikke vår tolkning av den. To
// felt bæres derfor ut av parseren uten at noen beregning rører dem:
// `Lengde` slik fila oppga den, og den rå `Type`.
//
// Uten dem kunne basen bare lagre intervallet — og da ville vi ha
// KASTET Easys eget timetall og beholdt vårt, i en tabell som lover å
// bevare kilden. Det er nøyaktig formen på `Betalingsfrekvens`-feilen:
// tallet lagret, enheten borte.
// =====================================================================

describe('Basisrad bærer det kilden sa', () => {
  it('bevarer Lengde og rå Type ved siden av intervallet', () => {
    const [s] = lesBasiseksport(fil(
      rad('1 juli 2026', '308', 'A B', 'Betalt tid', '12:00', '18:00', '6'),
    )).stemplinger
    expect(s.minutter).toBe(360)
    expect(s.lengde).toBe(6)
    expect(s.type).toBe('Betalt tid')
    expect(s.betalt).toBe(true)
  })

  it('en pause bærer sin egen type, ikke bare betalt=false', () => {
    const [s] = lesBasiseksport(fil(
      rad('1 juli 2026', '308', 'A B', 'Pause', '15:00', '15:30', '0.5'),
    )).stemplinger
    expect(s.type).toBe('Pause')
    expect(s.betalt).toBe(false)
  })

  it('lengde er null når feltet ikke er et tall', () => {
    // ALDRI 0. En manglende lengde er ikke en vakt på null timer.
    const [s] = lesBasiseksport(fil(
      rad('1 juli 2026', '308', 'A B', 'Betalt tid', '12:00', '18:00', ''),
    )).stemplinger
    expect(s.lengde).toBeNull()
    expect(s.minutter).toBe(360)
  })

  it('en avvist rad bærer nok til å kunne lagres', () => {
    // EN AVVIST RAD SKAL IKKE FORSVINNE LYDLØST. Lagres den uten
    // fra_dato, type og minutter, kan den ikke skilles fra en
    // døgnkryssende vakt senere — og da er den verdiløs som spor.
    // Den gyldige raden maa vaere med: en fil UTEN brukbare vakter
    // kaster, og da ville testen maalt feilmeldingen i stedet for avviket.
    // DEN AVVISTE RADEN KRYSSER MIDNATT MED VILJE. Foerste utgave av
    // denne testen brukte en vanlig vakt, der `fraDato` og `dato` er
    // like - og da bestod den ogsaa naar parseren skrev forretningsdatoen
    // i begge feltene. Injeksjonen som beviste det var groenn.
    const { avvik } = lesBasiseksport(fil(
      rad('13 desember 2025', '308', 'A B', 'Betalt tid', '12:00', '18:00', '6'),
      rad('13 desember 2025', '1009', 'G H', 'Betalt tid',
          '14 desember 2025 09:10', '11:00', '25.82'),
    ))
    expect(avvik).toHaveLength(1)
    expect(avvik[0].grunn).toBe('lengde')
    expect(avvik[0].dato).toBe('2025-12-13')
    expect(avvik[0].fraDato).toBe('2025-12-14')
    expect(avvik[0].type).toBe('Betalt tid')
    expect(avvik[0].betalt).toBe(true)
    expect(avvik[0].lengde).toBe(25.82)
  })

  it('en døgnkryssende vakt beholder datoen arbeidet begynte', () => {
    // Målt: 28 slike i 8 069 rader, herav 13 av 193 på Laguneparken
    // august. Uten fra_dato får vakten feil ukedag, altså feil tillegg.
    const [s] = lesBasiseksport(fil(
      rad('31 juli 2026', '308', 'A B', 'Betalt tid', '1 august 2026 00:00', '00:55', '0.92'),
    )).stemplinger
    expect(s.dato).toBe('2026-07-31')
    expect(s.fraDato).toBe('2026-08-01')
  })
})

// =====================================================================
// ÉN REGEL FOR HVA ET KLOKKESLETT ER
//
// `Fra` kommer i to former: bart klokkeslett («00:00») og med hele
// datoen foran («1 august 2026 00:00»). De leses av hver sin kodevei.
//
// Den DATERTE veien padet tallene og returnerte dem rått. «12:75» slapp
// gjennom og ble til 13:15 i `Date.UTC`, som regner over av seg selv —
// nøyaktig feilen `tid()` ble skjerpet for, men på grenen som aldri
// kalte den. En umulig verdi ble et troverdig tidspunkt én time for
// sent, uten at noe ble rødt.
//
// Testen påstår derfor ikke bare at «12:75» avvises. Den påstår at de to
// veiene GIR SAMME SVAR — ellers kan de drive fra hverandre igjen.
// =====================================================================

describe('de to Fra-veiene har samme klokkeslettregel', () => {
  // `Lengde` er med vilje uleselig ('x'). Da hoppes lengdekontrollen
  // over, og det ENESTE som kan felle raden er klokkeslettet. Foerste
  // utgave brukte `Lengde 6` mot et intervall paa 20,83 timer: raden ble
  // et LENGDEavvik, fila sto uten gyldige vakter og kastet - og testen
  // rapporterte «avvist» for en helt annen grunn enn den maalte.
  const medDato = (klokke: string) => fil(
    rad('31 juli 2026', '308', 'A B', 'Betalt tid', `1 august 2026 ${klokke}`, '06:00', 'x'),
  )
  const utenDato = (klokke: string) => fil(
    rad('1 august 2026', '308', 'A B', 'Betalt tid', klokke, '06:00', 'x'),
  )
  const godtas = (bygg: (k: string) => string, klokke: string) => {
    try {
      lesBasiseksport(bygg(klokke))
      return true
    } catch {
      return false
    }
  }

  // `24:00` godtas av `tid()` som slutten av døgnet; `24:01` og `25:00`
  // finnes ikke. Tabellen speiler den kontrakten, den lager ikke en ny.
  const tilfeller: [string, boolean][] = [
    ['00:00', true],
    ['09:10', true],
    ['23:59', true],
    ['24:00', true],
    ['12:75', false],
    ['09:60', false],
    ['24:01', false],
    ['25:00', false],
  ]

  for (const [klokke, gyldig] of tilfeller) {
    it(`«${klokke}» ${gyldig ? 'godtas' : 'avvises'} på begge veiene`, () => {
      expect(godtas(medDato, klokke), `med dato foran: «1 august 2026 ${klokke}»`).toBe(gyldig)
      expect(godtas(utenDato, klokke), `bart klokkeslett: «${klokke}»`).toBe(gyldig)
    })
  }

  it('KANARI: tabellen skiller faktisk mellom gyldig og ugyldig', () => {
    // Godtok parseren alt, ville hver rad over vært «true» og halve
    // tabellen målt ingenting. Uten denne kunne testen vært grønn mens
    // den var blind.
    expect(tilfeller.filter(([, g]) => g).length).toBeGreaterThan(0)
    expect(tilfeller.filter(([, g]) => !g).length).toBeGreaterThan(0)
  })

  it('en avvist tid stopper fila, den blir ikke lest halvveis', () => {
    // FALLER `datoOgTid` TILBAKE, må `tid()` på hele strengen også gi
    // null — ellers ville en ugyldig tid blitt til forretningsdatoen med
    // et gjettet klokkeslett.
    expect(() => lesBasiseksport(medDato('12:75'))).toThrow(/Ugyldig «Fra»/)
  })
})
