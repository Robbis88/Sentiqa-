import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { kr, tall, datoLang } from '@/lib/format'
import { hentAlt } from '@/lib/paginer'
import { AiKontekst } from '../ai-kontekst'
import Link from 'next/link'
import { Sidehode, Tomtilstand } from '@/components/ui/side'
import { motNormalen, verdtEtBlikk } from '@/lib/salg/normalen'

type Svinn = {
  stasjon_id: string
  dato: string | null
  ean: string | null
  varenavn: string | null
  antall: number | null
  nettopris_total: number | null
}

export default async function SvinnSide({ searchParams }: { searchParams: Promise<{ stasjon?: string }> }) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) {
    return <p>Du har ikke tilgang til svinn.</p>
  }

  const sp = await searchParams
  const erUuid = (s?: string) => !!s && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s)
  const valgtStasjon = erUuid(sp.stasjon) ? sp.stasjon! : null

  const supabase = await lagSupabaseServerKlient()
  const { data: siste } = await supabase
    .from('synlig_svinn')
    .select('dato')
    .order('dato', { ascending: false })
    .limit(1)
    .maybeSingle<{ dato: string }>()

  if (!siste?.dato) {
    return (
      <>
        <Sidehode tittel="Synlig svinn" undertittel="Det som kastes, målt mot matsalget." />
        <Tomtilstand
          tittel="Ingen svinndata ennå"
          forklaring="Last opp en Varetransaksjonsliste under Import, så ser du hva som kastes og hvordan det ligger mot terskelen."
          handling={<Link href="/import" className="sq-knapp primar">Gå til Import</Link>}
        />
      </>
    )
  }

  // Rullende 30-dagers vindu for svinn% mot terskel (§11: ikke dag-for-dag).
  const slutt = siste.dato
  const startD = new Date(slutt)
  startD.setDate(startD.getDate() - 29)
  const start = startD.toISOString().slice(0, 10)

  // Vindussummene aggregeres i basen (mig 0077). Tidligere ble råe
  // transaksjonsrader hentet og summert her, men PostgREST kapper på 1000
  // rader — svinn% ble regnet på en vilkårlig delmengde, og en stasjon over
  // terskel kunne vises som grønn.
  const [rader, { data: stasjoner }, { data: svinnVindu }, { data: matVindu }] = await Promise.all([
    hentAlt<Svinn>((fra, til) =>
      supabase
        .from('synlig_svinn')
        .select('stasjon_id, dato, ean, varenavn, antall, nettopris_total')
        .eq('dato', siste.dato)
        .order('id')
        .range(fra, til)
        .overrideTypes<Svinn[]>(),
    ),
    supabase
      .from('stasjoner')
      .select('id, navn, butikknummer, svinnterskel_prosent')
      .is('slettet_tid', null)
      .order('butikknummer')
      .overrideTypes<{ id: string; navn: string; butikknummer: string; svinnterskel_prosent: number | null }[]>(),
    supabase.rpc('svinn_vindu_sum', { p_fra: start, p_til: slutt }),
    supabase.rpc('matsalg_vindu_sum', { p_fra: start, p_til: slutt }),
  ])

  // Aatte uker tilbake: nok til fire like ukedager selv om noen dager
  // mangler. Summeres per dag, saa radantallet holder seg lavt.
  const histFra = new Date(`${siste.dato}T12:00:00Z`)
  histFra.setUTCDate(histFra.getUTCDate() - 56)
  const { data: svinnHist } = await supabase
    .from('synlig_svinn')
    .select('stasjon_id, dato, nettopris_total')
    .gte('dato', histFra.toISOString().slice(0, 10))
    .lte('dato', siste.dato)
    .is('slettet_tid', null)

  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))

  // Svinn% = synlig svinn / matsalg i vinduet, mot terskel per stasjon.
  type SvinnSum = { stasjon_id: string; svinn_kr: number | null }
  type MatSum = { stasjon_id: string; mat_omsetning: number | null }
  const svinnSum = new Map(((svinnVindu ?? []) as SvinnSum[]).map((r) => [r.stasjon_id, r.svinn_kr ?? 0]))
  const matSum = new Map(((matVindu ?? []) as MatSum[]).map((r) => [r.stasjon_id, r.mat_omsetning ?? 0]))
  const terskelrader = (stasjoner ?? []).map((s) => {
    const svinn = svinnSum.get(s.id) ?? 0
    const mat = matSum.get(s.id) ?? 0
    const pst = mat > 0 ? (svinn / mat) * 100 : null
    const terskel = s.svinnterskel_prosent
    let klasse = 'gul'
    if (pst == null || terskel == null) klasse = ''
    else if (pst <= terskel) klasse = 'gronn'
    else if (pst <= terskel * 1.25) klasse = 'gul'
    else klasse = 'rod'
    return { navn: `${s.butikknummer} ${s.navn}`, pst, terskel, klasse, svinn, mat }
  })
  const alleRader = rader ?? []
  const erStasjon = valgtStasjon != null && navnFor.has(valgtStasjon)
  const valgtNavn = erStasjon ? navnFor.get(valgtStasjon!)! : null
  // KPI + topp varer gjelder valgt stasjon; tabellene under viser hele kjeden.
  const alle = erStasjon ? alleRader.filter((r) => r.stasjon_id === valgtStasjon) : alleRader
  const total = alle.reduce((a, r) => a + (r.nettopris_total ?? 0), 0)

  // Per stasjon (alltid hele kjeden)
  const perStasjon = new Map<string, { sum: number; antall: number }>()
  for (const r of alleRader) {
    const p = perStasjon.get(r.stasjon_id) ?? { sum: 0, antall: 0 }
    p.sum += r.nettopris_total ?? 0
    p.antall += r.antall ?? 0
    perStasjon.set(r.stasjon_id, p)
  }
  const stasjonsrader = [...perStasjon.entries()].sort((a, b) => b[1].sum - a[1].sum)

  // Topp varer (på tvers)
  const perVare = new Map<string, { navn: string; sum: number; antall: number }>()
  for (const r of alle) {
    const key = r.ean ?? r.varenavn ?? '?'
    const v = perVare.get(key) ?? { navn: r.varenavn ?? '—', sum: 0, antall: 0 }
    v.sum += r.nettopris_total ?? 0
    v.antall += r.antall ?? 0
    perVare.set(key, v)
  }
  const toppVarer = [...perVare.values()].sort((a, b) => b.sum - a.sum).slice(0, 10)

  // Svinn mot en vanlig ukedag. Samme maskineri som paa /salg, men
  // dommen er snudd: her er mer verre.
  const perDagSvinn = new Map<string, number>()
  for (const h of ((svinnHist ?? []) as {
    stasjon_id: string; dato: string; nettopris_total: number | null
  }[])) {
    if (erStasjon && h.stasjon_id !== valgtStasjon) continue
    perDagSvinn.set(h.dato, (perDagSvinn.get(h.dato) ?? 0) + Math.abs(Number(h.nettopris_total ?? 0)))
  }
  const mot = motNormalen(
    siste.dato,
    total,
    [...perDagSvinn].map(([d, o]) => ({ dato: d, omsetning: o })),
  )

  return (
    <>
      <Sidehode
        tittel="Synlig svinn"
        undertittel={mot.tekst
          ? `${mot.tekst}. ${datoLang.format(new Date(siste.dato))} · ${erStasjon ? valgtNavn : 'alle stasjoner'}`
          : `${datoLang.format(new Date(siste.dato))} · ${erStasjon ? valgtNavn : 'alle stasjoner'}`}
        handlinger={<AiKontekst tekst="Finn arsaken" sporsmal="Hva er de viktigste arsakene til svinnet vart den siste tiden?" />}
      />

      <section className="nokkeltall">
        <div className="kpi">
          <span className="kpi-tall">{kr.format(total)}</span>
          <span className="kpi-merke">Synlig svinn totalt</span>
          {/* Paa svinn er OVER normalen daarlig — motsatt av salg. Derfor
              snus dommen her, mens pilen peker samme vei. */}
          {mot.tekst && (
            <span className={`kpi-mot${verdtEtBlikk(mot) ? (mot.avvikProsent > 0 ? ' darlig' : ' god') : ''}`}>
              {mot.tekst}
            </span>
          )}
        </div>
        <div className="kpi">
          <span className="kpi-tall">{tall.format(alle.reduce((a, r) => a + (r.antall ?? 0), 0))}</span>
          <span className="kpi-merke">Antall enheter</span>
        </div>
      </section>

      <section className="kort">
        <h2>Svinn mot terskel · siste 30 dager</h2>
        <p className="undertittel">Synlig svinn i % av matsalg, mot terskel per stasjon (§11).</p>
        <table className="tabell">
          <thead><tr><th>Stasjon</th><th>Svinn %</th><th>Terskel</th><th>Status</th></tr></thead>
          <tbody>
            {terskelrader.map((r) => (
              <tr key={r.navn}>
                <td>{r.navn}</td>
                <td>{r.pst != null ? `${r.pst.toFixed(1)} %` : '—'}</td>
                <td>{r.terskel != null ? `${r.terskel} %` : '—'}</td>
                <td>
                  {r.klasse ? (
                    <span className={`status-pip ${r.klasse}`}>
                      {r.klasse === 'gronn' ? 'Under terskel' : r.klasse === 'gul' ? 'Følg med' : 'Over terskel'}
                    </span>
                  ) : (
                    '—'
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>

      {!erStasjon && (
        <section className="kort">
          <h2>Per stasjon · {datoLang.format(new Date(siste.dato))}</h2>
          <table className="tabell">
            <thead><tr><th>Stasjon</th><th>Svinn</th><th>Enheter</th></tr></thead>
            <tbody>
              {stasjonsrader.map(([id, p]) => (
                <tr key={id}>
                  <td>{navnFor.get(id) ?? '—'}</td>
                  <td>{kr.format(p.sum)}</td>
                  <td>{tall.format(p.antall)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      )}

      <section className="kort">
        <h2>Mest svinn (varer){erStasjon ? ` · ${valgtNavn}` : ''}</h2>
        <table className="tabell">
          <thead><tr><th>Vare</th><th>Svinn</th><th>Enheter</th></tr></thead>
          <tbody>
            {toppVarer.map((v, i) => (
              <tr key={i}>
                <td>{v.navn}</td>
                <td>{kr.format(v.sum)}</td>
                <td>{tall.format(v.antall)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>
    </>
  )
}
