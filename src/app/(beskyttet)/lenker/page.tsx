import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { oversettMange } from '@/lib/oversett'

type Lenke = { id: string; tittel: string; url: string; ikon: string }

export default async function LenkerSide() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle === 'plattform_redaktor') return <p>Ingen tilgang.</p>

  const supabase = await lagSupabaseServerKlient()
  // Oversettelse kun for tableten; admin/butikksjef ser alltid norsk.
  const { cookies } = await import('next/headers')
  const sprak = bruker.rolle === 'butikkbruker_tablet' ? ((await cookies()).get('sprak')?.value ?? 'no') : 'no'
  const { data } = await supabase.from('lenker').select('id, tittel, url, ikon').is('slettet_tid', null).order('sortering').overrideTypes<Lenke[]>()

  const fast = ['Lenker', 'Hurtiglenker for å hjelpe kunder.', 'Ingen lenker lagt inn.']
  const oversatt = await oversettMange([...fast, ...(data ?? []).map((l) => l.tittel)], sprak)
  const o = (s: string) => oversatt.get(s) ?? s

  return (
    <>
      <h1>{o('Lenker')}</h1>
      <p className="undertittel">{o('Hurtiglenker for å hjelpe kunder.')}</p>

      <section className="kort">
        {(data ?? []).length === 0 ? (
          <p className="undertittel">{o('Ingen lenker lagt inn.')}</p>
        ) : (
          <div className="lenke-liste">
            {(data ?? []).map((l) => (
              <a key={l.id} href={l.url} target="_blank" rel="noopener noreferrer" className="lenke-rad">
                <span className="lenke-ikon">{l.ikon}</span>
                <span className="lenke-tittel">{o(l.tittel)}</span>
                <span className="lenke-pil">→</span>
              </a>
            ))}
          </div>
        )}
      </section>
    </>
  )
}
