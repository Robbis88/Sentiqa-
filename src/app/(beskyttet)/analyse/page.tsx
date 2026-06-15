import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { manedAar, kr } from '@/lib/format'
import { byggPeriodeGrupper } from '@/lib/perioder'
import type { Analyse } from '@/lib/ai/regnskapsanalyse'
import { AnalyseKnapp } from './generer-knapp'
import { PeriodeVelger } from '../periode-velger'

// «Kjør analyse» (Opus) kan ta litt — gi handlingen tid.
export const maxDuration = 60

type Svinn = { stasjon_id: string; navn: string; salg: number | null; usynlig_kr: number | null; usynlig_pst: number | null }

const STATUS_TEKST: Record<string, string> = { gronn: 'God', gul: 'Følg med', rod: 'Krever tiltak' }
const PRIO_TEKST: Record<string, string> = { hoy: 'HØY', medium: 'MEDIUM', lav: 'LAV' }

export default async function AnalyseSide({ searchParams }: { searchParams: Promise<{ periode?: string }> }) {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin') {
    return <p>Kun eier har tilgang til regnskapsanalysen.</p>
  }

  const supabase = await lagSupabaseServerKlient()

  // Alle perioder med analyse (rød tråd) — velg via ?periode=YYYY-MM, ellers siste.
  const { data: perioder } = await supabase
    .from('regnskapsanalyser').select('periode').order('periode', { ascending: false })
    .overrideTypes<{ periode: string }[]>()
  const liste = [...new Set((perioder ?? []).map((p) => p.periode))]
  const valgt = (await searchParams).periode
  const valgtIso = valgt ? `${valgt}-01` : null
  const aktivPeriode = valgtIso && liste.includes(valgtIso) ? valgtIso : (liste[0] ?? null)

  const { data } = aktivPeriode
    ? await supabase
        .from('regnskapsanalyser')
        .select('periode, rapport, opprettet_tid')
        .eq('periode', aktivPeriode)
        .order('opprettet_tid', { ascending: false })
        .limit(1)
        .maybeSingle<{ periode: string; rapport: Analyse; opprettet_tid: string }>()
    : { data: null }

  const a = data?.rapport

  // Usynlig svinn per stasjon (+ = manko/penger borte, − = overskudd/positiv svinn)
  let svinnPerStasjon: { navn: string; manko: number; overskudd: number; topp: Svinn[]; bunn: Svinn[] }[] = []
  if (data?.periode) {
    const [{ data: svinn }, { data: stasjoner }] = await Promise.all([
      supabase.from('regnskap_usynlig_svinn').select('stasjon_id, navn, salg, usynlig_kr, usynlig_pst').eq('periode', data.periode).is('slettet_tid', null).overrideTypes<Svinn[]>(),
      supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null),
    ])
    const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))
    const grupper = new Map<string, Svinn[]>()
    for (const s of svinn ?? []) { const l = grupper.get(s.stasjon_id) ?? []; l.push(s); grupper.set(s.stasjon_id, l) }
    svinnPerStasjon = [...grupper.entries()].filter(([id]) => navnFor.has(id)).map(([id, liste]) => {
      let manko = 0, overskudd = 0
      for (const s of liste) { const v = s.usynlig_kr ?? 0; if (v > 0) manko += v; else overskudd += v }
      const sortert = [...liste].sort((x, y) => (y.usynlig_kr ?? 0) - (x.usynlig_kr ?? 0))
      return {
        navn: navnFor.get(id)!,
        manko: Math.round(manko),
        overskudd: Math.round(overskudd),
        topp: sortert.filter((s) => (s.usynlig_kr ?? 0) > 0).slice(0, 5),
        bunn: sortert.filter((s) => (s.usynlig_kr ?? 0) < 0).slice(-5).reverse(),
      }
    }).sort((x, y) => y.manko - x.manko)
  }

  return (
    <>
      <h1>Regnskapsanalyse</h1>
      <p className="undertittel">
        {data ? `${manedAar.format(new Date(data.periode))} · eier-analyse` : 'Ingen analyse ennå'}
      </p>

      {liste.length > 0 && aktivPeriode && (
        <div className="regnskap-velgere">
          <PeriodeVelger valgt={aktivPeriode.slice(0, 7)} grupper={byggPeriodeGrupper(liste, false)} basePath="/analyse" />
        </div>
      )}

      <AnalyseKnapp />

      {!a ? (
        <section className="kort">
          <p className="undertittel">
            Ingen analyse ennå. Behandle et regnskap og trykk «Kjør analyse».
          </p>
        </section>
      ) : (
        <>
          <section className="kort">
            <h2>Sammendrag</h2>
            <p>{a.sammendrag}</p>
          </section>

          {(a.systemfeil ?? []).length > 0 && (
            <section className="kort oppmerksomhet">
              <h2>⚙️ Systemfeil (registrering)</h2>
              <p className="undertittel">Mønstre på tvers av stasjoner — ikke ekte tap, men feilregistrering som forvrenger tallene.</p>
              <ul>{(a.systemfeil ?? []).map((f, i) => <li key={i}>{f}</li>)}</ul>
            </section>
          )}

          <section className="kort">
            <h2>Per stasjon</h2>
            <table className="tabell">
              <thead>
                <tr><th>Stasjon</th><th>Status</th><th>Kommentar</th></tr>
              </thead>
              <tbody>
                {a.perStasjon.map((s, i) => (
                  <tr key={i}>
                    <td>{s.stasjon}</td>
                    <td><span className={`status-pip ${s.status}`}>{STATUS_TEKST[s.status] ?? s.status}</span></td>
                    <td>{s.kommentar}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </section>

          {svinnPerStasjon.length > 0 && (
            <section className="kort">
              <h2>🔎 Usynlig svinn per stasjon</h2>
              <p className="undertittel"><span className="svinn-manko">+ = manko (penger borte etter telling)</span> · <span className="svinn-overskudd">− = overskudd (positiv svinn)</span></p>
              <div className="svinn-grid">
                {svinnPerStasjon.map((s, i) => (
                  <div className="svinn-kort" key={i}>
                    <div className="svinn-topp">
                      <strong>{s.navn}</strong>
                      <span className="svinn-totaler"><span className="svinn-manko">+{kr.format(s.manko)}</span> <span className="svinn-overskudd">{kr.format(s.overskudd)}</span></span>
                    </div>
                    <ul className="svinn-liste">
                      {s.topp.map((p, j) => <li key={`m${j}`}><span className="svinn-manko">+{kr.format(p.usynlig_kr ?? 0)}</span> {p.navn} <span className="svinn-pst">({Math.round(p.usynlig_pst ?? 0)} %)</span></li>)}
                      {s.bunn.map((p, j) => <li key={`o${j}`}><span className="svinn-overskudd">{kr.format(p.usynlig_kr ?? 0)}</span> {p.navn} <span className="svinn-pst">({Math.round(p.usynlig_pst ?? 0)} %)</span></li>)}
                    </ul>
                  </div>
                ))}
              </div>
            </section>
          )}

          {a.rodeFlagg.length > 0 && (
            <section className="kort oppmerksomhet">
              <h2>Røde flagg</h2>
              <ul>{a.rodeFlagg.map((f, i) => <li key={i}>{f}</li>)}</ul>
            </section>
          )}

          <section className="kort">
            <h2>Muligheter</h2>
            <ul className="fokus-liste">{a.muligheter.map((m, i) => <li key={i}>{m}</li>)}</ul>
          </section>

          <section className="kort">
            <h2>Prioriterte tiltak</h2>
            <ol className="tiltak-liste">{a.tiltak.map((t, i) => {
              const prio = typeof t === 'string' ? 'medium' : t.prioritet
              return (
                <li key={i}>
                  <span className={`prio prio-${prio}`}>{PRIO_TEKST[prio]}</span>
                  {typeof t === 'string' ? t : t.tekst}
                </li>
              )
            })}</ol>
          </section>

          {(a.endringer ?? []).length > 0 && (
            <section className="kort">
              <h2>Endringer mot forrige periode</h2>
              <ul className="fokus-liste">{(a.endringer ?? []).map((e, i) => <li key={i}>{e}</li>)}</ul>
            </section>
          )}
        </>
      )}
    </>
  )
}
