import { readFileSync, readdirSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, test } from 'vitest'
import { omfangstekst, medOmfang } from '../stasjonsomfang'

// =====================================================================
// HVILKE SIDER LESER EN STASJONSTABELL UTEN Å FILTRERE?
//
// En butikksjef kan ha flere stasjoner. Leser en side en tabell med
// `stasjon_id` uten et filter, gir RLS alle stasjonene hen når — og
// tallet på skjermen er en sum over dem. «12 svar · snitt 4,2» leses som
// «min stasjon».
//
// ---------------------------------------------------------------------
// MÅLINGEN LØY TRE GANGER FØR DEN VAR TIL Å STOLE PÅ
//
// En revisjon meldte «elleve lederflater viser tall på tvers av
// stasjoner uten å si det». Jeg fant ikke elleve. Jeg fant én — og
// sytten som allerede hadde tatt stilling.
//
// Veien dit gikk gjennom tre detektorer som alle tok feil, og de er
// verdt å skrive ned fordi de er samme feil i tre former:
//
//   1. `paaStasjon(supabase.from(…))` — filteret sto ETT LEDD unna, og
//      mønsteret krevde at det sto rett foran. Hele butikksjef-
//      dashbordet ble meldt: den ene sida som har tenkt grundigst på
//      nettopp dette.
//   2. Kjede-enden ble gjettet med en lookahead, og den bommet på
//      `/kontrakt`, som har `.eq('stasjon_id', …)` to linjer under.
//   3. Et `.insert({…})` med et helt annet `.select(` lenger nede i
//      vinduet så ut som en lesing. `/ikmat` sitt skriv ble meldt slik.
//
// **Alle tre meldte KORREKT kode som feil.** Det er den farligste
// formen en vakt kan ha — ikke fordi den er ubehagelig, men fordi den
// flytter arbeidet fra å rette feil til å avvise funn, og da slutter
// folk å lese rødt.
//
// Derfor er dette en FASIT med begrunnelser, ikke en forbudsliste.
// Hvert par (rute, tabell) står der med en grunn noen har skrevet, og
// et NYTT par er rødt til noen tar stilling.
// =====================================================================

const ROT = process.cwd()
const APP = join(ROT, 'src', 'app', '(beskyttet)')
const MIGRASJONER = join(ROT, 'supabase', 'migrations')
const FASIT = join(ROT, 'src', 'lib', 'redesign', 'omfangsfasit.json')

/** Tabellene som har en `stasjon_id`, lest ut av migrasjonene. */
function stasjonstabeller(): Set<string> {
  let sql = ''
  for (const f of readdirSync(MIGRASJONER).filter((n) => n.endsWith('.sql')).sort()) {
    sql += readFileSync(join(MIGRASJONER, f), 'utf8')
  }
  sql = sql.replace(/--.*/g, '')
  const ut = new Set<string>()
  for (const m of sql.matchAll(/create table if not exists public\.(\w+)\s*\(([\s\S]*?)\n\);/g)) {
    if (/\bstasjon_id\b/.test(m[2])) ut.add(m[1])
  }
  for (const m of sql.matchAll(/alter table public\.(\w+)\s+add column if not exists stasjon_id/g)) {
    ut.add(m[1])
  }
  return ut
}

function filer(mappe: string): string[] {
  const ut: string[] = []
  for (const rad of readdirSync(mappe, { withFileTypes: true })) {
    const sti = join(mappe, rad.name)
    if (rad.isDirectory()) ut.push(...filer(sti))
    else if (/\.tsx?$/.test(rad.name) && !rad.name.includes('.test.')) ut.push(sti)
  }
  return ut
}

