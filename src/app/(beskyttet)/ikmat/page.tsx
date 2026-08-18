import Link from 'next/link'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { FREKVENS_ETIKETT, kravTekst } from '@/lib/ikmat/standard'
import { registrerAvlesning, settOppStandard } from './handlinger'
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

  // NIVÅ 1: hva gjenstår i dag. Sida åpnet med modulnavnet og en setning
  // om at avvik varsler automatisk — sant, men ikke svaret på om noen har
  // målt ennå. Den som står med termometeret vil vite hvor mange igjen.
  const alleP = punkter ?? []
  const maalt = alleP.filter((p) => idagPer.has(p.id)).length
  const utenfor = alleP.filter((p) => idagPer.get(p.id)?.innenfor === false).length
  const svar = alleP.length === 0
    ? 'Ingen kontrollpunkter satt opp'
    : [
        maalt >= alleP.length ? `Alle ${alleP.length} målt i dag` : `${alleP.length - maalt} igjen å måle`,
        utenfor > 0 ? `${utenfor} utenfor kravet` : null,
      ].filter(Boolean).join(' · ')
  // Nettbrettet står i én butikk, og hun som holder det vet hvilken.
  // Styrt av rolle, ikke av antall stasjoner — en kjede med bare én
  // stasjon har fortsatt en leder som skal se hvilken det er.
  const paaNettbrett = bruker.rolle === 'butikkbruker_tablet'

  return (
    <>
      <header className="tablet-hode">
        <h1>{svar}</h1>
        <p className="undertittel">
          IK-mat og avvik. Utenfor kravet flagges som avvik og varsler automatisk.
          {kanRedigere ? <> · <Link href="/ikmat/oppsett">Rediger oppsett</Link></> : null}
        </p>
      </header>

      {(stasjoner ?? []).map((s) => {
        const sineP = punkterPerStasjon.get(s.id) ?? []
        return (
          <section className="kort" key={s.id}>
            {!paaNettbrett && <h2>{s.butikknummer} {s.navn}</h2>}

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
                      <tr><th>Punkt</th><th>Krav</th><th>I dag</th><th>Registrer</th></tr>
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
                                <button type="submit" className="sq-knapp">Lagre</button>
                              </form>
                            </td>
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
