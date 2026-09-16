import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, it } from 'vitest'
import { byggFenomener, utbredelse, type Stasjonsvarsel } from './fenomen'
import type { RegnskapVarsel, Signalsak, VarselNiva } from './regnskap-varsler'
import { utenKommentarer } from './redesign/design'

// =====================================================================
// AGGREGATET SKAL KOMPRIMERE OBSERVASJONER, IKKE FINNE PÅ FENOMENER
// =====================================================================
//
// «Kioskvarer · usynlig manko · 5 av 5» kan flytte hvor en eier ser.
// Er den bygget av et overskudd og et kast som tilfeldigvis delte
// varegruppe, er den en påstand om noe som ikke finnes — og den ser like
// troverdig ut.
//
// Produksjonen inneholdt nettopp den fellen: `180 Tobakk` har manko på
// Lone og Varden, og OVERSKUDD på Dale og Bønes. Gruppert på varegruppe
// alene ville det blitt «4 av 5 stasjoner». Fire stasjoner, motsatt
// fortegn, ingen overlapp.
//
// Testene under er derfor i hovedsak negative.
// =====================================================================

const vare = (kode: string, navn = `${kode} Varegruppe`) =>
  ({ form: 'varegruppe', kode, navn }) as const

let teller = 0
function varsel(sak: Signalsak | null, nivaa: VarselNiva, vekt = 1000): RegnskapVarsel {
  teller += 1
  return {
    nivaa, omfang: 'stasjon', tittel: `varsel ${teller}`,
    detalj: 'detalj', vekt, gruppe: 2, sak,
  }
}

const sv = (
  id: string, navn: string, sak: Signalsak | null, nivaa: VarselNiva, vekt = 1000,
): Stasjonsvarsel => ({ stasjonId: id, stasjonsnavn: navn, varsel: varsel(sak, nivaa, vekt) })

const MANKO160: Signalsak = { slag: 'usynlig_manko', vare: vare('160', '160 Kioskvarer') }
const KAST120: Signalsak = { slag: 'synlig_kast', vare: vare('120', '120 Mat') }
const MANKO120: Signalsak = { slag: 'usynlig_manko', vare: vare('120', '120 Mat') }

describe('samme sak over flere stasjoner blir ETT fenomen', () => {
  it('fem stasjoner, ett fenomen, fem underliggende', () => {
    const f = byggFenomener([
      sv('s1', 'Lone', MANKO160, 'rod'),
      sv('s2', 'Dale', MANKO160, 'rod'),
      sv('s3', 'Laguneparken', MANKO160, 'rod'),
      sv('s4', 'Varden', MANKO160, 'rod'),
      sv('s5', 'Bønes', MANKO160, 'rod'),
    ], 5)
    expect(f).toHaveLength(1)
    expect(f[0].stasjoner).toHaveLength(5)
    expect(f[0].underliggende).toHaveLength(5)
    expect(utbredelse(f[0])).toBe('5 av 5 stasjoner')
  })

  it('ÉN STASJON ER OGSAA ET FENOMEN', () => {
    // Dales loenn er Dales. En eksistensregel paa «>= 2 stasjoner» ville
    // gjort den usynlig i sannhetsmodellen - og utvalget hoerer i
    // presentasjonen, ikke her.
    const f = byggFenomener([sv('s2', 'Dale', { slag: 'lonn_over_budsjett' }, 'rod')], 5)
    expect(f).toHaveLength(1)
    expect(utbredelse(f[0])).toBe('1 av 5 stasjoner')
  })

  it('alle underliggende stasjoner kan naas', () => {
    const f = byggFenomener([
      sv('s1', 'Lone', MANKO160, 'gul'),
      sv('s2', 'Dale', MANKO160, 'rod'),
    ], 5)
    expect(f[0].stasjoner.map((s) => s.stasjonId)).toEqual(['s1', 's2'])
    expect(f[0].stasjoner.map((s) => s.stasjonsnavn)).toEqual(['Lone', 'Dale'])
  })
})

