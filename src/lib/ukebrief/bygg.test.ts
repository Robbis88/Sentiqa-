// =====================================================================
// Vakt over ukebriefen.
//
// Briefen sender seg selv. Det finnes ingen som leser korrektur mandag
// morgen, så reglene må bevises her — og bevises RØDE. Flere av testene
// under bruker syntetiske signaler som ingen kilde lager i dag; det er
// med vilje. En test som bare kjører de ekte kildene måler forutsetningen
// «kildene oppfører seg pent», ikke regelen «briefen tvinger dem til det».
// =====================================================================

import { describe, it, expect } from 'vitest'
import { byggUkebrief, velgHandlinger, ukenummer, sisteHeleUke, forrigeUke, MAKS_HANDLINGER, MAKS_PER_BOLK } from './bygg'
import type { Rangert, Ukedata } from './type'

function ukedata(over: Partial<Ukedata> = {}): Ukedata {
  return {
    stasjonNavn: 'Teststasjon',
    ukeMandag: '2026-08-24',
    omsetning: 400000,
    omsetningIfjor: 400000,
    bpUke: null,
    avdelinger: [],
    utsolgt: [],
    treff: { antall: 10, snittTreffPst: 90 },
    timer: { brukt: 200, ukesramme: 200 },
    tilbakemeldinger: { antall: 0, ulest: 0, harAlvorlig: false },
    hull: [],
    ...over,
  }
}

function signal(over: Partial<Rangert> = {}): Rangert {
  return {
    id: 'x', merke: 'Test', tittel: 'Test', detalj: '', niva: 'folg', lenke: '/',
    grunnlag: 'fakta', retning: 'darlig', poeng: 300, ...over,
  }
}

describe('ukenummer', () => {
  // 1. januar 2026 er en torsdag, så uke 1 starter mandag 29. desember 2025.
  it('følger torsdagsregelen', () => {
    expect(ukenummer('2025-12-29')).toBe(1)
    expect(ukenummer('2026-08-24')).toBe(35)
  })
})

describe('sisteHeleUke', () => {
  // Uke 35 er 24.-30. august 2026, uke 36 er 31.08.-06.09.
  const uker = ['2026-08-31', '2026-08-24', '2026-08-17']

  it('tar uken som er ferdig, ikke den som er nest nyest', () => {
    // Onsdag i uke 36: uke 36 loeper fortsatt, uke 35 er ferdig.
    expect(sisteHeleUke(uker, '2026-09-02')).toBe('2026-08-24')
  })

  // REGRESJONEN. Stopper importen paa en soendag, er den NYESTE uken
  // komplett - og «nest nyeste» hoppet da en uke for langt tilbake.
  it('tar den nyeste naar den nyeste allerede er ferdig', () => {
    expect(sisteHeleUke(['2026-08-24', '2026-08-17'], '2026-09-02')).toBe('2026-08-24')
  })

  it('faller tilbake paa den nyeste naar ingen uke er ferdig', () => {
    expect(sisteHeleUke(['2026-08-31'], '2026-09-02')).toBe('2026-08-31')
  })

  it('gir null uten uker i det hele tatt', () => {
    expect(sisteHeleUke([], '2026-09-02')).toBeNull()
  })
})

describe('forrigeUke', () => {
  // Uke 36 er 31.08-06.09 2026; uke 35 er 24.-30. august.
  it('peker paa uken som ble ferdig, uansett hvilken dag jobben kjoerer', () => {
    for (const dag of ['2026-08-31', '2026-09-02', '2026-09-06']) {
      expect(sisteHeleUke([forrigeUke(dag)], '2999-01-01')).toBe('2026-08-24')
    }
  })

  // DETTE er hele poenget: en gjentatt kjoering maa treffe SAMME uke, ellers
  // kjenner ikke duplikatsperren igjen det som alt er sendt.
  it('gir samme uke naar jobben gjentas senere i uken', () => {
    expect(forrigeUke('2026-09-02')).toBe(forrigeUke('2026-08-31'))
  })

  it('haandterer soendag uten aa hoppe en uke fram', () => {
    expect(forrigeUke('2026-09-06')).toBe('2026-08-24')
    expect(forrigeUke('2026-09-07')).toBe('2026-08-31')
  })
})

