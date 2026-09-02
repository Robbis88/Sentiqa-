'use server'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { maaLykkes } from '@/lib/skriv-svar'

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

// Lagrer/overstyrer en plan-linje (planlagt, startAntall, ekskluder). Bevarer
// lagd_hittil (settes ikke her — kun fra tableten).
export async function setLinje(data: LinjeData): Promise<void> {
  const bruker = await hentInnloggetBruker()
  if (!bruker.retailerId || !data.stasjon_id || !data.dato || !data.varenavn) return
  const supabase = await lagSupabaseServerKlient()
  maaLykkes(await supabase.from('produksjonsplan_linjer').upsert(
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
    { onConflict: 'stasjon_id,dato,varenavn' },
  ), 'lagre produksjonsplan linjer')
}

// Notat til de ansatte (per stasjon/dag).
export async function setNotat(stasjon_id: string, dato: string, notat: string): Promise<void> {
  const bruker = await hentInnloggetBruker()
  if (!bruker.retailerId || !stasjon_id || !dato) return
  const supabase = await lagSupabaseServerKlient()
  maaLykkes(await supabase.from('produksjonsplan_hode').upsert(
    { retailer_id: bruker.retailerId, stasjon_id, dato, notat: notat.trim() || null, oppdatert_tid: new Date().toISOString() },
    { onConflict: 'stasjon_id,dato' },
  ), 'lagre produksjonsplan hode')
}

// Publiser planen til tableten (bevarer «lagd hittil»). Setter publisert_tid.
export async function publiser(stasjon_id: string, dato: string): Promise<{ ok: boolean }> {
  const bruker = await hentInnloggetBruker()
  if (!bruker.retailerId || !stasjon_id || !dato) return { ok: false }
  const supabase = await lagSupabaseServerKlient()
  const { error } = await supabase.from('produksjonsplan_hode').upsert(
    { retailer_id: bruker.retailerId, stasjon_id, dato, publisert_tid: new Date().toISOString(), oppdatert_tid: new Date().toISOString() },
    { onConflict: 'stasjon_id,dato' },
  )
  return { ok: !error }
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
  if (!bruker.retailerId || !stasjon_id || !varegruppe_kode) return
  const klem = (v: number | null, maks: number) =>
    v == null || !Number.isFinite(v) ? null : Math.min(maks, Math.max(0, Math.round(v)))
  const supabase = await lagSupabaseServerKlient()
  maaLykkes(await supabase.from('stasjon_produksjon_innstilling').upsert(
    {
      retailer_id: bruker.retailerId,
      stasjon_id,
      varegruppe_kode,
      start_prosent: klem(verdi.start, 99),
      margin_prosent: klem(verdi.margin, 100),
      oppdatert_tid: new Date().toISOString(),
    },
    { onConflict: 'stasjon_id,varegruppe_kode' },
  ), 'lagre produksjonsprosent')
}
