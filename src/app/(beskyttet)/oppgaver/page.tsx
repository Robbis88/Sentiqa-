import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { datoLang } from '@/lib/format'
import { Sidehode, Tomtilstand } from '@/components/ui/side'
import { Sidepanel } from '@/components/ui/sidepanel'
import { NyOppgave } from './ny-oppgave'
import { veksleOppgave, slettOppgave } from './handlinger'

type Oppgave = {
  id: string
  stasjon_id: string
  tittel: string
  beskrivelse: string | null
  status: string
  frist: string | null
  vis_paa_tablet: boolean
}

export default async function OppgaverSide() {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) {
    return <p>Du har ikke tilgang til oppgaver.</p>
  }

  const supabase = await lagSupabaseServerKlient()
  const [{ data: oppgaver }, { data: stasjoner }] = await Promise.all([
    supabase
      .from('oppgaver')
      .select('id, stasjon_id, tittel, beskrivelse, status, frist, vis_paa_tablet')
      .is('slettet_tid', null)
      .order('status')
      .order('frist', { nullsFirst: false })
      .overrideTypes<Oppgave[]>(),
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null).order('butikknummer'),
  ])

  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))
  const apne = (oppgaver ?? []).filter((o) => o.status === 'apen')
  const fullfort = (oppgaver ?? []).filter((o) => o.status === 'fullfort')

  const rad = (o: Oppgave) => (
    <li key={o.id} className={o.status === 'fullfort' ? 'gjort' : ''}>
      <form action={veksleOppgave}>
        <input type="hidden" name="id" value={o.id} />
        <input type="hidden" name="til" value={o.status === 'apen' ? 'fullfort' : 'apen'} />
        <button type="submit" className={`kryss ${o.status === 'fullfort' ? 'av' : ''}`} aria-label="Veksle">
          {o.status === 'fullfort' ? '✓' : ''}
        </button>
      </form>
      <div className="rutine-tekst">
        <strong>{o.tittel}</strong>
        {o.vis_paa_tablet ? <span className="merke-tablet" title="Vises på tableten">📨 tablet</span> : null}
        <span className="undertittel"> · {navnFor.get(o.stasjon_id) ?? '—'}</span>
        {o.frist ? <span className="undertittel"> · frist {datoLang.format(new Date(o.frist))}</span> : null}
        {o.beskrivelse ? <div className="undertittel">{o.beskrivelse}</div> : null}
      </div>
      <form action={slettOppgave}>
        <input type="hidden" name="id" value={o.id} />
        <button type="submit" className="liten slett" aria-label="Slett">✕</button>
      </form>
    </li>
  )

  const nyPanel = (
    <Sidepanel
      knapp="Ny oppgave"
      tittel="Ny oppgave"
      beskrivelse="Du kan også si det til Assistenten: «lag en oppgave på Bønes om å bestille kaffe»."
    >
      <NyOppgave stasjoner={(stasjoner ?? []).map((s) => ({ id: s.id, navn: `${s.butikknummer} ${s.navn}` }))} />
    </Sidepanel>
  )

  return (
    <>
      <Sidehode
        tittel="Oppgaver"
        undertittel={apne.length === 0
          ? 'Ingenting åpent akkurat nå.'
          : `${apne.length} ${apne.length === 1 ? 'åpen' : 'åpne'}.`}
        handlinger={nyPanel}
      />

      {apne.length === 0 ? (
        <Tomtilstand
          tittel="Ingen åpne oppgaver"
          forklaring={'Oppgaver kan merkes for nettbrettet, så de ansatte ser dem '
            + 'på vakt og kan kvittere ut.'}
          handling={nyPanel}
        />
      ) : (
        <ul className="rutine-liste">{apne.map(rad)}</ul>
      )}

      {fullfort.length > 0 && (
        // Fullforte er dokumentasjon, ikke arbeid. De ligger sammenlagt.
        <details className="sq-forklaring" style={{ marginTop: '1.5rem' }}>
          <summary>Fullført ({fullfort.length})</summary>
          <div className="sq-forklaring-innhold">
            <ul className="rutine-liste">{fullfort.map(rad)}</ul>
          </div>
        </details>
      )}
    </>
  )
}
