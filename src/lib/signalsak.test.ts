import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, it } from 'vitest'
import { sammeSak, type Signalsak } from './regnskap-varsler'

// =====================================================================
// SAKEN SKAL BEVARE STRUKTUR, IKKE FINNE PÅ SAMMENHENGER
// =====================================================================
//
// Motoren kjente `160 Kioskvarer` da den skrev «160 Kioskvarer: 21 558
// kr usynlig manko» — og kastet koden. Målt i produksjon 2026-09-16 ga
// gruppering på varslenes egen identitet `(gruppe, nivaa, tittel)` alle
// 59 nøkler «1 stasjon», fordi tittelen bærer stasjonens eget beløp.
// Mønsteret var der; nøkkelen var borte.
//
// `sak` bevarer den. Den forklarer ingenting.
//
// ---------------------------------------------------------------------
// DET FARLIGE ER IKKE AT NOE IKKE GRUPPERES. DET ER AT NOE GRUPPERES
// SOM IKKE HØRER SAMMEN.
// ---------------------------------------------------------------------
//
// «5 av 5 stasjoner har manko i Kioskvarer» er en observasjon som kan
// endre hvor en eier ser. Er den bygget av et overskudd og et kast som
// tilfeldigvis delte varegruppe, er den en påstand om noe som ikke
// finnes — og den ser like troverdig ut.
//
// Testene under er derfor i hovedsak NEGATIVE: hva som ALDRI skal
// grupperes.
// =====================================================================

const vare = (kode: string, navn = 'Varegruppe') =>
  ({ form: 'varegruppe', kode, navn }) as const
const motpost = (avdeling: string, navn = 'Gruppe') =>
  ({ form: 'motpostgruppe', avdeling, navn }) as const

describe('samme fenomen paa to stasjoner er samme sak', () => {
  it('lik varegruppe og likt slag grupperes', () => {
    // KRONENE ER ULIKE, OG DET SKAL IKKE BETY NOE. Det er nettopp fordi
    // beloepet sto i tittelen at den gamle noekkelen ga «1 stasjon» 59
    // ganger.
    const a: Signalsak = { slag: 'usynlig_manko', vare: vare('160', '160 Kioskvarer') }
    const b: Signalsak = { slag: 'usynlig_manko', vare: vare('160', '160 Kioskvarer') }
    expect(sammeSak(a, b)).toBe(true)
  })

  it('NAVNET ER IKKE IDENTITETEN - koden er', () => {
    // To kjeder kan kalle samme kode noe ulikt, og samme navn kan brukes
    // om to koder. Tekst er aldri en noekkel.
    const a: Signalsak = { slag: 'usynlig_manko', vare: vare('160', '160 Kioskvarer') }
    const b: Signalsak = { slag: 'usynlig_manko', vare: vare('160', 'Kiosk') }
    expect(sammeSak(a, b), 'ulikt navn, samme kode -> samme sak').toBe(true)

    const c: Signalsak = { slag: 'usynlig_manko', vare: vare('120', '160 Kioskvarer') }
    expect(sammeSak(a, c), 'samme navn, ulik kode -> ULIKE saker').toBe(false)
  })

  it('saker uten vare grupperes paa slaget alene', () => {
    expect(sammeSak({ slag: 'lonn_over_budsjett' }, { slag: 'lonn_over_budsjett' })).toBe(true)
  })
})

