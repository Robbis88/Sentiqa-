import { effektivProsent, medMargin, startAntall } from './produksjonsplan'
import { lagProduksjonsplan, leggTilDager, produksjonsreferanse, type PlanForslag, type SalgsPunkt, type Vaerdag } from './produksjonsplan'
import { hentProduksjonskoder } from './produksjonskoder'
import { hentKalibrering } from './backtest'
import { hentVaerKoeff } from './vaerprofil'
import { hentPerDato, maaVaereHele } from './supabase/datobolker'
import { erHelligdag, fjorHelligdag } from './helligdager'
import type { lagSupabaseServerKlient } from './supabase/server'

type Klient = Awaited<ReturnType<typeof lagSupabaseServerKlient>>

export type LagretPlanlinje = {
  id?: string
  varenavn: string
  planlagt: number | null
  start_antall: number | null
  ekskludert?: boolean | null
}

export type MarginAvvik = {
  varegruppe_kode: string
  margin_prosent: number | null
  start_prosent: number | null
}

export type ProduksjonsResultat = {
  varenavn: string
  varegruppeKode: string | null
  varegruppeNavn: string | null
  forventetSalg: number
  foreslattProduksjon: number
  anbefaltProduksjon: number
  anbefaltStartantall: number
  planlagtAntall: number
  publisertAntall: number | null
  manuellPlan: boolean
  ekskludert: boolean
  kalibreringFaktor: number
  marginProsent: number
  startProsent: number
  flagg: PlanForslag['forslag'][number]['flagg']
  forklaring: PlanForslag['forslag'][number]['forklaring'] & {
    kalibreringFaktor: number
    modellForslag: number
    manuellPlan: boolean
    startAntall: number
  }
}

export type BeregnetProduksjonsPlan = {
  produkter: ProduksjonsResultat[]
  summer: {
    forventetSalg: number
    anbefaltProduksjon: number
    anbefaltStartantall: number
    publisertAntall: number | null
  }
}

export type Produksjonsgrunnlag = {
  dato: string
  stasjonId: string
  sisteSalgsdato: string
  punkter: SalgsPunkt[]
  vaerMaal: Vaerdag | null
  vaerFjor: Vaerdag | null
  arrangementFaktor: number
  arrangementer: { navn: string; faktor: number }[]
  kalibrering: Map<string, number>
  avvik: Map<string, MarginAvvik>
  standardMargin: number | null
  standardStart: number | null
  lagrede: Map<string, LagretPlanlinje>
  datadekning: number
}

