import { readFileSync, readdirSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, it } from 'vitest'
import { maaVaereHele, TAK } from './datobolker'

// =====================================================================
// EN SPØRRING UTEN GRENSE ER EN SPØRRING SOM KAN LYVE
//
// PostgREST returnerer tusen rader og sier ingenting. Rutinesida hadde
// ikke én `.limit()`, og utføringene for dagens vaktdatoer — over alle
// stasjoner — ligger rundt tusen. Da taket traff, falt Bønes sine
// avhukinger utenfor, og sida meldte **68 rutiner igjen** som folk
// nettopp hadde gjort ferdig.
//
// Det ser ikke ut som en feil. Det ser ut som at ingen har gjort jobben
// sin — og det er den verste formen: tallet er troverdig.
//
// Samme fella står i migrasjonshistorikken tre ganger (`0090`, `0166`,
// `0175`) og i `hentPerDato` sin egen kommentar. Fjerde gang er ikke
// uflaks; det er en regel som mangler en vakt.
//
// ---------------------------------------------------------------------
// HVA DENNE MÅLER, OG HVA DEN IKKE GJØR
//
// Den teller `.select(` i sidefiler som IKKE har en `.limit(`, en
// `.maybeSingle(`, en `.single(` eller går gjennom `hentPerDato`. Den
// beviser ikke at grensen er riktig satt — bare at noen har tatt
// stilling til at det finnes en.
//
// Feiler hvis tallet VOKSER. Det er mange fra før, og en storrengjøring
// nå ville vært en diff ingen kunne lese. Men ingen nye skal komme til.
// =====================================================================

const ROT = process.cwd()
const FASIT = join(ROT, 'src', 'lib', 'supabase', 'grensefasit.json')

function tsFiler(mappe: string): string[] {
  const ut: string[] = []
  for (const rad of readdirSync(mappe, { withFileTypes: true })) {
    const sti = join(mappe, rad.name)
    if (rad.isDirectory()) ut.push(...tsFiler(sti))
    else if (/\.tsx?$/.test(rad.name) && !/\.test\.tsx?$/.test(rad.name)) ut.push(sti)
  }
  return ut
}

/**
 * Kjeden som følger et `.from('x')`.
 *
 * Stopper ved det første som ligner en avslutning. `//` er MED i den
 * lista, og det er en kjent blindsone: et `.from()` som står under en
 * kommentar inne i samme `Promise.all([…])` blir spist av kjeden over og
 * vurderes aldri. Se påstanden «vurderer det meste av spørringene den
 * finner» — den holder avstanden under oppsyn i stedet for å late som
 * den ikke finnes.
 */
