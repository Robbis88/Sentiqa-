import { readFileSync, readdirSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, test } from 'vitest'

// =====================================================================
// ANONYMISERINGEN SKAL BLI VÆRENDE UNDER VISNINGEN
//
// `malekort.anonymiser` byttet butikknavnet til «Butikk #4» i
// `leaderboard.tsx` — altså i JSX-en. Navnene kom fra
// `malekort_stasjoner()`, en `security definer`-RPC enhver innlogget
// kunne kalle, og tallene fra `beregn_malekort_salg`. En butikksjef
// kunne joine de to over PostgREST og få den navngitte rangeringen
// tilbake, uansett hva admin hadde huket av.
//
// Det er nøyaktig formen AGENTS.md advarer mot: **et flagg i en kolonne
// er ikke en grense før noe under visningen leser det.** Samme som
// `malekort.vis_tablet` før `0134`.
//
// `0194` flyttet anonymiseringen til `malekort_navn(p_malekort)`, som
// kjenner kortet og returnerer `navn = null` for stasjoner kalleren
// ikke skal se. `0195` tar granten på den gamle.
//
// ---------------------------------------------------------------------
// HVA DENNE MÅLER
//
// At den ikke sniker seg tilbake. Tre ting:
//
//   1. Ingen flate kaller `malekort_stasjoner()` lenger.
//   2. `malekort_navn` finnes i migrasjonene og anonymiserer selv.
//   3. `leaderboard.tsx` tar ingen avgjørelse om navn.
//
// Den tredje er den som ville sagt fra hvis noen «forenklet» ved å
// flytte logikken tilbake dit den var lettest å skrive.
// =====================================================================

const ROT = process.cwd()
const APP = join(ROT, 'src', 'app', '(beskyttet)')
const MIGRASJONER = join(ROT, 'supabase', 'migrations')

function filer(mappe: string): string[] {
  const ut: string[] = []
  for (const rad of readdirSync(mappe, { withFileTypes: true })) {
    const sti = join(mappe, rad.name)
    if (rad.isDirectory()) ut.push(...filer(sti))
    else if (/\.tsx?$/.test(rad.name) && !rad.name.includes('.test.')) ut.push(sti)
  }
  return ut
}

const kilder = filer(APP).map((sti) => ({ sti, kilde: readFileSync(sti, 'utf8') }))
const migrasjoner = readdirSync(MIGRASJONER).filter((f) => f.endsWith('.sql')).sort()
  .map((f) => readFileSync(join(MIGRASJONER, f), 'utf8')).join('\n')

describe('målingen ser flatene', () => {
  test('KANARIFUGL: den leste faktisk sidene og migrasjonene', () => {
    expect(kilder.length, 'fant nesten ingen sider').toBeGreaterThan(100)
    expect(migrasjoner.length, 'fant nesten ingen migrasjons-SQL')
      .toBeGreaterThan(100000)
    // Den ene sida regelen handler om må finnes, ellers måler dette
    // ingenting.
    expect(kilder.some((k) => k.sti.includes('maaling'))).toBe(true)
  })
})

describe('anonymiseringen bor under visningen', () => {
  test('ingen flate kaller den gamle malekort_stasjoner()', () => {
    const syndere = kilder
      .filter((k) => /rpc\(\s*'malekort_stasjoner'/.test(k.kilde))
      .map((k) => k.sti.replace(ROT, '.'))
    expect(
      syndere,
      '\n`malekort_stasjoner()` gir navnet paa HVER stasjon i kjeden til '
      + 'enhver innlogget, og kan joines med `beregn_malekort_salg` for aa '
      + 'omgaa `anonymiser`.\n\nBruk `malekort_navn(p_malekort)` (0194), '
      + 'som anonymiserer selv.\n',
    ).toEqual([])
  })

  test('malekort_navn finnes og anonymiserer selv', () => {
    expect(migrasjoner, 'malekort_navn mangler i migrasjonene')
      .toMatch(/create or replace function public\.malekort_navn/)
    // Uten rollesjekken ville funksjonen returnert navn til alle, og
    // hele flyttingen vaert uten virkning.
    const def = /create or replace function public\.malekort_navn[\s\S]*?\$\$;/
      .exec(migrasjoner)![0]
    expect(def, 'malekort_navn leser ikke anonymiser-flagget').toMatch(/anonymiser/)
    expect(def, 'malekort_navn har ingen rollesjekk').toMatch(/gjeldende_rolle/)
    expect(def, 'malekort_navn er ikke tenantbundet - definer uten predikat')
      .toMatch(/gjeldende_retailer_id/)
    expect(def, 'malekort_navn skiller ikke egne stasjoner fra de andre')
      .toMatch(/mine_stasjoner/)
  })

  test('leaderboard tar ingen avgjørelse om navn', () => {
    const lb = readFileSync(join(APP, 'maaling', 'leaderboard.tsx'), 'utf8')
    const utenKommentar = lb.replace(/\/\*[\s\S]*?\*\//g, ' ').replace(/\/\/.*/g, '')
    expect(
      utenKommentar,
      'Anonymiseringen er tilbake i visningen. Da kan den omgaas igjen — '
      + 'navnet skal komme ferdig anonymisert fra malekort_navn().',
    ).not.toMatch(/Butikk #|anonymiser/)
  })

  test('0195 fjerner granten, og sier at den maa kjores ETTER koden', () => {
    const f = readdirSync(MIGRASJONER).find((x) => x.startsWith('0195'))
    expect(f, 'migrasjon 0195 mangler').toBeTruthy()
    const sql = readFileSync(join(MIGRASJONER, f!), 'utf8')
    expect(sql).toMatch(/revoke execute on function public\.malekort_stasjoner/)
    // Rekkefoelgen er motsatt av husregelen, og det er hele grunnen til
    // at den maa staa skrevet i fila.
    expect(sql, '0195 sier ikke at den skal kjores etter deployen')
      .toMatch(/ETTER/)
  })
})
