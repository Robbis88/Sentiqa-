import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { oversettMange } from '@/lib/oversett'
import { leggTilAnvisning, slettAnvisning } from './handlinger'

type Anvisning = { id: string; kategori: string; tittel: string; innhold: string }

export default async function AnvisningerSide() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle === 'plattform_redaktor') return <p>Ingen tilgang.</p>
  const erLeder = bruker.rolle === 'retailer_admin' || bruker.rolle === 'butikksjef'

  const supabase = await lagSupabaseServerKlient()
  const { data } = await supabase
    .from('anvisninger')
    .select('id, kategori, tittel, innhold')
    .is('slettet_tid', null)
    .order('kategori')
    .order('sortering')
    .overrideTypes<Anvisning[]>()

  const grupper = new Map<string, Anvisning[]>()
  for (const a of data ?? []) {
    const l = grupper.get(a.kategori) ?? []
    l.push(a)
    grupper.set(a.kategori, l)
  }

  const { cookies } = await import('next/headers')
  const sprak = (await cookies()).get('sprak')?.value ?? 'no'
  const fast = ['Anvisninger', 'Prosedyrer og oppskrifter — slå opp når du trenger det.', 'Ingen anvisninger ennå.']
  const oversatt = await oversettMange([...fast, ...(data ?? []).flatMap((a) => [a.kategori, a.tittel, a.innhold])], sprak)
  const o = (s: string) => oversatt.get(s) ?? s

  return (
    <>
      <h1>{o('Anvisninger')}</h1>
      <p className="undertittel">{o('Prosedyrer og oppskrifter — slå opp når du trenger det.')}</p>

      {erLeder && (
        <section className="kort">
          <h2>Ny anvisning</h2>
          <form action={leggTilAnvisning} className="skjema" style={{ maxWidth: 520 }}>
            <label className="felt"><span>Kategori</span><input name="kategori" placeholder="f.eks. Hurtigmat" /></label>
            <label className="felt"><span>Tittel</span><input name="tittel" placeholder="Slik lager du kaffe" required /></label>
            <label className="felt"><span>Innhold</span><textarea name="innhold" rows={5} required /></label>
            <button type="submit" className="liten">Legg til</button>
          </form>
        </section>
      )}

      {grupper.size === 0 ? (
        <section className="kort"><p className="undertittel">{o('Ingen anvisninger ennå.')}</p></section>
      ) : (
        [...grupper.entries()].map(([kat, liste]) => (
          <section className="kort" key={kat}>
            <h2>{o(kat)}</h2>
            {liste.map((a) => (
              <details className="anvisning" key={a.id}>
                <summary>{o(a.tittel)}</summary>
                <p style={{ whiteSpace: 'pre-wrap' }}>{o(a.innhold)}</p>
                {erLeder && (
                  <form action={slettAnvisning}>
                    <input type="hidden" name="id" value={a.id} />
                    <button type="submit" className="liten slett">Slett</button>
                  </form>
                )}
              </details>
            ))}
          </section>
        ))
      )}
    </>
  )
}
