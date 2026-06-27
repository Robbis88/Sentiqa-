import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { hentVarehierarki } from '@/lib/varehierarki'
import { MalekortSkjema } from './skjema'
import { slettMalekort } from './handlinger'

export const dynamic = 'force-dynamic'

const METRIKK_ETIKETT: Record<string, string> = {
  omsetning: 'Omsetning',
  antall: 'Antall solgt',
  brutto: 'Bruttofortjeneste',
  snittpris_kunde: 'Snittpris per kunde',
  snittbong: 'Snittbong',
  kunder: 'Kunder',
}
const PERIODE_ETIKETT: Record<string, string> = {
  uke: 'Uke mot i fjor',
  maaned: 'Måned mot i fjor',
  rullende4uker: 'Rullende 4 uker',
}

type MalekortRad = {
  id: string
  navn: string
  metrikk: string
  periode: string
  vis_butikksjef: boolean
  vis_tablet: boolean
  malekort_scope: { nivaa: string; kode: string; navn: string | null }[]
}

export default async function MalingSide() {
  const bruker = await hentInnloggetBruker()

  // Fase 1: kun admin-administrasjon. Leaderboard for butikksjef/tablet kommer
  // i senere faser (motoren).
  if (bruker.rolle !== 'retailer_admin') {
    return (
      <>
        <h1>Måling</h1>
        <p className="undertittel">Rangering av butikkene kommer her snart.</p>
      </>
    )
  }

  const supabase = await lagSupabaseServerKlient()
  const [{ data: kort }, tre] = await Promise.all([
    supabase
      .from('malekort')
      .select('id, navn, metrikk, periode, vis_butikksjef, vis_tablet, malekort_scope(nivaa, kode, navn)')
      .is('slettet_tid', null)
      .order('sortering')
      .order('opprettet_tid')
      .overrideTypes<MalekortRad[]>(),
    hentVarehierarki(supabase),
  ])
  const malekort = kort ?? []

  return (
    <>
      <h1>Måling</h1>
      <p className="undertittel">
        Lag målekort som rangerer butikkene mot hverandre og mot i fjor. Du velger hva som måles og
        på hvilke varer. Butikksjef og tablet ser kun de du deler med dem.
      </p>

      <section className="kort">
        <h2>Dine målekort</h2>
        {malekort.length === 0 ? (
          <p className="undertittel">Ingen målekort ennå — lag ditt første nedenfor.</p>
        ) : (
          <ul className="malekort-liste">
            {malekort.map((m) => (
              <li key={m.id} className="malekort-rad">
                <div>
                  <strong>{m.navn}</strong>
                  <span className="malekort-meta">
                    {METRIKK_ETIKETT[m.metrikk] ?? m.metrikk} · {PERIODE_ETIKETT[m.periode] ?? m.periode}
                    {m.malekort_scope.length > 0
                      ? ` · ${m.malekort_scope.map((s) => s.navn ?? s.kode).join(', ')}`
                      : ' · alt salg'}
                  </span>
                  <span className="malekort-synlig">
                    {m.vis_butikksjef ? '👤 butikksjef ' : ''}{m.vis_tablet ? '📱 tablet' : ''}
                  </span>
                </div>
                <form action={slettMalekort}>
                  <input type="hidden" name="id" value={m.id} />
                  <button type="submit" className="logg-ut">Slett</button>
                </form>
              </li>
            ))}
          </ul>
        )}
      </section>

      <section className="kort">
        <h2>+ Nytt målekort</h2>
        <MalekortSkjema tre={tre} />
      </section>
    </>
  )
}