describe('det som ALDRI blir ett fenomen', () => {
  it('SAMME VARE, ULIKT SLAG — 120 Mat sto to ganger i produksjon', () => {
    const f = byggFenomener([
      sv('s1', 'Lone', KAST120, 'gul'),
      sv('s1', 'Lone', MANKO120, 'rod'),
    ], 5)
    expect(f, 'kast og manko ble slaatt sammen').toHaveLength(2)
  })

  it('ULIK VAREKODE', () => {
    const f = byggFenomener([
      sv('s1', 'Lone', MANKO160, 'rod'),
      sv('s1', 'Lone', MANKO120, 'rod'),
    ], 5)
    expect(f).toHaveLength(2)
  })

  it('MANKO OG OVERSKUDD PAA SAMME VARE — Tobakk-fellen fra produksjon', () => {
    // Lone og Varden hadde manko paa 180; Dale og Boenes overskudd.
    // Gruppert paa varegruppe alene: «4 av 5 stasjoner». Et fenomen som
    // ikke finnes.
    const manko: Signalsak = { slag: 'usynlig_manko', vare: vare('180', '180 Tobakk') }
    const over: Signalsak = { slag: 'usynlig_overskudd', vare: vare('180', '180 Tobakk') }
    const f = byggFenomener([
      sv('s1', 'Lone', manko, 'gul'),
      sv('s4', 'Varden', manko, 'gul'),
      sv('s2', 'Dale', over, 'gul'),
      sv('s5', 'Bønes', over, 'gul'),
    ], 5)
    expect(f).toHaveLength(2)
    expect(f.map((x) => x.stasjoner.length)).toEqual([2, 2])
    expect(f.some((x) => x.stasjoner.length === 4),
      'fire stasjoner ble til ett fenomen som ikke finnes').toBe(false)
  })

  it('`sak: null` GRUPPERES ALDRI — heller ikke med en annen null', () => {
    // To ukjente er ikke det samme; de er to ukjente. Ble de like, ville
    // hver varegruppe uten kode havnet i én haug som saa ut som ett
    // fenomen.
    const f = byggFenomener([
      sv('s1', 'Lone', null, 'gul'),
      sv('s2', 'Dale', null, 'gul'),
      sv('s3', 'Laguneparken', null, 'rod'),
    ], 5)
    expect(f).toHaveLength(3)
    for (const x of f) expect(x.stasjoner).toHaveLength(1)
  })
})

describe('nivaa er en AVLESNING, aldri en oppgradering', () => {
  it('aggregatet er roedt, stasjonene beholder sitt eget', () => {
    const f = byggFenomener([
      sv('s1', 'Lone', MANKO160, 'gul'),
      sv('s2', 'Dale', MANKO160, 'rod'),
      sv('s3', 'Laguneparken', MANKO160, 'gul'),
    ], 5)
    expect(f[0].nivaa, 'hoeyeste underliggende').toBe('rod')
    // DE GULE ER FORTSATT GULE. Dette er hele forskjellen paa en
    // avlesning og en oppgradering: driller man ned, skal ingen stasjon
    // vaere blitt verre av at naboen er det.
    expect(f[0].stasjoner.map((s) => s.nivaa)).toEqual(['gul', 'rod', 'gul'])
    expect(f[0].underliggende.map((v) => v.nivaa)).toEqual(['gul', 'rod', 'gul'])
  })

  it('bare gule gir et gult fenomen', () => {
    const f = byggFenomener([
      sv('s1', 'Lone', KAST120, 'gul'),
      sv('s2', 'Dale', KAST120, 'gul'),
    ], 5)
    expect(f[0].nivaa).toBe('gul')
  })

  it('UNDERLIGGENDE VARSLER ER BITIDENTISKE', () => {
    // Aggregatet baerer dem videre, det skriver dem ikke om.
    const inn = [
      sv('s1', 'Lone', MANKO160, 'gul', 28562),
      sv('s2', 'Dale', MANKO160, 'rod', 30066),
    ]
    const kopi = inn.map((x) => JSON.parse(JSON.stringify(x.varsel)))
    const f = byggFenomener(inn, 5)
    expect(f[0].underliggende).toEqual(kopi)
  })
})

