import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { iDag, manedAar } from '@/lib/format'

// Aldri cache — datadekning skal alltid speile basen med en gang.
export const dynamic = 'force-dynamic'
export const revalidate = 0

// Datasett med dato-kolonne. Distinkte datoer kommer fra v_datodekning (0059).
const DATASETT = [
  { key: 'daglig_salg', navn: 'Salg' },
  { key: 'kassererstatistikk', navn: 'Kasserer' },
  { key: 'timesalg', navn: 'Timesalg' },
  { key: 'synlig_svinn', navn: 'Svinn' },
] as const

const MAANEDER = 14 // år-mot-år trenger ~13–14 mnd historikk
const UKEDAG = ['sø', 'ma', 'ti', 'on', 'to', 'fr', 'lø']

function leggTil(dato: string, n: number): string {
  const d = new Date(`${dato}T12:00:00Z`)
  d.setUTCDate(d.getUTCDate() + n)
  return d.toISOString().slice(0, 10)
}
function dagerIMaaned(ym: string, idag: string): string[] {
  const ut: string[] = []
  let d = `${ym}-01`
  while (d.slice(0, 7) === ym && d <= idag) { ut.push(d); d = leggTil(d, 1) }
  return ut
}

export default async function DekningSide() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin') {
    return <p>Datadekning er en eier-oversikt.</p>
  }
  const supabase = await lagSupabaseServerKlient()
  const idag = iDag()

  // 14 måneder, nyeste først.
  const maaneder: string[] = []
  for (let i = 0; i < MAANEDER; i++) {
    const d = new Date(`${idag.slice(0, 8)}01T12:00:00Z`)
    d.setUTCMonth(d.getUTCMonth() - i)
    maaneder.push(d.toISOString().slice(0, 7))
  }
  const start = `${maaneder[maaneder.length - 1]}-01`

  // Distinkte datoer pr datasett (≤ ~430 rader hver → under 1000-grensen).
  const settPer = new Map<string, Set<string>>()
  await Promise.all(
    DATASETT.map(async (d) => {
      const { data } = await supabase.from('v_datodekning').select('dato').eq('datasett', d.key).gte('dato', start).overrideTypes<{ dato: string }[]>()
      settPer.set(d.key, new Set((data ?? []).map((r) => r.dato)))
    }),
  )

  // Per datasett: eldste dato + antall manglende dager over hele vinduet.
  const alleDager = maaneder.flatMap((ym) => dagerIMaaned(ym, idag))
  const oppsummering = DATASETT.map((d) => {
    const sett = settPer.get(d.key)!
    const eldste = [...sett].sort()[0] ?? null
    const mangler = alleDager.filter((dt) => dt < idag && !sett.has(dt)).length
    return { ...d, eldste, mangler }
  })

  return (
    <>
      <h1>Datadekning</h1>
      <p className="undertittel">
        Hvilke dager vi har tall fra, {MAANEDER} måneder bakover. År-mot-år-analysene trenger ~13–14 mnd historikk.
        Rødt = mangler opplasting. Gjenopplasting erstatter tallene for datoen — den dupliserer aldri.
      </p>
      <p className="undertittel" style={{ background: 'var(--gul-svak)', padding: '0.4rem 0.7rem', borderRadius: 8 }}>
        🔎 Leser nå <b>{settPer.get('daglig_salg')?.size ?? 0}</b> salgsdager fra basen (i {MAANEDER}-mnd-vinduet) · oppdatert {new Intl.DateTimeFormat('nb-NO', { timeZone: 'Europe/Oslo', timeStyle: 'medium' }).format(new Date())}
      </p>

      <section className="nokkeltall">
        {oppsummering.map((d) => (
          <div className="kpi" key={d.key}>
            <span className={`kpi-tall ${d.mangler === 0 ? 'gronn' : 'rod'}`}>{d.mangler}</span>
            <span className="kpi-merke">{d.navn} — dager mangler{d.eldste ? ` · fra ${d.eldste}` : ' · ingen data'}</span>
          </div>
        ))}
      </section>

      <section className="kort">
        <h2>Måned for måned</h2>
        <table className="tabell dekning-mnd">
          <thead>
            <tr><th>Måned</th>{DATASETT.map((d) => <th key={d.key}>{d.navn}</th>)}</tr>
          </thead>
          <tbody>
            {maaneder.map((ym) => {
              const dager = dagerIMaaned(ym, idag).filter((dt) => dt <= idag)
              const tot = dager.length
              return (
                <tr key={ym}>
                  <td>{manedAar.format(new Date(`${ym}-01T12:00:00Z`))}</td>
                  {DATASETT.map((d) => {
                    const sett = settPer.get(d.key)!
                    const har = dager.filter((dt) => sett.has(dt)).length
                    const klasse = tot === 0 ? '' : har === 0 ? 'rod' : har >= tot ? 'gronn' : 'gul'
                    return <td key={d.key}><span className={`status-pip ${klasse}`}>{har}/{tot}</span></td>
                  })}
                </tr>
              )
            })}
          </tbody>
        </table>
      </section>

      {maaneder.map((ym) => {
        const dager = dagerIMaaned(ym, idag)
        if (dager.length === 0) return null
        return (
          <details className="kort dekning-mnd-detalj" key={ym}>
            <summary>📅 {manedAar.format(new Date(`${ym}-01T12:00:00Z`))} — vis dager</summary>
            <div className="heatmap-wrap">
              <table className="heatmap dekning">
                <thead>
                  <tr><th>Datasett</th>{dager.map((dt) => {
                    const d = new Date(`${dt}T12:00:00Z`)
                    return <th key={dt} className="dekning-dag" title={dt}>{UKEDAG[d.getUTCDay()]}<br />{d.getUTCDate()}</th>
                  })}</tr>
                </thead>
                <tbody>
                  {DATASETT.map((ds) => {
                    const sett = settPer.get(ds.key)!
                    return (
                      <tr key={ds.key}>
                        <td className="dekning-navn">{ds.navn}</td>
                        {dager.map((dt) => {
                          const har = sett.has(dt)
                          const klasse = har ? 'har' : dt >= idag ? 'vente' : 'mangler'
                          return <td key={dt} className={`dekning-celle ${klasse}`} title={`${ds.navn} · ${dt}: ${har ? 'OK' : klasse === 'vente' ? 'i dag' : 'mangler'}`}>{har ? '✓' : klasse === 'mangler' ? '✕' : ''}</td>
                        })}
                      </tr>
                    )
                  })}
                </tbody>
              </table>
            </div>
          </details>
        )
      })}
    </>
  )
}
