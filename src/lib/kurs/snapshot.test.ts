// EN HALV STRUKTUR SKAL IKKE BLI HALVE TALL PÅ FLATEN.
//
// =====================================================================
// HVORFOR DENNE VAKTEN FINNES
// =====================================================================
//
// `matkast` og `usynlig` er `jsonb`-kolonner. Postgres garanterer at
// innholdet er gyldig JSON og ingenting mer — ikke at `dom.naa` finnes,
// ikke at `faktiskPst` er et tall, ikke at snapshotet ble skrevet av
// DENNE motoren. PostgREST leverer dem som `unknown`.
//
// Første utgave av `lesMatkast` sjekket tre strenger og at `dom` og
// `blokkering` var til stede, og typecastet resten. Et snapshot skrevet
// av en eldre motor — eller av en rettet migrasjon — slapp da gjennom og
// krasjet først i `analysevisning`, altså inne i rendringen av
// butikksjefens plan.
//
// Regelen er Roberts: «Hvis noe ikke kan bli 100 % korrekt, skal du
// heller blokkere analysen og vise "ikke nok datagrunnlag" enn å vise en
// feil konklusjon.» `null` fra disse to funksjonene er nettopp den
// blokkeringen — flaten sier «Ikke beregnet».
//
// ---------------------------------------------------------------------
// KANARIFUGLEN
//
// Hver «skal avvises»-test bygger på et snapshot som ER gyldig, og
// ødelegger ÉN ting. Går den gyldige varianten i stykker, blir
// `gyldig …`-testene røde først — og da måler ikke resten av fila noe.
// En vakt som avviser alt ser nøyaktig ut som en vakt som virker.
// =====================================================================

import { describe, expect, it } from 'vitest'
import {
  ANALYSEVERSJON, lagSnapshot, lesMatkast, lesRangering, lesUsynlig,
} from './snapshot'
import type { Maanedsplan } from './plan'

const FELLES = {
  analyseversjon: ANALYSEVERSJON,
  beregnetForMaaned: '2026-07-01',
  beregnetTid: '2026-09-13T12:00:00.000Z',
}

const KASTTALL = {
  maaned: '2026-07-01',
  matsalgKr: 400_000,
  synligKastKr: 30_000,
  faktiskPst: 7.5,
  budsjettPst: 6,
  justertBudsjettKr: 24_000,
  avvikKr: 6_000,
  avvikPstpoeng: 1.5,
  gunstig: false,
}

const KURS = { vei: 'opp', paaRad: 3, endring: 4_000, spenn: 9_000 }

const KASTDOM = {
  slag: 'tiltak',
  naa: KASTTALL,
  kurs: KURS,
  ugunstige: 4,
  antallMaaneder: 5,
  tekst: 'Matkastet ligger 1,5 prosentpoeng over budsjettet.',
}

const MATKAST = { ...FELLES, dom: KASTDOM, blokkering: null }
const USYNLIG = {
  ...FELLES,
  naaKr: 31_902,
  kurs: KURS,
  vindu: 3,
  usikker: false,
  aarsakUsikker: null,
  blokkering: null,
}

/** Kopi med én nøkkel endret eller fjernet. */
function uten<T extends object>(o: T, noekkel: string): Record<string, unknown> {
  const k = { ...o } as Record<string, unknown>
  delete k[noekkel]
  return k
}
function med<T extends object>(o: T, endring: Record<string, unknown>): Record<string, unknown> {
  return { ...o, ...endring }
}

