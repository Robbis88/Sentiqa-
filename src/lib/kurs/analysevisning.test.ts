// Flaten, ikke beregningsobjektet.
//
// =====================================================================
// SAMME SNAPSHOT HELE VEIEN
// =====================================================================
//
// Kjeden er: beregning → lagret utkast → eier ser snapshotet → eier
// slipper → butikksjef får samme snapshot. Testene under måler at
// tall, dom, forklaring og blokkering er identiske mellom den lagrede
// JSON-en, kortets visningsobjekt, HTML-e-posten og ren tekst.
//
// Tallene er de målte fra produksjon 2026-09-13.

import { describe, expect, it } from 'vitest'
import {
  ingenFeilVei, matkastvisning, medFortegn, RANGERING_UKJENT, samletAvvikvisning,
  rangeringstekst, usynligvisning,
  USYNLIG_AARSAKER, UTEN_KRONEVERDI,
} from './analysevisning'
import { lagSnapshot, lesMatkast, lesUsynlig, ANALYSEVERSJON } from './snapshot'
import { tilEpost } from './epost'
import { byggMaanedsplan, type Maanedsdata, type Maanedstall } from './plan'

/**
 * Tall formateres med HARDT mellomrom. Paastandene skal maale innhold,
 * ikke tegnvalg - samme grep som `plan.test.ts`.
 */
const flat = (s: string) => s.replace(/\s/g, ' ')

const sats = (andel: number) =>
  ({ stasjonId: 's1', aar: 2026, andel, nivaa: 'avdeling' })

function mnd(over: Partial<Maanedstall> & { maaned: string }): Maanedstall {
  return {
    omsetningKr: 1_000_000, omsetningBudsjettKr: 1_000_000, bruttoKr: 500_000,
    matsalgKr: 400_000, matkastKr: 30_000,
    usynligRestKr: -99_999, usynligMatKr: 4_000,
    avvikAntall: 0, matRader: 9, harSvinndata: true, datastatus: 'gruppe',
    personalKr: 300_000, personalBudsjettKr: 300_000,
    paavirkbarDriftKr: 40_000, paavirkbarDriftBudsjettKr: 40_000,
    resultatKr: 50_000,
    ...over,
  }
}

function plan(over: Partial<Maanedsdata> & { historikk: Maanedstall[] }) {
  return byggMaanedsplan({
    stasjonNavn: 'Testeriet', stasjonId: 's1', butikknummer: '4185',
    leverandorer: [], satser: null, kastsats: sats(0.06232289968), forbehold: null,
    ...over,
  })
}

/** Dales faktiske januar–juli, slik produksjonen har dem. */
const DALE: Maanedstall[] = [
  ['2026-01-01', 519573.61, 37861.32, 19034.08],
  ['2026-02-01', 517322.38, 35076.17, -6333.21],
  ['2026-03-01', 545167.87, 36961.30, -2061.95],
  ['2026-04-01', 625019.16, 40898.24, -9991.53],
  ['2026-05-01', 644784.51, 37144.00, -2958.12],
  ['2026-06-01', 724620.49, 32881.44, -5642.90],
  ['2026-07-01', 838292.15, 32018.74, 31902.47],
].map(([m, salg, kast, usy]) => mnd({
  maaned: m as string, matsalgKr: salg as number,
  matkastKr: kast as number, usynligMatKr: usy as number,
}))

