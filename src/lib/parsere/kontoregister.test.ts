import { describe, expect, it } from 'vitest'
import { ParserFeil } from './felles'
import {
  normaliser,
  registrertePar,
  slaaOppKonto,
  type Kontobegrep,
} from './kontoregister'
import { BUTIKKSJEF_BEGREP, BUTIKKSJEF_DRIFT_KODER, BUTIKKSJEF_KOSTNAD_KODER } from '@/lib/regnskap-tilgang'

// Denne fila beviser at oppslaget SER. En tabell som slår opp koden alene
// ser nøyaktig like riktig ut som en som leser paret — helt til St1 flytter
// en linje. Derfor er kanarifuglene her de viktigste testene: de injiserer
// nettopp den regresjonen og krever at den felles.

describe('slaaOppKonto', () => {
  it('slår opp 2026-parene', () => {
    expect(slaaOppKonto('627', 'Renhold').begrep).toBe('renhold')
    expect(slaaOppKonto('628', 'Renovasjon').begrep).toBe('renovasjon')
    expect(slaaOppKonto('634', 'Rep & vedlikehold').begrep).toBe('rep_vedlikehold')
    expect(slaaOppKonto('746', 'Kassedifferanse').begrep).toBe('kassedifferanse')
  })

  it('tåler at arket skriver koden inni navnecellen', () => {
    // Stasjonsarket har «627 Renhold» i kolonne 7, ikke bare «Renhold».
    expect(slaaOppKonto('627', '627 Renhold').begrep).toBe('renhold')
    expect(slaaOppKonto('503', '  503   Timelønn  ').begrep).toBe('timelonn')
  })

  it('tåler skrivevarianter, men ikke betydningsforskjeller', () => {
    expect(slaaOppKonto('541', 'Arb.avg av feriep.').begrep)
      .toBe(slaaOppKonto('541', 'Arb.avg av feriepenger').begrep)
    // «Renhold» og «Renhold-renovasj» er IKKE samme begrep, selv om de
    // deler kode og de fleste bokstavene. Det er hele grunnen til at
    // paret er noekkelen: en tabell paa kode alene ville svart likt.
    expect(slaaOppKonto('627', 'Renhold').begrep).toBe('renhold')
    expect(slaaOppKonto('627', 'Renhold-renovasj').begrep).toBe('renhold_og_renovasjon')
  })

  it('kaster når navnet mangler', () => {
    expect(() => slaaOppKonto('627', '')).toThrow(/mangler navn/)
    expect(() => slaaOppKonto('627', '   ')).toThrow(/mangler navn/)
  })

  it('kaster på et par ingen har tatt stilling til', () => {
    expect(() => slaaOppKonto('651', 'Droneleie')).toThrow(ParserFeil)
    expect(() => slaaOppKonto('651', 'Droneleie')).toThrow(/endret rapportlinjene/)
  })

  it('beskjeden peker på samme NAVN på en annen kode', () => {
    // Navnet er identiteten. Kjenner vi det igjen et annet sted, er det
    // nesten alltid den samme linja fra et annet skjema — og da er
    // beskjeden verdt mye mer enn «ukjent».
    //
    // Uten dette koster hver manglende linje en ny opplasting: januar
    // 2026 felte først på «743 Erstatn - tyveri», og «738 Bilutgifter»
    // lå rett bak den.
    expect(() => slaaOppKonto('999', 'Kassedifferanse'))
      .toThrow(/Samme navn staar paa 744 \(kassedifferanse\), 746 \(kassedifferanse\)/)
  })

  it('KANARI: sporet dukker ikke opp når navnet er ukjent overalt', () => {
    // Ellers ville beskjeden lovet et spor som ikke finnes, og sendt
    // folk på leting etter en linje som aldri har eksistert.
    let melding = ''
    try { slaaOppKonto('651', 'Droneleie') } catch (e) { melding = (e as Error).message }
    expect(melding).not.toMatch(/Samme navn/)
  })

  it('de to parene januar 2026 manglet', () => {
    // Funnet ved å lese alle 24 regnskapsfilene og telle hvert (kode,
    // navn)-par, i stedet for å vente på én feil per opplasting.
    // Registeret var bygget av det jeg kunne SE, og alt jeg hadde sett
    // var februar og senere.
    expect(slaaOppKonto('738', 'Bilutgifter').begrep).toBe('bilutgifter')
    expect(slaaOppKonto('738', 'Bilutgifter').epoke).toBe('for_feb_2026')
    expect(slaaOppKonto('743', 'Erstatn - tyveri').begrep).toBe('erstatning_tyveri')
    expect(slaaOppKonto('743', 'Erstatn - tyveri').epoke).toBe('for_feb_2026')
  })

  it('KANARI: de to nye kodene betyr noe ANNET i dag', () => {
    // 738 og 743 er ikke bare nye rader - de er samme forskyvning paa
    // to som resten. 743 er «Diverse» i dagens skjema. Leste vi koden
    // alene, ville januars tyverierstatning havnet der.
    expect(slaaOppKonto('743', 'Diverse').begrep).toBe('diverse')
    expect(slaaOppKonto('740', 'Bilutgifter').begrep).toBe('bilutgifter')
    expect(slaaOppKonto('745', 'Erstatn - tyveri').begrep).toBe('erstatning_tyveri')
  })

  it('KANARI: en KJENT kode med et UKJENT navn faller ikke tilbake på koden', () => {
    // Dette er regresjonen som faktisk kan snike seg inn: noen legger til
    // en «hjelpsom» fallback som slår opp koden alene når paret bommer.
    // Testen over fanger den ikke — 651 finnes ikke i registeret i det
    // hele tatt, så en fallback finner ingenting og det kastes uansett.
    //
    // Her finnes 627. Med en kodefallback ville den svart «Renhold» på en
    // linje som heter noe helt annet, og det er nøyaktig den stille
    // feilmerkingen hele fila er skrevet for å hindre.
    expect(() => slaaOppKonto('627', 'Vaktmestertjenester')).toThrow(ParserFeil)
    expect(() => slaaOppKonto('634', 'Leie av kaffemaskin')).toThrow(ParserFeil)

    let begrep: Kontobegrep | null = null
    try {
      begrep = slaaOppKonto('627', 'Vaktmestertjenester').begrep
    } catch {
      begrep = null
    }
    expect(begrep).toBeNull()
  })

  // ---- KANARIFUGLENE ------------------------------------------------
  //
  // St1 renummererte i februar 2026. Før det betydde 628 «Leie
  // driftsmidler». Den gamle tabellen slo opp 628 og svarte «Renovasjon»
  // — feil navn, feil beløp i feil bøtte, og ingen som ropte.

  it('KANARI: 628 fra det gamle formatet blir ikke lest som renovasjon', () => {
    // Fram til 0203 KASTET denne. Naa leses den - og det er den samme
    // kanarifuglen, bare med et sterkere krav: den skal gi det gamle
    // begrepet, ikke dagens.
    const g = slaaOppKonto('628', 'Leie driftsmidler')
    expect(g.begrep).toBe('leie_driftsmidler')
    expect(g.begrep).not.toBe('renovasjon')
    expect(g.epoke).toBe('for_feb_2026')

    // OG DET AVGJOERENDE: leasing er ikke butikksjefens kostnad. Var den
    // det, hadde hele oevelsen vaert forgjeves - da ville en gammel fil
    // vist leasingen til butikksjefen, bare med riktig NAVN.
    expect(BUTIKKSJEF_BEGREP as readonly string[]).not.toContain(g.begrep)
  })

  it('KANARI: hele det gamle formatet leses som seg selv, ikke som dagens', () => {
    // Hvert par: samme kode betyr noe ANNET i dag. Slo oppslaget paa
    // koden alene, ville begge kolonnene vaert like.
    const gamle: Array<[string, string, Kontobegrep, Kontobegrep]> = [
      ['630', 'Utstyr & verktøy', 'utstyr_verktoy', 'leie_driftsmidler'],
      ['632', 'Rep & vedlikehold', 'rep_vedlikehold', 'utstyr_verktoy'],
      ['634', 'Pengehåndtering', 'pengehandtering', 'rep_vedlikehold'],
      ['636', 'Kontorrekvisita', 'kontorrekvisita', 'pengehandtering'],
      ['637', 'Telefon', 'telefon', 'fremmedtjenester_vakthold'],
      ['744', 'Kassedifferanse', 'kassedifferanse', 'forsikringer'],
    ]
    for (const [kode, navn, gammelt, idag] of gamle) {
      const g = slaaOppKonto(kode, navn)
      expect(g.begrep, `${kode} ${navn}`).toBe(gammelt)
      expect(g.epoke, `${kode} ${navn}`).toBe('for_feb_2026')
      expect(gammelt, `${kode}: gammelt og nytt begrep er like - da maaler raden ingenting`)
        .not.toBe(idag)
    }
  })

  it('KANARI: det gamle formatet er faktisk registrert — ellers måler testen over ingenting', () => {
    // Uten denne ville testen over bestått også om vi bare hadde slettet
    // de gamle parene: da kastes det med «ukjent», og fila kan ikke
    // importeres i det hele tatt — som er nøyaktig det 0203 fjernet.
    const gamle = registrertePar().filter((p) => p.epoke === 'for_feb_2026')
    expect(gamle.length).toBeGreaterThanOrEqual(14)
    expect(gamle.map((p) => p.kode)).toContain('628')
  })
})

