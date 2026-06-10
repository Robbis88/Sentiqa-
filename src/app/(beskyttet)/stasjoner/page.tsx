import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { StasjonSkjema } from './skjema'
import { settTerskel, settStasjonstype, settPosisjon } from './handlinger'

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
}

export default async function StasjonerSide() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin') {
    return <p>Kun eier har tilgang til stasjoner.</p>
  }

  const supabase = await lagSupabaseServerKlient()
  const { data } = await supabase
    .from('stasjoner')
    .select('id, butikknummer, navn, stasjonstype, stasjonstype_sekundaer, svinnterskel_prosent, breddegrad, lengdegrad')
    .is('slettet_tid', null)
    .order('butikknummer')
    .overrideTypes<Stasjon[]>()

  const stasjoner = data ?? []

  return (
    <>
      <h1>Stasjoner</h1>
      <p className="undertittel">
        Registrer butikknummer + navn så importen kobles til riktig stasjon (§6).
      </p>

      <section className="kort">
        <h2>Ny stasjon</h2>
        <StasjonSkjema />
      </section>

      <section className="kort">
        <h2>{stasjoner.length} stasjon(er)</h2>
        {stasjoner.length === 0 ? (
          <p className="undertittel">Ingen stasjoner ennå.</p>
        ) : (
          <table className="tabell">
            <thead>
              <tr><th>Butikknr</th><th>Navn</th><th>Type</th><th>Svinnterskel</th><th>Posisjon (vær)</th></tr>
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
        )}
      </section>
    </>
  )
}