describe('populasjonen er brukerens, ikke kjedens', () => {
  it('avTotalt kommer inn og baeres uendret', () => {
    const f = byggFenomener([sv('s1', 'Lone', MANKO160, 'rod')], 2)
    expect(f[0].avTotalt).toBe(2)
    expect(utbredelse(f[0])).toBe('1 av 2 stasjoner')
  })

  it('ÉN AUTORISERT STASJON GIR INGEN KJEDEPRESENTASJON', () => {
    // «1 av 1 stasjoner» er stoey som later som den er innsikt.
    // Butikksjefens flate skal ikke bli et kjedebilde med én rad.
    const f = byggFenomener([sv('s1', 'Lone', MANKO160, 'rod')], 1)
    expect(f[0].avTotalt).toBe(1)
    expect(utbredelse(f[0]), 'butikksjefen fikk et kjedebilde').toBeNull()
  })
})

// =====================================================================
// STRUKTURVAKTER
// =====================================================================
const RAA = readFileSync(join(process.cwd(), 'src', 'lib', 'fenomen.ts'), 'utf8')
  .replace(/\r\n/g, '\n')

// KODE UTEN KOMMENTARER OG UTEN STRENGINNHOLD.
//
// Fila FORKLARER hvorfor den ikke summerer kroner og ikke rangerer — og
// en vakt som leser den prosaen feller fila for å ha skrevet ned sin
// egen regel. Begge vaktene under kom rødt tilbake på nettopp det.
// Samme grep som `bildevakt.test.ts`.
const KILDE = utenKommentarer(RAA)
  .replace(/`(?:[^`\\]|\\.)*`/g, '‹streng›')
  .replace(/'(?:[^'\\\n]|\\.)*'/g, '‹streng›')
  .replace(/"(?:[^"\\\n]|\\.)*"/g, '‹streng›')

describe('aggregatet regner ingenting', () => {
  it('KANARIFUGL: fila blir funnet', () => {
    expect(RAA.length).toBeGreaterThan(3000)
    expect(KILDE).toContain('export function byggFenomener')
  })

  it('INGEN KRONESUM FINNES', () => {
    // `usynlig_kr` er teknisk addbart, men en kjedesum ville vaert et
    // nytt oekonomisk tall ingen motor eier - og `nettMotposter` finnes
    // nettopp fordi raa summer villeder. Typen har ikke noe kronefelt,
    // og fila har ingen addisjon.
    expect(KILDE).not.toMatch(/\breduce\(/)
    expect(KILDE).not.toMatch(/\bvekt\b/)
    expect(KILDE).not.toMatch(/kroner|Kr\b|_kr/)
  })

  it('INGEN RANGERING, INGEN TERSKEL, INGEN POENGFORMEL', () => {
    // `nivaa`, utbredelse og de underliggende tallene er separate
    // sannheter til noen eksplisitt bestemmer en regel som forener dem.
    expect(KILDE).not.toMatch(/\.sort\(/)
    expect(KILDE).not.toMatch(/poeng/)
    expect(KILDE).not.toMatch(/>=\s*\d|length\s*>\s*1\s*\)/)
  })

  it('IDENTITETEN ER `sammeSak`, IKKE EN KOPI', () => {
    // IMPORTSTIEN LESES AV RAAKILDEN. `KILDE` har gjort hver streng om
    // til ‹streng›, saa en sjekk paa den ville maalt sin egen erstatning.
    expect(RAA).toContain("from './regnskap-varsler'")
    expect(KILDE).toContain('sammeSak(x.sak, varsel.sak)')
    // Ingen egen sammenligning av slag eller kode.
    expect(KILDE).not.toMatch(/\.slag\s*===/)
    expect(KILDE).not.toMatch(/\.kode\s*===/)
  })

  it('STASJONEN KOMMER INN, DEN PARSES IKKE UT AV `omfang`', () => {
    expect(KILDE).not.toMatch(/omfang[^\n]*\.(split|match|replace|slice)\(/)
    expect(KILDE).toContain('stasjonId: string')
  })
})