// =====================================================================
describe('kanarifuglen: de gyldige formene slipper gjennom', () => {
  it('fullt matkastsnapshot', () => expect(lesMatkast(MATKAST)).not.toBeNull())
  it('fullt usynligsnapshot', () => expect(lesUsynlig(USYNLIG)).not.toBeNull())

  it('BLOKKERT matkast er gyldig: dom null OG en årsak', () => {
    const b = { ...FELLES, dom: null, blokkering: 'Datagrunnlag mangler' }
    expect(lesMatkast(b)).not.toBeNull()
    expect(lesMatkast(b)?.dom).toBeNull()
  })

  it('BLOKKERT usynlig er gyldig: naaKr null OG en årsak', () => {
    const b = {
      ...FELLES, naaKr: null, kurs: null, vindu: 0,
      usikker: false, aarsakUsikker: null, blokkering: 'Hull i svinnserien',
    }
    expect(lesUsynlig(b)).not.toBeNull()
  })

  it('usikker usynlig uten kurs er gyldig', () => {
    const u = med(USYNLIG, {
      kurs: null, vindu: 0, usikker: true,
      aarsakUsikker: 'Fortegnsskifte i vinduet',
    })
    expect(lesUsynlig(u)).not.toBeNull()
  })
})

// =====================================================================
describe('matkast som skal avvises', () => {
  const avvises = (navn: string, v: unknown) =>
    it(navn, () => expect(lesMatkast(v)).toBeNull())

  avvises('null', null)
  avvises('en streng', 'matkast')
  avvises('en liste', [MATKAST])
  avvises('ukjent analyseversjon', med(MATKAST, { analyseversjon: 'p1-kroner-2' }))
  avvises('analyseversjon som mangler', uten(MATKAST, 'analyseversjon'))
  avvises('beregnetForMaaned som mangler', uten(MATKAST, 'beregnetForMaaned'))
  avvises('beregnetTid som mangler', uten(MATKAST, 'beregnetTid'))

  // DEN SOM KRASJET FLATEN: dommen finnes, men tallene under mangler.
  avvises('dom uten naa', med(MATKAST, { dom: uten(KASTDOM, 'naa') }))
  avvises('dom med naa = null', med(MATKAST, { dom: med(KASTDOM, { naa: null }) }))

  // `faktiskPst` som TEKST. jsonb tar imot «7,5» like gjerne som 7.5, og
  // `toFixed` finnes ikke på en streng.
  avvises('faktiskPst som tekst', med(MATKAST, {
    dom: med(KASTDOM, { naa: med(KASTTALL, { faktiskPst: '7,5' }) }),
  }))
  avvises('avvikKr som tekst', med(MATKAST, {
    dom: med(KASTDOM, { naa: med(KASTTALL, { avvikKr: '6000' }) }),
  }))
  avvises('gunstig som tekst', med(MATKAST, {
    dom: med(KASTDOM, { naa: med(KASTTALL, { gunstig: 'nei' }) }),
  }))

  avvises('ukjent slag', med(MATKAST, { dom: med(KASTDOM, { slag: 'advarsel' }) }))
  avvises('tekst som mangler', med(MATKAST, { dom: uten(KASTDOM, 'tekst') }))
  avvises('ugunstige som mangler', med(MATKAST, { dom: uten(KASTDOM, 'ugunstige') }))

  // KURS: halv struktur. `vei` er der, tallene er det ikke.
  avvises('kurs uten paaRad', med(MATKAST, {
    dom: med(KASTDOM, { kurs: uten(KURS, 'paaRad') }),
  }))
  avvises('kurs med ugyldig vei', med(MATKAST, {
    dom: med(KASTDOM, { kurs: med(KURS, { vei: 'oppover' }) }),
  }))

  // Verken dom eller årsak: ingenting å si til den som leser.
  avvises('dom null uten blokkering', { ...FELLES, dom: null, blokkering: null })
  avvises('blokkering som tall', med(MATKAST, { blokkering: 7 }))
})

