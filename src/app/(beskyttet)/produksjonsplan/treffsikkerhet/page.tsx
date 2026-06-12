import Link from 'next/link'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { datoLang, iDag, tall } from '@/lib/format'
import { PRODUKSJON_KODER, leggTilDager } from '@/lib/produksjonsplan'

type Rad = { dato: string; planlagt: number; foreslatt: number; faktisk: number; treff: number }

function treffKlasse(t: number): string {
  return t >= 80 ? 'gronn' : t >= 60 ? 'gul' : 'rod'
}

export default async function TreffsikkerhetSide({ searchParams }: { searchParams: Promise<{ butikknummer?: string }> }) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return <p>Du har ikke tilgang.</p>
  const supabase = await lagSupabaseServerKlient()
  const sp = await searchParams

  const { data: alleStasjoner } = await supabase
    .from('stasjoner').select('id, butikknummer, navn').is('slettet_tid', null).order('butikknummer')
    .overrideTypes<{ id: string; butikknummer: string; navn: string }[]>()
  let stasjoner = alleStasjoner ?? []
  if (bruker.rolle === 'butikksjef') {
    const { data: tilgang } = await supabase.from('butikksjef_stasjoner').select('stasjon_id').eq('profil_id', bruker.id)
    const ids = new Set((tilgang ?? []).map((t) => t.stasjon_id))
    stasjoner = stasjoner.filter((s) => ids.has(s.id))
  }
  const valgtNr = sp.butikknummer || stasjoner[0]?.butikknummer || ''
  const stasjon = stasjoner.find((s) => s.butikknummer === valgtNr)

  let rader: Rad[] = []
  let totalTreff: number | null = null
  if (stasjon) {
    const idag = iDag()
    const fra = leggTilDager(idag, -30)
    const { data: plan } = await supabase
      .from('produksjonsplan_linjer').select('dato, varenavn, planlagt, foreslatt')
      .eq('stasjon_id', stasjon.id).gte('dato', fra).lt('dato', idag).gt('planlagt', 0)
      .overrideTypes<{ dato: string; varenavn: string; planlagt: number; foreslatt: number }[]>()

    if (plan && plan.length > 0) {
      const min = plan.reduce((m, p) => (p.dato < m ? p.dato : m), plan[0].dato)
      const { data: salg } = await supabase
        .from('daglig_salg').select('dato, varenavn, antall')
        .eq('stasjon_id', stasjon.id).in('varegruppe_kode', PRODUKSJON_KODER).gte('dato', min).lt('dato', idag).is('slettet_tid', null)
        .overrideTypes<{ dato: string; varenavn: string | null; antall: number | null }[]>()
      const faktisk = new Map<string, number>()
      for (const s of salg ?? []) {
        const k = `${s.dato}|${(s.varenavn ?? '').trim()}`
        faktisk.set(k, (faktisk.get(k) ?? 0) + (s.antall ?? 0))
      }
      const perDato = new Map<string, { planlagt: number; foreslatt: number; faktisk: number }>()
      for (const p of plan) {
        const f = faktisk.get(`${p.dato}|${p.varenavn.trim()}`) ?? 0
        const d = perDato.get(p.dato) ?? { planlagt: 0, foreslatt: 0, faktisk: 0 }
        d.planlagt += p.planlagt; d.foreslatt += p.foreslatt; d.faktisk += f
        perDato.set(p.dato, d)
      }
      rader = [...perDato.entries()].map(([dato, d]) => {
        const treff = Math.max(0, 100 - Math.round((Math.abs(d.planlagt - d.faktisk) / Math.max(d.faktisk, d.planlagt, 1)) * 100))
        return { dato, ...d, treff }
      }).sort((a, b) => (a.dato < b.dato ? 1 : -1))
      totalTreff = rader.length ? Math.round(rader.reduce((a, r) => a + r.treff, 0) / rader.length) : null
    }
  }

  return (
    <>
      <h1>Treffsikkerhet</h1>
      <p className="undertittel">Hvor godt traff planen faktisk salg? <Link href="/produksjonsplan">← Tilbake til planen</Link></p>

      <section className="kort">
        <form method="get" className="plan-velg">
          <label className="felt">
            <span>Stasjon</span>
            <select name="butikknummer" defaultValue={valgtNr}>
              {(stasjoner ?? []).map((s) => <option key={s.id} value={s.butikknummer}>{s.butikknummer} {s.navn}</option>)}
            </select>
          </label>
          <button type="submit">Vis</button>
        </form>
      </section>

      {rader.length === 0 ? (
        <section className="kort"><p className="undertittel">Ingen publiserte planer med faktisk salg å sammenligne ennå.</p></section>
      ) : (
        <>
          {totalTreff != null && (
            <section className="nokkeltall">
              <div className="kpi">
                <span className={`kpi-tall ${treffKlasse(totalTreff)}`}>{totalTreff} %</span>
                <span className="kpi-merke">Snitt treffsikkerhet (siste 30 d)</span>
              </div>
            </section>
          )}
          <section className="kort">
            <table className="tabell">
              <thead>
                <tr><th>Dag</th><th>Forslag</th><th>Planlagt</th><th>Faktisk</th><th>Treff</th></tr>
              </thead>
              <tbody>
                {rader.map((r) => (
                  <tr key={r.dato}>
                    <td>{datoLang.format(new Date(r.dato))}</td>
                    <td>{tall.format(r.foreslatt)}</td>
                    <td>{tall.format(r.planlagt)}</td>
                    <td>{tall.format(r.faktisk)}</td>
                    <td><span className={`status-pip ${treffKlasse(r.treff)}`}>{r.treff} %</span></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </section>
        </>
      )}
    </>
  )
}
