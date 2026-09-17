'use server'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { erLeder } from '@/lib/auth/roller'
import { traffEnRad } from '@/lib/skriv-svar'

export type LinjeData = {
  stasjon_id: string
  dato: string
  varenavn: string
  varegruppe_kode: string | null
  varegruppe_navn: string | null
  foreslatt: number
  planlagt: number
  start_antall?: number
  ekskludert?: boolean
}

export type PlansnapshotLinje = Omit<LinjeData, 'stasjon_id' | 'dato'>

function validerLinje(data: PlansnapshotLinje) {
  if (!data.varenavn?.trim() || !Number.isInteger(data.foreslatt) || data.foreslatt < 0
    || !Number.isInteger(data.planlagt) || data.planlagt < 0
    || !Number.isInteger(data.start_antall ?? 0) || (data.start_antall ?? 0) < 0
    || (data.start_antall ?? 0) > data.planlagt) {
    throw new Error('Kontroller antallene. Startpartiet kan ikke være større enn dagsplanen.')
  }
}

// Lagrer/overstyrer en plan-linje (planlagt, startAntall, ekskluder). Bevarer
// lagd_hittil (settes ikke her — kun fra tableten).
export async function setLinje(data: LinjeData): Promise<void> {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle) || !bruker.retailerId) throw new Error('Kun leder kan endre planen.')
  if (!data.stasjon_id || !data.dato) throw new Error('Velg stasjon og dato.')
  validerLinje(data)
  const supabase = await lagSupabaseServerKlient()
  traffEnRad(await supabase.from('produksjonsplan_linjer').upsert(
    {
      retailer_id: bruker.retailerId,
      stasjon_id: data.stasjon_id,
      dato: data.dato,
      varenavn: data.varenavn,
      varegruppe_kode: data.varegruppe_kode,
      varegruppe_navn: data.varegruppe_navn,
      foreslatt: Math.round(data.foreslatt),
      planlagt: Math.max(0, Math.round(data.planlagt)),
      start_antall: Math.max(0, Math.round(data.start_antall ?? 0)),
      ekskludert: data.ekskludert ?? false,
      oppdatert_tid: new Date().toISOString(),
    },
    { onConflict: 'stasjon_id,dato,varenavn', count: 'exact' },
  ), 'lagre produksjonsplan linjer')
}

// Notat til de ansatte (per stasjon/dag).
export async function setNotat(stasjon_id: string, dato: string, notat: string): Promise<void> {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle) || !bruker.retailerId) throw new Error('Kun leder kan endre notatet.')
  if (!stasjon_id || !dato) throw new Error('Velg stasjon og dato.')
  const supabase = await lagSupabaseServerKlient()
  traffEnRad(await supabase.from('produksjonsplan_hode').upsert(
    { retailer_id: bruker.retailerId, stasjon_id, dato, notat: notat.trim() || null, oppdatert_tid: new Date().toISOString() },
    { onConflict: 'stasjon_id,dato', count: 'exact' },
  ), 'lagre produksjonsplan hode')
}

// Publiser planen til tableten (bevarer «lagd hittil»). Setter publisert_tid.
export async function publiser(stasjon_id: string, dato: string, linjer: PlansnapshotLinje[], notat: string): Promise<{ ok: boolean; feil?: string }> {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle) || !bruker.retailerId) return { ok: false, feil: 'Kun leder kan publisere.' }
  if (!stasjon_id || !/^\d{4}-\d{2}-\d{2}$/.test(dato) || !Array.isArray(linjer) || linjer.length === 0 || linjer.length > 1000) {
    return { ok: false, feil: 'Velg en gyldig stasjon, dato og komplett plan.' }
  }
  try {
    linjer.forEach(validerLinje)
    if (new Set(linjer.map((l) => l.varenavn.trim())).size !== linjer.length) throw new Error('Planen inneholder dupliserte produkter.')
  } catch (e) {
    return { ok: false, feil: e instanceof Error ? e.message : 'Kontroller planen.' }
  }
  const supabase = await lagSupabaseServerKlient()
  // Hele snapshotet og publiseringshodet skrives i én databasetransaksjon.
  const { error } = await supabase.rpc('publiser_produksjonsplan', {
    p_stasjon: stasjon_id, p_dato: dato,
    p_linjer: linjer.map((l) => ({ varenavn: l.varenavn.trim(), varegruppe_kode: l.varegruppe_kode,
      varegruppe_navn: l.varegruppe_navn, foreslatt: l.foreslatt, planlagt: l.planlagt,
      start_antall: l.start_antall ?? 0, ekskludert: l.ekskludert ?? false })),
    p_notat: notat.trim() || null,
  })
  return error ? { ok: false, feil: 'Planen ble ikke publisert. Prøv igjen.' } : { ok: true }
}