// =====================================================================
describe('Dale juli på flaten', () => {
  const p = plan({ stasjonNavn: 'St1 Dale', historikk: DALE })
  const s = lagSnapshot(p)
  const m = matkastvisning(s.matkast)
  const u = usynligvisning(s.usynlig)

  it('viser alle ti feltene', () => {
    expect(m.slag).toBe('bekreftelse')
    if (m.slag === 'ikke_beregnet' || m.slag === 'blokkert') throw new Error('feil gren')
    const som = Object.fromEntries(m.rader.map((r) => [r.navn, r.verdi]))
    expect(flat(som['Matomsetning'])).toBe('838 292')
    expect(flat(som['Synlig kast'])).toBe('32 019')
    expect(flat(som['Kastprosent'])).toBe('3,82 %')
    expect(flat(som['Budsjettert'])).toBe('6,23 %')
    expect(flat(som['Justert kastbudsjett'])).toBe('52 245')
    expect(flat(som['Avvik'])).toBe('−2,41 pp')
    expect(flat(m.rader.find((r) => r.navn === 'Avvik')?.bi ?? ''))
      .toBe('20 226 bedre enn budsjett')
    expect(m.retning).toBe('Kastprosenten faller')
    expect(m.merke).toBe('bekreftelse')
    expect(m.forklaring).toContain('Under kastbudsjettet')
  })

  it('uforklart matavvik: usikker, ikke manko', () => {
    expect(u.slag).toBe('usikker')
    if (u.slag === 'ikke_beregnet' || u.slag === 'blokkert') throw new Error('feil gren')
    expect(u.merke).toBe('usikker måling')
    expect(flat(u.verdi)).toBe('+31 902 kr')
    expect(u.utvikling).toContain('Usikker enkeltmåling')
    expect(u.utvikling).toContain('telling')
    expect(u.utvikling).toContain('periodisering')
    expect(u.utvikling).toContain('fakturaflyt')
    expect(u.forklaring).toContain('teoretisk bruttofortjeneste minus faktisk')
    expect(u.aarsaker).toBe(USYNLIG_AARSAKER)
  })

  it('ordet «manko» og ordet «gevinst» står ingen steder', () => {
    const alt = JSON.stringify([m, u])
    expect(alt.toLowerCase()).not.toContain('manko')
    expect(alt.toLowerCase()).not.toContain('gevinst')
    expect(alt.toLowerCase()).not.toContain('tyveri i juli')
  })

  it('summerer registrert og uforklart avvik uten dobbelttelling', () => {
    const samlet = samletAvvikvisning(s.matkast, s.usynlig)
    expect(samlet?.kr).toBeCloseTo(63921.21, 2)
    expect(samlet?.prosent).toBeCloseTo(7.63, 2)
  })
})

// =====================================================================
describe('retningen sier PERIODEN', () => {
  const medSerie = (usy: number[]) => plan({
    historikk: usy.map((v, i) => mnd({
      maaned: `2026-0${i + 1}-01`, usynligMatKr: v, matkastKr: 20_000,
    })),
  })

  it('Varden-formen: har økt de siste tre månedene', () => {
    const u = usynligvisning(lagSnapshot(medSerie([6174, 3928, -85, 183, 2353, 3133, 3815])).usynlig)
    if (u.slag !== 'retning') throw new Error('forventet retning')
    expect(u.merke).toBe('retning tilgjengelig')
    expect(u.utvikling).toBe('Uforklart matavvik har økt de siste 3 månedene.')
  })

  it('Laguneparken-formen: har falt, men er fortsatt +1 405', () => {
    const u = usynligvisning(
      lagSnapshot(medSerie([11349, 3707, -9895, -7993, 14501, 2511, 1405])).usynlig)
    if (u.slag !== 'retning') throw new Error('forventet retning')
    expect(flat(u.utvikling))
      .toBe('Uforklart matavvik har falt de siste 3 månedene, men er fortsatt +1 405 kr.')
  })

  it('aldri bare «stigende» eller «fallende» uten periode', () => {
    for (const serie of [[6174, 3928, -85, 183, 2353, 3133, 3815],
      [11349, 3707, -9895, -7993, 14501, 2511, 1405]]) {
      const u = usynligvisning(lagSnapshot(medSerie(serie)).usynlig)
      if (u.slag !== 'retning') throw new Error('forventet retning')
      expect(u.utvikling).toContain('de siste 3 månedene')
    }
  })

  it('et overskudd omtales ikke som gevinst', () => {
    const u = usynligvisning(lagSnapshot(medSerie([-1000, -1200, -1400, -1600])).usynlig)
    if (u.slag !== 'retning') throw new Error('forventet retning')
    expect(flat(u.verdi)).toBe('−1 600 kr')
    expect(u.utvikling.toLowerCase()).not.toContain('gevinst')
    expect(u.utvikling).toContain('Overskuddet mot teoretisk bruttofortjeneste')
  })
})

