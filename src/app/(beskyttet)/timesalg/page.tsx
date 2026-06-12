import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { datoLang } from '@/lib/format'
import { TimesalgKart } from './timesalg-kart'
import { StasjonsVelger } from '../stasjonsvelger'

type Rad = { stasjon_id: string; time: string; salg: number | null; inne_kunder: number | null; ute_kunder: number | null }

export default async function TimesalgSide({ searchParams }: { searchParams: Promise<{ stasjon?: string }> }) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) {
    return <p>Du har ikke tilgang til timesalg.</p>
  }

  const sp = await searchParams
  const erUuid = (s?: string) => !!s && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s)
  const valgtStasjon = erUuid(sp.stasjon) ? sp.stasjon! : null

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

  const medData = (stasjoner ?? []).filter((s) => (rader ?? []).some((r) => r.stasjon_id === s.id))
  const erStasjon = valgtStasjon != null && medData.some((s) => s.id === valgtStasjon)
  const valgtNavn = erStasjon ? medData.find((s) => s.id === valgtStasjon)?.navn ?? null : null

  const stasjonsliste = (erStasjon ? medData.filter((s) => s.id === valgtStasjon) : medData).map((s) => ({ id: s.id, navn: s.navn }))
  const kartRaderAlle = (rader ?? []).map((r) => ({
    stasjon_id: r.stasjon_id,
    time: r.time,
    salg: r.salg ?? 0,
    inne: r.inne_kunder ?? 0,
    ute: r.ute_kunder ?? 0,
  }))
  const kartRader = erStasjon ? kartRaderAlle.filter((r) => r.stasjon_id === valgtStasjon) : kartRaderAlle
  const harInneUte = (rader ?? []).some((r) => r.inne_kunder != null || r.ute_kunder != null)

  return (
    <>
      <h1>Timesalg</h1>
      <p className="undertittel">{datoLang.format(new Date(siste.dato))} · pr time{harInneUte ? ' · inne/utekunder' : ''} · {erStasjon ? valgtNavn : 'alle stasjoner'}</p>

      {medData.length > 0 && (
        <StasjonsVelger
          stasjoner={medData.map((s) => ({ id: s.id, navn: `${s.butikknummer} ${s.navn}` }))}
          valgtId={erStasjon ? valgtStasjon : null}
          basePath="/timesalg"
        />
      )}

      <section className="kort">
        <TimesalgKart stasjoner={stasjonsliste} rader={kartRader} harInneUte={harInneUte} />
      </section>
    </>
  )
}
