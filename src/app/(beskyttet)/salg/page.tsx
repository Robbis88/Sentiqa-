import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'

const kr = new Intl.NumberFormat('nb-NO', {
  style: 'currency',
  currency: 'NOK',
  maximumFractionDigits: 0,
})
const tall = new Intl.NumberFormat('nb-NO', { maximumFractionDigits: 0 })
const datoFmt = new Intl.DateTimeFormat('nb-NO', { dateStyle: 'long', timeZone: 'Europe/Oslo' })

type StasjonRad = {
  stasjon_id: string
  omsetning: number
  antall: number
  mat_omsetning: number | null
}
type VaregruppeRad = { varegruppe_navn: string | null; omsetning: number; antall: number }

export default async function SalgSide({
  searchParams,
}: {
  searchParams: Promise<{ dato?: string }>
}) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) {
    return <p>Du har ikke tilgang til salgsoversikten.</p>
  }

  const supabase = await lagSupabaseServerKlient()
  const { dato: valgtDato } = await searchParams

  // Default: siste dato med data (RLS scoper til brukerens stasjoner)
  let dato = valgtDato && /^\d{4}-\d{2}-\d{2}$/.test(valgtDato) ? valgtDato : null
  if (!dato) {
    const { data } = await supabase
      .from('v_salg_per_stasjon_dag')
      .select('dato')
      .order('dato', { ascending: false })
      .limit(1)
      .maybeSingle<{ dato: string }>()
    dato = data?.dato ?? null
  }

  if (!dato) {
    return (
      <>
        <h1>Salg</h1>
        <p className="undertittel">
          Ingen salgsdata ennå. Last opp en Salgsstatistikk-fil under Import og trykk Behandle.
        </p>
      </>
    )
  }

  const [{ data: stasjonRader }, { data: stasjoner }, { data: varegrupper }] = await Promise.all([
    supabase
      .from('v_salg_per_stasjon_dag')
      .select('stasjon_id, omsetning, antall, mat_omsetning')
      .eq('dato', dato)
      .overrideTypes<StasjonRad[]>(),
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null),
    supabase
      .from('v_salg_per_varegruppe_dag')
      .select('varegruppe_navn, omsetning, antall')
      .eq('dato', dato)
      .order('omsetning', { ascending: false })
      .limit(10)
      .overrideTypes<VaregruppeRad[]>(),
  ])

  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))
  const rader = (stasjonRader ?? []).sort((a, b) => b.omsetning - a.omsetning)
  const totalOms = rader.reduce((a, r) => a + r.omsetning, 0)
  const totalAntall = rader.reduce((a, r) => a + r.antall, 0)

  return (
    <>
      <h1>Salg</h1>
      <p className="undertittel">{datoFmt.format(new Date(dato))}</p>

      <section className="nokkeltall">
        <div className="kpi">
          <span className="kpi-tall">{kr.format(totalOms)}</span>
          <span className="kpi-merke">Omsetning eks. mva</span>
        </div>
        <div className="kpi">
          <span className="kpi-tall">{tall.format(totalAntall)}</span>
          <span className="kpi-merke">Antall solgt</span>
        </div>
        <div className="kpi">
          <span className="kpi-tall">{rader.length}</span>
          <span className="kpi-merke">Stasjoner med salg</span>
        </div>
      </section>

      <section className="kort">
        <h2>Per stasjon</h2>
        <table className="tabell">
          <thead>
            <tr><th>Stasjon</th><th>Omsetning</th><th>Antall</th><th>Matsalg</th></tr>
          </thead>
          <tbody>
            {rader.map((r) => (
              <tr key={r.stasjon_id}>
                <td>{navnFor.get(r.stasjon_id) ?? '—'}</td>
                <td>{kr.format(r.omsetning)}</td>
                <td>{tall.format(r.antall)}</td>
                <td>{kr.format(r.mat_omsetning ?? 0)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>

      <section className="kort">
        <h2>Topp varegrupper</h2>
        <table className="tabell">
          <thead>
            <tr><th>Varegruppe</th><th>Omsetning</th><th>Antall</th></tr>
          </thead>
          <tbody>
            {(varegrupper ?? []).map((v, i) => (
              <tr key={i}>
                <td>{v.varegruppe_navn ?? '—'}</td>
                <td>{kr.format(v.omsetning)}</td>
                <td>{tall.format(v.antall)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>
    </>
  )
}
