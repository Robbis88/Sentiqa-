import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseAdminKlient } from '@/lib/supabase/admin'
import { finnTeller, settTrafikkAktiv } from './handlinger'
import { Sidehode, Tomtilstand, Datatabell, Forklaring } from '@/components/ui/side'
import { Sideramme } from '@/components/ui/sideramme'

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
    return (
      <Sideramme>
        <Sidehode tittel="Trafikk" />
        <Tomtilstand
          tittel="Mangler service-nøkkel"
          forklaring="Trafikk-oppsettet leser på tvers av kjeder og trenger service-nøkkelen i miljøet. Uten den kan siden ikke vise stasjonene."
        />
      </Sideramme>
    )
  }

  const [{ data: stasjoner }, { data: retailers }] = await Promise.all([
    admin.from('stasjoner').select('id, navn, butikknummer, retailer_id, breddegrad, lengdegrad, trafikk_punkt_id, trafikk_punkt_navn, trafikk_punkt_vei, trafikk_aktiv').is('slettet_tid', null).order('butikknummer').overrideTypes<{ id: string; navn: string; butikknummer: string; retailer_id: string; breddegrad: number | null; lengdegrad: number | null; trafikk_punkt_id: string | null; trafikk_punkt_navn: string | null; trafikk_punkt_vei: string | null; trafikk_aktiv: boolean }[]>(),
    admin.from('retailers').select('id, navn').overrideTypes<{ id: string; navn: string }[]>(),
  ])
  const kjedeNavn = new Map((retailers ?? []).map((r) => [r.id, r.navn]))
  const liste = stasjoner ?? []
  const aktive = liste.filter((s) => s.trafikk_aktiv).length

  // NIVÅ 1 på en liste: hvor mange, og hvor mange av dem krever noe.
  // «5 stasjon(er) måles nå» sto midt i et avsnitt om metode, og sa
  // ingenting om de som IKKE måles — som er de eneste det er noe å gjøre
  // med. To slag: mangler koordinat (kan ikke kobles), og koblet men av.
  const utenKoordinat = liste.filter((s) => s.breddegrad == null).length
  const koblingKlar = liste.filter((s) => s.trafikk_punkt_id && !s.trafikk_aktiv).length
  const ukoblet = liste.filter((s) => s.breddegrad != null && !s.trafikk_punkt_id).length
  const svar = [
    `${liste.length} ${liste.length === 1 ? 'stasjon' : 'stasjoner'}`,
    `${aktive} måles`,
    ukoblet > 0 ? `${ukoblet} mangler tellepunkt` : null,
    koblingKlar > 0 ? `${koblingKlar} koblet, men av` : null,
    utenKoordinat > 0 ? `${utenKoordinat} mangler koordinat` : null,
  ].filter(Boolean).join(' · ')

  return (
    <Sideramme>
      <Sidehode
        tittel="Trafikk"
        undertittel={svar}
      />

      <section className="kort">
        <Datatabell
          antall={liste.length}
          tom={
            <Tomtilstand
              tittel="Ingen stasjoner å koble"
              forklaring="Trafikkmåling kobles per stasjon. Så snart det finnes stasjoner i basen, står de her."
            />
          }
        >
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
                    <form action={finnTeller}><input type="hidden" name="id" value={s.id} /><button type="submit" className="liten primar" disabled={s.breddegrad == null}>Finn teller</button></form>
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
        </Datatabell>
      </section>

      <Forklaring sporsmaal="Hvordan kobler jeg riktig teller?">
        <p>
          «Finn teller» velger nærmeste VEHICLE-teller med ekte volum — ikke sykkel-
          eller gangstitellere, som ligger tett i byene og ellers ville vunnet på
          avstand alene. Forslaget er et forslag: klikk koordinaten for å se stasjonen
          i kart, og sammenlign med tellerens vei før du skrur på.
        </p>
        <p>
          Nærmest i luftlinje er ikke det samme som «på veien forbi». En teller på
          motorveien to hundre meter unna måler trafikk som aldri passerer stasjonen,
          og gjør tallet verre enn ingen tall. Derfor er «Skru på» et eget steg, og
          ikke noe «Finn teller» gjør for deg.
        </p>
      </Forklaring>
    </Sideramme>
  )
}
