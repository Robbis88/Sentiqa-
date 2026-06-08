import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { NyttInnlegg } from './ny-innlegg'
import { settPublisert, slettInnlegg } from './handlinger'

type Innlegg = {
  id: string
  tittel: string
  innhold: string
  publisert: boolean
  publisert_tid: string | null
  opprettet_tid: string
}

const tid = new Intl.DateTimeFormat('nb-NO', { timeZone: 'Europe/Oslo', dateStyle: 'short', timeStyle: 'short' })

export default async function RedaktorSide() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'plattform_redaktor') return <p>Kun plattform-redaktør har tilgang her.</p>

  const supabase = await lagSupabaseServerKlient()
  const { data } = await supabase
    .from('plattform_innlegg')
    .select('id, tittel, innhold, publisert, publisert_tid, opprettet_tid')
    .is('slettet_tid', null)
    .order('opprettet_tid', { ascending: false })
    .overrideTypes<Innlegg[]>()

  return (
    <>
      <h1>Publisering</h1>
      <p className="undertittel">Nyheter, kampanjer og beste praksis til alle kjedene.</p>

      <section className="kort">
        <h2>Nytt innlegg</h2>
        <NyttInnlegg />
      </section>

      {(data ?? []).map((i) => (
        <section className="kort" key={i.id}>
          <h2>{i.tittel}{' '}
            <span className={`status-pip ${i.publisert ? 'gronn' : 'gul'}`}>{i.publisert ? 'Publisert' : 'Utkast'}</span>
          </h2>
          <p style={{ whiteSpace: 'pre-wrap' }}>{i.innhold}</p>
          <p className="undertittel">{i.publisert && i.publisert_tid ? `Publisert ${tid.format(new Date(i.publisert_tid))}` : `Utkast · ${tid.format(new Date(i.opprettet_tid))}`}</p>
          <div className="konk-knapper">
            <form action={settPublisert}>
              <input type="hidden" name="id" value={i.id} />
              <input type="hidden" name="til" value={i.publisert ? 'nei' : 'ja'} />
              <button type="submit" className="liten">{i.publisert ? 'Avpubliser' : 'Publiser'}</button>
            </form>
            <form action={slettInnlegg}>
              <input type="hidden" name="id" value={i.id} />
              <button type="submit" className="liten slett">Slett</button>
            </form>
          </div>
        </section>
      ))}
    </>
  )
}
