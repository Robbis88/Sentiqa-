import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { oversettMange } from '@/lib/oversett'
import { leggTilAnvisning, slettAnvisning } from './handlinger'
import { Sidehode, Tomtilstand } from '@/components/ui/side'
import { Sidepanel } from '@/components/ui/sidepanel'

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

  // Oversettelse gjelder KUN tableten. Admin/butikksjef ser alltid norsk
  // (selv om sprak-cookien er satt av en tablet-bruker i samme nettleser).
  const { cookies } = await import('next/headers')
  const sprak = bruker.rolle === 'butikkbruker_tablet' ? ((await cookies()).get('sprak')?.value ?? 'no') : 'no'
  const fast = ['Anvisninger', 'Prosedyrer og oppskrifter — slå opp når du trenger det.', 'Ingen anvisninger ennå.']
  const oversatt = await oversettMange([...fast, ...(data ?? []).flatMap((a) => [a.kategori, a.tittel, a.innhold])], sprak)
  const o = (s: string) => oversatt.get(s) ?? s

  const antall = [...grupper.values()].reduce((n, l) => n + l.length, 0)
  const nyPanel = erLeder ? (
    <Sidepanel knapp="Ny anvisning" tittel="Ny anvisning">
      <form action={leggTilAnvisning} className="skjema">
        <label className="felt"><span>Kategori</span><input name="kategori" placeholder="f.eks. Hurtigmat" /></label>
        <label className="felt"><span>Tittel</span><input name="tittel" placeholder="Slik lager du kaffe" required /></label>
        <label className="felt"><span>Innhold</span><textarea name="innhold" rows={8} required /></label>
        <button type="submit" className="sq-knapp primar">Legg til anvisning</button>
      </form>
    </Sidepanel>
  ) : undefined

  return (
    <>
      <Sidehode
        tittel={o('Anvisninger')}
        undertittel={o('Prosedyrer og oppskrifter — slå opp når du trenger det.')}
        handlinger={nyPanel}
      />

      {grupper.size === 0 ? (
        <Tomtilstand
          tittel={o('Ingen anvisninger ennå')}
          forklaring={o('Her legger dere prosedyrene folk må slå opp — hvordan '
            + 'kaffemaskinen rengjøres, hvordan pølsegrillen settes opp.')}
          handling={nyPanel}
        />
      ) : (
        // Kategoriene er en EKTE gruppering — folk leter etter «Hurtigmat»,
        // ikke etter den fjerde anvisningen. Derfor beholdes de.
        [...grupper.entries()].map(([kat, liste]) => (
          <section className="sq-anvkat" key={kat}>
            <h2>{o(kat)} <span className="undertittel">· {liste.length}</span></h2>
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
      <p className="undertittel">{antall} {antall === 1 ? o('anvisning') : o('anvisninger')}</p>
    </>
  )
}
