import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { leggTilLenke, slettLenke } from './handlinger'

type Lenke = { id: string; tittel: string; url: string; ikon: string }

export default async function LenkerSide() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle === 'plattform_redaktor') return <p>Ingen tilgang.</p>
  const kanRedigere = true // alle i tenanten (også tablet) styrer hurtiglenkene

  const supabase = await lagSupabaseServerKlient()
  const { data } = await supabase.from('lenker').select('id, tittel, url, ikon').is('slettet_tid', null).order('sortering').overrideTypes<Lenke[]>()

  return (
    <>
      <h1>Lenker</h1>
      <p className="undertittel">Hurtiglenker til verktøyene dere bruker.</p>

      {kanRedigere && (
        <section className="kort">
          <h2>Ny lenke</h2>
          <form action={leggTilLenke} className="rutine-form">
            <input name="ikon" placeholder="🔗" maxLength={4} style={{ width: '4rem' }} />
            <input name="tittel" placeholder="St1-portal" required />
            <input name="url" placeholder="https://…" required />
            <button type="submit" className="liten">Legg til</button>
          </form>
        </section>
      )}

      {(data ?? []).length === 0 ? (
        <section className="kort"><p className="undertittel">Ingen lenker ennå.</p></section>
      ) : (
        <div className="lenke-grid">
          {(data ?? []).map((l) => (
            <div className="lenke-kort" key={l.id}>
              <a href={l.url} target="_blank" rel="noopener noreferrer" className="lenke-a">
                <span className="lenke-ikon">{l.ikon}</span>
                <span>{l.tittel}</span>
              </a>
              {kanRedigere && (
                <form action={slettLenke}>
                  <input type="hidden" name="id" value={l.id} />
                  <button type="submit" className="lenke-slett" aria-label="Slett">✕</button>
                </form>
              )}
            </div>
          ))}
        </div>
      )}
    </>
  )
}
