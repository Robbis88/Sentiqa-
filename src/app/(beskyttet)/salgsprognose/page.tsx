import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { kr, iDag } from '@/lib/format'
import { AVDELINGER } from '@/lib/avdelinger'
import { leggTilDager, type Vaerdag } from '@/lib/produksjonsplan'
import { lagSalgsprognose, type AvdSalg } from '@/lib/salgsprognose'
import { hentKalibrering } from '@/lib/backtest'
import { hentVaerKoeff } from '@/lib/vaerprofil'
import { erHelligdag, helligdagNavn } from '@/lib/helligdager'
import { StasjonsVelger } from '../stasjonsvelger'

const datoLang = new Intl.DateTimeFormat('nb-NO', { weekday: 'long', day: 'numeric', month: 'long', timeZone: 'Europe/Oslo' })
const UTELAT = new Set(['10', '250', '40']) // drivstoff/pant/CR — ikke butikkdrift

// Signaler bak prognosen. 'live' = i bruk nå, 'kommer' = bygges/venter (lett å
// skru på: bytt status til 'live' når datakilden er på plass).
const SIGNALER: { ikon: string; navn: string; status: 'live' | 'kommer' }[] = [
  { ikon: '☀️', navn: 'Vær', status: 'live' },
  { ikon: '📅', navn: 'Helligdager', status: 'live' },
  { ikon: '📈', navn: 'Salgshistorikk (år mot år)', status: 'live' },
  { ikon: '🔥', navn: 'Trend', status: 'live' },
  { ikon: '🏟️', navn: 'Arrangementer', status: 'live' },
  { ikon: '🚗', navn: 'Trafikk', status: 'kommer' },
  { ikon: '⛽', navn: 'Drivstoffpriser', status: 'kommer' },
]

