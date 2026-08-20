import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { iDag, manedAar, ramsOpp } from '@/lib/format'
import { Sidehode, Forklaring, Nokkeltall, Datatabell } from '@/components/ui/side'
import { Status } from '@/components/ui/status'

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

  // NIVÅ 1 — svaret. Siden fantes for å svare på ett spørsmål: kan jeg
  // stole på analysene? Den viste fire tellere og 14 måneder med ruter,
  // og lot leseren finne ut av det selv.
  //
  // To ting kan være galt, og de krever ulik handling: HULL (last opp
  // dagene som mangler) og FOR KORT HISTORIKK (ingenting å laste opp —
  // år-mot-år må vente). Den andre var usynlig før nå.
  const manederTilbake = (fra: string) => {
    const a = new Date(`${fra}T12:00:00Z`)
    const b = new Date(`${idag}T12:00:00Z`)
    return (b.getUTCFullYear() - a.getUTCFullYear()) * 12 + (b.getUTCMonth() - a.getUTCMonth())
  }
  const totalMangler = oppsummering.reduce((s, d) => s + d.mangler, 0)
  const verst = oppsummering.reduce((a, d) => (d.mangler > a.mangler ? d : a))
  const forKort = oppsummering.filter((d) => !d.eldste || manederTilbake(d.eldste) < 13)

  const svar = totalMangler === 0
    ? `Ingen huller de siste ${MAANEDER} månedene`
    : `${totalMangler} ${totalMangler === 1 ? 'dag' : 'dager'} mangler, flest på ${verst.navn} (${verst.mangler})`
  const historikk = forKort.length > 0
    ? `${ramsOpp(forKort.map((d) => d.navn))} har under 13 måneders historikk — for kort for år-mot-år`
    : `Alle datasett rekker 13 måneder tilbake, nok for år-mot-år`

  return (
    <>
      <Sidehode tittel="Datadekning" undertittel={`${svar}. ${historikk}.`} />

      {/* FARGEN VAR DEN ENESTE FORSKJELLEN. Tallet sto gront naar det
          var null og rodt ellers - men «0» og «4» ser like ut for den
          som ikke ser farge, og et tall alene sier ikke om det er bra.
          Naa staar dommen som ord ved siden av, og fargen forsterker.

          Ingen dom paa `bra` her: et datasett uten huller er
          utgangspunktet, ikke en seier. */}
      <div className="sq-nokkelrad">
        {oppsummering.map((d) => (
          <Nokkeltall
            key={d.key}
            merkelapp={`${d.navn} — dager som mangler`}
            verdi={String(d.mangler)}
            sammenlignet={d.mangler === 0
              ? (d.eldste ? `komplett fra ${d.eldste}` : 'ingen data')
              : `av ${MAANEDER} måneder${d.eldste ? ` · fra ${d.eldste}` : ''}`}
            bra={d.mangler === 0 ? undefined : false}
          />
        ))}
      </div>

      {/* EKTE SAMMENLIGNINGSMATRISE. Her leses rad mot rad (maaned mot
          maaned) OG kolonne mot kolonne (datasett mot datasett). Den
          skal vaere en tabell, og blir det - i primitivet. */}
      <Datatabell tittel="Måned for måned" antall={maaneder.length}>
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
                    // Tallet «22/28» BAERER informasjonen; nivaaet
                    // forsterker den. Ingen tilstand her finnes bare
                    // som farge.
                    const nivaa = klasse === 'gronn' ? 'normal'
                      : klasse === 'gul' ? 'endring'
                        : klasse === 'rod' ? 'handling' : undefined
                    return (
                      <td key={d.key}>
                        {nivaa ? <Status nivaa={nivaa}>{har}/{tot}</Status> : <>{har}/{tot}</>}
                      </td>
                    )
                  })}
                </tr>
              )
            })}
          </tbody>
      </Datatabell>

      {maaneder.map((ym) => {
        const dager = dagerIMaaned(ym, idag)
        if (dager.length === 0) return null
        return (
          <details className="kort dekning-mnd-detalj" key={ym}>
            <summary>{manedAar.format(new Date(`${ym}-01T12:00:00Z`))} — vis dager</summary>
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

      <Forklaring sporsmaal="Hva betyr fargene, og hva gjør jeg med hullene?">
        <p>
          Grønt er full måned, gult er delvis, rødt er ingenting. I dagrutenettet er
          en tom celle dagen i dag — den er ikke lastet opp ennå, og skal ikke telles
          som et hull.
        </p>
        <p>
          Hull fikses ved å laste opp filen for datoen på nytt under Import.
          Gjenopplasting <strong>erstatter</strong> tallene for den datoen; den
          dupliserer aldri, så det er trygt å laste opp en periode om igjen når du er
          i tvil om den kom med.
        </p>
        <p>
          Kort historikk er noe annet enn hull, og kan ikke lastes bort: har vi bare
          fire måneders timesalg, finnes det ikke tall fra i fjor å sammenligne med.
          År-mot-år-analysene trenger rundt 13–14 måneder, og siden viser derfor
          {' '}{MAANEDER} måneder bakover.
        </p>
      </Forklaring>
    </>
  )
}
