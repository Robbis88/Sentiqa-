import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { hentVarehierarki } from '@/lib/varehierarki'
import { beregnMalekort, type Malekort } from '@/lib/malekort'
import { MalekortSkjema } from './skjema'
import { Leaderboard } from './leaderboard'
import { slettMalekort } from './handlinger'
import { Sidehode, Tomtilstand, Forklaring } from '@/components/ui/side'
import { Sidepanel } from '@/components/ui/sidepanel'

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
        <Sidehode tittel="Måling" />
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

  // NIVÅ 1 — svaret. Siden viste rangeringene, men lot leseren telle selv
  // hvor hun stod på tvers av dem. Butikksjefen vil vite plasseringen sin,
  // eieren vil vite hvem som leder.
  const klare = resultater.flatMap((r, i) => (r.klar ? [{ kort: malekort[i], res: r }] : []))

  let svar: string | null = null
  if (erButikksjef) {
    const egne = klare.flatMap(({ kort, res }) => {
      const plass = res.rader.findIndex((rad) => egenIds?.has(rad.stasjonId))
      return plass < 0 ? [] : [{ navn: kort.navn, plass: plass + 1, av: res.rader.length }]
    })
    if (egne.length > 0) {
      const snitt = Math.round(egne.reduce((s, e) => s + e.plass, 0) / egne.length)
      const best = egne.reduce((a, e) => (e.plass < a.plass ? e : a))
      const svakest = egne.reduce((a, e) => (e.plass > a.plass ? e : a))
      svar = `Din butikk ligger i snitt på ${snitt}. plass av ${egne[0].av}`
      // Med bare ett målekort er «best» og «svakest» det samme kortet.
      if (egne.length > 1 && best.navn !== svakest.navn) {
        svar += `. Best på «${best.navn}», svakest på «${svakest.navn}»`
      }
    }
  } else {
    const forsteplasser = new Map<string, number>()
    for (const { res } of klare) {
      const forste = res.rader[0]
      if (forste) forsteplasser.set(forste.navn, (forsteplasser.get(forste.navn) ?? 0) + 1)
    }
    const leder = [...forsteplasser.entries()].sort((a, b) => b[1] - a[1])[0]
    if (leder) {
      svar = `${leder[0]} leder på ${leder[1]} av ${klare.length} ${klare.length === 1 ? 'måling' : 'målinger'}`
    }
  }

  const undertittel = erAdmin
    ? 'Rangering av butikkene mot hverandre og mot i fjor. Butikksjef og nettbrett ser kun de du deler.'
    : 'Slik ligger butikken din an mot de andre, og mot samme periode i fjor.'

  return (
    <>
      <Sidehode
        tittel="Måling"
        undertittel={svar ? `${svar}. ${undertittel}` : undertittel}
        handlinger={erAdmin ? (
          <Sidepanel
            knapp="Nytt målekort"
            tittel="Nytt målekort"
            beskrivelse="Velg hva som måles, på hvilke varer, og hvem som får se det."
          >
            <MalekortSkjema tre={tre} />
          </Sidepanel>
        ) : undefined}
      />

      {malekort.length === 0 ? (
        <Tomtilstand
          tittel={erAdmin ? 'Ingen målekort ennå' : 'Ingen målekort er delt med deg ennå'}
          forklaring={erAdmin
            ? 'Et målekort er én ting butikkene måles på — omsetning, snittbong, antall — for en periode, mot hverandre og mot i fjor. Lag det første, så begynner rangeringen.'
            : 'Eieren bestemmer hvilke målinger som deles. Så snart én er delt, ser du hvordan butikken din ligger an her.'}
        />
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
                  {/* Sto som 👤 og 📱. Hvem som ser kortet er en opplysning,
                      ikke et ikon — og to emoji ved siden av hverandre sa
                      ingenting om hvilken som var hvilken. */}
                  {erAdmin && (m.vis_butikksjef || m.vis_tablet)
                    ? ` · delt med ${[m.vis_butikksjef ? 'butikksjef' : null, m.vis_tablet ? 'nettbrett' : null].filter(Boolean).join(' og ')}`
                    : erAdmin ? ' · kun deg' : ''}
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

      <Forklaring sporsmaal="Hvordan rangeres butikkene?">
        <p>
          Hvert målekort måler én ting for én periode. Butikkene sorteres på verdien,
          og «mot i fjor» sammenligner med samme periode året før — så en butikk som
          er liten, men vokser, ikke automatisk taper mot en stor som står stille.
        </p>
        <p>
          Krever kortet en fullstendig periode, vises ingen rangering før perioden er
          ferdig. Halve uker gir halve tall, og en butikk som mangler én dag ville
          sett ut som den taper.
          {erAdmin ? ' Du velger selv om butikksjefene får se navnene på de andre butikkene eller bare sin egen plassering.' : ''}
        </p>
      </Forklaring>
    </>
  )
}
