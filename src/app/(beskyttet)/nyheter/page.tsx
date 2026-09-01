import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { Sidehode, Tomtilstand } from '@/components/ui/side'
import { Sideramme } from '@/components/ui/sideramme'

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

  const innlegg = data ?? []

  return (
    <Sideramme>
      <Sidehode
        tittel="Nyheter fra Sentiqa"
        undertittel="Oppdateringer, kampanjer og tips."
      />

      {innlegg.length === 0 ? (
        <Tomtilstand
          tittel="Ingen nyheter ennå"
          forklaring="Her kommer oppdateringer om systemet og tips fra andre stasjoner."
        />
      ) : (
        // Var et kort per nyhet. En liste med tre saker skal ikke se ut
        // som tre atskilte moduler.
        <ul className="sq-innleggsliste">
          {innlegg.map((i) => (
            <li key={i.id} className="sq-innlegg">
              <div className="sq-innlegg-topp"><strong>{i.tittel}</strong></div>
              {i.publisert_tid ? (
                <span className="undertittel">{tid.format(new Date(i.publisert_tid))}</span>
              ) : null}
              <p className="sq-innlegg-tekst">{i.innhold}</p>
            </li>
          ))}
        </ul>
      )}
    </Sideramme>
  )
}