describe('det som ALDRI skal grupperes', () => {
  it('ulik varegruppe', () => {
    expect(sammeSak(
      { slag: 'usynlig_manko', vare: vare('160') },
      { slag: 'usynlig_manko', vare: vare('120') },
    )).toBe(false)
  })

  it('SYNLIG KAST OG USYNLIG MANKO - selv med samme varegruppe', () => {
    // De maaler ulike ting. Synlig kast er registrert i haandterminalen;
    // usynlig er teoretisk BF minus faktisk BF minus synlig kast. Et
    // aggregat som blandet dem ville talt samme varegruppe to ganger og
    // kalt det ett fenomen.
    expect(sammeSak(
      { slag: 'usynlig_manko', vare: vare('120') },
      { slag: 'synlig_kast', vare: vare('120') },
    )).toBe(false)
  })

  it('MANKO OG OVERSKUDD - motsatt fortegn er ikke samme observasjon', () => {
    // Pluss er manko, minus er overskudd, og et overskudd er ikke et
    // lite tap - se `usynlig-fortegnet`. At de deler varegruppe gjoer
    // dem ikke til samme sak.
    expect(sammeSak(
      { slag: 'usynlig_manko', vare: vare('190') },
      { slag: 'usynlig_overskudd', vare: vare('190') },
    )).toBe(false)
  })

  it('LOENNSAVVIK OG OMSETNINGSAVVIK', () => {
    expect(sammeSak({ slag: 'lonn_over_budsjett' }, { slag: 'omsetning_mot_budsjett' })).toBe(false)
    expect(sammeSak({ slag: 'lonn_over_budsjett' }, { slag: 'lonn_brukt_brutto_under' })).toBe(false)
    expect(sammeSak({ slag: 'negativt_resultat' }, { slag: 'driftsresultat' })).toBe(false)
  })

  it('VAREGRUPPE OG MOTPOSTGRUPPE - samme navn, ulik form', () => {
    // `130 Varm drikke` som motpostgruppe er kaffe + te + lojalitet,
    // vurdert NETTO etter at utdelingen er trukket fra. Det er ikke den
    // samme observasjonen som én varegruppe med samme navn.
    expect(sammeSak(
      { slag: 'usynlig_manko', vare: vare('130', 'Varm drikke') },
      { slag: 'usynlig_manko', vare: motpost('130', 'Varm drikke') },
    )).toBe(false)
  })

  it('MANGLENDE STRUKTUR GRUPPERES ALDRI - heller ikke med seg selv', () => {
    // `null` betyr «vi kjenner ikke identiteten». To ukjente er ikke det
    // samme; de er to ukjente. Ble de like, ville hver varegruppe uten
    // kode havnet i én stor haug som saa ut som ett fenomen.
    expect(sammeSak(null, null)).toBe(false)
    expect(sammeSak(null, { slag: 'usynlig_manko', vare: vare('160') })).toBe(false)
    expect(sammeSak({ slag: 'usynlig_manko', vare: vare('160') }, null)).toBe(false)
  })
})

// =====================================================================
// STRUKTURVAKTER PÅ SELVE MOTOREN
// =====================================================================
const KILDE = readFileSync(
  join(process.cwd(), 'src', 'lib', 'regnskap-varsler.ts'), 'utf8',
).replace(/\r\n/g, '\n')

