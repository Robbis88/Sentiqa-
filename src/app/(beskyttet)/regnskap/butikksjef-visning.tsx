import Link from 'next/link'
import type { InnloggetBruker } from '@/lib/auth/typer'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { kr, prosent, manedAar, avviksKlasse } from '@/lib/format'
import { BUTIKKSJEF_PERSONAL_KODER, BUTIKKSJEF_DRIFT_KODER } from '@/lib/regnskap-tilgang'
import { SKJUL_OMS_KODER as SKJUL_OMS } from '@/lib/avdelinger'

type Linje = { seksjon: string; kode: string | null; post: string; regnskap: number | null; budsjett: number | null; avvik: number | null; index_pct: number | null }
type Kost = { navn: string; regnskap: number; budsjett: number }

// Butikksjef ser kun EGEN stasjon: omsetning + BRF + påvirkbare kostnader.
// Aldri royalty/husleie/finans/varekost-detaljer eller «Resultat» (admin-nivå).
export async function RegnskapButikksjef({ bruker, periode: valgtPeriode, butikknummer }: { bruker: InnloggetBruker; periode?: string; butikknummer?: string }) {
  const supabase = await lagSupabaseServerKlient()

  const { data: tilgang } = await supabase.from('butikksjef_stasjoner').select('stasjon_id').eq('profil_id', bruker.id)
  const stasjonIds = (tilgang ?? []).map((t) => t.stasjon_id as string)
  if (stasjonIds.length === 0) return <p className="undertittel">Du har ingen stasjon tildelt ennå.</p>
  const { data: stasjoner } = await supabase.from('stasjoner').select('id, butikknummer, navn').in('id', stasjonIds).order('butikknummer').overrideTypes<{ id: string; butikknummer: string; navn: string }[]>()
  const valgtNr = butikknummer || stasjoner?.[0]?.butikknummer || ''
  const stasjon = (stasjoner ?? []).find((s) => s.butikknummer === valgtNr) ?? stasjoner?.[0]
  if (!stasjon) return <p className="undertittel">Ingen stasjon.</p>

  // Perioder for stasjonen (rød tråd)
  const { data: perRader } = await supabase.from('regnskapslinjer').select('periode').eq('stasjon_id', stasjon.id).order('periode', { ascending: false }).overrideTypes<{ periode: string }[]>()
  const perioder = [...new Set((perRader ?? []).map((p) => p.periode))]
  if (perioder.length === 0) {
    return (
      <>
        <h1>Regnskap · {stasjon.butikknummer} {stasjon.navn}</h1>
        <p className="undertittel">Ingen regnskapsdata for din stasjon ennå.</p>
      </>
    )
  }
  const valgtIso = valgtPeriode ? `${valgtPeriode}-01` : null
  const aktivPeriode = valgtIso && perioder.includes(valgtIso) ? valgtIso : perioder[0]

  const { data } = await supabase
    .from('regnskapslinjer').select('seksjon, kode, post, regnskap, budsjett, avvik, index_pct')
    .eq('stasjon_id', stasjon.id).eq('periode', aktivPeriode).order('sortering')
    .overrideTypes<Linje[]>()
  const linjer = data ?? []

  const seksjon = (n: string) => linjer.filter((l) => l.seksjon === n && !SKJUL_OMS.has(l.kode ?? ''))
  const sumR = (ls: Linje[]) => ls.reduce((a, l) => a + (l.regnskap ?? 0), 0)
  const omsTot = sumR(seksjon('omsetning'))
  const brfTot = sumR(seksjon('bruttofortjeneste'))

  // Påvirkbare kostnader: personal samlet til én linje + de utvalgte drift-kodene.
  const drift = seksjon('driftskostnader')
  const personal = drift.filter((l) => l.kode && BUTIKKSJEF_PERSONAL_KODER.has(l.kode))
  const kostnader: Kost[] = []
  if (personal.length > 0) {
    kostnader.push({ navn: 'Personalkostnad', regnskap: sumR(personal), budsjett: personal.reduce((a, l) => a + (l.budsjett ?? 0), 0) })
  }
  for (const kode of BUTIKKSJEF_DRIFT_KODER) {
    const l = drift.find((x) => x.kode === kode)
    if (l && ((l.regnskap ?? 0) !== 0 || (l.budsjett ?? 0) !== 0)) kostnader.push({ navn: l.post, regnskap: l.regnskap ?? 0, budsjett: l.budsjett ?? 0 })
  }

  return (
    <>
      <h1>Regnskap · {stasjon.butikknummer} {stasjon.navn}</h1>
      <p className="undertittel">{manedAar.format(new Date(aktivPeriode))} · din stasjon. Du ser omsetning, BRF og kostnadene du selv kan påvirke.</p>

      {(stasjoner ?? []).length > 1 && (
        <section className="kort">
          <form method="get" className="plan-velg">
            <label className="felt"><span>Stasjon</span>
              <select name="butikknummer" defaultValue={valgtNr}>
                {(stasjoner ?? []).map((s) => <option key={s.id} value={s.butikknummer}>{s.butikknummer} {s.navn}</option>)}
              </select>
            </label>
            <button type="submit">Vis</button>
          </form>
        </section>
      )}

      {perioder.length > 1 && (
        <nav className="periode-trad" aria-label="Tidligere måneder">
          {perioder.map((p) => (
            <Link key={p} href={`/regnskap?periode=${p.slice(0, 7)}${stasjoner && stasjoner.length > 1 ? `&butikknummer=${valgtNr}` : ''}`} className={`periode-chip ${p === aktivPeriode ? 'aktiv' : ''}`}>{manedAar.format(new Date(p))}</Link>
          ))}
        </nav>
      )}

      <section className="nokkeltall">
        <div className="kpi"><span className="kpi-tall">{kr.format(omsTot)}</span><span className="kpi-merke">Omsetning</span></div>
        <div className="kpi"><span className="kpi-tall">{kr.format(brfTot)}</span><span className="kpi-merke">Bruttofortjeneste</span></div>
      </section>

      {(['omsetning', 'bruttofortjeneste'] as const).map((navn) => (
        <section className="kort" key={navn}>
          <h2>{navn === 'omsetning' ? 'Omsetning' : 'Bruttofortjeneste'}</h2>
          <table className="tabell">
            <thead><tr><th>Avdeling</th><th>Regnskap</th><th className="mob-skjul">Budsjett</th><th>Mot budsjett</th></tr></thead>
            <tbody>
              {seksjon(navn).map((l, i) => (
                <tr key={i}>
                  <td>{l.post}</td>
                  <td>{kr.format(l.regnskap ?? 0)}</td>
                  <td className="mob-skjul">{kr.format(l.budsjett ?? 0)}</td>
                  <td>{l.index_pct != null ? <span className={`status-pip ${avviksKlasse(l.index_pct)}`}>{prosent.format(l.index_pct / 100)}</span> : '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      ))}

      <section className="kort">
        <h2>Påvirkbare kostnader</h2>
        <p className="undertittel">Kostnadene du selv styrer. Resten (royalty, husleie, finans …) ligger på admin-nivå.</p>
        <table className="tabell">
          <thead><tr><th>Kostnad</th><th>Regnskap</th><th className="mob-skjul">Budsjett</th><th>Mot budsjett</th></tr></thead>
          <tbody>
            {kostnader.map((k) => {
              const avvik = k.regnskap - k.budsjett
              const overBudsjett = k.budsjett > 0 && avvik > 0
              return (
                <tr key={k.navn}>
                  <td>{k.navn}</td>
                  <td>{kr.format(k.regnskap)}</td>
                  <td className="mob-skjul">{kr.format(k.budsjett)}</td>
                  <td><span className={`status-pip ${overBudsjett ? 'rod' : 'gronn'}`}>{avvik >= 0 ? '+' : '−'}{kr.format(Math.abs(avvik))}</span></td>
                </tr>
              )
            })}
          </tbody>
        </table>
      </section>
    </>
  )
}