const KJEDE = /\.from\((['"`])([^'"`]+)\1\)([\s\S]{0,900}?)(?=\n\s*(?:\]|\)|const |return |\/\/|$))/g

/** Hvor mange `.from()`-kall kjederegexen faktisk rekker over. */
export function vurderte(kilde: string): number {
  return [...kilde.matchAll(KJEDE)].length
}

/** `.from('x').select(...)`-kjeder uten en grense i samme kjede. */
export function utenGrense(kilde: string): string[] {
  const ut: string[] = []
  for (const m of kilde.matchAll(KJEDE)) {
    const kjede = m[3]
    if (!/\.select\(/.test(kjede)) continue
    // `.single<T>()` og `.maybeSingle<T>()` har en typeparameter mellom
    // navnet og parentesen. Uten `<[^>]*>?` telte 52 enkeltradsoppslag
    // som funn, og fasittallet ble mest støy over signalet.
    if (/\.limit\(|\.range\(|\.maybeSingle(<[^>]*>)?\(|\.single(<[^>]*>)?\(|head:\s*true/.test(kjede)) continue
    ut.push(m[2])
  }
  return ut
}

const filer = tsFiler(join(ROT, 'src'))
  .map((f) => ({ f, kilde: readFileSync(f, 'utf8') }))
const naa = filer.reduce((s, { kilde }) => s + utenGrense(kilde).length, 0)

describe('målingen forstår det den teller', () => {
  it('teller en select uten grense', () => {
    expect(utenGrense("await sb.from('rutiner').select('id')\n")).toEqual(['rutiner'])
  })

  it('teller ikke en som har grense', () => {
    expect(utenGrense("await sb.from('rutiner').select('id').limit(500)\n")).toEqual([])
  })

  it('teller ikke en enkeltrad', () => {
    expect(utenGrense("await sb.from('rutiner').select('id').eq('id', x).maybeSingle()\n")).toEqual([])
    expect(utenGrense("await sb.from('rutiner').select('id').eq('id', x).single()\n")).toEqual([])
  })

  // TYPEPARAMETEREN GJORDE 52 ENKELTRADER TIL FUNN.
  //
  // Kodebasen skriver `.maybeSingle<Rad>()`, ikke `.maybeSingle()`. Uten
  // `<[^>]*>?` i mønsteret talte hver eneste av dem som en spørring uten
  // grense — og et fasittall på 244 der 52 var støy, gjør det umulig å
  // se når et EKTE funn kommer til. Etter rettelsen: 193.
  it('teller ikke en enkeltrad med typeparameter', () => {
    expect(utenGrense("await sb.from('x').select('id').eq('id', y).maybeSingle<Rad>()\n")).toEqual([])
    expect(utenGrense("await sb.from('x').select('id').eq('id', y).single<{ a: number }>()\n")).toEqual([])
  })

  it('teller ikke en ren telling', () => {
    expect(utenGrense("await sb.from('x').select('*', { count: 'exact', head: true })\n")).toEqual([])
  })

  it('teller ikke et skriv', () => {
    expect(utenGrense("await sb.from('x').insert({ a: 1 })\n")).toEqual([])
  })
})

describe('grensevakten', () => {
  it('den ser fortsatt filene', () => {
    // Peker stien feil, blir lista tom og skrallen grønn uten å ha sett
    // en eneste spørring.
    expect(filer.length, 'fant ingen .ts-filer under src/').toBeGreaterThan(300)
  })

  // =================================================================
  // ET GULV, IKKE BARE ET TAK
  // =================================================================
  // Skrallen under feiler bare når tallet VOKSER. Slutter kjederegexen
  // å treffe — fordi en formatering endrer seg, eller fordi noen skriver
  // spørringene sine annerledes — blir `naa` null, og null er mindre enn
  // fasiten. Grønn, uten å ha sett noe.
  //
  // Det er nøyaktig samme form som `design.test.ts` og `skrivevakt.test.ts`
  // begge har et gulv for. Denne ble skrevet uten, samme dag som jeg
  // skrev ned regelen.
  it('antallet har ikke falt uten at fasiten fulgte med', () => {
    const fasit = JSON.parse(readFileSync(FASIT, 'utf8')) as { utenGrense: number }
    expect(
      naa,
      `Tallet har gått ned fra ${fasit.utenGrense} til ${naa}. Enten er noe ryddet `
      + '— da skal fasiten følge med: OPPDATER_FASIT=1 npx vitest run src/lib/supabase '
      + '— eller så har detektoren sluttet å se. Sjekk det siste først.',
    ).toBeGreaterThanOrEqual(fasit.utenGrense)
  })

  // =================================================================
  // BLINDSONEN: 125 SPØRRINGER BLE ALDRI VURDERT
  // =================================================================
  // Kjederegexen sluker opptil 900 tegn framover og stopper på det
  // første som ligner en avslutning — blant annet en `//`-kommentar. Et
  // `.from()` som står lenger nede i samme `Promise.all([…])` ble
  // dermed spist av kjeden over. Målt: 749 `.from(`-kall i `src/`, bare
  // 569 vurdert.
  //
  // Et `.from()` som aldri telles ser nøyaktig ut som et som er trygt.
  // Denne påstanden holder avstanden mellom «finnes» og «vurdert» under
  // oppsyn: vokser den, har detektoren mistet syne av flere.
  it('vurderer det meste av spørringene den finner', () => {
    const funnet = filer.reduce(
      (s, { kilde }) => s + [...kilde.matchAll(/\.from\((['"`])/g)].length, 0,
    )
    const vurdert = filer.reduce((s, { kilde }) => s + vurderte(kilde), 0)
    expect(funnet, 'fant ingen .from(-kall i det hele tatt').toBeGreaterThan(400)
    expect(
      vurdert / funnet,
      `Detektoren vurderer ${vurdert} av ${funnet} spørringer. Blindsonen har `
      + 'vokst — et `.from()` som aldri telles ser nøyaktig ut som et som er trygt.',
    ).toBeGreaterThan(0.7)
  })

  it('antallet har ikke vokst', () => {
    if (process.env.OPPDATER_FASIT === '1') {
      writeFileSync(FASIT, `${JSON.stringify({ utenGrense: naa }, null, 2)}\n`)
      return
    }
    const fasit = JSON.parse(readFileSync(FASIT, 'utf8')) as { utenGrense: number }
    expect(
      naa,
      `Spørringer uten grense har gått fra ${fasit.utenGrense} til ${naa}.\n\n`
      + `PostgREST kutter på ${TAK} rader UTEN å feile, og et avkortet svar `
      + 'ser ut som ekte tall. Bønes meldte 68 rutiner igjen som folk nettopp '
      + 'hadde gjort ferdig.\n\n'
      + 'Sett en generøs `.limit()` og send svaret gjennom `maaVaereHele`, '
      + 'eller bruk `hentPerDato` for en datoserie.\n\n'
      + 'Er økningen med vilje: OPPDATER_FASIT=1 npx vitest run src/lib/supabase',
    ).toBeLessThanOrEqual(fasit.utenGrense)
  })
})

describe('maaVaereHele', () => {
  it('slipper gjennom et svar under grensen', () => {
    expect(maaVaereHele({ data: [1, 2, 3], error: null }, 'noe', 10)).toEqual([1, 2, 3])
  })

  it('kaster når svaret fyller grensen', () => {
    const data = Array.from({ length: 10 }, (_, i) => i)
    expect(() => maaVaereHele({ data, error: null }, 'utførte rutiner', 10))
      .toThrow(/avkortet/)
  })

  // =================================================================
  // ET TAK OVER TUSEN ER IKKE ET TAK
  // =================================================================
  // `supabase/config.toml` setter `max_rows = 1000`. En `.limit(20000)`
  // gir aldri mer enn tusen rader, saa en sjekk paa «naadde du tjue
  // tusen» kan ALDRI utloeses.
  //
  // Foerste utgave av `maaVaereHele` gjorde noeyaktig det. Den ble
  // skrevet samme dag for aa fange «68 rutiner igjen», og var inert paa
  // hvert kallsted som brukte et generoest tall. En vakt som ikke kan
  // feile ser noeyaktig ut som en vakt som ikke finner noe.
  it('kaster på tusen selv når kalleren ba om tjue tusen', () => {
    const tusen = Array.from({ length: TAK }, (_, i) => i)
    expect(() => maaVaereHele({ data: tusen, error: null }, 'utførte rutiner', 20000))
      .toThrow(/traff taket paa 1000/)
  })

  it('sier fra at kalleren ba om noe PostgREST aldri gir', () => {
    const tusen = Array.from({ length: TAK }, (_, i) => i)
    expect(() => maaVaereHele({ data: tusen, error: null }, 'noe', 20000))
      .toThrow(/kalleren bad om 20000/)
  })

  it('lar kalleren SENKE taket, aldri heve det', () => {
    const femti = Array.from({ length: 50 }, (_, i) => i)
    // 50 rader mot et tak paa 50: skal kaste.
    expect(() => maaVaereHele({ data: femti, error: null }, 'noe', 50)).toThrow()
    // 50 rader mot standardtaket: skal gaa fint.
    expect(maaVaereHele({ data: femti, error: null }, 'noe')).toHaveLength(50)
  })

  it('kaster på feil, i stedet for å gi tom liste', () => {
    // En lesefeil som blir til `[]` er den samme løgnen som avkorting:
    // null rader ser ut som «ingenting er gjort».
    expect(() => maaVaereHele({ data: null, error: { message: 'nei' } }, 'utførte rutiner'))
      .toThrow(/Kunne ikke lese utførte rutiner/)
  })

  it('tåler tomt svar uten feil', () => {
    expect(maaVaereHele({ data: null, error: null }, 'noe', 10)).toEqual([])
  })
})
