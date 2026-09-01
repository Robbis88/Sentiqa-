import { describe, it, expect } from 'vitest'
import { vurderDag, vurderDager, type Dag } from './rimelighet'

// =====================================================================
// FIXTUREN ER LAGUNEPARKENS EKTE AUGUST 2026.
//
// Tallene er lest ut av basen 01.09.2026, og 25. august er den ekte
// feilen: 676 kr paa 8 rader, mot nabotirsdager paa 37-39 000.
//
// En vakt som ikke feller den dagen, maaler ingenting.
// =====================================================================
const AUGUST: Dag[] = [
  { dato: '2026-08-01', kroner: 28670 },
  { dato: '2026-08-02', kroner: 92376 },
  { dato: '2026-08-03', kroner: 33011 },
  { dato: '2026-08-04', kroner: 38974 },
  { dato: '2026-08-05', kroner: 37784 },
  { dato: '2026-08-06', kroner: 37696 },
  { dato: '2026-08-07', kroner: 39281 },
  { dato: '2026-08-08', kroner: 34368 },
  { dato: '2026-08-09', kroner: 74315 },
  { dato: '2026-08-10', kroner: 42388 },
  { dato: '2026-08-11', kroner: 38388 },
  { dato: '2026-08-12', kroner: 41247 },
  { dato: '2026-08-13', kroner: 36602 },
  { dato: '2026-08-14', kroner: 40576 },
  { dato: '2026-08-15', kroner: 40969 },
  { dato: '2026-08-16', kroner: 91659 },
  { dato: '2026-08-17', kroner: 39266 },
  { dato: '2026-08-18', kroner: 37158 },
  { dato: '2026-08-19', kroner: 46004 },
  { dato: '2026-08-20', kroner: 49632 },
  { dato: '2026-08-21', kroner: 46628 },
  { dato: '2026-08-22', kroner: 39079 },
  { dato: '2026-08-23', kroner: 108273 },
  { dato: '2026-08-24', kroner: 47133 },
  { dato: '2026-08-25', kroner: 676 },      // <- feilen
  { dato: '2026-08-26', kroner: 46192 },
  { dato: '2026-08-27', kroner: 47629 },
  { dato: '2026-08-28', kroner: 51477 },
  { dato: '2026-08-29', kroner: 40816 },
  { dato: '2026-08-30', kroner: 101430 },
  { dato: '2026-08-31', kroner: 43006 },
]

const foer = (dato: string) => AUGUST.filter((d) => d.dato < dato)
const den = (dato: string) => AUGUST.find((d) => d.dato === dato)!

