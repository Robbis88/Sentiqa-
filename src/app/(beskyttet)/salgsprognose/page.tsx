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
import { Sidehode, Tomtilstand, Forklaring } from '@/components/ui/side'
import Link from 'next/link'

const datoLang = new Intl.DateTimeFormat('nb-NO', { weekday: 'long', day: 'numeric', month: 'long', timeZone: 'Europe/Oslo' })
const UTELAT = new Set(['10', '250', '40']) // drivstoff/pant/CR — ikke butikkdrift

// Signaler bak prognosen. 'live' = i bruk nå, 'kommer' = bygges/venter (lett å
// skru på: bytt status til 'live' når datakilden er på plass).
//
// Sto tidligere som en stripe med emoji-pip nederst på siden. Det gjorde
// metoden til pynt, og ga «kommer»-signalene samme visuelle vekt som de
// som faktisk brukes. Nå er de to setninger i forklaringen.
const SIGNALER: { navn: string; status: 'live' | 'kommer' }[] = [
  { navn: 'vær', status: 'live' },
  { navn: 'helligdager', status: 'live' },
  { navn: 'salgshistorikk år mot år', status: 'live' },
  { navn: 'trend', status: 'live' },
  { navn: 'arrangementer', status: 'live' },
  { navn: 'trafikk (Vegvesenets tellepunkt)', status: 'kommer' },
  { navn: 'drivstoffpriser', status: 'kommer' },
]

/** «a, b og c» — norsk oppramsing, ikke kommaliste med hengende «og». */
const ramsOpp = (ord: string[]) =>
  ord.length <= 1 ? (ord[0] ?? '') : `${ord.slice(0, -1).join(', ')} og ${ord[ord.length - 1]}`

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
  if (liste.length === 0) {
    return (
      <>
        <Sidehode tittel="Salgsprognose" undertittel="Forventet salg i morgen, per kategori." />
        <Tomtilstand
          tittel="Ingen stasjoner tilgjengelig"
          forklaring="Prognosen regnes per stasjon. Så snart du har tilgang til minst én, ser du den her."
        />
      </>
    )
  }

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
          ? [...raaPrognose.advarsler, 'Selvlært kalibrering aktiv — justert mot stasjonens egen treffhistorikk.']
          : raaPrognose.advarsler
        return { ...raaPrognose, forslag, advarsler, totalForventet: forslag.reduce((s, f) => s + f.forventet, 0) }
      })()
    : null

  const navnFor = new Map(AVDELINGER.map((a) => [a.kode, a.navn]))

  // NIVÅ 1 — svaret. Tallet alene sier ingenting om i morgen er en god
  // eller dårlig dag; det er avviket mot en normal ukedag som gjør det.
  const maalTekst = datoLang.format(new Date(`${maalDato}T12:00:00Z`))
  const ukedag = maalTekst.split(' ')[0]
  const avvikPst = prognose
    ? Math.round(((prognose.totalForventet / Math.max(1, prognose.totalBasis)) - 1) * 100)
    : 0
  const svar = prognose && prognose.forslag.length > 0
    ? `${kr.format(prognose.totalForventet)} forventet i morgen, ${avvikPst >= 0 ? '+' : '−'}${Math.abs(avvikPst)} % mot en normal ${ukedag}`
    : null

  // Rødt og vått er kontekst for tallet, ikke en advarsel — derfor i
  // undertittelen og ikke i oppmerksomhetsfeltet.
  const kontekst = [
    `${maalTekst} · ${stasjon.butikknummer} ${stasjon.navn}`,
    roddagNavn ? `${roddagNavn} — prognosen bruker fjorårets samme helligdag` : null,
    vMaal?.temp_maks != null
      ? `varsel ${vMaal.temp_maks.toFixed(0)}°${vMaal.nedbor_mm != null && vMaal.nedbor_mm >= 1 ? `, ${vMaal.nedbor_mm.toFixed(0)} mm regn` : ''}`
      : null,
  ].filter(Boolean).join(' · ')

  return (
    <>
      <Sidehode
        tittel="Salgsprognose"
        undertittel={svar ? `${svar}. ${kontekst}` : kontekst}
      />

      {liste.length > 1 && (
        <StasjonsVelger
          stasjoner={liste.map((s) => ({ id: s.id, navn: `${s.butikknummer} ${s.navn}` }))}
          valgtId={valgtId}
          basePath="/salgsprognose"
        />
      )}

      {!prognose || prognose.forslag.length === 0 ? (
        <Tomtilstand
          tittel="Ikke nok salgshistorikk for denne stasjonen ennå"
          forklaring="Prognosen sammenligner med fjorårets samme ukedag, så den trenger rundt 13 måneder med daglige salgstall før den kan si noe."
          handling={<Link href="/import" className="sq-knapp primar">Gå til Import</Link>}
        />
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
                    <td>{navnFor.get(f.kode) ?? f.navn}</td>
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
          </section>
        </>
      )}

      <Forklaring sporsmaal="Hvordan er prognosen regnet ut?">
        <p>
          Grunnlaget er fjorårets samme ukedag (median ±2 uker), justert med nylig
          trend og værvarselet for i morgen. «Vær/dag-effekt» i tabellen er hvor mye
          vær og ukedag løfter eller demper hver kategori mot en normal dag.
          Drivstoff, pant og CR er holdt utenfor — dette er butikkdrift.
        </p>
        <p>
          Prognosen bruker {ramsOpp(SIGNALER.filter((s) => s.status === 'live').map((s) => s.navn))}.
          {' '}
          {ramsOpp(SIGNALER.filter((s) => s.status === 'kommer').map((s) => s.navn))} er klare å
          koble på når vi avgjør dem, men brukes ikke ennå.
        </p>
        <p>
          Stasjonen kalibrerer seg selv: treffer prognosen skjevt på en kategori over
          tid, korrigeres den mot stasjonens egen treffhistorikk. Er det slått på,
          står det blant meldingene over.
        </p>
      </Forklaring>
    </>
  )
}