// =====================================================================
describe('blokkert og ikke beregnet er ulike beskjeder', () => {
  it('gammel plan: ikke beregnet, ikke blokkert', () => {
    const m = matkastvisning(null)
    const u = usynligvisning(null)
    expect(m.slag).toBe('ikke_beregnet')
    expect(u.slag).toBe('ikke_beregnet')
    if (m.slag !== 'ikke_beregnet') throw new Error('feil gren')
    expect(m.tekst).toBe('Planen ble laget før mat- og svinnanalysen var tilgjengelig.')
    expect(m.tekst.toLowerCase()).not.toContain('blokkert')
  })

  it('blokkert: årsak og måned, og den forsvinner ikke', () => {
    const p = plan({
      kastsats: null,
      historikk: [1, 2, 3, 4].map((i) => mnd({ maaned: `2026-0${i}-01` })),
    })
    const m = matkastvisning(lagSnapshot(p).matkast)
    expect(m.slag).toBe('blokkert')
    if (m.slag !== 'blokkert') throw new Error('feil gren')
    expect(m.tittel).toBe('Datagrunnlag mangler')
    expect(m.tekst).toContain('Kastbudsjett er ikke lastet opp')
    expect(m.merke).toBe('ikke beregnet')
    // og den er IKKE et punkt
    expect(p.punkter.some((x) => x.loftestang === 'matkast')).toBe(false)
  })

  it('blokkert midt i serien navngir måneden', () => {
    const p = plan({
      historikk: [1, 2, 3, 4].map((i) => mnd({
        maaned: `2026-0${i}-01`, ...(i === 2 ? { avvikAntall: 3 } : {}),
      })),
    })
    const m = matkastvisning(lagSnapshot(p).matkast)
    if (m.slag !== 'blokkert') throw new Error('feil gren')
    expect(m.maaned).toBe('2026-02-01')
  })
})

// =====================================================================
describe('observer vises, men blir aldri et punkt', () => {
  const p = plan({
    // 3 % → 5,5 %, mot 6,23 %. Under hele veien, men på vei opp.
    historikk: [12, 14, 17, 20, 22].map((k, i) => mnd({
      maaned: `2026-0${i + 1}-01`, matkastKr: k * 1_000,
    })),
  })

  it('dommen er observer', () => {
    expect(p.matkast.dom?.slag).toBe('observer')
  })

  it('vises i analyseblokken', () => {
    const m = matkastvisning(lagSnapshot(p).matkast)
    expect(m.slag).toBe('observer')
    expect(m.merke).toBe('observer')
  })

  it('men er verken tiltak eller bekreftelse i punktene', () => {
    expect(p.punkter.some((x) => x.loftestang === 'matkast')).toBe(false)
  })
})

