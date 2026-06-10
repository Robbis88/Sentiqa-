import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { FREKVENS_ETIKETT, kravTekst } from '@/lib/ikmat/standard'
import { registrerAvlesning, settOppStandard, slettKontrollpunkt, redigerKontrollpunkt } from './handlinger'
import { AvvikDel } from '../avvik/avvik-del'

type Punkt = {
  id: string
  stasjon_id: string
  navn: string
  type: string
  min_temp: number | null
  max_temp: number | null
  frekvens: string
  sortering: number
}
type Avlesning = { kontrollpunkt_id: string; temperatur: number; innenfor: boolean }

const FREKVENS_REKKE = ['daglig', 'to_ukentlig', 'ukentlig']

export default async function IkMatSide() {
  const bruker = await hentInnloggetBruker()
  const supabase = await lagSupabaseServerKlient()
  const idag = new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Oslo' }).format(new Date())

  const [{ data: punkter }, { data: stasjoner }, { data: avlesninger }] = await Promise.all([
    supabase
      .from('ik_kontrollpunkter')
      .select('id, stasjon_id, navn, type, min_temp, max_temp, frekvens, sortering')
      .is('slettet_tid', null)
      .order('sortering')
      .overrideTypes<Punkt[]>(),
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null).order('butikknummer'),
    supabase
      .from('ik_avlesninger')
      .select('kontrollpunkt_id, temperatur, innenfor, avlest_tid')
      .eq('dato', idag)
      .order('avlest_tid')
      .overrideTypes<(Avlesning & { avlest_tid: string })[]>(),
  ])

  // Siste avlesning i dag per punkt
  const idagPer = new Map<string, Avlesning>()
  for (const a of avlesninger ?? []) idagPer.set(a.kontrollpunkt_id, a)

  const kanRedigere = bruker.rolle === 'retailer_admin' || bruker.rolle === 'butikksjef'
  const punkterPerStasjon = new Map<string, Punkt[]>()
  for (const p of punkter ?? []) {
    const l = punkterPerStasjon.get(p.stasjon_id) ?? []
    l.push(p)
    punkterPerStasjon.set(p.stasjon_id, l)
  }

  return (
    <>
      <h1>IK-mat &amp; avvik</h1>
      <p className="undertittel">Logg temperaturer. Utenfor kravet flagges som avvik og varsler automatisk.</p>

      {(stasjoner ?? []).map((s) => {
        const sineP = punkterPerStasjon.get(s.id) ?? []
        return (
          <section className="kort" key={s.id}>
            <h2>{s.butikknummer} {s.navn}</h2>

            {sineP.length === 0 ? (
              kanRedigere ? (
                <form action={settOppStandard}>
                  <input type="hidden" name="stasjon_id" value={s.id} />
                  <p className="undertittel">Ingen kontrollpunkter ennå.</p>
                  <button type="submit">Sett opp St1-standard (27 punkter)</button>
                </form>
              ) : (
                <p className="undertittel">Ingen kontrollpunkter satt opp ennå.</p>
              )
            ) : (
              FREKVENS_REKKE.filter((f) => sineP.some((p) => p.frekvens === f)).map((frekvens) => (
                <div key={frekvens} className="ik-gruppe">
                  <h3>{FREKVENS_ETIKETT[frekvens]}</h3>
                  <table className="tabell ik-tabell">
                    <thead>
                      <tr><th>Punkt</th><th>Krav</th><th>I dag</th><th>Registrer</th>{kanRedigere && <th></th>}</tr>
                    </thead>
                    <tbody>
                      {sineP.filter((p) => p.frekvens === frekvens).map((p) => {
                        const a = idagPer.get(p.id)
                        return (
                          <tr key={p.id} className={a ? (a.innenfor ? 'ok-rad' : 'avvik-rad') : ''}>
                            <td>{p.navn}</td>
                            <td className="krav">{kravTekst(p.min_temp, p.max_temp)}</td>
                            <td>
                              {a ? (
                                <span className={`status-pip ${a.innenfor ? 'gronn' : 'rod'}`}>{a.temperatur}°C</span>
                              ) : <span className="undertittel">—</span>}
                            </td>
                            <td>
                              <form action={registrerAvlesning} className="ik-form">
                                <input type="hidden" name="kontrollpunkt_id" value={p.id} />
                                <input name="temperatur" inputMode="decimal" placeholder="°C" aria-label={`Temperatur ${p.navn}`} required />
                                <button type="submit" className="liten">Lagre</button>
                              </form>
                            </td>
                            {kanRedigere && (
                              <td className="adm-celle">
                                <details className="rediger-detalj">
                                  <summary>⋯</summary>
                                  <form action={redigerKontrollpunkt} className="rediger-form">
                                    <input type="hidden" name="id" value={p.id} />
                                    <input name="navn" defaultValue={p.navn} aria-label="Navn" />
                                    <input name="min_temp" inputMode="decimal" defaultValue={p.min_temp ?? ''} placeholder="min" aria-label="Min" />
                                    <input name="max_temp" inputMode="decimal" defaultValue={p.max_temp ?? ''} placeholder="maks" aria-label="Maks" />
                                    <button type="submit" className="liten">Lagre</button>
                                  </form>
                                  <form action={slettKontrollpunkt}>
                                    <input type="hidden" name="id" value={p.id} />
                                    <button type="submit" className="liten slett">Slett punkt</button>
                                  </form>
                                </details>
                              </td>
                            )}
                          </tr>
                        )
                      })}
                    </tbody>
                  </table>
                </div>
              ))
            )}
          </section>
        )
      })}

      <AvvikDel />
    </>
  )
}
