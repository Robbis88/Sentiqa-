import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { sendMelding, slettMelding } from './handlinger'
import { Sidehode, Tomtilstand } from '@/components/ui/side'
import { Sidepanel } from '@/components/ui/sidepanel'

type Melding = { id: string; stasjon_id: string | null; tekst: string; viktig: boolean; opprettet_tid: string }

const tid = new Intl.DateTimeFormat('nb-NO', { timeZone: 'Europe/Oslo', dateStyle: 'short', timeStyle: 'short' })

export default async function MeldingerSide() {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) {
    return <p>Kun eier/butikksjef kan sende meldinger.</p>
  }
  const supabase = await lagSupabaseServerKlient()
  const [{ data: meldinger }, { data: stasjoner }] = await Promise.all([
    supabase.from('tablet_meldinger').select('id, stasjon_id, tekst, viktig, opprettet_tid').is('slettet_tid', null).order('opprettet_tid', { ascending: false }).overrideTypes<Melding[]>(),
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null).order('butikknummer'),
  ])
  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))

  const liste = meldinger ?? []
  const nyMeldingPanel = (
    <Sidepanel
      knapp="Ny melding"
      tittel="Ny melding"
      beskrivelse="Vises på stasjonens nettbrett til du sletter den."
    >
      <form action={sendMelding} className="skjema">
        <label className="felt"><span>Til</span>
          <select name="stasjon_id" defaultValue="">
            <option value="">Alle stasjoner</option>
            {(stasjoner ?? []).map((s) => <option key={s.id} value={s.id}>{s.butikknummer} {s.navn}</option>)}
          </select>
        </label>
        <label className="felt"><span>Melding</span><textarea name="tekst" rows={3} required /></label>
        <label className="felt avkryss"><input type="checkbox" name="viktig" /> Viktig (rød)</label>
        <button type="submit" className="sq-knapp primar">Send til nettbrettet</button>
      </form>
    </Sidepanel>
  )

  return (
    <>
      <Sidehode
        tittel="Meldinger til nettbrettet"
        undertittel={liste.length === 0
          ? 'Korte beskjeder som vises på stasjonens nettbrett.'
          : `${liste.length} aktive. De står på nettbrettet til du sletter dem.`}
        handlinger={nyMeldingPanel}
      />

      {liste.length === 0 ? (
        <Tomtilstand
          tittel="Ingen aktive meldinger"
          forklaring={'En melding her dukker opp på nettbrettet med en gang — nyttig '
            + 'for beskjeder som ikke tåler å vente til neste vakt.'}
          handling={nyMeldingPanel}
        />
      ) : (
        <ul className="melding-liste">
          {liste.map((m) => (
            <li key={m.id} className={m.viktig ? 'viktig' : ''}>
              <div>
                <p className="melding-tekst">{m.tekst}</p>
                <span className="undertittel">{m.stasjon_id ? navnFor.get(m.stasjon_id) ?? '—' : 'Alle stasjoner'} · {tid.format(new Date(m.opprettet_tid))}</span>
              </div>
              <form action={slettMelding}>
                <input type="hidden" name="id" value={m.id} />
                <button type="submit" className="liten slett" aria-label="Slett">Slett</button>
              </form>
            </li>
          ))}
        </ul>
      )}
    </>
  )
}