export default async function SalgsprognoseSide({ searchParams }: { searchParams: Promise<{ stasjon?: string }> }) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return <p>Salgsprognosen er for eier og butikksjef.</p>
  const sp = await searchParams
  const erUuid = (s?: string) => !!s && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s)

  const supabase = await lagSupabaseServerKlient()
  const { data: stasjoner } = await supabase
    .from('stasjoner').select('id, navn, butikknummer, stasjonstype, vaerfolsomhet, vaerfolsomhet_laert').is('slettet_tid', null).order('butikknummer')
    .overrideTypes<{ id: string; navn: string; butikknummer: string; stasjonstype: string; vaerfolsomhet: number | null; vaerfolsomhet_laert: number | null }[]>()
  const liste = stasjoner ?? []
  if (liste.length === 0) return <><h1>Salgsprognose</h1><p className="undertittel">Ingen stasjoner tilgjengelig.</p></>

  // Admin velger fritt; butikksjef er RLS-scopet til egne stasjoner.
  const valgtId = erUuid(sp.stasjon) && liste.some((s) => s.id === sp.stasjon) ? sp.stasjon! : liste[0].id
  const stasjon = liste.find((s) => s.id === valgtId)!

  const idag = iDag()
  const maalDato = leggTilDager(idag, 1) // i morgen
  const fjorBase = leggTilDager(maalDato, -364)
  const helligdag = erHelligdag(maalDato)
  const roddagNavn = helligdagNavn(maalDato)

  const [{ data: nylig }, { data: fjor }, { data: vMaal }, { data: vFjor }] = await Promise.all([
    supabase.from('v_salg_per_avdeling_dag').select('dato, avdeling_kode, avdeling_navn, omsetning').eq('stasjon_id', valgtId).gte('dato', leggTilDager(idag, -35)).lte('dato', idag).overrideTypes<{ dato: string; avdeling_kode: string | null; avdeling_navn: string | null; omsetning: number | null }[]>(),
    supabase.from('v_salg_per_avdeling_dag').select('dato, avdeling_kode, avdeling_navn, omsetning').eq('stasjon_id', valgtId).gte('dato', leggTilDager(fjorBase, -28)).lte('dato', leggTilDager(fjorBase, 21)).overrideTypes<{ dato: string; avdeling_kode: string | null; avdeling_navn: string | null; omsetning: number | null }[]>(),
    supabase.from('vaer').select('temp_maks, nedbor_mm').eq('stasjon_id', valgtId).eq('dato', maalDato).maybeSingle<Vaerdag>(),
    supabase.from('vaer').select('temp_maks, nedbor_mm').eq('stasjon_id', valgtId).eq('dato', fjorBase).maybeSingle<Vaerdag>(),
  ])

  const rader = [...(nylig ?? []), ...(fjor ?? [])]
  const salg: AvdSalg[] = rader
    .filter((r) => r.avdeling_kode && !UTELAT.has(r.avdeling_kode))
    .map((r) => ({ dato: r.dato, avdelingKode: r.avdeling_kode!, avdelingNavn: r.avdeling_navn ?? r.avdeling_kode!, omsetning: r.omsetning ?? 0 }))
  const datoer = (nylig ?? []).map((r) => r.dato).sort()
  const sisteSalgsdato = datoer.length ? datoer[datoer.length - 1] : idag

  const vaerKoeff = await hentVaerKoeff(supabase, valgtId, 'avdeling')
  const raaPrognose = salg.length > 0
    ? lagSalgsprognose({ maalDato, sisteSalgsdato, salg, vaerMaal: vMaal ?? null, vaerFjor: vFjor ?? null, vaerfolsomhet: stasjon.vaerfolsomhet_laert ?? stasjon.vaerfolsomhet ?? 0.5, vaerKoeff, stasjonstype: stasjon.stasjonstype, helligdag })
    : null
  // Selvlæring: gang inn korreksjon pr avdeling fra egen treffhistorikk.
  const kalibrering = raaPrognose ? await hentKalibrering(supabase, valgtId, 'salgsprognose') : new Map<string, number>()
  const prognose = raaPrognose
    ? (() => {
        const forslag = raaPrognose.forslag.map((f) => {
          const korr = kalibrering.get(f.kode) ?? 1
          return korr === 1 ? f : { ...f, forventet: Math.max(0, Math.round(f.forventet * korr)) }
        })
        const advarsler = kalibrering.size > 0
          ? [...raaPrognose.advarsler, '🤖 Selvlært kalibrering aktiv — justert mot stasjonens egen treffhistorikk.']
          : raaPrognose.advarsler
        return { ...raaPrognose, forslag, advarsler, totalForventet: forslag.reduce((s, f) => s + f.forventet, 0) }
      })()
    : null

  const ikonFor = new Map(AVDELINGER.map((a) => [a.kode, a.ikon]))
  const navnFor = new Map(AVDELINGER.map((a) => [a.kode, a.navn]))

  return (
    <>
      <h1>Salgsprognose · i morgen</h1>
      <p className="undertittel">
        Forventet salg per kategori {datoLang.format(new Date(`${maalDato}T12:00:00Z`))} for {stasjon.butikknummer} {stasjon.navn}.
        {roddagNavn ? ` 🔴 ${roddagNavn} — prognosen bruker fjorårets samme helligdag.` : ''}
        {vMaal?.temp_maks != null ? ` Varsel: ${vMaal.temp_maks.toFixed(0)}°${vMaal.nedbor_mm != null && vMaal.nedbor_mm >= 1 ? `, ${vMaal.nedbor_mm.toFixed(0)} mm regn` : ''}.` : ''}
      </p>

      {liste.length > 1 && (
        <StasjonsVelger
          stasjoner={liste.map((s) => ({ id: s.id, navn: `${s.butikknummer} ${s.navn}` }))}
          valgtId={valgtId}
          basePath="/salgsprognose"
        />
      )}

      {!prognose || prognose.forslag.length === 0 ? (
        <section className="kort">
          <p className="undertittel">Ikke nok salgshistorikk til å lage en prognose for denne stasjonen ennå. Last opp daglige salgstall (helst ~13 mnd bakover for år-mot-år) under Import.</p>
        </section>
      ) : (
        <>
          <section className="nokkeltall">
            <div className="kpi">
              <span className="kpi-tall">{kr.format(prognose.totalForventet)}</span>
              <span className="kpi-merke">Forventet omsetning (eks. drivstoff/pant)</span>
            </div>
            <div className="kpi">
              <span className={`kpi-tall ${prognose.totalForventet >= prognose.totalBasis ? 'gronn' : 'rod'}`}>
                {prognose.totalForventet >= prognose.totalBasis ? '+' : '−'}{Math.abs(Math.round(((prognose.totalForventet / Math.max(1, prognose.totalBasis)) - 1) * 100))} %
              </span>
              <span className="kpi-merke">mot en normal {datoLang.format(new Date(`${maalDato}T12:00:00Z`)).split(' ')[0]}</span>
            </div>
          </section>

          {prognose.advarsler.length > 0 && (
            <section className="kort oppmerksomhet">
              <ul>{prognose.advarsler.map((a, i) => <li key={i}>{a}</li>)}</ul>
            </section>
          )}

          <section className="kort">
            <h2>Per kategori</h2>
            <table className="tabell">
              <thead><tr><th>Kategori</th><th>Forventet</th><th>Vær/dag-effekt</th></tr></thead>
              <tbody>
                {prognose.forslag.map((f) => (
                  <tr key={f.kode}>
                    <td>{ikonFor.get(f.kode) ?? '📦'} {navnFor.get(f.kode) ?? f.navn}</td>
                    <td>{kr.format(f.forventet)}</td>
                    <td>
                      {f.endringPst === 0 ? '—' : (
                        <span className={`status-pip ${f.endringPst > 0 ? 'gronn' : 'gul'}`}>{f.endringPst > 0 ? '+' : ''}{f.endringPst} %</span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
            <p className="undertittel" style={{ marginTop: '0.6rem' }}>
              Bygd på fjorårets samme ukedag (median ±2 uker) + nylig trend + værvarsel. «Vær/dag-effekt» er løftet/dempet av vær og ukedag mot en normal dag.
            </p>
          </section>
        </>
      )}

      <section className="kort">
        <h2>Signaler bak prognosen</h2>
        <div className="signal-stripe">
          {SIGNALER.map((s) => (
            <span key={s.navn} className={`signal-pip ${s.status}`}>
              {s.ikon} {s.navn}{s.status === 'kommer' ? <em> · kommer</em> : ''}
            </span>
          ))}
        </div>
        <p className="undertittel" style={{ marginTop: '0.6rem' }}>
          Trafikk (Vegvesenets tellepunkt) og drivstoffpriser er klare å koble på når vi avgjør dem — prognosen bruker dem ikke ennå.
        </p>
      </section>
    </>
  )
}
