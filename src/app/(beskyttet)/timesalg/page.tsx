import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { datoLang } from '@/lib/format'
import { TimesalgKart } from './timesalg-kart'

type Rad = { stasjon_id: string; time: string; salg: number | null; inne_kunder: number | null; ute_kunder: number | null }

export default async function TimesalgSide() {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) {
    return <p>Du har ikke tilgang til timesalg.</p>
  }

  const supabase = await lagSupabaseServerKlient()
  const { data: siste } = await supabase
    .from('timesalg')
    .select('dato')
    .order('dato', { ascending: false })
    .limit(1)
    .maybeSingle<{ dato: string }>()

  if (!siste) {
    return (
      <>
        <h1>Timesalg</h1>
        <p className="undertittel">Ingen timesalgsdata ennå. Last opp en timesalgsrapport under Import.</p>
      </>
    )
  }

  const [{ data: rader }, { data: stasjoner }] = await Promise.all([
    supabase.from('timesalg').select('stasjon_id, time, salg, inne_kunder, ute_kunder').eq('dato', siste.dato).overrideTypes<Rad[]>(),
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null).order('butikknummer'),
  ])

  const stasjonsliste = (stasjoner ?? [])
    .filter((s) => (rader ?? []).some((r) => r.stasjon_id === s.id))
    .map((s) => ({ id: s.id, navn: s.navn }))

  const kartRader = (rader ?? []).map((r) => ({
    stasjon_id: r.stasjon_id,
    time: r.time,
    salg: r.salg ?? 0,
    inne: r.inne_kunder ?? 0,
    ute: r.ute_kunder ?? 0,
  }))
  const harInneUte = (rader ?? []).some((r) => r.inne_kunder != null || r.ute_kunder != null)

  return (
    <>
      <h1>Timesalg</h1>
      <p className="undertittel">{datoLang.format(new Date(siste.dato))} · pr time{harInneUte ? ' · inne/utekunder' : ''}</p>

      <section className="kort">
        <TimesalgKart stasjoner={stasjonsliste} rader={kartRader} harInneUte={harInneUte} />
      </section>
    </>
  )
}
