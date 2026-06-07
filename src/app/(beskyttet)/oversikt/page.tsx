import Link from 'next/link'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { kr, prosent, datoLang, manedAar } from '@/lib/format'

export default async function OversiktSide() {
  const bruker = await hentInnloggetBruker()
  const supabase = await lagSupabaseServerKlient()

  // Siste salgsdag + total omsetning (RLS scoper til brukerens stasjoner)
  const { data: sisteDag } = await supabase
    .from('v_salg_per_stasjon_dag')
    .select('dato')
    .order('dato', { ascending: false })
    .limit(1)
    .maybeSingle<{ dato: string }>()

  let salgOms = 0
  if (sisteDag) {
    const { data } = await supabase
      .from('v_salg_per_stasjon_dag')
      .select('omsetning')
      .eq('dato', sisteDag.dato)
      .overrideTypes<{ omsetning: number }[]>()
    salgOms = (data ?? []).reduce((a, r) => a + (r.omsetning ?? 0), 0)
  }

  // Siste regnskapsperiode (admin – cluster). Brukes til KPI + oppmerksomhet.
  const { data: sisteReg } = await supabase
    .from('regnskapslinjer')
    .select('periode')
    .is('stasjon_id', null)
    .order('periode', { ascending: false })
    .limit(1)
    .maybeSingle<{ periode: string }>()

  let oppmerksomhet: { post: string; index_pct: number; avvik: number }[] = []
  if (sisteReg) {
    const { data } = await supabase
      .from('regnskapslinjer')
      .select('seksjon, post, avvik, index_pct')
      .eq('periode', sisteReg.periode)
      .is('stasjon_id', null)
      .overrideTypes<{ seksjon: string; post: string; avvik: number | null; index_pct: number | null }[]>()
    oppmerksomhet = (data ?? [])
      .filter((l) => l.seksjon === 'omsetning' && l.index_pct != null && !/totalt$/i.test(l.post))
      .filter((l) => (l.index_pct ?? 0) < -10)
      .sort((a, b) => (a.index_pct ?? 0) - (b.index_pct ?? 0))
      .slice(0, 4)
      .map((l) => ({ post: l.post, index_pct: l.index_pct ?? 0, avvik: l.avvik ?? 0 }))
  }

  // Resultat (regnskap-verdi, ikke avvik) til KPI
  let resultatRegnskap: number | null = null
  if (sisteReg) {
    const { data } = await supabase
      .from('regnskapslinjer')
      .select('regnskap')
      .eq('periode', sisteReg.periode)
      .is('stasjon_id', null)
      .eq('seksjon', 'resultat')
      .ilike('post', 'resultat')
      .maybeSingle<{ regnskap: number }>()
    resultatRegnskap = data?.regnskap ?? null
  }

  return (
    <>
      <h1>Oversikt</h1>
      <p className="undertittel">Hei, {bruker.fulltNavn ?? bruker.epost}.</p>

      {oppmerksomhet.length > 0 && (
        <section className="kort oppmerksomhet">
          <h2>Trenger oppmerksomhet</h2>
          <ul>
            {oppmerksomhet.map((o) => (
              <li key={o.post}>
                <span className="status-pip rod">{prosent.format(o.index_pct / 100)}</span>
                <strong>{o.post}</strong> ligger {kr.format(Math.abs(o.avvik))} under budsjett denne perioden.
              </li>
            ))}
          </ul>
        </section>
      )}

      <section className="nokkeltall">
        <Link href="/salg" className="kpi lenke">
          <span className="kpi-tall">{kr.format(salgOms)}</span>
          <span className="kpi-merke">
            Omsetning {sisteDag ? datoLang.format(new Date(sisteDag.dato)) : '– ingen data'}
          </span>
        </Link>
        {bruker.rolle === 'retailer_admin' && (
          <Link href="/regnskap" className="kpi lenke">
            <span className="kpi-tall">
              {resultatRegnskap != null ? kr.format(resultatRegnskap) : '–'}
            </span>
            <span className="kpi-merke">
              Resultat {sisteReg ? manedAar.format(new Date(sisteReg.periode)) : '– ingen data'}
            </span>
          </Link>
        )}
      </section>

      <section className="kort">
        <h2>Status</h2>
        <p className="undertittel">
          Datainntak er på plass: salg, timesalg, kasserer, svinn og regnskap importeres.
          Neste lag er analyselaget (§7) og AI-assistenten (§8).
        </p>
      </section>
    </>
  )
}