describe('registeret henger sammen med tilgangsgrensen', () => {
  // `BUTIKKSJEF_DRIFT_KODER` er en RLS-grense siden 0192, og den er skrevet
  // i RÅ KODER. Da må kodene bety det vi tror i formatet vi importerer.
  // Binder de to filene sammen, slik `lonnskost-koder.test.ts` gjør.
  const FORVENTET: Record<string, Kontobegrep> = {
    '627': 'renhold',
    '628': 'renovasjon',
    '629': 'broyting',
    '632': 'utstyr_verktoy',
    '633': 'forbruksmateriell',
    '634': 'rep_vedlikehold',
    '636': 'pengehandtering',
    '638': 'kontorrekvisita',
    '746': 'kassedifferanse',
  }

  it('dekker nøyaktig kodene butikksjefen ser', () => {
    expect(Object.keys(FORVENTET).sort()).toEqual([...BUTIKKSJEF_DRIFT_KODER].sort())
  })

  it('hver synlig kode betyr det tilgangsregelen tror i 2026-formatet', () => {
    const per2026 = new Map(
      registrertePar()
        .filter((p) => p.epoke !== 'for_feb_2026')
        .map((p) => [`${p.kode}|${p.navn}`, p.begrep]),
    )
    for (const kode of BUTIKKSJEF_DRIFT_KODER) {
      const treff = [...per2026.entries()]
        .filter(([n]) => n.startsWith(`${kode}|`))
        .map(([, b]) => b)
      expect(treff, `kode ${kode}`).toContain(FORVENTET[kode])
    }
  })

  it('ingen synlig kode betyr noe annet i det gamle formatet uten at vi vet det', () => {
    // Dokumenterer hvorfor grensen ikke kan staa i koder: paa en fil fra
    // foer februar 2026 betyr 628 «Leie driftsmidler», som butikksjefen
    // IKKE skal se - men koden 628 staar i BUTIKKSJEF_DRIFT_KODER.
    //
    // Fram til 0203 ble det loest ved aa avvise fila. Naa loeses det ved
    // at raden baerer begrepet.
    const gamleSynlige = registrertePar()
      .filter((p) => p.epoke === 'for_feb_2026')
      .filter((p) => (BUTIKKSJEF_DRIFT_KODER as readonly string[]).includes(p.kode))
      .filter((p) => p.begrep !== FORVENTET[p.kode])
    expect(gamleSynlige.map((p) => `${p.kode} ${p.navn}`)).toContain('628 leie driftsmidler')
  })
})