describe('rimelighet', () => {
  it('KANARIFUGL: feller 25. august, den ekte feilen', () => {
    // Uten denne maaler vakten ingenting. 676 kr mot en medianttirsdag
    // paa ~38 000 er 98 % avvik - dagen som kostet 44 578 kr og som
    // hverken /dekning, importloggen eller dublettsjekken kunne se.
    const funn = vurderDag(den('2026-08-25'), foer('2026-08-25'))
    expect(funn, '25. august slipper gjennom').not.toBeNull()
    expect(funn!.slag).toBe('for_lavt')
    expect(Math.round(funn!.avvik * 100)).toBeLessThan(-90)
    expect(funn!.tekst).toMatch(/lavere enn normalt/)
    expect(funn!.tekst).toMatch(/tirsdag/)
  })

  it('sier IKKE fra om en normal dag', () => {
    // Hver eneste andre dag i august skal vaere stille. En vakt som
    // roper paa normale dager blir slaatt av, og da beskytter den
    // ingenting.
    const stoy = AUGUST
      .filter((d) => d.dato !== '2026-08-25')
      .map((d) => vurderDag(d, foer(d.dato)))
      .filter((f) => f !== null)
    expect(stoy.map((f) => `${f!.dato} ${f!.slag}`), 'falske funn').toEqual([])
  })

  it('soendager maales mot soendager, ikke mot uka', () => {
    // Laguneparkens soendager ligger 2,5x over en tirsdag. Mot et
    // ukesnitt ville HVER soendag sett ut som et avvik, og en halvert
    // tirsdag ville druknet. Dette er hele grunnen til at
    // sammenligningen er per ukedag.
    const soendag = vurderDag(den('2026-08-30'), foer('2026-08-30'))
    expect(soendag, '30. august er en normal soendag').toBeNull()

    // …og en soendag paa tirsdagsnivaa ER et funn.
    const halv = vurderDag({ dato: '2026-08-30', kroner: 40000 }, foer('2026-08-30'))
    expect(halv, 'en soendag paa 40 000 skal fanges').not.toBeNull()
    expect(halv!.slag).toBe('for_lavt')
  })

  it('KANARIFUGL: fanger en maanedsfil lastet paa en enkelt dato', () => {
    // Salgsstatistikk kan lastes ned for et INTERVALL. Importoeren leser
    // foerste dato i «Dato: 01.08.2026 - 31.08.2026», saa hele maaneden
    // ville havnet paa 1. august. Det er den andre halvdelen av vakten.
    const maaned = vurderDag({ dato: '2026-08-25', kroner: 1537283 }, foer('2026-08-25'))
    expect(maaned, 'en hel maaned paa en dag slipper gjennom').not.toBeNull()
    expect(maaned!.slag).toBe('for_hoyt')
    expect(maaned!.tekst).toMatch(/to ganger|maanedsfil|månedsfil/)
  })

  it('tier naar grunnlaget er for tynt', () => {
    // En ny stasjon har ingenting aa sammenligne med. AA rope da ville
    // gjort vakten til stoey akkurat naar noen setter opp Sentiqa for
    // foerste gang - og det er da folk bestemmer seg for om varsler er
    // verdt aa lese.
    const to = [
      { dato: '2026-08-04', kroner: 38974 },
      { dato: '2026-08-11', kroner: 38388 },
    ]
    expect(vurderDag({ dato: '2026-08-18', kroner: 100 }, to)).toBeNull()

    const tre = [...to, { dato: '2026-08-18', kroner: 37158 }]
    expect(vurderDag({ dato: '2026-08-25', kroner: 100 }, tre)).not.toBeNull()
  })

  it('en oedelagt dag drar ikke grunnlaget ned for de neste', () => {
    // DETTE ER GRUNNEN TIL MEDIAN OG IKKE GJENNOMSNITT.
    //
    // Foerste utgave av denne testen sjekket at en tirsdag paa 20 000
    // ble felt etter at 676-dagen var med i grunnlaget. Den feilet - og
    // med rette: 20 000 er 53 % av medianen, altsaa OVER 50 %-grensen.
    // Testen maalte terskelen, ikke paastanden.
    //
    // Paastanden er at GRUNNLAGET holder seg. Den maales direkte:
    // medianen med den oedelagte dagen inne skal vaere nesten den samme
    // som uten. Med gjennomsnitt ville 676-dagen dratt tirsdagsnormalen
    // fra ~38 000 til ~29 000, og en halvert tirsdag ville sluppet unna.
    const tirsdager = AUGUST.filter((d) => new Date(`${d.dato}T12:00:00Z`).getUTCDay() === 2)
    expect(tirsdager.map((d) => d.dato))
      .toEqual(['2026-08-04', '2026-08-11', '2026-08-18', '2026-08-25'])

    const medOedelagt = vurderDag({ dato: '2026-09-01', kroner: 1000 }, AUGUST)!
    const utenOedelagt = vurderDag(
      { dato: '2026-09-01', kroner: 1000 },
      AUGUST.filter((d) => d.dato !== '2026-08-25'),
    )!
    expect(medOedelagt.median).toBeGreaterThan(35000)
    expect(Math.abs(medOedelagt.median - utenOedelagt.median) / utenOedelagt.median)
      .toBeLessThan(0.05)

    // Et gjennomsnitt ville derimot ligget langt under.
    const snitt = tirsdager.reduce((s, d) => s + d.kroner, 0) / tirsdager.length
    expect(snitt).toBeLessThan(30000)
  })

  it('vurderDager tar flere dager i en omgang', () => {
    const nye = [den('2026-08-25'), den('2026-08-26')]
    const funn = vurderDager(nye, foer('2026-08-25'))
    expect(funn.map((f) => f.dato)).toEqual(['2026-08-25'])
  })

  it('null i historikken gir ingen deling paa null', () => {
    const nuller = [
      { dato: '2026-08-04', kroner: 0 },
      { dato: '2026-08-11', kroner: 0 },
      { dato: '2026-08-18', kroner: 0 },
    ]
    expect(vurderDag({ dato: '2026-08-25', kroner: 500 }, nuller)).toBeNull()
  })
})