/** Leser nøyaktig samme grunnlag som produksjonsplansiden før motoren kjøres. */
export async function hentProduksjonsgrunnlag(
  supabase: Klient,
  stasjonId: string,
  dato: string,
): Promise<Produksjonsgrunnlag | null> {
  const oppsett = await hentProduksjonskoder(supabase)
  // Samme eksplisitte vakt som produksjonssiden: uten mapping er planen
  // ikke «tom», den er ikke_konfigurert og skal forklares til brukeren.
  if (oppsett.status === 'ikke_konfigurert' || oppsett.status !== 'mappet') return null
  const koder = oppsett.koder
  const { data: sisteRad, error: sisteFeil } = await supabase.from('v_butikksalg').select('dato')
    .eq('stasjon_id', stasjonId).in('varegruppe_kode', koder).is('slettet_tid', null)
    .lt('dato', dato).order('dato', { ascending: false }).limit(1).maybeSingle<{ dato: string }>()
  if (sisteFeil) throw new Error(`Siste salgsdag kunne ikke hentes: ${sisteFeil.message}`)
  const sisteSalgsdato = sisteRad?.dato ?? leggTilDager(dato, -1)
  const referanse = produksjonsreferanse(dato, sisteSalgsdato)
  const [maalSvar, fjorSvar, linjeSvar, innstillingSvar, arrangementSvar, stasjonSvar] = await Promise.all([
    supabase.from('vaer').select('temp_maks, nedbor_mm').eq('stasjon_id', stasjonId).eq('dato', dato).maybeSingle<Vaerdag>(),
    supabase.from('vaer').select('temp_maks, nedbor_mm').eq('stasjon_id', stasjonId).eq('dato', referanse.fjorDato).maybeSingle<Vaerdag>(),
    supabase.from('produksjonsplan_linjer').select('id, varenavn, planlagt, start_antall, ekskludert').eq('stasjon_id', stasjonId).eq('dato', dato).limit(1000)
      .overrideTypes<LagretPlanlinje[]>(),
    supabase.from('stasjon_produksjon_innstilling').select('varegruppe_kode, start_prosent, margin_prosent').eq('stasjon_id', stasjonId).limit(1000)
      .overrideTypes<MarginAvvik[]>(),
    supabase.from('arrangementer').select('id, navn, faktor, stasjon_id').eq('dato', dato).neq('status', 'forslag').is('slettet_tid', null).limit(1000)
      .overrideTypes<{ id: string; navn: string; faktor: number; stasjon_id: string | null }[]>(),
    supabase.from('stasjoner').select('vaerfolsomhet_laert, vaerfolsomhet').eq('id', stasjonId).maybeSingle<{ vaerfolsomhet_laert: number | null; vaerfolsomhet: number | null }>(),
  ])
  for (const svar of [maalSvar, fjorSvar, linjeSvar, innstillingSvar, arrangementSvar, stasjonSvar]) {
    if (svar.error) throw new Error(`Produksjonsgrunnlaget kunne ikke hentes: ${svar.error.message}`)
  }
  const arrangementer = (arrangementSvar.data ?? []).filter((a) => a.stasjon_id === null || a.stasjon_id === stasjonId)
  const salg = await hentPerDato<{ varenavn: string | null; varegruppe_kode: string | null; varegruppe_navn: string | null; antall: number | null; dato: string }>(
    (fra, til) => supabase.from('v_butikksalg').select('varenavn, varegruppe_kode, varegruppe_navn, antall, dato')
      .eq('stasjon_id', stasjonId).in('varegruppe_kode', koder).gte('dato', fra).lte('dato', til).is('slettet_tid', null)
      .order('dato').order('ean').limit(1000).overrideTypes<{
        varenavn: string | null; varegruppe_kode: string | null; varegruppe_navn: string | null; antall: number | null; dato: string
      }[]>(),
    referanse.fra, referanse.til,
  )
  const punkter = salg.map((r) => {
    if (r.antall == null || !Number.isFinite(r.antall)) throw new Error('Salgsantallet er ukjent. Produksjonsforslaget kan ikke beregnes.')
    return { dato: r.dato, varenavn: (r.varenavn ?? '').trim(), varegruppeKode: r.varegruppe_kode, varegruppeNavn: r.varegruppe_navn, antall: r.antall }
  }).filter((p) => p.varenavn)
  const avvik = maaVaereHele(innstillingSvar, 'produksjonsinnstillingene')
  const lagrede = maaVaereHele(linjeSvar, 'lagrede produksjonslinjer')
  const standard = (avvik ?? []).find((a) => a.varegruppe_kode === '*')
  return {
    dato, stasjonId, sisteSalgsdato, punkter,
    vaerMaal: maalSvar.data ?? null, vaerFjor: fjorSvar.data ?? null,
    arrangementFaktor: arrangementer.reduce((f, a) => f * a.faktor, 1),
    arrangementer: arrangementer.map((a) => ({ navn: a.navn, faktor: a.faktor })),
    kalibrering: await hentKalibrering(supabase, stasjonId, 'produksjonsplan'),
    avvik: new Map((avvik ?? []).map((a) => [a.varegruppe_kode, a])),
    standardMargin: standard?.margin_prosent ?? null, standardStart: standard?.start_prosent ?? null,
    lagrede: new Map((lagrede ?? []).map((l) => [l.varenavn, l])),
    datadekning: new Set(punkter.map((p) => p.dato)).size,
  }
}

