import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'

type Innlegg = { id: string; tittel: string; innhold: string; publisert_tid: string | null }

const tid = new Intl.DateTimeFormat('nb-NO', { timeZone: 'Europe/Oslo', dateStyle: 'long' })

export default async function NyheterSide() {
  await hentInnloggetBruker()
  const supabase = await lagSupabaseServerKlient()
  const { data } = await supabase
    .from('plattform_innlegg')
    .select('id, tittel, innhold, publisert_tid')
    .eq('publisert', true)
    .is('slettet_tid', null)
    .order('publisert_tid', { ascending: false })
    .limit(50)
    .overrideTypes<Innlegg[]>()

  return (
    <>
      <h1>Nyheter fra Sentiqa</h1>
      <p className="undertittel">Oppdateringer, kampanjer og tips.</p>

      {(data ?? []).length === 0 ? (
        <section className="kort"><p className="undertittel">Ingen nyheter ennå.</p></section>
      ) : (
        (data ?? []).map((i) => (
          <section className="kort" key={i.id}>
            <h2>{i.tittel}</h2>
            {i.publisert_tid ? <p className="undertittel">{tid.format(new Date(i.publisert_tid))}</p> : null}
            <p style={{ whiteSpace: 'pre-wrap' }}>{i.innhold}</p>
          </section>
        ))
      )}
    </>
  )
}