// =====================================================================
describe('rangering', () => {
  it('en mulig rangering sier ingenting', () => {
    expect(rangeringstekst({ mulig: true, kandidater: ['Matkast'] })).toBeNull()
    expect(rangeringstekst({ mulig: true, kandidater: [] })).toBeNull()
  })

  it('en umulig rangering NAVNGIR kandidatene', () => {
    const t = rangeringstekst({
      mulig: false,
      kandidater: ['Personalkostnad mot budsjett', 'Påvirkbare driftskostnader'],
    })
    expect(t).toContain(UTEN_KRONEVERDI)
    expect(t).toContain('2 løftestenger')
    expect(t).toContain('royaltysatser')
    expect(t).toContain('Personalkostnad mot budsjett')
    expect(t).toContain('Påvirkbare driftskostnader')
  })

  it('«ingen peker feil vei» står BARE når det er sant', () => {
    // Tom liste fordi ingenting gikk feil vei — god nyhet.
    expect(ingenFeilVei([], { mulig: true, kandidater: [] })).toBe(true)
    // Tom liste fordi TO gikk feil vei og ingen kunne velges. Samme
    // lengde, motsatt beskjed.
    expect(ingenFeilVei([], { mulig: false, kandidater: ['A', 'B'] })).toBe(false)
    // Kandidater fantes, men ble valgt bort? Da er lista ikke tom.
    expect(ingenFeilVei([{}], { mulig: true, kandidater: ['A'] })).toBe(false)
  })

  // ===================================================================
  // EN PLAN FRA FØR `0216` SKAL IKKE FRISKMELDES
  // ===================================================================
  //
  // Kolonnen er `null` på alt som ble skrevet før feltet fantes, og vi
  // vet ikke hva den motoren gjorde — den kan ha valgt et hovedtiltak
  // på rekkefølgen i `LOFTESTENGER` uten å lagre at den gjorde det.
  //
  // Sida skrev `?? { mulig: true, kandidater: [] }`. Det er ikke en
  // standardverdi, det er en påstand: «rangeringen var mulig, og det
  // fantes ingen kandidater». Da kunne flaten skrive «Ingen av
  // løftestengene peker feil vei denne måneden» om en plan ingen har
  // målt.
  it('null er IKKE TILGJENGELIG, ikke «alt i orden»', () => {
    expect(rangeringstekst(null)).toBe(RANGERING_UKJENT)
    expect(RANGERING_UKJENT).toContain('ikke tilgjengelig')
    expect(RANGERING_UKJENT).toContain('før')
  })

  it('null gir ALDRI «ingen løftestenger peker feil vei»', () => {
    expect(ingenFeilVei([], null)).toBe(false)
    // Den gamle fallbacken, skrevet ut: dette er påstanden som ble
    // laget av ingenting.
    expect(ingenFeilVei([], { mulig: true, kandidater: [] })).toBe(true)
  })

  it('manglende royaltyverdi blir ikke 0', () => {
    const p = plan({
      satser: null,
      historikk: [40, 36, 32, 30, 28].map((k, i) => mnd({
        maaned: `2026-0${i + 1}-01`, matkastKr: k * 1_000, resultatKr: 90_000 - i * 25_000,
      })),
    })
    const mk = p.punkter.find((x) => x.loftestang === 'matkast')
    expect(mk?.slag).toBe('tiltak')
    expect(mk?.kronerIAret).toBeNull()
  })
})

// =====================================================================
describe('SAMME SNAPSHOT: lagret JSON → kort → HTML → ren tekst', () => {
  const p = plan({ stasjonNavn: 'St1 Dale', historikk: DALE })
  const s = lagSnapshot(p)
  // Gjennom JSON, som basen gjør det.
  const lagret = JSON.parse(JSON.stringify(s)) as { matkast: unknown; usynlig: unknown }
  const e = tilEpost(p, 'https://x', lagret)

  it('snapshotet bærer versjon, måned og tidspunkt', () => {
    expect(s.matkast.analyseversjon).toBe(ANALYSEVERSJON)
    expect(s.matkast.beregnetForMaaned).toBe('2026-07-01')
    expect(s.matkast.beregnetTid).toMatch(/^\d{4}-\d{2}-\d{2}T/)
    expect(s.usynlig.vindu).toBe(0)
  })

  it('runder tur-retur JSON uten å miste noe', () => {
    expect(lesMatkast(lagret.matkast)).toEqual(s.matkast)
    expect(lesUsynlig(lagret.usynlig)).toEqual(s.usynlig)
  })

  const m = matkastvisning(lesMatkast(lagret.matkast))
  const u = usynligvisning(lesUsynlig(lagret.usynlig))

  it('HTML-e-posten har de samme tallene som kortet', () => {
    if (m.slag === 'ikke_beregnet' || m.slag === 'blokkert') throw new Error('feil gren')
    for (const r of m.rader) {
      expect(flat(e.html), `${r.navn} mangler i HTML`).toContain(flat(r.verdi))
    }
    expect(flat(e.html)).toContain(flat(m.forklaring))
    expect(flat(e.html)).toContain(flat(m.retning))
  })

  it('ren tekst har de samme tallene som kortet', () => {
    if (m.slag === 'ikke_beregnet' || m.slag === 'blokkert') throw new Error('feil gren')
    for (const r of m.rader) {
      expect(flat(e.tekst), `${r.navn} mangler i ren tekst`).toContain(flat(r.verdi))
    }
    expect(flat(e.tekst)).toContain(flat(m.forklaring))
  })

  it('uforklart matavvik er likt alle fire steder', () => {
    if (u.slag === 'ikke_beregnet' || u.slag === 'blokkert') throw new Error('feil gren')
    expect(u.verdi).toBe(medFortegn(31902.47))
    expect(flat(e.html)).toContain(flat(u.verdi))
    expect(flat(e.tekst)).toContain(flat(u.verdi))
    expect(flat(e.tekst)).toContain(flat(u.utvikling))
    expect(e.tekst).toContain(USYNLIG_AARSAKER)
  })

  it('e-posten regner IKKE på nytt — uten snapshot, ingen analyse', () => {
    const uten = tilEpost(p, 'https://x')
    expect(uten.html).not.toContain('Synlig matkast')
    expect(uten.tekst).not.toContain('UFORKLART MATAVVIK')
  })

  it('blokkering står ordrett i begge e-postformene', () => {
    const b = plan({
      stasjonNavn: 'St1 Dale', kastsats: null,
      historikk: [1, 2, 3, 4].map((i) => mnd({ maaned: `2026-0${i}-01` })),
    })
    const sb = JSON.parse(JSON.stringify(lagSnapshot(b)))
    const eb = tilEpost(b, 'https://x', sb)
    const mb = matkastvisning(lesMatkast(sb.matkast))
    if (mb.slag !== 'blokkert') throw new Error('feil gren')
    expect(eb.html).toContain(mb.tekst)
    expect(eb.tekst).toContain(mb.tekst)
  })

  it('norsk tegnsett overlever hele veien', () => {
    const n = plan({ stasjonNavn: 'St1 Bønes', historikk: DALE })
    const sn = JSON.parse(JSON.stringify(lagSnapshot(n)))
    const en = tilEpost(n, 'https://x', sn)
    expect(en.html).toContain('Bønes')
    expect(en.tekst).toContain('Bønes')
    expect(en.html).toContain('Uforklart matavvik')
    expect(en.tekst).toContain('månedene')
  })
})

