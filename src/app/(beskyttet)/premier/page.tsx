import { hentInnloggetBruker } from '@/lib/auth/dal'
import { SlettKnapp } from '@/components/ui/slett-knapp'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { kr, datoLang } from '@/lib/format'
import { registrerBruk, slettBruk, tildelPremie, vekslUtbetalt, slettTildeling } from './handlinger'
import { Sidehode, Datatabell } from '@/components/ui/side'
import { Sidepanel } from '@/components/ui/sidepanel'
import { Liste, Rad } from '@/components/ui/liste'
import { Status } from '@/components/ui/status'
import { Knapp } from '@/components/ui/knapp'

type Bruk = { id: string; stasjon_id: string; beskrivelse: string; belop_kr: number; dato: string }
type Tildeling = { id: string; stasjon_id: string; beskrivelse: string; belop_kr: number; dato: string; utbetalt: boolean }

export default async function PremierSide() {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return <p>Kun eier/butikksjef.</p>
  const erAdmin = bruker.rolle === 'retailer_admin'
  const supabase = await lagSupabaseServerKlient()
  const [{ data: stasjoner }, { data: tildelinger }, { data: bruk }] = await Promise.all([
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null).order('butikknummer'),
    supabase.from('pengepremie').select('id, stasjon_id, beskrivelse, belop_kr, dato, utbetalt').order('dato', { ascending: false }).limit(50).overrideTypes<Tildeling[]>(),
    supabase.from('pengepremie_bruk').select('id, stasjon_id, beskrivelse, belop_kr, dato').order('dato', { ascending: false }).limit(50).overrideTypes<Bruk[]>(),
  ])
  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))

  // Vunnet = alle tildelinger (konkurranse-vinnere oppretter en tildeling automatisk)
  const vunnetFor = new Map<string, number>()
  for (const t of tildelinger ?? []) vunnetFor.set(t.stasjon_id, (vunnetFor.get(t.stasjon_id) ?? 0) + Number(t.belop_kr))
  const bruktFor = new Map<string, number>()
  for (const b of bruk ?? []) bruktFor.set(b.stasjon_id, (bruktFor.get(b.stasjon_id) ?? 0) + Number(b.belop_kr))

  const samletIgjen = (stasjoner ?? []).reduce(
    (n, s2) => n + (vunnetFor.get(s2.id) ?? 0) - (bruktFor.get(s2.id) ?? 0), 0)

  const tildelPanel = (
    <Sidepanel
      knapp="Tildel premie"
      tittel="Tildel pengepremie"
      beskrivelse="Utenom konkurranser — for eksempel ekstra innsats. Kun eier kan tildele."
    >
      <form action={tildelPremie} className="rutine-form">
            <label className="felt"><span>Stasjon</span>
              <select name="stasjon_id" required defaultValue="">
                <option value="" disabled>Velg …</option>
                {(stasjoner ?? []).map((s) => <option key={s.id} value={s.id}>{s.butikknummer} {s.navn}</option>)}
              </select>
            </label>
            <label className="felt"><span>Hva gjelder det?</span>
              <input name="beskrivelse" placeholder="Toppinnsats i juli" required />
            </label>
            <label className="felt sq-smalt"><span>Beløp i kroner</span>
              <input name="belop_kr" type="number" min="1" step="1" required />
            </label>
            <label className="felt sq-smalt"><span>Dato</span>
              <input name="dato" type="date" />
            </label>
            <button type="submit" className="liten">Tildel</button>
          </form>
    </Sidepanel>
  )

  const brukPanel = (
    <Sidepanel
      knapp="Registrer bruk"
      tittel="Registrer bruk"
      beskrivelse="Hva pengene gikk til, så saldoen stemmer."
      knappeklasse="sq-knapp"
    >
      <form action={registrerBruk} className="rutine-form">
          <label className="felt"><span>Stasjon</span>
            <select name="stasjon_id" required defaultValue="">
              <option value="" disabled>Velg …</option>
              {(stasjoner ?? []).map((s) => <option key={s.id} value={s.id}>{s.butikknummer} {s.navn}</option>)}
            </select>
          </label>
          <label className="felt"><span>Hva ble pengene brukt til?</span>
            <input name="beskrivelse" placeholder="Julebord" required />
          </label>
          <label className="felt sq-smalt"><span>Beløp i kroner</span>
            <input name="belop_kr" type="number" min="1" step="1" required />
          </label>
          <label className="felt sq-smalt"><span>Dato</span>
            <input name="dato" type="date" />
          </label>
          <button type="submit" className="liten">Lagre</button>
        </form>
    </Sidepanel>
  )

  return (
    <>
      <Sidehode
        tittel="Premiesaldo"
        undertittel={`${kr.format(samletIgjen)} igjen å bruke. Vunnet fra konkurranser og tildelinger, minus det som er brukt.`}
        handlinger={(
          <>
            {erAdmin && tildelPanel}
            {brukPanel}
          </>
        )}
      />

      {/* DENNE ER EN EKTE MATRISE og blir staaende som tabell: man leser
          «vunnet mot brukt mot igjen» bortover, og stasjon mot stasjon
          nedover. Aa gjore den om til en liste for aa se moderne ut ville
          odelagt nettopp det den er god til. */}
      <Datatabell tittel="Premiepotten per stasjon" antall={(stasjoner ?? []).length}>
          <thead><tr><th>Stasjon</th><th>Vunnet</th><th>Brukt</th><th>Igjen</th></tr></thead>
          <tbody>
            {(stasjoner ?? []).map((s) => {
              const vunnet = vunnetFor.get(s.id) ?? 0
              const brukt = bruktFor.get(s.id) ?? 0
              return (
                <tr key={s.id}>
                  <td>{s.butikknummer} {s.navn}</td>
                  <td>{kr.format(vunnet)}</td>
                  <td>{kr.format(brukt)}</td>
                  <td><strong>{kr.format(vunnet - brukt)}</strong></td>
                </tr>
              )
            })}
          </tbody>
      </Datatabell>

      {/* TILDELINGER ER OBJEKTER, ikke en matrise. Ingen leser
          belopskolonnen mot datokolonnen; man leter etter EN tildeling
          og gjor noe med den.

          «Utbetalt: Nei» er det som krever noe av eieren - derfor
          `handling`, ikke bare en gul prikk. Og den var FOR en knapp
          forkledd som et statusmerke, med `border: 0` og en peker som
          inline-stil: noe som saa ut som en tilstand, men var en
          handling. Naa er de to ting: tilstanden vises, handlingen
          heter det den gjor.

          ROLLEFORSKJELLEN BESTAAR. Bare eier kan veksle og slette;
          butikksjefen ser det samme, men uten knappene. */}
      {(tildelinger ?? []).length > 0 && (
        <>
          <h2>Tildelinger</h2>
          <Liste merkelapp="Tildelte premier">
            {(tildelinger ?? []).map((t) => (
              <Rad
                key={t.id}
                primaer={t.beskrivelse}
                sekundaer={`${navnFor.get(t.stasjon_id) ?? '—'} · ${datoLang.format(new Date(t.dato))}`}
                metadata={kr.format(Number(t.belop_kr))}
                status={(
                  <Status nivaa={t.utbetalt ? 'normal' : 'handling'}>
                    {t.utbetalt ? 'Utbetalt' : 'Ikke utbetalt'}
                  </Status>
                )}
                handlinger={erAdmin ? (
                  <>
                    <form action={vekslUtbetalt}>
                      <input type="hidden" name="id" value={t.id} />
                      <input type="hidden" name="til" value={t.utbetalt ? 'nei' : 'ja'} />
                      <Knapp type="submit" variant="ghost" liten>
                        {t.utbetalt ? 'Marker som ikke utbetalt' : 'Marker utbetalt'}
                      </Knapp>
                    </form>
                    <SlettKnapp handling={slettTildeling} id={t.id} bekreftelse="Tildelingen slettet" />
                  </>
                ) : undefined}
              />
            ))}
          </Liste>
        </>
      )}

      {(bruk ?? []).length > 0 && (
        <>
          <h2>Siste bruk</h2>
          <Liste merkelapp="Brukte premiemidler">
            {(bruk ?? []).map((b) => (
              <Rad
                key={b.id}
                primaer={b.beskrivelse}
                sekundaer={`${navnFor.get(b.stasjon_id) ?? '—'} · ${datoLang.format(new Date(b.dato))}`}
                metadata={kr.format(Number(b.belop_kr))}
                handlinger={(
                  <SlettKnapp handling={slettBruk} id={b.id} bekreftelse="Bruken slettet" />
                )}
              />
            ))}
          </Liste>
        </>
      )}
    </>
  )
}