export async function lagProduksjonsresultatFraGrunnlag(
  supabase: Klient,
  grunnlag: Produksjonsgrunnlag,
): Promise<{ plan: BeregnetProduksjonsPlan; motor: PlanForslag }> {
  const stasjon = await supabase.from('stasjoner').select('vaerfolsomhet_laert, vaerfolsomhet').eq('id', grunnlag.stasjonId).maybeSingle<{ vaerfolsomhet_laert: number | null; vaerfolsomhet: number | null }>()
  if (stasjon.error) throw new Error(`Stasjonens værprofil kunne ikke hentes: ${stasjon.error.message}`)
  const vaerKoeff = await hentVaerKoeff(supabase, grunnlag.stasjonId, 'varegruppe')
  const motor = lagProduksjonsplan({
    maalDato: grunnlag.dato, sisteSalgsdato: grunnlag.sisteSalgsdato, salg: grunnlag.punkter,
    vaerMaal: grunnlag.vaerMaal, vaerFjor: grunnlag.vaerFjor,
    vaerfolsomhet: stasjon.data?.vaerfolsomhet_laert ?? stasjon.data?.vaerfolsomhet ?? 0.5,
    vaerKoeff, arrangementFaktor: grunnlag.arrangementFaktor,
    helligdag: erHelligdag(grunnlag.dato), fjorHelligdag: fjorHelligdag(grunnlag.dato),
  })
  return { motor, plan: beregnProduksjonsresultat(motor, {
    kalibrering: grunnlag.kalibrering, standardMargin: grunnlag.standardMargin,
    standardStart: grunnlag.standardStart, avvik: grunnlag.avvik, lagrede: grunnlag.lagrede,
  }) }
}

/**
 * Felles etterbehandling for produksjonssiden og andre lesere av planen.
 * `plan` kommer direkte fra lagProduksjonsplan(); denne funksjonen gjør kun
 * den eksisterende kalibreringen, marginen, startandelen og planavviket.
 */
export function beregnProduksjonsresultat(
  plan: PlanForslag,
  opts: {
    kalibrering?: Map<string, number>
    standardMargin?: number | null
    standardStart?: number | null
    avvik?: Map<string, MarginAvvik>
    lagrede?: Map<string, LagretPlanlinje>
  } = {},
): BeregnetProduksjonsPlan {
  const kalibrering = opts.kalibrering ?? new Map<string, number>()
  const avvik = opts.avvik ?? new Map<string, MarginAvvik>()
  const lagrede = opts.lagrede ?? new Map<string, LagretPlanlinje>()
  const produkter = plan.forslag.map((f) => {
    const lagret = lagrede.get(f.varenavn)
    const korr = kalibrering.get(f.varegruppeKode ?? '') ?? 1
    const modellForslag = Math.max(0, Math.round(f.foreslatt * korr))
    const gruppeAvvik = avvik.get(f.varegruppeKode ?? '')
    const marginProsent = effektivProsent(opts.standardMargin, gruppeAvvik?.margin_prosent)
    const startProsent = effektivProsent(opts.standardStart, gruppeAvvik?.start_prosent)
    const anbefaltProduksjon = medMargin(modellForslag, marginProsent)
    const planlagtAntall = lagret?.planlagt ?? anbefaltProduksjon
    const anbefaltStartantall = lagret?.start_antall ?? startAntall(planlagtAntall, startProsent)
    const manuellPlan = lagret?.planlagt != null && lagret.planlagt !== modellForslag
    return {
      varenavn: f.varenavn,
      varegruppeKode: f.varegruppeKode,
      varegruppeNavn: f.varegruppeNavn,
      forventetSalg: f.forklaring.avrundetForslag,
      foreslattProduksjon: modellForslag,
      anbefaltProduksjon,
      anbefaltStartantall,
      planlagtAntall,
      publisertAntall: lagret?.planlagt ?? null,
      manuellPlan,
      ekskludert: lagret?.ekskludert ?? false,
      kalibreringFaktor: korr,
      marginProsent,
      startProsent,
      flagg: f.flagg,
      forklaring: {
        ...f.forklaring,
        kalibreringFaktor: korr,
        modellForslag,
        manuellPlan,
        startAntall: anbefaltStartantall,
      },
    }
  })
  return {
    produkter,
    summer: {
      forventetSalg: produkter.reduce((sum, p) => sum + p.forventetSalg, 0),
      anbefaltProduksjon: produkter.reduce((sum, p) => sum + p.anbefaltProduksjon, 0),
      anbefaltStartantall: produkter.reduce((sum, p) => sum + p.anbefaltStartantall, 0),
      publisertAntall: produkter.some((p) => p.publisertAntall != null)
        ? produkter.reduce((sum, p) => sum + (p.publisertAntall ?? 0), 0)
        : null,
    },
  }
}
