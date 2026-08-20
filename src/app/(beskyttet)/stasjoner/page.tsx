import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { StasjonSkjema } from './skjema'
import { VaerKnapp } from './vaer-knapp'
import { settTerskel, settStasjonstype, settPosisjon, settVaerfolsomhet } from './handlinger'
import { Sidehode, Tomtilstand, Datatabell } from '@/components/ui/side'
import { Sidepanel } from '@/components/ui/sidepanel'
import { Knapp } from '@/components/ui/knapp'

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
        // REDIGERINGSRUTENETT. Formen kommer fra primitivet, lagringen
        // blir liggende her - fire uavhengige serverhandlinger, en per
        // felt, akkurat som for. Aa slaa dem sammen til en ville vaert
        // en funksjonell endring forkledd som design.
        //
        // Raden er EN stasjon man retter opp noe i. Den er ikke en
        // velger for aktiv stasjon; det spoersmaalet bor i toppstripen
        // og ble avklart i trinn 09.
        <Datatabell rutenett antall={stasjoner.length}>
            <thead>
              <tr><th>Butikknr</th><th>Navn</th><th>Type</th><th>Svinnterskel</th><th>Værfølsomhet</th><th>Posisjon (vær)</th></tr>
            </thead>
            <tbody>
              {stasjoner.map((s) => (
                <tr key={s.id}>
                  <td>{s.butikknummer}</td>
                  <td>{s.navn}</td>
                  <td>
                    {/* LAGRE-KNAPPEN SIER HVA DEN LAGRER. Fire knapper
                        med samme navn staar paa hver rad; med tjue
                        stasjoner blir det aatti «Lagre» paa sida, og en
                        skjermleser leste dem alle likt. */}
                    <form action={settStasjonstype} className="sq-rutenett-gruppe">
                      <input type="hidden" name="stasjon_id" value={s.id} />
                      <select name="stasjonstype" defaultValue={s.stasjonstype} aria-label={`Primær type for ${s.butikknummer} ${s.navn}`}>
                        {TYPER.map(([v, t]) => <option key={v} value={v}>{t}</option>)}
                      </select>
                      <select name="stasjonstype_sekundaer" defaultValue={s.stasjonstype_sekundaer ?? ''} aria-label={`Sekundær type for ${s.butikknummer} ${s.navn}`}>
                        <option value="">(ingen)</option>
                        {TYPER.map(([v, t]) => <option key={v} value={v}>{t}</option>)}
                      </select>
                      <Knapp type="submit" variant="ghost" liten aria-label={`Lagre type for ${s.butikknummer} ${s.navn}`}>
                        Lagre
                      </Knapp>
                    </form>
                  </td>
                  <td>
                    <form action={settTerskel} className="sq-rutenett-gruppe">
                      <input type="hidden" name="stasjon_id" value={s.id} />
                      <input
                        name="terskel"
                        inputMode="decimal"
                        defaultValue={s.svinnterskel_prosent ?? ''}
                        placeholder="2,8"
                        aria-label={`Svinnterskel i prosent for ${s.butikknummer} ${s.navn}`}
                      />
                      <span>%</span>
                      <Knapp type="submit" variant="ghost" liten aria-label={`Lagre svinnterskel for ${s.butikknummer} ${s.navn}`}>
                        Lagre
                      </Knapp>
                    </form>
                  </td>
                  <td>
                    <form action={settVaerfolsomhet} className="sq-rutenett-gruppe">
                      <input type="hidden" name="stasjon_id" value={s.id} />
                      <input name="vaerfolsomhet" inputMode="decimal" defaultValue={s.vaerfolsomhet ?? 0.5} placeholder="0.5" aria-label={`Værfølsomhet 0–1 for ${s.butikknummer} ${s.navn}, manuell fallback`} className="sq-smalt-felt" />
                      <Knapp type="submit" variant="ghost" liten aria-label={`Lagre værfølsomhet for ${s.butikknummer} ${s.navn}`}>
                        Lagre
                      </Knapp>
                    </form>
                    {s.vaerfolsomhet_laert != null ? (
                      <div className="undertittel sq-finstilt">
                        Lært: <b>{s.vaerfolsomhet_laert.toFixed(2)}</b> · temp {s.vaer_temp_korr != null ? `${s.vaer_temp_korr >= 0 ? '+' : ''}${s.vaer_temp_korr.toFixed(2)}` : '–'} · nedbør {s.vaer_nedbor_korr != null ? `${s.vaer_nedbor_korr >= 0 ? '+' : ''}${s.vaer_nedbor_korr.toFixed(2)}` : '–'} <span title="Motoren bruker den lærte verdien; tallet over er kun fallback">(i bruk)</span>
                      </div>
                    ) : null}
                  </td>
                  <td>
                    <form action={settPosisjon} className="sq-rutenett-gruppe">
                      <input type="hidden" name="stasjon_id" value={s.id} />
                      <label>Bredde<input name="breddegrad" inputMode="decimal" defaultValue={s.breddegrad ?? ''} placeholder="60.3913" /></label>
                      <label>Lengde<input name="lengdegrad" inputMode="decimal" defaultValue={s.lengdegrad ?? ''} placeholder="5.3221" /></label>
                      <Knapp type="submit" variant="ghost" liten aria-label={`Lagre posisjon for ${s.butikknummer} ${s.navn}`}>
                        Lagre
                      </Knapp>
                    </form>
                  </td>
                </tr>
              ))}
            </tbody>
        </Datatabell>
      )}
    </>
  )
}
