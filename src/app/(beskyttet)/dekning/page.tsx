import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { iDag } from '@/lib/format'

// Hvilke datasett vi sjekker datodekning for (alle har en dato-kolonne).
const DATASETT = [
  { tabell: 'daglig_salg', navn: 'Salg' },
  { tabell: 'kassererstatistikk', navn: 'Kasserer' },
  { tabell: 'timesalg', navn: 'Timesalg' },
  { tabell: 'synlig_svinn', navn: 'Svinn' },
] as const

const DAGER = 42 // siste 6 uker
const UKEDAG = ['sø', 'ma', 'ti', 'on', 'to', 'fr', 'lø']

function leggTil(dato: string, n: number): string {
  const d = new Date(`${dato}T12:00:00Z`)
  d.setUTCDate(d.getUTCDate() + n)
  return d.toISOString().slice(0, 10)
}

export default async function DekningSide() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin') {
    return <p>Datadekning er en eier-oversikt.</p>
  }
  const supabase = await lagSupabaseServerKlient()
  const idag = iDag()
  const start = leggTil(idag, -(DAGER - 1))
  const datoer = Array.from({ length: DAGER }, (_, i) => leggTil(start, i))

  const settPer = new Map<string, Set<string>>()
  await Promise.all(
    DATASETT.map(async (d) => {
      const { data } = await supabase.from(d.tabell).select('dato').gte('dato', start).lte('dato', idag).overrideTypes<{ dato: string }[]>()
      settPer.set(d.tabell, new Set((data ?? []).map((r) => r.dato)))
    }),
  )

  const manglerPer = DATASETT.map((d) => ({
    ...d,
    mangler: datoer.filter((dt) => dt < idag && !settPer.get(d.tabell)!.has(dt)).length,
  }))

  return (
    <>
      <h1>Datadekning</h1>
      <p className="undertittel">Hvilke dager vi har tall fra (siste {DAGER} dager). Rødt = mangler opplasting. Gjenopplasting erstatter tallene for datoen — den dupliserer aldri.</p>

      <section className="nokkeltall">
        {manglerPer.map((d) => (
          <div className="kpi" key={d.tabell}>
            <span className={`kpi-tall ${d.mangler === 0 ? 'gronn' : 'rod'}`}>{d.mangler}</span>
            <span className="kpi-merke">{d.navn} — dager mangler</span>
          </div>
        ))}
      </section>

      <section className="kort">
        <div className="heatmap-wrap">
          <table className="heatmap dekning">
            <thead>
              <tr>
                <th>Datasett</th>
                {datoer.map((dt) => {
                  const d = new Date(`${dt}T12:00:00Z`)
                  return <th key={dt} className="dekning-dag" title={dt}>{UKEDAG[d.getUTCDay()]}<br />{d.getUTCDate()}</th>
                })}
              </tr>
            </thead>
            <tbody>
              {DATASETT.map((ds) => {
                const sett = settPer.get(ds.tabell)!
                return (
                  <tr key={ds.tabell}>
                    <td className="dekning-navn">{ds.navn}</td>
                    {datoer.map((dt) => {
                      const har = sett.has(dt)
                      const fremtid = dt > idag
                      const klasse = har ? 'har' : fremtid || dt === idag ? 'vente' : 'mangler'
                      return <td key={dt} className={`dekning-celle ${klasse}`} title={`${ds.navn} · ${dt}: ${har ? 'OK' : klasse === 'vente' ? 'i dag/fremtid' : 'mangler'}`}>{har ? '✓' : klasse === 'mangler' ? '✕' : ''}</td>
                    })}
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
        <p className="undertittel dekning-tegn">
          <span className="dekning-prikk har" /> har data ·
          <span className="dekning-prikk mangler" /> mangler ·
          <span className="dekning-prikk vente" /> i dag (ofte ikke lastet ennå)
        </p>
      </section>
    </>
  )
}
