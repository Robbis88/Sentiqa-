import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { StasjonSkjema } from './skjema'
import { VaerKnapp } from './vaer-knapp'
import { settTerskel, settStasjonstype, settPosisjon, settVaerfolsomhet } from './handlinger'
import { Sidehode, Tomtilstand } from '@/components/ui/side'
import { Sidepanel } from '@/components/ui/sidepanel'

const TYPER: [string, string][] = [
  ['utfart', 'Utfart'],
  ['pendler', 'Pendler'],
  ['bydel', 'Bydel/lokal'],
  ['gjennomfart', 'Gjennomfart'],
  ['sentrum', 'Sentrum'],
]

type Stasjon = {
  id: string
  butikknummer: string
  navn: string
  stasjonstype: string
  stasjonstype_sekundaer: string | null
  svinnterskel_prosent: number | null
  breddegrad: number | null
  lengdegrad: number | null
  vaerfolsomhet: number | null
  vaerfolsomhet_laert: number | null
  vaer_temp_korr: number | null
  vaer_nedbor_korr: number | null
}

export default async function StasjonerSide() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin') {
    return <p>Kun eier har tilgang til stasjoner.</p>
  }

  const supabase = await lagSupabaseServerKlient()
  const { data } = await supabase
    .from('stasjoner')
    .select('id, butikknummer, navn, stasjonstype, stasjonstype_sekundaer, svinnterskel_prosent, breddegrad, lengdegrad, vaerfolsomhet, vaerfolsomhet_laert, vaer_temp_korr, vaer_nedbor_korr')
    .is('slettet_tid', null)
    .order('butikknummer')
    .overrideTypes<Stasjon[]>()

  const stasjoner = data ?? []

  return (
    <>
      <Sidehode
        tittel="Stasjoner"
        undertittel={stasjoner.length === 0
          ? 'Butikknummeret er nøkkelen — det er slik importen finner riktig stasjon.'
          : `${stasjoner.length} ${stasjoner.length === 1 ? 'stasjon' : 'stasjoner'}. `
            + 'Butikknummeret kobler importen til riktig sted.'}
        handlinger={(
          <>
            <VaerKnapp />
            <Sidepanel
              knapp="Ny stasjon"
              tittel="Ny stasjon"
              beskrivelse="Butikknummeret må stemme med det som står i rapportene fra St1."
            >
              <StasjonSkjema />
            </Sidepanel>
          </>
        )}
      />

      <p className="undertittel">
        Breddegrad og lengdegrad hentes fra Google Maps. Er de satt, henter
        systemet været automatisk til produksjonsplanen.
      </p>

      {stasjoner.length === 0 ? (
        <Tomtilstand
          tittel="Ingen stasjoner ennå"
          forklaring="Uten en stasjon har importen ingen steder å legge tallene."
        />
      ) : (
        <div className="tabellramme">
          <table className="tabell">
            <thead>
              <tr><th>Butikknr</th><th>Navn</th><th>Type</th><th>Svinnterskel</th><th>Værfølsomhet</th><th>Posisjon (vær)</th></tr>
            </thead>
            <tbody>
              {stasjoner.map((s) => (
                <tr key={s.id}>
                  <td>{s.butikknummer}</td>
                  <td>{s.navn}</td>
                  <td>
                    <form action={settStasjonstype} className="type-form">
                      <input type="hidden" name="stasjon_id" value={s.id} />
                      <select name="stasjonstype" defaultValue={s.stasjonstype} aria-label="Primær type">
                        {TYPER.map(([v, t]) => <option key={v} value={v}>{t}</option>)}
                      </select>
                      <select name="stasjonstype_sekundaer" defaultValue={s.stasjonstype_sekundaer ?? ''} aria-label="Sekundær type">
                        <option value="">(ingen)</option>
                        {TYPER.map(([v, t]) => <option key={v} value={v}>{t}</option>)}
                      </select>
                      <button type="submit" className="liten">Lagre</button>
                    </form>
                  </td>
                  <td>
                    <form action={settTerskel} className="terskel-form">
                      <input type="hidden" name="stasjon_id" value={s.id} />
                      <input
                        name="terskel"
                        inputMode="decimal"
                        defaultValue={s.svinnterskel_prosent ?? ''}
                        placeholder="2,8"
                        aria-label="Svinnterskel %"
                      />
                      <span>%</span>
                      <button type="submit" className="liten">Lagre</button>
                    </form>
                  </td>
                  <td>
                    <form action={settVaerfolsomhet} className="terskel-form">
                      <input type="hidden" name="stasjon_id" value={s.id} />
                      <input name="vaerfolsomhet" inputMode="decimal" defaultValue={s.vaerfolsomhet ?? 0.5} placeholder="0.5" aria-label="Værfølsomhet 0–1 (manuell fallback)" className="sq-smalt-felt" />
                      <button type="submit" className="liten">Lagre</button>
                    </form>
                    {s.vaerfolsomhet_laert != null ? (
                      <div className="undertittel sq-finstilt">
                        Lært: <b>{s.vaerfolsomhet_laert.toFixed(2)}</b> · temp {s.vaer_temp_korr != null ? `${s.vaer_temp_korr >= 0 ? '+' : ''}${s.vaer_temp_korr.toFixed(2)}` : '–'} · nedbør {s.vaer_nedbor_korr != null ? `${s.vaer_nedbor_korr >= 0 ? '+' : ''}${s.vaer_nedbor_korr.toFixed(2)}` : '–'} <span title="Motoren bruker den lærte verdien; tallet over er kun fallback">(i bruk)</span>
                      </div>
                    ) : null}
                  </td>
                  <td>
                    <form action={settPosisjon} className="posisjon-form">
                      <input type="hidden" name="stasjon_id" value={s.id} />
                      <label>Bredde<input name="breddegrad" inputMode="decimal" defaultValue={s.breddegrad ?? ''} placeholder="60.3913" /></label>
                      <label>Lengde<input name="lengdegrad" inputMode="decimal" defaultValue={s.lengdegrad ?? ''} placeholder="5.3221" /></label>
                      <button type="submit" className="liten">Lagre</button>
                    </form>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </>
  )
}
