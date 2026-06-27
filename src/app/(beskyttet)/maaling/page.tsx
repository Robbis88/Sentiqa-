import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { hentVarehierarki } from '@/lib/varehierarki'
import { beregnMalekort, type Malekort } from '@/lib/malekort'
import { MalekortSkjema } from './skjema'
import { Leaderboard } from './leaderboard'
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

type MalekortDb = Malekort & {
  malekort_scope: { nivaa: string; kode: string; navn: string | null }[]
}

export default async function MalingSide() {
  const bruker = await hentInnloggetBruker()

  // Fase 1–2: admin-administrasjon + rangering. Butikksjef/tablet-visning er
  // egne faser.
  if (bruker.rolle !== 'retailer_admin') {
    return (
      <>
        <h1>Måling</h1>
        <p className="undertittel">Rangering av butikkene kommer her snart.</p>
      </>
    )
  }

  const supabase = await lagSupabaseServerKlient()
  const [{ data: kortData }, { data: stasjonData }, tre] = await Promise.all([
    supabase
      .from('malekort')
      .select('id, navn, metrikk, normalisering, periode, retning, krev_fullstendig_periode, anonymiser, vis_butikksjef, vis_tablet, malekort_scope(nivaa, kode, navn)')
      .is('slettet_tid', null)
      .order('sortering')
      .order('opprettet_tid')
      .overrideTypes<(MalekortDb & { vis_butikksjef: boolean; vis_tablet: boolean })[]>(),
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null).order('butikknummer'),
    hentVarehierarki(supabase),
  ])
  const malekort = kortData ?? []
  const stasjoner = (stasjonData ?? []).map((s) => ({ id: s.id, navn: `${s.butikknummer} ${s.navn}` }))

  // Regn ut rangeringen for hvert målekort (parallelt).
  const resultater = await Promise.all(malekort.map((m) => beregnMalekort(supabase, m, stasjoner)))

  return (
    <>
      <h1>Måling</h1>
      <p className="undertittel">
        Rangering av butikkene dine mot hverandre og mot i fjor. Du velger hva som måles og på hvilke
        varer. Butikksjef og tablet ser kun de du deler med dem.
      </p>

      {malekort.length === 0 ? (
        <section className="kort">
          <p className="undertittel">Ingen målekort ennå — lag ditt første nedenfor.</p>
        </section>
      ) : (
        malekort.map((m, i) => (
          <section className="kort malekort-kort" key={m.id}>
            <div className="malekort-topp">
              <div>
                <h2>{m.navn}</h2>
                <span className="malekort-meta">
                  {METRIKK_ETIKETT[m.metrikk] ?? m.metrikk} · {PERIODE_ETIKETT[m.periode] ?? m.periode}
                  {m.malekort_scope.length > 0
                    ? ` · ${m.malekort_scope.map((s) => s.navn ?? s.kode).join(', ')}`
                    : ' · alt salg'}
                  {' · '}{m.vis_butikksjef ? '👤 ' : ''}{m.vis_tablet ? '📱' : ''}
                </span>
              </div>
              <form action={slettMalekort}>
                <input type="hidden" name="id" value={m.id} />
                <button type="submit" className="logg-ut">Slett</button>
              </form>
            </div>
            <Leaderboard resultat={resultater[i]} />
          </section>
        ))
      )}

      <section className="kort">
        <h2>+ Nytt målekort</h2>
        <MalekortSkjema tre={tre} />
      </section>
    </>
  )
}