// =====================================================================
// HVA EN GAMMEL FIL FAKTISK VISER BUTIKKSJEFEN
// =====================================================================
//
// Dette er beviset paa at 0203 gjoer det den lover. Vi tar hvert par fra
// det gamle skjemaet og spoer: naar denne raden ligger i basen med sitt
// begrep, ser butikksjefen den?
//
// Svaret skal vaere: de paavirkbare ja, admin-kostnadene nei - uavhengig
// av at kodene har flyttet seg. En kode som betyr «Pengehaandtering» i
// 2025 og «Rep & vedlikehold» i 2026 skal vaere synlig begge aar, fordi
// BEGGE er butikksjefens kostnader. Og 628 skal vaere synlig i 2026
// (renovasjon) og skjult i 2025 (leasing) - samme tall, to svar.
// =====================================================================
describe('det gamle skjemaet gjennom tilgangsgrensen', () => {
  // Hvert navn her er en BESLUTNING. Vokser lista uten at noen har tatt
  // stilling, blir dette roedt - og det er meningen: et nytt gammelt par
  // som sniker seg inn i butikksjefens verden skal ikke gaa stille.
  const SYNLIG_FRA_GAMMEL_EPOKE = [
    'forbruksmateriell',        // 631 den gang, 633 i dag
    'kassedifferanse',          // 744 den gang, 746 i dag
    'kontorrekvisita',          // 636 den gang, 638 i dag
    'pengehandtering',          // 634 den gang, 636 i dag
    'renhold_og_renovasjon',    // 627 den gang; splittet i 627 + 628
    'rep_vedlikehold',          // 632 den gang, 634 i dag
    'utstyr_verktoy',           // 630 den gang, 632 i dag
  ]

  const gamleBegrep = [...new Set(
    registrertePar().filter((p) => p.epoke === 'for_feb_2026').map((p) => p.begrep),
  )]

  it('noeyaktig de paavirkbare kostnadene er synlige', () => {
    const synlige = gamleBegrep
      .filter((b) => (BUTIKKSJEF_BEGREP as readonly string[]).includes(b))
      .sort()
    expect(synlige).toEqual(SYNLIG_FRA_GAMMEL_EPOKE)
  })

  it('KANARI: leasing, telefon og forsikring er IKKE med', () => {
    // De tre er admin-kostnader som laa paa koder butikksjefen ser i
    // dag. Slipper de gjennom, har grensen sluttet aa virke - og det
    // ville sett ut som om alt var i orden, for navnene er riktige.
    for (const b of ['leie_driftsmidler', 'telefon', 'forsikringer', 'data_kortsystem']) {
      expect(gamleBegrep, `${b} finnes ikke i det gamle skjemaet - kanarifuglen maaler ingenting`)
        .toContain(b)
      expect(BUTIKKSJEF_BEGREP as readonly string[], `${b} er synlig for butikksjef`)
        .not.toContain(b)
    }
  })

  it('KANARI: 628 er skjult i 2025 og synlig i 2026 — samme tall, to svar', () => {
    const gammel = slaaOppKonto('628', 'Leie driftsmidler').begrep
    const ny = slaaOppKonto('628', 'Renovasjon').begrep
    expect(BUTIKKSJEF_BEGREP as readonly string[]).not.toContain(gammel)
    expect(BUTIKKSJEF_BEGREP as readonly string[]).toContain(ny)
  })
})

