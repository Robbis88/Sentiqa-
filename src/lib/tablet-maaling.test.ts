import { describe, expect, it } from 'vitest'
import { createClient, type SupabaseClient } from '@supabase/supabase-js'
import { readFileSync } from 'node:fs'
import { hentHjemData } from '@/lib/tablethjem'

// =====================================================================
// TABLET — BASELINE. MÅLER, RETTER INGENTING.
// =====================================================================
//
// Revisjonen pekte på to ting i koden: en sekvensiell foss i
// `layout.tsx` og `router.refresh()` hvert 30. sekund. Begge er LESBARE
// i kilden — ingen av dem er MÅLT.
//
// Denne fila måler serversiden av nettbrettets landingsside: hvor mange
// rundturer den faktisk gjør, hvor lenge hvert ledd tar, og hvor mye av
// tiden som går med til å vente sekvensielt på noe som kunne gått
// parallelt.
//
// ---------------------------------------------------------------------
// HVA DEN IKKE MÅLER
// ---------------------------------------------------------------------
//
// TTFB, first useful paint, klientrender og antall HTTP-forespørsler
// fra nettleseren. De krever en ekte nettleser med en ekte
// nettbrettøkt, og de skal måles der — ikke gjettes her.
//
// KREVER KANARI_EPOST og KANARI_PASSORD.
// =====================================================================

const EPOST = process.env.KANARI_EPOST
const PASSORD = process.env.KANARI_PASSORD