/** `<rute>::<tabell>` for hver lesing uten stasjonsfilter. */
export function utenStasjonsfilter(
  kilde: string, rute: string, stasjonstabell: (t: string) => boolean,
): string[] {
  const ut: string[] = []
  // ET FAST VINDU, IKKE EN KJEDE-ENDE.
  //
  // Første utgave prøvde å finne slutten på kallkjeden med en lookahead.
  // Den bommet: `/kontrakt` har `.eq('stasjon_id', valgt.id)` to linjer
  // under `.from(...)` og ble likevel meldt. En detektor som ikke ser et
  // filter som STÅR DER er verre enn ingen — den flytter arbeidet fra å
  // rette feil til å avvise funn.
  //
  // Et fast vindu på 500 tegn dekker hver kjede i dette repoet og har
  // ingen kant å bomme på. Prisen er at et filter lenger unna enn det
  // ikke ses; da havner paret i fasiten med en grunn, og det er en
  // billigere feil.
  for (const m of kilde.matchAll(/\.from\((['"])(\w+)\1\)/g)) {
    const tabell = m[2]
    if (!stasjonstabell(tabell)) continue
    const vindu = kilde.slice(m.index!, m.index! + 500)
    // Et SKRIV er ikke et aggregat. `.from('x').insert({…})` etterfulgt
    // av et helt annet kall med `.select(` lenger nede i vinduet så ut
    // som en lesing — `/ikmat` sitt insert ble meldt slik.
    if (/^[\s\S]{0,40}\.(insert|upsert|update|delete)\(/.test(vindu)) continue
    if (!/\.select\(/.test(vindu)) continue
    if (/stasjon_id|butikknummer/.test(vindu)) continue
    // Ett oppslag på primærnøkkel er ikke et aggregat.
    if (/\.maybeSingle\(|\.single\(|\.eq\((['"])id\1/.test(vindu)) continue
    // `paaStasjon(supabase.from(...))` FILTRERER — bare et ledd unna.
    // Uten dette meldte målingen hele butikksjef-dashbordet, som er den
    // ene sida som har tenkt grundigst på nettopp dette.
    const foran = kilde.slice(Math.max(0, m.index! - 60), m.index!)
    if (/paaStasjon\(|bareStasjon/.test(foran)) continue
    ut.push(`${rute}::${tabell}`)
  }
  return ut
}

const tabeller = stasjonstabeller()
const alle = filer(APP)
const naa = [...new Set(alle.flatMap((sti) => {
  const rute = `/${sti.slice(APP.length + 1).replace(/\\/g, '/').replace(/\/[^/]+$/, '')}`
  return utenStasjonsfilter(readFileSync(sti, 'utf8'), rute === '/' ? '/(rot)' : rute,
    (t) => tabeller.has(t))
}))].sort()

describe('målingen ser det den skal', () => {
  test('KANARIFUGL: den fant stasjonstabellene', () => {
    // Endres formen på migrasjonene, blir settet tomt — og «ingen side
    // leser en stasjonstabell uten filter» blir sant fordi ingen tabell
    // finnes.
    expect(tabeller.size, 'fant nesten ingen tabeller med stasjon_id')
      .toBeGreaterThan(40)
    expect(tabeller.has('puls_svar')).toBe(true)
    expect(tabeller.has('rutine_utforinger')).toBe(true)
  })

  test('KANARIFUGL: den fant sidene', () => {
    expect(alle.length, 'fant nesten ingen sider').toBeGreaterThan(100)
  })

  test('et filter teller som et filter', () => {
    const er = (t: string) => t === 'puls_svar'
    expect(utenStasjonsfilter(
      "await sb.from('puls_svar').select('skala').eq('stasjon_id', x)\n", '/p', er)).toEqual([])
    expect(utenStasjonsfilter(
      "await sb.from('puls_svar').select('skala')\n", '/p', er)).toEqual(['/p::puls_svar'])
  })

  test('paaStasjon() teller som et filter', () => {
    // Den ekte formen fra butikksjef-dashbordet. Uten dette meldte
    // målingen tretten korrekte sider, og en vakt med falske funn
    // laerer folk aa se bort fra roedt.
    const er = (t: string) => t === 'rutiner'
    expect(utenStasjonsfilter(
      "paaStasjon(supabase.from('rutiner').select('*', { count: 'exact' }))\n", '/d', er))
      .toEqual([])
  })
})

describe('omfangsvakten', () => {
  test('hvert (rute, tabell)-par er tatt stilling til', () => {
    if (process.env.OPPDATER_FASIT === '1') {
      const gammel = JSON.parse(readFileSync(FASIT, 'utf8')) as { par: Record<string, string> }
      const ny: Record<string, string> = {}
      for (const p of naa) ny[p] = gammel.par[p] ?? 'IKKE KLASSIFISERT - skriv grunnen her'
      writeFileSync(FASIT, `${JSON.stringify({ par: ny }, null, 2)}\n`)
      return
    }
    const fasit = JSON.parse(readFileSync(FASIT, 'utf8')) as { par: Record<string, string> }
    const nye = naa.filter((p) => !(p in fasit.par))

    expect(
      nye,
      `\nDisse leser en tabell med stasjon_id uten aa filtrere:\n`
      + `${nye.map((p) => `  ${p}`).join('\n')}\n\n`
      + 'RLS gir da ALLE stasjonene brukeren naar, og tallet blir en sum '
      + 'over dem. Det kan vaere riktig - en butikksjef med tre stasjoner '
      + 'har ansvar for tre - men da skal det STAA. Bruk `medOmfang()`.\n\n'
      + 'Er det riktig som det er, foer paret inn i omfangsfasit.json med '
      + 'en grunn: OPPDATER_FASIT=1 npx vitest run src/lib/redesign\n',
    ).toEqual([])
  })

  test('ingen post i fasiten staar uten grunn', () => {
    const fasit = JSON.parse(readFileSync(FASIT, 'utf8')) as { par: Record<string, string> }
    const tomme = Object.entries(fasit.par)
      .filter(([, grunn]) => !grunn || grunn.length < 15 || /IKKE KLASSIFISERT/.test(grunn))
      .map(([p]) => p)
    expect(
      tomme,
      'En fasit uten begrunnelser er en liste, ikke en beslutning.',
    ).toEqual([])
  })

  test('fasiten er ikke full av doede par', () => {
    const fasit = JSON.parse(readFileSync(FASIT, 'utf8')) as { par: Record<string, string> }
    const doede = Object.keys(fasit.par).filter((p) => !naa.includes(p))
    expect(
      doede,
      `${doede.join(', ')} finnes ikke lenger. Stram fasiten:\n`
      + '  OPPDATER_FASIT=1 npx vitest run src/lib/redesign',
    ).toEqual([])
  })
})

describe('omfangsteksten', () => {
  test('sier ingenting ved én stasjon', () => {
    // «Tallene dekker alle 1 stasjonene dine» er stoey, og en merknad
    // som staar der uansett slutter folk aa lese.
    expect(omfangstekst(1)).toBeNull()
    expect(omfangstekst(0)).toBeNull()
    expect(medOmfang('Fem målinger.', 1)).toBe('Fem målinger.')
  })

  test('navngir antallet ved flere', () => {
    expect(omfangstekst(3)).toBe('Tallene dekker alle 3 stasjonene dine.')
    expect(medOmfang('Fem målinger.', 3))
      .toBe('Fem målinger. Tallene dekker alle 3 stasjonene dine.')
  })
})
