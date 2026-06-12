import Link from 'next/link'
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
  searchParams: Promise<{ dato?: string; stasjon?: string }>
}) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) {
    return <p>Du har ikke tilgang til salgsoversikten.</p>
  }

  const supabase = await lagSupabaseServerKlient()
  const sp = await searchParams
  const valgtDato = sp.dato
  const erUuid = (s?: string) => !!s && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s)
  const valgtStasjon = erUuid(sp.stasjon) ? sp.stasjon! : null

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

  const [{ data: stasjonRader }, { data: stasjoner }] = await Promise.all([
    supabase
      .from('v_salg_per_stasjon_dag')
      .select('stasjon_id, omsetning, antall, mat_omsetning')
      .eq('dato', dato)
      .overrideTypes<StasjonRad[]>(),
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null),
  ])

  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))
  const rader = (stasjonRader ?? []).sort((a, b) => b.omsetning - a.omsetning)
  const erStasjon = valgtStasjon != null && navnFor.has(valgtStasjon)
  const valgtNavn = erStasjon ? navnFor.get(valgtStasjon!)! : null
  const valgtRad = erStasjon ? rader.find((r) => r.stasjon_id === valgtStasjon) ?? null : null

  // Topp varegrupper: kjede-view for «alle samlet», ellers rett fra daglig_salg
  // (viewet har ikke stasjon_id) summert per varegruppe for valgt stasjon.
  let varegrupper: VaregruppeRad[]
  if (erStasjon) {
    const { data } = await supabase
      .from('daglig_salg')
      .select('varegruppe_navn, omsetning_eks_mva, antall')
      .eq('dato', dato)
      .eq('stasjon_id', valgtStasjon!)
      .is('slettet_tid', null)
      .not('varegruppe_kode', 'is', null)
      .overrideTypes<{ varegruppe_navn: string | null; omsetning_eks_mva: number | null; antall: number | null }[]>()
    const m = new Map<string, { omsetning: number; antall: number }>()
    for (const r of data ?? []) {
      const key = r.varegruppe_navn ?? '—'
      const o = m.get(key) ?? { omsetning: 0, antall: 0 }
      o.omsetning += r.omsetning_eks_mva ?? 0
      o.antall += r.antall ?? 0
      m.set(key, o)
    }
    varegrupper = [...m.entries()]
      .map(([varegruppe_navn, v]) => ({ varegruppe_navn, ...v }))
      .sort((a, b) => b.omsetning - a.omsetning)
      .slice(0, 10)
  } else {
    const { data } = await supabase
      .from('v_salg_per_varegruppe_dag')
      .select('varegruppe_navn, omsetning, antall')
      .eq('dato', dato)
      .order('omsetning', { ascending: false })
      .limit(10)
      .overrideTypes<VaregruppeRad[]>()
    varegrupper = data ?? []
  }

  const totalOms = rader.reduce((a, r) => a + r.omsetning, 0)
  const totalAntall = rader.reduce((a, r) => a + r.antall, 0)

  return (
    <>
      <h1>Salg</h1>
      <p className="undertittel">{datoFmt.format(new Date(dato))} · {erStasjon ? valgtNavn : 'alle stasjoner samlet'}</p>

      {(stasjoner ?? []).length > 0 && (
        <nav className="periode-trad" aria-label="Velg stasjon">
          <Link href={`/salg?dato=${dato}`} className={`periode-chip ${!erStasjon ? 'aktiv' : ''}`} aria-current={!erStasjon ? 'page' : undefined}>
            Alle samlet
          </Link>
          {[...(stasjoner ?? [])]
            .sort((a, b) => a.butikknummer.localeCompare(b.butikknummer))
            .map((s) => {
              const aktiv = s.id === valgtStasjon
              return (
                <Link key={s.id} href={`/salg?dato=${dato}&stasjon=${s.id}`} className={`periode-chip ${aktiv ? 'aktiv' : ''}`} aria-current={aktiv ? 'page' : undefined}>
                  {s.butikknummer} {s.navn}
                </Link>
              )
            })}
        </nav>
      )}

      <section className="nokkeltall">
        <div className="kpi">
          <span className="kpi-tall">{kr.format(erStasjon ? (valgtRad?.omsetning ?? 0) : totalOms)}</span>
          <span className="kpi-merke">Omsetning eks. mva</span>
        </div>
        <div className="kpi">
          <span className="kpi-tall">{tall.format(erStasjon ? (valgtRad?.antall ?? 0) : totalAntall)}</span>
          <span className="kpi-merke">Antall solgt</span>
        </div>
        <div className="kpi">
          <span className="kpi-tall">{erStasjon ? kr.format(valgtRad?.mat_omsetning ?? 0) : tall.format(rader.length)}</span>
          <span className="kpi-merke">{erStasjon ? 'Matsalg' : 'Stasjoner med salg'}</span>
        </div>
      </section>

      {!erStasjon && (
        <section className="kort">
          <h2>Per stasjon</h2>
          <table className="tabell">
            <thead>
              <tr><th>Stasjon</th><th>Omsetning</th><th>Antall</th><th>Matsalg</th></tr>
            </thead>
            <tbody>
              {rader.map((r) => (
                <tr key={r.stasjon_id}>
                  <td><Link href={`/salg?dato=${dato}&stasjon=${r.stasjon_id}`}>{navnFor.get(r.stasjon_id) ?? '—'}</Link></td>
                  <td>{kr.format(r.omsetning)}</td>
                  <td>{tall.format(r.antall)}</td>
                  <td>{kr.format(r.mat_omsetning ?? 0)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      )}

      <section className="kort">
        <h2>Topp varegrupper{erStasjon ? ` · ${valgtNavn}` : ''}</h2>
        <table className="tabell">
          <thead>
            <tr><th>Varegruppe</th><th>Omsetning</th><th>Antall</th></tr>
          </thead>
          <tbody>
            {varegrupper.length === 0 ? (
              <tr><td colSpan={3} className="undertittel">Ingen varegruppe-salg denne dagen.</td></tr>
            ) : varegrupper.map((v, i) => (
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
