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
  vis_butikksjef: boolean
  vis_tablet: boolean
  malekort_scope: { nivaa: string; kode: string; navn: string | null }[]
}

export default async function MalingSide() {
  const bruker = await hentInnloggetBruker()
  const erAdmin = bruker.rolle === 'retailer_admin'
  const erButikksjef = bruker.rolle === 'butikksjef'

  if (!erAdmin && !erButikksjef) {
    return (
      <>
        <h1>Måling</h1>
        <p className="undertittel">Måling er for eier og butikksjef.</p>
      </>
    )
  }

  const supabase = await lagSupabaseServerKlient()

  // Alle cluster-stasjoner (navn) via definer-RPC — butikksjef ser ellers bare
  // sine egne via RLS, men leaderboardet trenger alle.
  const { data: stData } = await supabase.rpc('malekort_stasjoner')
  const stasjoner = ((stData ?? []) as { id: string; navn: string; butikknummer: string }[]).map((s) => ({
    id: s.id,
    navn: `${s.butikknummer} ${s.navn}`,
  }))

  // Butikksjefens egen(e) stasjon(er) — for uthevingen.
  let egenIds: Set<string> | undefined
  if (erButikksjef) {
    const { data: mine } = await supabase.from('stasjoner').select('id').is('slettet_tid', null)
    egenIds = new Set((mine ?? []).map((m) => m.id))
  }

  let q = supabase
    .from('malekort')
    .select('id, navn, metrikk, normalisering, periode, retning, krev_fullstendig_periode, anonymiser, vis_butikksjef, vis_tablet, malekort_scope(nivaa, kode, navn)')
    .is('slettet_tid', null)
    .order('sortering')
    .order('opprettet_tid')
  if (erButikksjef) q = q.eq('vis_butikksjef', true) // butikksjef ser kun delte
  const { data: kortData } = await q.overrideTypes<MalekortDb[]>()
  const malekort = kortData ?? []

  const [resultater, tre] = await Promise.all([
    Promise.all(malekort.map((m) => beregnMalekort(supabase, m, stasjoner))),
    erAdmin ? hentVarehierarki(supabase) : Promise.resolve([]),
  ])

  return (
    <>
      <h1>Måling</h1>
      <p className="undertittel">
        {erAdmin
          ? 'Rangering av butikkene mot hverandre og mot i fjor. Du velger hva som måles og på hvilke varer. Butikksjef og tablet ser kun de du deler.'
          : 'Slik ligger butikken din an mot de andre, og mot samme periode i fjor.'}
      </p>

      {malekort.length === 0 ? (
        <section className="kort">
          <p className="undertittel">
            {erAdmin ? 'Ingen målekort ennå — lag ditt første nedenfor.' : 'Ingen målekort er delt med deg ennå.'}
          </p>
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
                  {erAdmin ? ` · ${m.vis_butikksjef ? '👤 ' : ''}${m.vis_tablet ? '📱' : ''}` : ''}
                </span>
              </div>
              {erAdmin && (
                <form action={slettMalekort}>
                  <input type="hidden" name="id" value={m.id} />
                  <button type="submit" className="logg-ut">Slett</button>
                </form>
              )}
            </div>
            <Leaderboard resultat={resultater[i]} egenIds={egenIds} anonymiser={erButikksjef && m.anonymiser} />
          </section>
        ))
      )}

      {erAdmin && (
        <section className="kort">
          <h2>+ Nytt målekort</h2>
          <MalekortSkjema tre={tre} />
        </section>
      )}
    </>
  )
}