describe('velgHandlinger', () => {
  // KANARIFUGL. Ingen ekte kilde setter både `mangler_data` og `handling`
  // i dag — så uten dette syntetiske signalet ville testen bestått selv om
  // regelen ble slettet, og målt kildene i stedet for regelen.
  it('lar aldri et signal uten datagrunnlag foreslå noe', () => {
    const ut = velgHandlinger([
      signal({ id: 'blind', grunnlag: 'mangler_data', handling: 'Gjør noe drastisk' }),
    ])
    expect(ut).toHaveLength(0)
  })

  // KANARIFUGL. Åtte signaler som alle vil foreslå noe.
  it('slipper aldri gjennom flere enn taket', () => {
    const mange = Array.from({ length: 8 }, (_, i) =>
      signal({ id: `s${i}`, handling: `Handling ${i}`, poeng: 900 - i }))
    expect(velgHandlinger(mange)).toHaveLength(MAKS_HANDLINGER)
  })

  it('tar dem i rangert rekkefølge, ikke i innsettingsrekkefølge', () => {
    const ut = velgHandlinger([
      signal({ id: 'lav', handling: 'Sist', poeng: 100 }),
      signal({ id: 'hoy', handling: 'Først', poeng: 900 }),
    ].sort((a, b) => b.poeng - a.poeng))
    expect(ut.map((h) => h.fraSignal)).toEqual(['hoy', 'lav'])
  })
})