describe('normaliser', () => {
  it('stripper kode, skilletegn og store bokstaver', () => {
    expect(normaliser('627 Renhold')).toBe('renhold')
    expect(normaliser('Arb.avg av lønn')).toBe('arb avg av lønn')
    expect(normaliser('Fremmedtj & vakth')).toBe('fremmedtj vakth')
  })

  it('beholder æ, ø og å', () => {
    expect(normaliser('Brøyting')).toBe('brøyting')
    expect(normaliser('Påløpte feriepenger')).toBe('påløpte feriepenger')
  })
})

describe('BUTIKKSJEF_BEGREP speiler kodelistene', () => {
  // Grensen finnes i to former: koder for stasjonsarkene, begrep for
  // bilagsbufferen (0199). De maa bety det samme, ellers ser en
  // butikksjef ulike ting avhengig av hvilken kilde tallet kom fra.
  //
  // Bufferen er den farlige av de to: den baerer tolv maaneder bakover,
  // og de eldste radene er fra skjemaet foer februar 2026 der 628 var
  // «Leie driftsmidler». Derfor kan grensen der ikke skrives i koder.
  it('hver synlig kode har sitt begrep i lista', () => {
    const per2026 = registrertePar().filter((p) => p.epoke !== 'for_feb_2026')
    for (const kode of BUTIKKSJEF_KOSTNAD_KODER) {
      const begreper = per2026.filter((p) => p.kode === kode).map((p) => p.begrep)
      expect(begreper.length, `kode ${kode} mangler i registeret`).toBeGreaterThan(0)
      for (const b of begreper) {
        expect(BUTIKKSJEF_BEGREP as readonly string[], `kode ${kode} -> ${b}`).toContain(b)
      }
    }
  })

  it('KANARI: ingen begrep i lista hoerer til en kode butikksjefen IKKE ser', () => {
    // Uten denne kunne lista vokse med noe som aldri ble besluttet -
    // og en generert plan ville nevnt en admin-kostnad.
    //
    // TO LEDD, OG DE MAALER HVER SIN TING.
    //
    // 1) Begrepet maa FINNES i registeret - i en av epokene. Et begrep
    //    ingen kode peker paa er en linje i lista som aldri treffer noe.
    //    `renhold_og_renovasjon` finnes bare i den gamle epoken, saa et
    //    filter paa 2026 alene ville felt den av feil grunn.
    //
    // 2) Bare 2026-KODENE maa ligge i `BUTIKKSJEF_KOSTNAD_KODER`. Den
    //    lista beskriver DAGENS skjema, og de gamle kodene er nettopp
    //    der de to beskrivelsene har lov til aa vaere uenige:
    //    `utstyr_verktoy` var 630 den gang og er 632 i dag.
    const alle = registrertePar()
    for (const b of BUTIKKSJEF_BEGREP) {
      const treff = alle.filter((p) => p.begrep === b)
      expect(treff.length, `begrep ${b} finnes ikke i registeret`).toBeGreaterThan(0)
      for (const p of treff.filter((x) => x.epoke !== 'for_feb_2026')) {
        expect(BUTIKKSJEF_KOSTNAD_KODER, `begrep ${b} -> kode ${p.kode}`).toContain(p.kode)
      }
    }
  })

  it('KANARI: ledd 2 ville sett en kode som ikke hoerer hjemme', () => {
    // Uten denne kunne filteret paa epoke ha tomt ut hele loekka, og
    // testen over vaert groenn fordi den ikke sjekket noe.
    const per2026 = registrertePar().filter((p) => p.epoke !== 'for_feb_2026')
    const sjekkede = (BUTIKKSJEF_BEGREP as readonly string[])
      .flatMap((b) => per2026.filter((p) => p.begrep === b))
    expect(sjekkede.length, 'ingen 2026-par ble sjekket i det hele tatt')
      .toBeGreaterThanOrEqual(18)
    // `telefon` staar paa 639 i dag, og 639 er ikke butikksjefens.
    expect(BUTIKKSJEF_KOSTNAD_KODER).not.toContain('639')
  })

  it('KANARI: «leie_driftsmidler» er IKKE i lista', () => {
    // Det er nettopp den 628 betydde foer februar 2026, og den grensen
    // hele oevelsen finnes for.
    expect(BUTIKKSJEF_BEGREP as readonly string[]).not.toContain('leie_driftsmidler')
  })
})