// Tablet: ansatte logger hvor mange som er lagd hittil (absolutt verdi).
/**
 * Nettbrettets ene operative handling: hvor mange som er lagd.
 *
 * GJENNOM `logg_lagd()`, IKKE RETT PAA TABELLEN (0167).
 *
 * `produksjonsplan_upd` slapp foer alle med stasjonen til paa HELE raden.
 * Denne handlingen trenger `lagd_hittil`; raden baerer ogsaa `planlagt` -
 * det butikksjefen har bestemt skal lages - og `start_antall` og
 * `ekskludert`. Et kolonnegrant kunne ikke skille dem: det ville truffet
 * butikksjefen, som skal kunne sette `planlagt` gjennom `setLinje`.
 *
 * Funksjonen er `security definer`, baerer tenantpredikatet selv og
 * roerer bare de to kolonnene.
 */
export async function loggLagd(stasjon_id: string, dato: string, varenavn: string, lagd: number): Promise<void> {
  await hentInnloggetBruker() // sikrer innlogget sesjon; funksjonen sjekker stasjonen
  if (!stasjon_id || !dato || !varenavn) return
  const supabase = await lagSupabaseServerKlient()
  // `error` LESES EKSPLISITT, ikke gjennom `maaLykkes`. Et rpc-kall som
  // ikke sjekker feilen gjoer «funksjonen finnes ikke» om til «ingen
  // data» — se `rpc-feil.test.ts` og `/maaling`, som sto og sa «Ingen
  // stasjoner» i maanedsvis fordi `0075` aldri var kjoert.
  const { data, error } = await supabase.rpc('logg_lagd', {
    p_stasjon_id: stasjon_id, p_dato: dato, p_varenavn: varenavn,
    p_lagd: Math.max(0, Math.round(lagd)),
  })
  if (error) throw new Error(`Fikk ikke logget antallet: ${error.message}`)
  // NULL RADER ER IKKE EN SUKSESS. Funksjonen returnerer 0 baade naar
  // stasjonen ikke er min og naar linja ikke finnes. En handling som
  // svarer «ok» paa noe som ikke ble skrevet, ser ut som en som virket -
  // og da teller nettbrettet videre paa et tall som aldri ble lagret.
  if (Number(data ?? 0) === 0) {
    throw new Error('Fikk ikke logget antallet — linja finnes ikke, eller stasjonen er ikke din.')
  }
}

// Driftsreglene: start- og marginprosent (0149).
//
// `varegruppeKode = '*'` er stasjonens standard; en varegruppekode er et
// avvik fra den. `null` i et felt betyr ARV — den lagres som null, ikke
// som 0, fordi de to betyr forskjellige ting: 0 er «null prosent, og det
// er et valg», null er «bruk standarden».
//
// BEGGE NIVAAER LIGGER I SAMME TABELL fordi `stasjoner` bare kan skrives
// av retailer_admin (0001). En standard som kolonne der ville vaert
// utenfor butikksjefens rekkevidde, og det var nettopp hun som skulle
// sette den.
export async function setProsent(
  stasjon_id: string,
  varegruppe_kode: string,
  verdi: { start: number | null; margin: number | null },
): Promise<void> {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle) || !bruker.retailerId) throw new Error('Kun leder kan endre driftsreglene.')
  if (!stasjon_id || !varegruppe_kode) throw new Error('Velg stasjon og varegruppe.')
  const klem = (v: number | null, maks: number) =>
    v == null || !Number.isFinite(v) ? null : Math.min(maks, Math.max(0, Math.round(v)))
  const supabase = await lagSupabaseServerKlient()
  traffEnRad(await supabase.from('stasjon_produksjon_innstilling').upsert(
    {
      retailer_id: bruker.retailerId,
      stasjon_id,
      varegruppe_kode,
      start_prosent: klem(verdi.start, 99),
      margin_prosent: klem(verdi.margin, 100),
      oppdatert_tid: new Date().toISOString(),
    },
    { onConflict: 'stasjon_id,varegruppe_kode', count: 'exact' },
  ), 'lagre produksjonsprosent')
}
