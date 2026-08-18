import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { Sidehode, Tomtilstand } from '@/components/ui/side'
import { Sidepanel } from '@/components/ui/sidepanel'
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

  const innlegg = data ?? []
  const nyPanel = (
    <Sidepanel knapp="Nytt innlegg" tittel="Nytt innlegg">
      <NyttInnlegg />
    </Sidepanel>
  )

  return (
    <>
      <Sidehode
        tittel="Publisering"
        undertittel={innlegg.length === 0
          ? 'Nyheter, kampanjer og beste praksis til alle kjedene.'
          : `${innlegg.filter((i) => i.publisert).length} publisert av ${innlegg.length}. `
            + 'Går ut til alle kjedene.'}
        handlinger={nyPanel}
      />

      {innlegg.length === 0 ? (
        <Tomtilstand
          tittel="Ingen innlegg ennå"
          forklaring="Det du publiserer her dukker opp hos alle kjedene under Nyheter."
          handling={nyPanel}
        />
      ) : (
        // Hvert innlegg var et eget kort. Da betyr kortet ingenting — det
        // er en liste, og den skal se ut som en liste.
        <ul className="sq-innleggsliste">
          {innlegg.map((i) => (
            <li key={i.id} className="sq-innlegg">
              <div className="sq-innlegg-topp">
                <strong>{i.tittel}</strong>
                <span className={`status-pip ${i.publisert ? 'gronn' : 'gul'}`}>
                  {i.publisert ? 'Publisert' : 'Utkast'}
                </span>
              </div>
              <p className="sq-innlegg-tekst">{i.innhold}</p>
              <div className="sq-innlegg-bunn">
                <span className="undertittel">
                  {i.publisert && i.publisert_tid ? `Publisert ${tid.format(new Date(i.publisert_tid))}` : `Utkast · ${tid.format(new Date(i.opprettet_tid))}`}
                </span>
                <span className="knapperad">
                  <form action={settPublisert}>
                    <input type="hidden" name="id" value={i.id} />
                    <input type="hidden" name="til" value={i.publisert ? 'nei' : 'ja'} />
                    <button type="submit" className="liten">{i.publisert ? 'Avpubliser' : 'Publiser'}</button>
                  </form>
                  <form action={slettInnlegg}>
                    <input type="hidden" name="id" value={i.id} />
                    <button type="submit" className="liten slett">Slett</button>
                  </form>
                </span>
              </div>
            </li>
          ))}
        </ul>
      )}
    </>
  )
}
