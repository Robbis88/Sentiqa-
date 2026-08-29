import 'server-only'
import type { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { leggTilDager, type Vaerdag } from '@/lib/produksjonsplan'
import { lagSalgsprognose, type AvdSalg, type SalgsPrognose } from '@/lib/salgsprognose'
import { hentKalibrering } from '@/lib/backtest'
import { hentVaerKoeff } from '@/lib/vaerprofil'
import { erHelligdag } from '@/lib/helligdager'
import { SKJUL_OMS_KODER } from '@/lib/avdelinger'

// =====================================================================
// PROGNOSEN FINNES FOR I MORGEN. IKKE FOR NOEN ANNEN DAG.
//
// `lagSalgsprognose` bygger paa vaervarselet for maaldagen og paa
// trenden de siste fire ukene. Begge deler peker framover fra ETT sted:
// siste dag med salgstall.
//
// Skulle den svare for en dag som har vaert, maatte «nylig» avgrenses
// til dagen FOER - ellers regner den med tall fra etter dagen den skal
// forutsi. Da er det ikke en prognose, det er et etterpaaklokt anslag
// som ser ut som en prognose, og det er den verste sorten tall.
//
//   «vi trenger bare forventet for dagen etterpaa, saa ikke det loves
//    mere enn vi kan» - Robert 2026-08-29
//
// Derfor: `null` for alt annet enn i morgen. Kolonnen staar tom, og det
// er et aerlig svar.
//
// ---------------------------------------------------------------------
// ÉN KILDE, TO SIDER
//
// /salgsprognose og /salg viser det SAMME tallet for den samme dagen.
// Skrives regnestykket to steder, skiller de lag i stillhet - og da har
// produktet to sannheter om i morgen. Kalibreringen maa derfor vaere med
// her ogsaa: uten den ville /salg vist raa prognose og /salgsprognose
// den kalibrerte.
// =====================================================================

type Klient = Awaited<ReturnType<typeof lagSupabaseServerKlient>>

export type Stasjonsprofil = {
  id: string
  stasjonstype: string
  vaerfolsomhet: number | null
  vaerfolsomhet_laert: number | null
}

/**
 * Prognosen finnes for I MORGEN. Ikke for dagen etter siste salgsdag.
 *
 * DE TO ER IKKE DET SAMME, og forskjellen bet meg her: importen ligger
 * gjerne to dager bak, saa siste salgsdag kan vaere den 27. mens i dag er
 * den 29. Regnes prognosedagen fra siste salgsdag, ville /salg tilbudt
 * en «prognose» for den 28. - en dag som alt er forbi - mens
 * /salgsprognose svarte for den 30.
 *
 * Maaldagen er kalenderens i morgen. At salgstallene ligger bakerst er
 * modellens problem, ikke brukerens: `lagSalgsprognose` tar
 * `sisteSalgsdato` for seg og varsler selv naar avstanden blir stor.
 */
export function erPrognosedag(dato: string, idag: string): boolean {
  return dato === leggTilDager(idag, 1)
}

/**
 * Forventet omsetning per avdelingskode for `maalDato`.
 *
 * `null` naar dagen ikke er i morgen, naar stasjonen mangler, eller naar
 * det ikke finnes salgshistorikk aa bygge paa. Alle tre er «vi vet ikke»,
 * og kallstedet skal vise tomt - ikke null kroner.
 */
export async function hentForventet(
  supabase: Klient,
  stasjon: Stasjonsprofil,
  maalDato: string,
  sisteSalgsdato: string,
): Promise<{
  prognose: SalgsPrognose
  perAvdeling: Map<string, number>
  total: number
  /** Varselet for maaldagen. Kontekst for tallet, saa kallstedet
   *  slipper aa hente det om igjen - og de to kan ikke vise ulikt vaer. */
  vaerMaal: Vaerdag | null
} | null> {
  const fjorBase = leggTilDager(maalDato, -364)

  const [{ data: nylig }, { data: fjor }, { data: vMaal }, { data: vFjor }] = await Promise.all([
    supabase.from('v_salg_per_avdeling_dag')
      .select('dato, avdeling_kode, avdeling_navn, omsetning')
      .eq('stasjon_id', stasjon.id)
      .gte('dato', leggTilDager(sisteSalgsdato, -35)).lte('dato', sisteSalgsdato)
      .overrideTypes<{ dato: string; avdeling_kode: string | null; avdeling_navn: string | null; omsetning: number | null }[]>(),
    supabase.from('v_salg_per_avdeling_dag')
      .select('dato, avdeling_kode, avdeling_navn, omsetning')
      .eq('stasjon_id', stasjon.id)
      .gte('dato', leggTilDager(fjorBase, -28)).lte('dato', leggTilDager(fjorBase, 21))
      .overrideTypes<{ dato: string; avdeling_kode: string | null; avdeling_navn: string | null; omsetning: number | null }[]>(),
    supabase.from('vaer').select('temp_maks, nedbor_mm')
      .eq('stasjon_id', stasjon.id).eq('dato', maalDato).maybeSingle<Vaerdag>(),
    supabase.from('vaer').select('temp_maks, nedbor_mm')
      .eq('stasjon_id', stasjon.id).eq('dato', fjorBase).maybeSingle<Vaerdag>(),
  ])

  const salg: AvdSalg[] = [...(nylig ?? []), ...(fjor ?? [])]
    .filter((r) => r.avdeling_kode && !SKJUL_OMS_KODER.has(r.avdeling_kode))
    .map((r) => ({
      dato: r.dato,
      avdelingKode: r.avdeling_kode!,
      avdelingNavn: r.avdeling_navn ?? r.avdeling_kode!,
      omsetning: r.omsetning ?? 0,
    }))
  if (salg.length === 0) return null

  const vaerKoeff = await hentVaerKoeff(supabase, stasjon.id, 'avdeling')
  const raa: SalgsPrognose = lagSalgsprognose({
    maalDato,
    sisteSalgsdato,
    salg,
    vaerMaal: vMaal ?? null,
    vaerFjor: vFjor ?? null,
    vaerfolsomhet: stasjon.vaerfolsomhet_laert ?? stasjon.vaerfolsomhet ?? 0.5,
    vaerKoeff,
    stasjonstype: stasjon.stasjonstype,
    helligdag: erHelligdag(maalDato),
  })

  // Selvlaert korreksjon fra stasjonens egen treffhistorikk - den samme
  // /salgsprognose bruker. Uten den ville de to sidene sagt ulikt.
  const kalibrering = await hentKalibrering(supabase, stasjon.id, 'salgsprognose')
  const perAvdeling = new Map<string, number>()
  for (const f of raa.forslag) {
    const korr = kalibrering.get(f.kode) ?? 1
    perAvdeling.set(f.kode, korr === 1 ? f.forventet : Math.max(0, Math.round(f.forventet * korr)))
  }

  // Hele prognosen tilbake, kalibrert. /salgsprognose trenger `basis`,
  // `endringPst` og `vaerfaktor` per avdeling; /salg trenger bare
  // kronene. Returneres bare kronene, maatte den andre sida bygget
  // resten selv - og da er vi tilbake til to regnestykker.
  const forslag = raa.forslag.map((f) => ({ ...f, forventet: perAvdeling.get(f.kode) ?? f.forventet }))
  const total = forslag.reduce((s, f) => s + f.forventet, 0)

  return {
    prognose: {
      ...raa,
      forslag,
      totalForventet: total,
      advarsler: kalibrering.size > 0
        ? [...raa.advarsler, 'Selvlært kalibrering aktiv — justert mot stasjonens egen treffhistorikk.']
        : raa.advarsler,
    },
    perAvdeling,
    total,
    vaerMaal: vMaal ?? null,
  }
}