function env(navn: string): string {
  const fil = readFileSync('.env.local', 'utf8')
  const l = fil.split(/\r?\n/).find((x) => x.startsWith(`${navn}=`))
  if (!l) throw new Error(`${navn} mangler i .env.local`)
  return l.slice(navn.length + 1).trim().replace(/^["']|["']$/g, '')
}

type Kall = { slag: string; navn: string }

/**
 * Teller rundturer uten aa endre oppfoerselen.
 *
 * TELLER, IKKE TIDFESTER. Foerste utgave pakket ogsaa hver
 * spoerringsbygger i en proxy for aa ta tiden paa selve nettverket.
 * Den ble skjoer mot PostgREST-byggerens kjeding, og den maalte noe
 * jeg allerede maaler: hvert LEDD tas det tid paa eksplisitt under.
 */
function tellende(k: SupabaseClient, logg: Kall[]): SupabaseClient {
  return new Proxy(k, {
    get(maal, felt, mottaker) {
      const v = Reflect.get(maal, felt, mottaker)
      if (felt === 'from' || felt === 'rpc') {
        return (...a: unknown[]) => {
          logg.push({ slag: String(felt), navn: String(a[0]) })
          return (v as (...x: unknown[]) => unknown).apply(maal, a)
        }
      }
      return v
    },
  })
}

const kjor = EPOST && PASSORD ? it : it.skip

describe('TABLET BASELINE — serversiden av landingssida', () => {
  kjor('måler rundturer og tid per ledd', async () => {
    const raa = createClient(
      env('NEXT_PUBLIC_SUPABASE_URL'), env('NEXT_PUBLIC_SUPABASE_ANON_KEY'),
    ) as SupabaseClient

    const tInn = performance.now()
    const { error } = await raa.auth.signInWithPassword({
      email: EPOST!, password: PASSORD!,
    })
    if (error) throw new Error(`Innlogging feilet: ${error.message}`)
    const innloggingMs = Math.round(performance.now() - tInn)

    const logg: Kall[] = []
    const supabase = tellende(raa, logg)

    // --- LAYOUTENS LEDD, i den rekkefølgen den faktisk gjør dem ------
    const t0 = performance.now()

    const tAuth = performance.now()
    const { data: { user } } = await raa.auth.getUser()
    const authMs = Math.round(performance.now() - tAuth)

    const tProfil = performance.now()
    await supabase.from('profiler').select('*').eq('id', user?.id ?? '').maybeSingle()
    const profilMs = Math.round(performance.now() - tProfil)

    const tVarsler = performance.now()
    await supabase.from('varsler').select('id', { count: 'exact', head: true })
    const varslerMs = Math.round(performance.now() - tVarsler)

    const tStasjoner = performance.now()
    const { data: stasjoner } = await supabase
      .from('stasjoner').select('id, navn, butikknummer')
      .is('slettet_tid', null).order('butikknummer')
    const stasjonerMs = Math.round(performance.now() - tStasjoner)

    const layoutMs = Math.round(performance.now() - t0)

    // --- SIDENS EGNE DATA -------------------------------------------
    const st = (stasjoner ?? [])[0] as { id: string; navn: string } | undefined
    if (!st) throw new Error('Ingen stasjon i scopet')

    const logFoerHjem = logg.length
    const tHjem = performance.now()
    await hentHjemData(supabase, st.id)
    const hjemMs = Math.round(performance.now() - tHjem)

    // --- ATTRIBUSJON: de fire grenene hver for seg --------------------
    //
    // SAMME SPOERRINGER, ETT OM GANGEN. Ikke for aa maale sidens
    // faktiske kostnad - den er malt over, parallelt - men for aa finne
    // ut HVILKEN gren som setter gulvet naar de kjoerer samtidig.
    const idag = new Date().toISOString().slice(0, 10)
    type Gren = { navn: string; ms: number; rader: number | string }
    const grener: Gren[] = []
    const maal = async (navn: string, f: () => PromiseLike<{ data: unknown }>) => {
      const t = performance.now()
      const { data } = await f()
      grener.push({
        navn,
        ms: Math.round(performance.now() - t),
        rader: Array.isArray(data) ? data.length : data == null ? 0 : 1,
      })
    }

    await maal('rpc hjem_stasjonstall', () =>
      raa.rpc('hjem_stasjonstall', { p_stasjon_id: st.id }))
    await maal('pengepremie', () =>
      raa.from('pengepremie').select('belop_kr').eq('stasjon_id', st.id))
    await maal('v_salg_per_stasjon_dag (760)', () =>
      raa.from('v_salg_per_stasjon_dag')
        .select('dato, mat_omsetning, kald_drikke_omsetning')
        .eq('stasjon_id', st.id).order('dato', { ascending: false }).limit(760))
    await maal('produksjonsplan_hode', () =>
      raa.from('produksjonsplan_hode').select('publisert_tid')
        .eq('stasjon_id', st.id).eq('dato', idag).maybeSingle())

    const totalMs = Math.round(performance.now() - t0)

    // --- ETTER: SAMME FIRE LEDD, PARALLELT ---------------------------
    //
    // MAALT I SAMME KJOERING som «foer». Mellom to kjoeringer varierte
    // totalen fra 806 til 1640 ms - nettverket alene. En foer/etter over
    // to kjoeringer ville derfor maalt vaeret, ikke rettelsen.
    const tEtter = performance.now()
    await Promise.all([
      raa.auth.getUser(),
      raa.from('profiler').select('*').eq('id', user?.id ?? '').maybeSingle(),
      raa.from('varsler').select('id', { count: 'exact', head: true }),
      raa.from('stasjoner').select('id, navn, butikknummer')
        .is('slettet_tid', null).order('butikknummer'),
    ])
    const parallelltMs = Math.round(performance.now() - tEtter)

    const L = ['', '  TABLET BASELINE — serversiden', '']
    L.push(`  stasjon .................... ${st.navn}`)
    L.push(`  innlogging (utenfor) ....... ${innloggingMs} ms`)
    L.push('')
    L.push('  LAYOUT (sekvensielt, ett ledd om gangen):')
    L.push(`    auth.getUser ............. ${authMs} ms`)
    L.push(`    profiler ................. ${profilMs} ms`)
    L.push(`    varsler (count) .......... ${varslerMs} ms`)
    L.push(`    stasjoner ................ ${stasjonerMs} ms`)
    L.push(`    SUM layout ............... ${layoutMs} ms`)
    L.push('')
    L.push('  SIDA (/oversikt -> hentHjemData):')
    L.push(`    rundturer ................ ${logg.length - logFoerHjem}`)
    for (const k of logg.slice(logFoerHjem)) L.push(`      ${k.slag} ${k.navn}`)
    L.push(`    SUM hjemdata (parallelt) . ${hjemMs} ms`)
    L.push('')
    L.push('  ATTRIBUSJON — hver gren alene:')
    for (const g of grener.sort((x, y) => y.ms - x.ms)) {
      L.push(`    ${g.navn.padEnd(30)} ${String(g.ms).padStart(5)} ms   ${g.rader} rader`)
    }
    const tregestGren = Math.max(...grener.map((g) => g.ms))
    L.push(`    tregeste gren ................ ${tregestGren} ms`)
    L.push(`    maalt parallelt .............. ${hjemMs} ms`)
    L.push(`    overhead over tregeste gren .. ${hjemMs - tregestGren} ms`)
    L.push('')
    L.push(`  TOTAL serversid ............ ${totalMs} ms`)
    L.push(`  rundturer totalt ........... ${logg.length + 1}  (+1 = auth.getUser)`)
    L.push('')
    L.push('  LAYOUT: FOER -> ETTER, samme kjoering:')
    const sekvensielt = authMs + profilMs + varslerMs + stasjonerMs
    const tregeste = Math.max(authMs, profilMs, varslerMs, stasjonerMs)
    L.push(`    sekvensielt (foer) ....... ${sekvensielt} ms`)
    L.push(`    parallelt (etter) ........ ${parallelltMs} ms   MAALT`)
    L.push(`    spart .................... ${sekvensielt - parallelltMs} ms`)
    L.push(`    tregeste ledd alene ...... ${tregeste} ms  (gulvet)`)
    L.push(`    rundturer ................ 4 -> 4  (uendret, som ventet)`)
    L.push('')
    console.log(L.join('\n'))

    expect(logg.length).toBeGreaterThan(0)
    expect(totalMs).toBeGreaterThan(0)
  }, 180000)
})
