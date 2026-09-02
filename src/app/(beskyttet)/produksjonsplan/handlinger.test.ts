import { describe, expect, test } from 'vitest'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'

// =====================================================================
// NETTBRETTET SKRIVER ETT TALL, IKKE EN RAD
//
// `produksjonsplan_upd` (0136) slapp alle med stasjonen til paa HELE
// raden. `loggLagd` trenger `lagd_hittil`; raden baerer ogsaa `planlagt`
// - det butikksjefen har bestemt skal lages - og `start_antall` og
// `ekskludert`. UI-et tilbyr det ikke, men RLS avgjoer hva som ER mulig,
// ikke hva skjermen viser.
//
// Lukket i `0167` med `logg_lagd()`: security definer, eget
// tenantpredikat, og bare de to kolonnene.
//
// LESER KILDEN. Handlingen er 'use server' og drar inn env-modulen, som
// kaster i vitest. Det som maa vaktes er ikke rundskrivet, men de tre
// valgene: at skrivingen gaar gjennom funksjonen, at feilen leses, og at
// null rader ikke er en suksess.
// =====================================================================

const KILDE = readFileSync(
  join(process.cwd(), 'src', 'app', '(beskyttet)', 'produksjonsplan', 'handlinger.ts'),
  'utf8',
)
/** Uten kommentarene - de omtaler nettopp det vi leter etter. */
const kode = KILDE.replace(/\/\*[\s\S]*?\*\//g, '').replace(/^\s*\/\/.*$/gm, '')

describe('loggLagd gaar gjennom den smale veien', () => {
  test('KANARIFUGL: kilden lar seg lese, og kommentarene er strippet', () => {
    // Treffer ikke strippingen, leser paastandene under prosaen i stedet
    // for koden - og da beviser de ingenting.
    expect(kode).toContain('export async function loggLagd')
    expect(kode, 'kommentarene ble ikke fjernet').not.toContain('NETTBRETTET SKRIVER')
    expect(kode.length).toBeGreaterThan(500)
  })

  test('skriver gjennom logg_lagd, ikke rett paa tabellen', () => {
    // Selve saken.
    // Fra `loggLagd` til neste `export` — da maales bare denne funksjonen,
    // ikke `setLinje` under, som SKAL skrive rett paa tabellen.
    const fra = kode.indexOf('export async function loggLagd')
    const etter = kode.indexOf('export ', fra + 10)
    const kropp = kode.slice(fra, etter === -1 ? undefined : etter)
    expect(kropp).toMatch(/rpc\(\s*'logg_lagd'/)
    expect(kropp, 'skriver fortsatt rett paa tabellen')
      .not.toMatch(/from\('produksjonsplan_linjer'\)[\s\S]{0,80}\.update\(/)
  })

  test('feilen fra funksjonen leses', () => {
    // «Funksjonen finnes ikke» blir ellers til «ingen data» - samme form
    // som lot `/maaling` staa og si «Ingen stasjoner» i maanedsvis.
    expect(kode).toMatch(/const \{ data, error \} = await supabase\.rpc\(\s*'logg_lagd'/)
    expect(kode).toMatch(/if \(error\) throw/)
  })

  test('KANARIFUGL: null rader er IKKE en suksess', () => {
    // Funksjonen returnerer 0 baade naar stasjonen ikke er min og naar
    // linja ikke finnes. Svarer handlingen «ok» paa det, teller
    // nettbrettet videre paa et tall som aldri ble lagret.
    expect(kode).toMatch(/Number\(data \?\? 0\) === 0/)
    expect(kode.slice(kode.indexOf('Number(data ?? 0) === 0'))).toMatch(/throw new Error/)
  })

  test('lederens upsert er urort', () => {
    // `setLinje` er butikksjefens vei inn og maa fortsatt skrive hele
    // raden - `planlagt` er hennes beslutning. Tas den bort, kan ingen
    // endre en plan som alt er laget.
    expect(kode).toMatch(/from\('produksjonsplan_linjer'\)[\s\S]{0,120}\.upsert\(/)
  })
})

describe('migrasjonen og koden peker paa det samme', () => {
  // UTEN KOMMENTARENE. De omtaler nettopp det vi leter etter - «security
  // definer», «mine_stasjoner», «planlagt» - og en paastand som leser dem
  // holder selv naar SETNINGEN er endret. Det har skjedd tre ganger i
  // dette prosjektet; her er den lukket foer den rakk aa skje en fjerde.
  const sql = readFileSync(
    join(process.cwd(), 'supabase', 'migrations', '0167_logg_lagd_smal_vei.sql'), 'utf8',
  ).replace(/^\s*--.*$/gm, '')

  test('funksjonen roerer bare de to kolonnene', () => {
    // Kommer flere kolonner inn i `set`, er hele poenget borte - da er
    // den smale veien like bred som den gamle policyen.
    const sett = sql.slice(sql.indexOf('update public.produksjonsplan_linjer'))
      .slice(0, sql.slice(sql.indexOf('update public.produksjonsplan_linjer')).indexOf('where'))
    expect(sett).toMatch(/lagd_hittil/)
    expect(sett).toMatch(/oppdatert_tid/)
    expect(sett, 'planlagt er innenfor igjen').not.toMatch(/planlagt/)
    expect(sett, 'start_antall er innenfor igjen').not.toMatch(/start_antall/)
    expect(sett, 'ekskludert er innenfor igjen').not.toMatch(/ekskludert/)
  })

  test('KANARIFUGL: funksjonen baerer tenantpredikatet selv', () => {
    // `security definer` gaar forbi RLS. Uten denne linja kunne enhver
    // innlogget skrive paa enhver stasjon i enhver kjede.
    expect(sql).toMatch(/security definer/)
    expect(sql).toMatch(/mine_stasjoner\(\)/)
  })

  test('policyen er strammet til lederne', () => {
    const pol = sql.slice(sql.indexOf('create policy produksjonsplan_upd'))
    expect(pol).toMatch(/retailer_admin/)
    expect(pol).toMatch(/butikksjef/)
  })
})