// =====================================================================
// E-POSTEN LESER RANGERINGEN GJENNOM SAMME VALIDERING
// =====================================================================
//
// Kortet, `/min-plan` og brevet skal si det samme om rangeringen. Sto
// e-posten igjen med `plan.rangering` mens flatene leste den lagrede
// raden, kunne butikksjefen fått to forskjellige svar på samme spørsmål
// — og den ene av dem fra et snapshot ingen hadde validert.
// =====================================================================
describe('e-posten og rangeringen', () => {
  const p = plan({ stasjonNavn: 'St1 Dale', historikk: DALE })
  const s = lagSnapshot(p)
  const grunn = JSON.parse(JSON.stringify(s)) as { matkast: unknown; usynlig: unknown }

  it('en ØDELAGT lagret rangering krasjer ikke — den blir ikke tilgjengelig', () => {
    // `{}` passerte den gamle typecasten, og `rangeringstekst` leste
    // `r.kandidater.length` på noe som ikke hadde `kandidater`.
    const e = tilEpost(p, 'https://x', { ...grunn, rangering: {} })
    expect(e.tekst).toContain(RANGERING_UKJENT)
    expect(e.tekst).not.toContain('Ingen av løftestengene peker feil vei')
  })

  it('en gyldig lagret rangering brukes som den er', () => {
    const e = tilEpost(p, 'https://x', {
      ...grunn,
      rangering: { mulig: false, kandidater: ['Matkast', 'Personalkostnad mot budsjett'] },
    })
    expect(e.tekst).toContain(UTEN_KRONEVERDI)
    expect(e.tekst).toContain('Personalkostnad mot budsjett')
    expect(e.tekst).not.toContain(RANGERING_UKJENT)
  })

  it('uten lagret rangering brukes den motoren nettopp regnet', () => {
    const e = tilEpost(p, 'https://x', grunn)
    expect(e.tekst).not.toContain(RANGERING_UKJENT)
  })

  it('html og ren tekst sier det samme', () => {
    const e = tilEpost(p, 'https://x', { ...grunn, rangering: null })
    expect(e.tekst).toContain(RANGERING_UKJENT)
    // HTML-en rommer den samme setningen, escapet.
    expect(e.html).toContain('Rangering er ikke tilgjengelig')
  })
})