describe('byggUkebrief', () => {
  it('gir nøyaktig samme brev for samme uke', () => {
    const d = ukedata({ omsetning: 500000, omsetningIfjor: 400000, utsolgt: [{ navn: 'Kaffe', taptKr: 8000, dager: 4 }] })
    expect(JSON.stringify(byggUkebrief(d))).toBe(JSON.stringify(byggUkebrief(d)))
  })

  // Regelen fra AGENTS.md, oversatt: ingen anbefaling uten et tall bak.
  // Bolkene kappes ved MAKS_PER_BOLK, så dette kan brytes av kapping alene.
  it('lar aldri en handling peke på et signal brevet ikke viser', () => {
    const d = ukedata({
      omsetning: 300000,
      omsetningIfjor: 400000,
      bpUke: 380000,
      utsolgt: [{ navn: 'Kaffe', taptKr: 12000, dager: 5 }],
      treff: { antall: 8, snittTreffPst: 55 },
      timer: { brukt: 240, ukesramme: 200 },
      tilbakemeldinger: { antall: 3, ulest: 2, harAlvorlig: true },
      avdelinger: [
        { kode: '20', navn: 'Bakeri', omsetning: 10000, ifjor: 40000, vekstPst: -75 },
        { kode: '30', navn: 'Kiosk', omsetning: 12000, ifjor: 45000, vekstPst: -73 },
      ],
    })
    const b = byggUkebrief(d)
    const vist = new Set([...b.bra, ...b.oppmerksomhet].map((s) => s.id))
    expect(b.handlinger.length).toBeGreaterThan(0)
    for (const h of b.handlinger) expect(vist.has(h.fraSignal)).toBe(true)
    expect(b.oppmerksomhet.length).toBeLessThanOrEqual(MAKS_PER_BOLK)
  })

  it('flytter det vi ikke kan vurdere ut av funnene', () => {
    const b = byggUkebrief(ukedata({ treff: null, timer: { brukt: 200, ukesramme: null } }))
    const ider = [...b.bra, ...b.oppmerksomhet].map((s) => s.id)
    expect(ider).not.toContain('treff-mangler')
    expect(ider).not.toContain('timer-mangler')
    expect(b.viIkkeVet.join(' ')).toContain('Produksjonstreff')
    expect(b.viIkkeVet.join(' ')).toContain('ramme')
  })

  it('navngir hullene i stedet for å si at noe mangler', () => {
    const b = byggUkebrief(ukedata({ hull: [{ kilde: 'Timesalg', dagerMangler: 2 }] }))
    expect(b.viIkkeVet.some((t) => t.includes('Timesalg') && t.includes('2 dager'))).toBe(true)
  })

  it('tier om budsjettet når det ikke finnes', () => {
    const b = byggUkebrief(ukedata({ bpUke: null, omsetning: 300000, omsetningIfjor: 400000 }))
    expect([...b.bra, ...b.oppmerksomhet].map((s) => s.id)).not.toContain('salg-bp')
  })

  // Arven fra `avdelingsSignaler`: en kategori som faller SAMMEN MED
  // butikken er vær, ikke ledelse. Skriver noen en egen variant her, ryker
  // denne — og det er nettopp da den skal ryke.
  it('varsler ikke om en kategori som faller sammen med butikken', () => {
    const b = byggUkebrief(ukedata({
      omsetning: 200000,
      omsetningIfjor: 400000,
      avdelinger: [{ kode: '20', navn: 'Bakeri', omsetning: 20000, ifjor: 40000, vekstPst: -50 }],
    }))
    expect(b.oppmerksomhet.map((s) => s.id)).not.toContain('avd-20')
  })

  it('finner den som går motsatt vei av en butikk i vekst', () => {
    const b = byggUkebrief(ukedata({
      omsetning: 600000,
      omsetningIfjor: 400000,
      avdelinger: [{ kode: '20', navn: 'Bakeri', omsetning: 20000, ifjor: 40000, vekstPst: -50 }],
    }))
    expect(b.oppmerksomhet.map((s) => s.id)).toContain('avd-20')
  })

  it('sier ifra når det gikk bra, ikke bare når det gikk galt', () => {
    const b = byggUkebrief(ukedata({
      omsetning: 500000,
      omsetningIfjor: 400000,
      avdelinger: [{ kode: '40', navn: 'Ferskmat', omsetning: 60000, ifjor: 20000, vekstPst: 200 }],
    }))
    expect(b.bra.map((s) => s.id)).toContain('avd-opp-40')
    expect(b.bra.map((s) => s.id)).toContain('salg-ifjor')
  })

  it('foreslår ingenting i en uke uten funn', () => {
    const b = byggUkebrief(ukedata())
    expect(b.handlinger).toHaveLength(0)
    expect(b.ingress).toContain('Ingenting krever oppmerksomhet')
  })

  // Meldingene kan gjelde krenkelse eller uhell. Briefen skal kunne bli en
  // e-post, og en e-post kan videresendes — derfor teller den, og siterer aldri.
  it('teller meldingene fra de ansatte uten å gjengi dem', () => {
    const b = byggUkebrief(ukedata({ tilbakemeldinger: { antall: 3, ulest: 2, harAlvorlig: true } }))
    const s = b.oppmerksomhet.find((x) => x.id === 'tilbakemelding')
    expect(s).toBeDefined()
    expect(s!.endring).toBe('2 ulest')
    expect(s!.detalj).toContain('Innholdet står i Sentiqa')
  })

  it('merker anslaget om utsolgt som en hypotese, ikke et faktum', () => {
    const b = byggUkebrief(ukedata({ utsolgt: [{ navn: 'Kaffe', taptKr: 12000, dager: 5 }] }))
    const s = b.oppmerksomhet.find((x) => x.id === 'utsolgt')
    expect(s!.grunnlag).toBe('hypotese')
    expect(s!.detalj).toContain('anslag')
  })

  // Ukesrammen er fordelt fra en månedsramme. Sier briefen «over budsjett»
  // uten å si det, har systemet gjort en fordeling om til et faktum.
  it('merker det som er fordelt fra måneden som indikasjon', () => {
    const b = byggUkebrief(ukedata({ timer: { brukt: 240, ukesramme: 200 }, bpUke: 500000, omsetning: 400000 }))
    for (const id of ['timer', 'salg-bp']) {
      const s = [...b.bra, ...b.oppmerksomhet].find((x) => x.id === id)
      expect(s!.grunnlag).toBe('indikasjon')
      expect(s!.detalj.toLowerCase()).toContain('fordelt')
    }
  })
})
