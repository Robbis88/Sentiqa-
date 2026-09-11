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
    // deler kode og de fleste bokstavene.
    expect(slaaOppKonto('627', 'Renhold').begrep).toBe('renhold')
    expect(() => slaaOppKonto('627', 'Renhold-renovasj')).toThrow(ParserFeil)
  })

  it('kaster når navnet mangler', () => {
    expect(() => slaaOppKonto('627', '')).toThrow(/mangler navn/)
    expect(() => slaaOppKonto('627', '   ')).toThrow(/mangler navn/)
  })

  it('kaster på et par ingen har tatt stilling til', () => {
    expect(() => slaaOppKonto('651', 'Droneleie')).toThrow(ParserFeil)
    expect(() => slaaOppKonto('651', 'Droneleie')).toThrow(/endret rapportlinjene/)
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
    expect(() => slaaOppKonto('628', 'Leie driftsmidler')).toThrow(ParserFeil)
    expect(() => slaaOppKonto('628', 'Leie driftsmidler')).toThrow(/FØR februar 2026/)

    // Og om noen «fikser» det ved å falle tilbake på koden, skal dette
    // fortsatt ikke gi renovasjon.
    let begrep: Kontobegrep | null = null
    try {
      begrep = slaaOppKonto('628', 'Leie driftsmidler').begrep
    } catch {
      begrep = null
    }
    expect(begrep).not.toBe('renovasjon')
  })

  it('KANARI: hele det gamle formatet avvises, ikke bare 628', () => {
    const gamle: Array<[string, string]> = [
      ['630', 'Utstyr & verktøy'],
      ['632', 'Rep & vedlikehold'],
      ['634', 'Pengehåndtering'],
      ['636', 'Kontorrekvisita'],
      ['637', 'Telefon'],
      ['744', 'Kassedifferanse'],
    ]
    for (const [kode, navn] of gamle) {
      expect(() => slaaOppKonto(kode, navn), `${kode} ${navn}`).toThrow(/FØR februar 2026/)
    }
  })

  it('KANARI: det gamle formatet er faktisk registrert — ellers måler testen over ingenting', () => {
    // Uten denne ville testen over bestått også om vi bare hadde slettet
    // de gamle parene: da kastes det med «ukjent», ikke «gammelt format»,
    // og brukeren får en beskjed som ikke forklarer noe.
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
    // Dokumenterer hullet: på en fil fra før februar 2026 betyr 628
    // «Leie driftsmidler», som butikksjefen IKKE skal se. Det er grunnen
    // til at slaaOppKonto avviser gamle filer i stedet for å lese dem.
    const gamleSynlige = registrertePar()
      .filter((p) => p.epoke === 'for_feb_2026')
      .filter((p) => (BUTIKKSJEF_DRIFT_KODER as readonly string[]).includes(p.kode))
      .filter((p) => p.begrep !== FORVENTET[p.kode])
    expect(gamleSynlige.map((p) => `${p.kode} ${p.navn}`)).toContain('628 leie driftsmidler')
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
    const per2026 = registrertePar().filter((p) => p.epoke !== 'for_feb_2026')
    for (const b of BUTIKKSJEF_BEGREP) {
      const koder = per2026.filter((p) => p.begrep === b).map((p) => p.kode)
      expect(koder.length, `begrep ${b} finnes ikke i registeret`).toBeGreaterThan(0)
      for (const k of koder) {
        expect(BUTIKKSJEF_KOSTNAD_KODER, `begrep ${b} -> kode ${k}`).toContain(k)
      }
    }
  })

  it('KANARI: «leie_driftsmidler» er IKKE i lista', () => {
    // Det er nettopp den 628 betydde foer februar 2026, og den grensen
    // hele oevelsen finnes for.
    expect(BUTIKKSJEF_BEGREP as readonly string[]).not.toContain('leie_driftsmidler')
  })
})
