import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseAdminKlient } from '@/lib/supabase/admin'
import { finnTeller, settTrafikkAktiv } from './handlinger'

// Plattform-eierens trafikk-oppsett: koble hver stasjon til nærmeste bilteller
// (Vegvesen) og skru måling på/av. Kun der telleren faktisk står på veien forbi
// stasjonen. Service-role (på tvers av kjeder) bak redaktør-gate.
export default async function TrafikkSide() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'plattform_redaktor') return <p>Trafikk-oppsettet er for plattform-eier.</p>

  let admin
  try {
    admin = lagSupabaseAdminKlient()
  } catch {
    return <><h1>Trafikk</h1><p className="undertittel">Mangler service-nøkkel.</p></>
  }

  const [{ data: stasjoner }, { data: retailers }] = await Promise.all([
    admin.from('stasjoner').select('id, navn, butikknummer, retailer_id, breddegrad, lengdegrad, trafikk_punkt_id, trafikk_punkt_navn, trafikk_punkt_vei, trafikk_aktiv').is('slettet_tid', null).order('butikknummer').overrideTypes<{ id: string; navn: string; butikknummer: string; retailer_id: string; breddegrad: number | null; lengdegrad: number | null; trafikk_punkt_id: string | null; trafikk_punkt_navn: string | null; trafikk_punkt_vei: string | null; trafikk_aktiv: boolean }[]>(),
    admin.from('retailers').select('id, navn').overrideTypes<{ id: string; navn: string }[]>(),
  ])
  const kjedeNavn = new Map((retailers ?? []).map((r) => [r.id, r.navn]))
  const liste = stasjoner ?? []
  const aktive = liste.filter((s) => s.trafikk_aktiv).length

  return (
    <>
      <h1>Trafikk</h1>
      <p className="undertittel">
        Koble hver stasjon til nærmeste Vegvesen-bilteller og skru måling på — kun der telleren faktisk står på veien forbi stasjonen.
        «Finn teller» henter forslaget; bekreft selv mot kart før du skrur på. {aktive} stasjon(er) måles nå.
      </p>

      <section className="kort">
        <table className="tabell">
          <thead><tr><th>Kjede</th><th>Stasjon</th><th>Koordinat</th><th>Tellepunkt</th><th>Måling</th><th>Handlinger</th></tr></thead>
          <tbody>
            {liste.map((s) => (
              <tr key={s.id}>
                <td className="undertittel">{kjedeNavn.get(s.retailer_id) ?? '—'}</td>
                <td>{s.butikknummer} {s.navn}</td>
                <td className="undertittel">
                  {s.breddegrad != null ? <a href={`https://www.google.com/maps?q=${s.breddegrad},${s.lengdegrad}`} target="_blank" rel="noreferrer">{s.breddegrad}, {s.lengdegrad}</a> : 'mangler'}
                </td>
                <td>
                  {s.trafikk_punkt_navn ? <>{s.trafikk_punkt_vei ? <strong>{s.trafikk_punkt_vei}</strong> : null}<br /><span className="undertittel">{s.trafikk_punkt_navn}</span></> : <span className="undertittel">ikke koblet</span>}
                </td>
                <td>{s.trafikk_aktiv ? <span className="status-pip gronn">på</span> : <span className="status-pip">av</span>}</td>
                <td>
                  <div className="plattform-handlinger">
                    <form action={finnTeller}><input type="hidden" name="id" value={s.id} /><button type="submit" className="liten" disabled={s.breddegrad == null}>Finn teller</button></form>
                    {s.trafikk_punkt_id ? (
                      <form action={settTrafikkAktiv}>
                        <input type="hidden" name="id" value={s.id} />
                        <input type="hidden" name="aktiv" value={s.trafikk_aktiv ? 'false' : 'true'} />
                        <button type="submit" className={s.trafikk_aktiv ? 'liten slett' : 'liten'}>{s.trafikk_aktiv ? 'Skru av' : 'Skru på'}</button>
                      </form>
                    ) : null}
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        <p className="undertittel" style={{ marginTop: '0.6rem' }}>
          Tips: «Finn teller» velger nærmeste VEHICLE-teller med ekte volum (ikke sykkel/gangsti). Klikk koordinaten for å se stasjonen i kart, og sammenlign med tellerens vei før du skrur på.
        </p>
      </section>
    </>
  )
}
