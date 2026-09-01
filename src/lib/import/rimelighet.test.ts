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

    // Og her er beviset paa at grupperingen betyr noe: 10 000 kr.
    //
    //   mot soendagsmedianen 92 000  ->  11 %  ->  FANGET
    //   mot tirsdagsmedianen 38 000  ->  26 %  ->  ville sluppet unna
    //
    // Samme belop, to svar. Uten ukedagsgrupperingen ville en soendag
    // som mistet 89 % av salget sett normal ut.
    //
    // (Foerste utgave brukte 40 000 her, skrevet mens terskelen var 0,5.
    // Med 0,2 er 40 000 en STILLE soendag, ikke en oedelagt en - og det
    // er riktig. Testen maalte terskelen, ikke grupperingen.)
    const oedelagt = vurderDag({ dato: '2026-08-30', kroner: 10000 }, foer('2026-08-30'))
    expect(oedelagt, 'en soendag paa 10 000 skal fanges').not.toBeNull()
    expect(oedelagt!.slag).toBe('for_lavt')
    expect(Math.round(oedelagt!.median)).toBeGreaterThan(80000)
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

// =====================================================================
// DE ELLEVE EKTE STILLE DAGENE
//
// En skanning 13 maaneder bakover over alle fem stasjoner, med terskelen
// paa 0,5, ga elleve treff. INGEN av dem var tapte data - alle hadde
// normalt antall rader (66-125). To var julaften og nyttaarsaften, resten
// enkeltlordager.
//
// De staar her fordi de er det VANSKELIGE tilfellet: en vakt som roper om
// disse blir slaatt av, og da beskytter den ingenting. Terskelen ble
// derfor flyttet til 0,2 - og disse elleve er beviset paa at den er
// riktig satt.
//
// Tallene er de faktiske avvikene fra skanningen.
// =====================================================================
const STILLE_DAGER: { navn: string; kroner: number; median: number }[] = [
  { navn: '2025-12-24 Dale (julaften)', kroner: 6103, median: 27053 },
  { navn: '2025-08-30 Dale', kroner: 13998, median: 40418 },
  { navn: '2025-09-20 Dale', kroner: 13046, median: 34153 },
  { navn: '2025-10-11 Dale', kroner: 12904, median: 30143 },
  { navn: '2026-07-11 Boenes', kroner: 8894, median: 20250 },
  { navn: '2026-07-25 Boenes', kroner: 8596, median: 19275 },
  { navn: '2026-03-28 Varden', kroner: 13808, median: 29908 },
  { navn: '2025-10-04 Lone', kroner: 10439, median: 22494 },
  { navn: '2025-12-31 Dale (nyttaarsaften)', kroner: 12975, median: 26786 },
  { navn: '2026-07-30 Boenes', kroner: 9464, median: 19249 },
  { navn: '2025-12-31 Lone (nyttaarsaften)', kroner: 7809, median: 15728 },
]

describe('terskelen, prøvd mot 13 måneder med ekte data', () => {
  // Bygger en historikk der medianen blir nøyaktig `median`: fire like
  // dager gir samme median som ett tall, og ukedagen holdes lik.
  const historikkMed = (median: number, ukedag: string) =>
    [0, 7, 14, 21].map((n) => ({
      dato: new Date(Date.UTC(2026, 4, Number(ukedag) + n)).toISOString().slice(0, 10),
      kroner: median,
    }))

  it('KANARIFUGL: tier om alle elleve ekte stille dager', () => {
    const roper: string[] = []
    for (const d of STILLE_DAGER) {
      const hist = historikkMed(d.median, '4')
      const dagen = { dato: '2026-05-32'.replace('32', '25'), kroner: d.kroner }
      // Samme ukedag som historikken: 25. mai 2026 er en mandag, og
      // historikken over starter på 4. mai, også mandag.
      const funn = vurderDag(dagen, hist)
      if (funn) roper.push(`${d.navn}: ${Math.round(funn.avvik * 100)} %`)
    }
    expect(roper, `vakten roper om ekte stille dager:\n  ${roper.join('\n  ')}`)
      .toEqual([])
  })

  it('KANARIFUGL: og feller likevel 25. august', () => {
    // Marginen er hele poenget. Verste ekte stille dag var -77 %,
    // den ødelagte lå på -98 %. Slipper denne gjennom samtidig som
    // testen over er grønn, er terskelen satt for løst.
    const funn = vurderDag(den('2026-08-25'), foer('2026-08-25'))
    expect(funn, '25. august slipper gjennom med den nye terskelen')
      .not.toBeNull()
    expect(Math.round(funn!.avvik * 100)).toBeLessThan(-95)
  })
})