// =====================================================================
describe('usynlig som skal avvises', () => {
  const avvises = (navn: string, v: unknown) =>
    it(navn, () => expect(lesUsynlig(v)).toBeNull())

  avvises('null', null)
  avvises('en streng', 'usynlig')
  avvises('ukjent analyseversjon', med(USYNLIG, { analyseversjon: 'p2-kastbudsjett-0' }))
  avvises('naaKr som tekst', med(USYNLIG, { naaKr: '31902' }))
  avvises('naaKr som NaN', med(USYNLIG, { naaKr: Number.NaN }))
  avvises('vindu som mangler', uten(USYNLIG, 'vindu'))
  avvises('usikker som tekst', med(USYNLIG, { usikker: 'ja' }))
  avvises('aarsakUsikker som tall', med(USYNLIG, { aarsakUsikker: 3 }))
  avvises('halv kurs', med(USYNLIG, { kurs: { vei: 'opp' } }))
  avvises('kurs med ugyldig vei', med(USYNLIG, { kurs: med(KURS, { vei: 'stigende' }) }))

  // HALV STRUKTUR: verken verdi eller årsak.
  avvises('naaKr null uten blokkering', med(USYNLIG, { naaKr: null, kurs: null }))
})

// =====================================================================
describe('lagSnapshot gir noe leserne godtar', () => {
  // RUNDTUREN. Skriver motoren en form leserne avviser, er hele
  // lagringen til ingen nytte — og det ville ikke vist seg før en plan
  // ble åpnet i produksjon.
  const plan = {
    maaned: '2026-07-01',
    matkast: { dom: KASTDOM, blokkering: null },
    usynlig: {
      naaKr: 31_902, kurs: KURS, vindu: 3,
      usikker: false, aarsakUsikker: null, blokkering: null,
    },
  } as unknown as Maanedsplan

  const s = lagSnapshot(plan, new Date('2026-09-13T12:00:00Z'))

  it('matkastet leses tilbake', () => expect(lesMatkast(s.matkast)).not.toBeNull())
  it('usynlig leses tilbake', () => expect(lesUsynlig(s.usynlig)).not.toBeNull())

  it('også etter en tur gjennom JSON, slik jsonb gjør det', () => {
    const rundt = JSON.parse(JSON.stringify(s))
    expect(lesMatkast(rundt.matkast)).not.toBeNull()
    expect(lesUsynlig(rundt.usynlig)).not.toBeNull()
  })

  it('en blokkert plan lagres og leses som blokkert', () => {
    const blokkert = {
      maaned: '2026-07-01',
      matkast: { dom: null, blokkering: 'Datagrunnlag mangler' },
      usynlig: {
        naaKr: null, kurs: null, vindu: 0,
        usikker: false, aarsakUsikker: null, blokkering: 'Hull i svinnserien',
      },
    } as unknown as Maanedsplan
    const b = lagSnapshot(blokkert, new Date('2026-09-13T12:00:00Z'))
    expect(lesMatkast(b.matkast)?.blokkering).toBe('Datagrunnlag mangler')
    expect(lesUsynlig(b.usynlig)?.blokkering).toBe('Hull i svinnserien')
  })

  it('bærer versjonen, så en gammel plan kan forklares', () => {
    expect(s.matkast.analyseversjon).toBe(ANALYSEVERSJON)
    expect(s.matkast.beregnetForMaaned).toBe('2026-07-01')
    expect(s.usynlig.beregnetTid).toBe('2026-09-13T12:00:00.000Z')
  })
})