describe('saken bygges av struktur, aldri av tekst', () => {
  it('KANARIFUGL: fila blir funnet og har varslene i seg', () => {
    expect(KILDE.length).toBeGreaterThan(5000)
    expect(KILDE).toContain('export type Signalsak')
  })

  it('HVERT `legg`-kall tar en sak - kompilatoren krever det', () => {
    // Parameteren er PAAKREVD. Et nytt varsel uten klassifisering ville
    // ellers faatt `undefined` i stillhet, og vaert usynlig for enhver
    // gruppering - samme form som en tabell som faller mellom stolene i
    // dekningssjekken.
    expect(KILDE).toContain('vekt: number, gruppe: number, sak: Signalsak | null,')
    const kall = [...KILDE.matchAll(/\blegg\(/g)].length
    // Ett treff er definisjonen selv.
    expect(kall, 'ingen legg-kall aa maale').toBeGreaterThan(10)
  })

  it('INGEN SAK BYGGES AV EN TITTEL', () => {
    // Ingen parsing tilbake fra teksten. Hver `sak` settes av de samme
    // strukturerte verdiene som formaterer den.
    expect(KILDE).not.toMatch(/tittel[^\n]*\.(match|split|replace|slice)\(/)
    expect(KILDE).not.toMatch(/slag:\s*[^,\n]*tittel/)
  })

  it('VAREIDENTITETEN LESER `kode`, IKKE `navn`', () => {
    expect(KILDE).toContain("if (!s.kode) return null")
    expect(KILDE).toContain("form: 'varegruppe', kode: s.kode, navn: s.navn")
    // Og motpostgruppen leser avdelingen, ikke navnet.
    expect(KILDE).toContain("form: 'motpostgruppe', avdeling: g.avdeling")
  })

  // ===================================================================
  // HVER VARIANT MOT SITT EGET SLAG
  // ===================================================================
  //
  // Her sto bare «finnes hvert slag et sted i fila». Den var blind for
  // det som faktisk er farlig: at et slag står på FEIL kallsted. Tre
  // injeksjoner kom grønne tilbake — kast klassifisert som manko,
  // overskudd som manko, og lønn som omsetning. Alle tre ville gjort et
  // aggregat til en påstand om noe som ikke finnes.
  //
  // Fila deles nå på `legg(`, så hver bit er ETT kall. Finner vi
  // tittelen der, må slaget stå i den samme biten.
  const kall = KILDE.split('legg(').slice(1)

  /** tittelfragment -> slaget kallet MÅ bære */
  const VARIANTER: [string, string][] = [
    ['`Omsetning ${pst1(i)} mot budsjett`', "'omsetning_mot_budsjett'"],
    ['`Bruttofortjeneste ${pst1(brfTot.index_pct)} mot budsjett`', "'brutto_mot_budsjett'"],
    ['`Driftskostnader ${pst1(over)} over budsjett`', "'driftskostnader_over_budsjett'"],
    ["'Negativt driftsresultat'", "'driftsresultat'"],
    ["'Driftsresultat under budsjett'", "'driftsresultat'"],
    ['`Lønn ${pst1(lonnPst)} over budsjett`', "'lonn_over_budsjett'"],
    ['Lønn brukt, men brutto', "'lonn_brukt_brutto_under'"],
    ["'Negativt resultat'", "'negativt_resultat'"],
    ['${g.navn}: ${kr0(g.kr)} usynlig manko', "'usynlig_manko', vare: { form: 'motpostgruppe'"],
    ['${s.navn}: ${kr0(krV)} usynlig manko', "vareSak('usynlig_manko'"],
    ['${s.navn}: ${kr0(krV)} usynlig overskudd', "vareSak('usynlig_overskudd'"],
    ['${s.navn}: ${kr0(kast)} kastet/synlig svinn', "vareSak('synlig_kast'"],
  ]

  it('KANARIFUGL: hver variant finnes i kilden', () => {
    // Uten dette ville en omskrevet tittel gjort paret uobserverbart, og
    // loekka under hadde staatt groenn paa null treff.
    for (const [tittel] of VARIANTER) {
      expect(kall.some((k) => k.includes(tittel)), `fant ikke varianten ${tittel}`).toBe(true)
    }
  })

  it('HVERT KALLSTED BAERER SITT EGET SLAG', () => {
    const feil: string[] = []
    for (const [tittel, slag] of VARIANTER) {
      for (const k of kall.filter((x) => x.includes(tittel))) {
        if (!k.includes(slag)) feil.push(`${tittel}  ->  mangler ${slag}`)
      }
    }
    expect(
      feil,
      '\nEt varsel er klassifisert som noe annet enn det er:\n\n  '
      + feil.join('\n  ')
      + '\n\nEt aggregat bygget paa feil slag er en paastand om et fenomen\n'
      + 'som ikke finnes - og det ser like troverdig ut som et ekte.\n',
    ).toEqual([])
  })

  it('SAKEN ENDRER INGENTING ANNET - ingen nivaa, kroner eller vekt', () => {
    // 3A skal BEVARE informasjon som ble kastet, ingenting mer.
    // Terskler, fortegn og beloep er uroert; det beviser diffen, og
    // produksjonskanarifuglen maaler at vektoren er bitidentisk.
    expect(KILDE).toContain('const T = TERSKLER')
    // INGEN GRUPPERING I 3A. `sammeSak` skal finnes ÉN gang i fila — som
    // definisjon. Kalles den herfra, har motoren begynt å slå sammen
    // varsler, og det er 3B sin jobb på et lag over.
    expect([...KILDE.matchAll(/sammeSak\(/g)],
      'motoren har begynt aa gruppere selv').toHaveLength(1)
    expect(KILDE).toContain('export function sammeSak(')
  })
})
