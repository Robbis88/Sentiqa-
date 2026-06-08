import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { datoLang } from '@/lib/format'
import { NyOppgave } from './ny-oppgave'
import { veksleOppgave, slettOppgave } from './handlinger'

type Oppgave = {
  id: string
  stasjon_id: string
  tittel: string
  beskrivelse: string | null
  status: string
  frist: string | null
}

export default async function OppgaverSide() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin' && bruker.rolle !== 'butikksjef') {
    return <p>Du har ikke tilgang til oppgaver.</p>
  }

  const supabase = await lagSupabaseServerKlient()
  const [{ data: oppgaver }, { data: stasjoner }] = await Promise.all([
    supabase
      .from('oppgaver')
      .select('id, stasjon_id, tittel, beskrivelse, status, frist')
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

  return (
    <>
      <h1>Oppgaver</h1>
      <p className="undertittel">Opprett her eller via Assistenten — «lag en oppgave på Bønes om å bestille kaffe».</p>

      <section className="kort">
        <h2>Ny oppgave</h2>
        <NyOppgave stasjoner={(stasjoner ?? []).map((s) => ({ id: s.id, navn: `${s.butikknummer} ${s.navn}` }))} />
      </section>

      <section className="kort">
        <h2>Åpne ({apne.length})</h2>
        {apne.length === 0 ? <p className="undertittel">Ingen åpne oppgaver.</p> : <ul className="rutine-liste">{apne.map(rad)}</ul>}
      </section>

      {fullfort.length > 0 && (
        <section className="kort">
          <h2>Fullført ({fullfort.length})</h2>
          <ul className="rutine-liste">{fullfort.map(rad)}</ul>
        </section>
      )}
    </>
  )
}