// =====================================================================
// `kurs` SOM MANGLER, MOT `kurs` SOM ER `null`
// =====================================================================
//
// To tilstander som ser like ut i JavaScript og betyr motsatte ting:
//
//   kurs: null      MAALT. Serien fantes, men hadde ikke nok punkter
//                   til en retning. Gyldig. Flaten sier «ingen retning
//                   ennaa».
//   ingen `kurs`    UFULLSTENDIG. Snapshotet mangler et felt motoren
//                   alltid skriver. Ugyldig.
//
// Foerste utgave skrev `erKurs(v.kurs ?? null)`. `??` gjoer nettopp den
// forskjellen usynlig: et manglende felt ble til en gyldig `null`, og
// leseren godkjente et halvt snapshot mens rapporten min sa at den
// avviste det.
//
// TESTEN BRUKER `delete`, IKKE `= null`. En test som setter feltet til
// null maaler den gyldige tilstanden og ville vaert groenn i begge
// utgaver.
// =====================================================================
describe('manglende kurs er ikke kurs = null', () => {
  it('KANARIFUGL: kurs = null er GYLDIG i begge', () => {
    // Uten denne kunne leseren avvise alt og fortsatt vaere «groenn».
    expect(lesMatkast(med(MATKAST, { dom: med(KASTDOM, { kurs: null }) }))).not.toBeNull()
    expect(lesUsynlig(med(USYNLIG, { kurs: null, vindu: 0 }))).not.toBeNull()
  })

  it('delete dom.kurs avvises', () => {
    const s = JSON.parse(JSON.stringify(MATKAST))
    expect(lesMatkast(s), 'kanarifuglen: kopien maa vaere gyldig foer vi river')
      .not.toBeNull()
    delete s.dom.kurs
    expect(lesMatkast(s)).toBeNull()
  })

  it('delete kurs avvises paa usynlig', () => {
    const s = JSON.parse(JSON.stringify(USYNLIG))
    expect(lesUsynlig(s)).not.toBeNull()
    delete s.kurs
    expect(lesUsynlig(s)).toBeNull()
  })

  it('undefined er det samme som manglende', () => {
    // `jsonb` kan ikke baere `undefined`, men et objekt paa vei INN kan.
    expect(lesUsynlig({ ...USYNLIG, kurs: undefined })).toBeNull()
  })
})

// =====================================================================
// DEN TREDJE JSONB-KOLONNEN
// =====================================================================
//
// `rangering` gikk rett fra basen til komponenten, typecastet. To ting
// kunne skje, og begge er stille:
//
//   1  `{}` eller en tekst passerte casten, og `rangeringstekst()` leste
//      `r.kandidater.length` paa noe som ikke hadde `kandidater`.
//   2  `null` - en plan laget FOER `0216` - ble til
//      `{ mulig: true, kandidater: [] }`, og da kunne flaten skrive
//      «Ingen av loeftestengene peker feil vei» om en plan ingen har
//      maalt.
// =====================================================================
describe('lesRangering', () => {
  const gyldig = { mulig: false, kandidater: ['Matkast', 'Personalkostnad'] }

  it('KANARIFUGL: en gyldig rangering slipper gjennom', () => {
    expect(lesRangering(gyldig)).toEqual(gyldig)
    expect(lesRangering({ mulig: true, kandidater: [] }))
      .toEqual({ mulig: true, kandidater: [] })
  })

  const avvises = (navn: string, v: unknown) =>
    it(navn, () => expect(lesRangering(v)).toBeNull())

  avvises('null - planen er eldre enn feltet', null)
  avvises('tomt objekt', {})
  avvises('en tekst', 'mulig')
  avvises('et tall', 7)
  avvises('en liste', [gyldig])
  avvises('mulig som tekst', { mulig: 'ja', kandidater: [] })
  avvises('mulig som mangler', { kandidater: [] })
  avvises('kandidater som mangler', { mulig: true })
  avvises('kandidater som tekst', { mulig: true, kandidater: 'Matkast' })
  avvises('kandidater som objekt', { mulig: true, kandidater: { 0: 'Matkast' } })
  avvises('en kandidat som ikke er tekst', { mulig: false, kandidater: ['Matkast', 7] })
  avvises('en kandidat som er null', { mulig: false, kandidater: [null] })

  it('kopierer lista, saa flaten ikke kan skrive i raden', () => {
    const ut = lesRangering(gyldig)
    ut!.kandidater.push('Noe annet')
    expect(gyldig.kandidater).toHaveLength(2)
  })
})
