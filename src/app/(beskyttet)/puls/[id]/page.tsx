import Link from 'next/link'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { datoLang } from '@/lib/format'

type Runde = { id: string; start_dato: string; slutt_dato: string; status: string; notat: string | null; puls_sporsmal: { tekst: string; kategori: string } | null }
type Svar = { skala: number | null; kommentar: string | null; stasjon_id: string }

export default async function RundeResultat({ params }: { params: Promise<{ id: string }> }) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return <p>Ingen tilgang.</p>
  const { id } = await params
  const supabase = await lagSupabaseServerKlient()

  const [{ data: runde }, { data: svar }, { data: stasjoner }] = await Promise.all([
    supabase.from('puls_runde').select('id, start_dato, slutt_dato, status, notat, puls_sporsmal(tekst, kategori)').eq('id', id).maybeSingle<Runde>(),
    supabase.from('puls_svar').select('skala, kommentar, stasjon_id').eq('runde_id', id).overrideTypes<Svar[]>(),
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null).order('butikknummer'),
  ])
  if (!runde) return <p>Fant ikke målingen.</p>
  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))

  // Per stasjon: antall, sum, fordeling [1..5]
  type Agg = { antall: number; sum: number; fordeling: number[] }
  const perStasjon = new Map<string, Agg>()
  let totAntall = 0
  let totSum = 0
  const kommentarer: string[] = []
  for (const s of svar ?? []) {
    if (s.kommentar) kommentarer.push(s.kommentar)
    if (s.skala == null) continue
    const a = perStasjon.get(s.stasjon_id) ?? { antall: 0, sum: 0, fordeling: [0, 0, 0, 0, 0] }
    a.antall++; a.sum += s.skala; a.fordeling[s.skala - 1]++
    perStasjon.set(s.stasjon_id, a)
    totAntall++; totSum += s.skala
  }
  const totSnitt = totAntall > 0 ? (totSum / totAntall).toFixed(1) : '—'

  return (
    <>
      <h1>{runde.puls_sporsmal?.tekst ?? 'Måling'}</h1>
      <p className="undertittel">
        {runde.puls_sporsmal?.kategori} · {datoLang.format(new Date(runde.start_dato))}–{datoLang.format(new Date(runde.slutt_dato))} · <Link href="/puls">Tilbake</Link>
      </p>

      <section className="nokkeltall">
        <div className="kpi"><span className="kpi-tall">{totSnitt}</span><span className="kpi-merke">Snitt hele kjeden</span></div>
        <div className="kpi"><span className="kpi-tall">{totAntall}</span><span className="kpi-merke">Svar totalt</span></div>
      </section>

      <section className="kort">
        <h2>Per stasjon</h2>
        {perStasjon.size === 0 ? <p className="undertittel">Ingen svar ennå.</p> : (
          <table className="tabell">
            <thead><tr><th>Stasjon</th><th>Svar</th><th>Snitt</th><th>Fordeling 1–5</th></tr></thead>
            <tbody>
              {[...perStasjon.entries()].map(([sid, a]) => (
                <tr key={sid}>
                  <td>{navnFor.get(sid) ?? '—'}</td>
                  <td>{a.antall}</td>
                  <td>{(a.sum / a.antall).toFixed(1)}</td>
                  <td className="fordeling">{a.fordeling.map((n, i) => <span key={i} title={`${i + 1}: ${n}`}>{n}</span>)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </section>

      {kommentarer.length > 0 && (
        <section className="kort">
          <h2>Kommentarer ({kommentarer.length})</h2>
          <ul className="puls-kommentarer">
            {kommentarer.map((k, i) => <li key={i}>{k}</li>)}
          </ul>
        </section>
      )}
    </>
  )
}
