import Link from 'next/link'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { husketStasjon } from '@/lib/stasjonskontekst'
import { stasjonFraUrl, tillatAlleFor } from '@/lib/stasjonsvalg'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { datoLang, tall, kr } from '@/lib/format'
import { AVDELINGER } from '@/lib/avdelinger'
import { OppdaterKnapp } from './oppdater-knapp'
import { Sidehode, Tomtilstand, Forklaring } from '@/components/ui/side'

// Backtesten kan ta litt når den kjøres fra knappen (motorene × ~60 dager × stasjoner).
export const maxDuration = 120

type TreffRad = { type: 'produksjonsplan' | 'salgsprognose'; dato: string; kategori: string; forventet: number; faktisk: number; treff: number }
type Type = 'produksjonsplan' | 'salgsprognose'

function klasse(t: number): string {
  return t >= 80 ? 'gronn' : t >= 60 ? 'gul' : 'rod'
}

const AVD_NAVN = new Map(AVDELINGER.map((a) => [a.kode, a.navn]))
const PROD_NAVN = new Map<string, string>([
  ['1201', 'Boller'], ['1202', 'Brød/bakst'], ['1203', 'Smørbrød'],
  ['1216', 'Varmmat'], ['1217', 'Pølser'], ['1218', 'Kylling'],
  ['1219', 'Søtt'], ['1221', 'Salat'],
])
function katNavn(type: Type, kode: string): string {
  return (type === 'salgsprognose' ? AVD_NAVN.get(kode) : PROD_NAVN.get(kode)) ?? `Kode ${kode}`
}

export default async function TreffsikkerhetSide({ searchParams }: { searchParams: Promise<{ butikknummer?: string }> }) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return <p>Du har ikke tilgang.</p>
  const supabase = await lagSupabaseServerKlient()
  const sp = await searchParams

  const { data: alleStasjoner } = await supabase
    .from('stasjoner').select('id, butikknummer, navn').is('slettet_tid', null).order('butikknummer')
    .overrideTypes<{ id: string; butikknummer: string; navn: string }[]>()
  let stasjoner = alleStasjoner ?? []
  if (bruker.rolle === 'butikksjef') {
    const { data: tilgang } = await supabase.from('butikksjef_stasjoner').select('stasjon_id').eq('profil_id', bruker.id)
    const ids = new Set((tilgang ?? []).map((t) => t.stasjon_id))
    stasjoner = stasjoner.filter((s) => ids.has(s.id))
  }
  // Samme kontrakt som /produksjonsplan. Treffsikkerheten maales per
  // stasjon - et snitt over kjeden ville skjult den ene som bommer.
  const sok = new URLSearchParams()
  if (sp.butikknummer) sok.set('butikknummer', sp.butikknummer)
  const valgtId = await husketStasjon(
    stasjoner, stasjonFraUrl(sok, stasjoner),
    tillatAlleFor('/produksjonsplan/treffsikkerhet', bruker.rolle, stasjoner.length),
  )
  const stasjon = stasjoner.find((s) => s.id === valgtId) ?? stasjoner[0]

  // Alle treff-rader for stasjonen (paginert — kan være >1000).
  const rader: TreffRad[] = []
  if (stasjon) {
    for (let side = 0; side < 20; side++) {
      const { data, error } = await supabase
        .from('prognose_treff').select('type, dato, kategori, forventet, faktisk, treff')
        .eq('stasjon_id', stasjon.id).order('dato').range(side * 1000, side * 1000 + 999)
        .overrideTypes<TreffRad[]>()
      if (error || !data || data.length === 0) break
      rader.push(...data)
      if (data.length < 1000) break
    }
  }
  const { data: kalRader } = stasjon
    ? await supabase.from('prognose_kalibrering').select('type, kategori, korreksjon, n').eq('stasjon_id', stasjon.id)
    : { data: [] }
  const kalibrering = new Map<string, { korreksjon: number; n: number }>()
  for (const k of (kalRader ?? []) as { type: string; kategori: string; korreksjon: number; n: number }[]) {
    kalibrering.set(`${k.type}|${k.kategori}`, { korreksjon: k.korreksjon, n: k.n })
  }

  // Aggreger pr type.
  function byggType(type: Type) {
    const total = rader.filter((r) => r.type === type && r.kategori === '*')
    const snitt = total.length ? Math.round(total.reduce((a, r) => a + r.treff, 0) / total.length) : null
    const dager = total.length
    const perKat = new Map<string, { treff: number[]; forventet: number; faktisk: number; n: number }>()
    for (const r of rader) {
      if (r.type !== type || r.kategori === '*') continue
      const v = perKat.get(r.kategori) ?? { treff: [], forventet: 0, faktisk: 0, n: 0 }
      v.treff.push(r.treff); v.forventet += r.forventet; v.faktisk += r.faktisk; v.n += 1
      perKat.set(r.kategori, v)
    }
    const kategorier = [...perKat.entries()].map(([kode, v]) => ({
      kode,
      treff: Math.round(v.treff.reduce((a, b) => a + b, 0) / v.treff.length),
      forventet: v.forventet / v.n, faktisk: v.faktisk / v.n,
      kal: kalibrering.get(`${type}|${kode}`) ?? null,
    })).sort((a, b) => a.treff - b.treff) // svakeste øverst (der det er mest å hente)
    return { snitt, dager, kategorier, trend: total }
  }
  const prod = byggType('produksjonsplan')
  const salg = byggType('salgsprognose')

  // Felles dags-trend (siste 21 dager) for begge.
  const trendMap = new Map<string, { prod?: number; salg?: number }>()
  for (const r of prod.trend) { const d = trendMap.get(r.dato) ?? {}; d.prod = r.treff; trendMap.set(r.dato, d) }
  for (const r of salg.trend) { const d = trendMap.get(r.dato) ?? {}; d.salg = r.treff; trendMap.set(r.dato, d) }
  const trendDager = [...trendMap.entries()].sort((a, b) => (a[0] < b[0] ? 1 : -1)).slice(0, 21)

  const harData = prod.snitt != null || salg.snitt != null

  const renderSeksjon = (tittel: string, type: Type, t: ReturnType<typeof byggType>, fmt: (n: number) => string) => {
    if (t.snitt == null) {
      return (
        <section className="kort">
          <h2>{tittel}</h2>
          <p className="undertittel">Ingen målte dager ennå. Kjør «Oppdater treffsikkerhet» — eller vent til nattjobben.</p>
        </section>
      )
    }
    return (
      <section className="kort">
        <div className="seksjon-topp">
          <h2>{tittel}</h2>
          <span className={`kpi-tall ${klasse(t.snitt)}`} style={{ fontSize: '1.6rem' }}>{t.snitt} %</span>
        </div>
        <p className="undertittel" style={{ marginBottom: '0.6rem' }}>Snitt treffsikkerhet over {t.dager} målte dager (forventet vs. faktisk).</p>
        <table className="tabell">
          <thead><tr><th>Kategori</th><th>Treff</th><th>Snitt forventet</th><th>Snitt faktisk</th><th>Selvlæring</th></tr></thead>
          <tbody>
            {t.kategorier.map((k) => (
              <tr key={k.kode}>
                <td>{katNavn(type, k.kode)}</td>
                <td><span className={`status-pip ${klasse(k.treff)}`}>{k.treff} %</span></td>
                <td>{fmt(Math.round(k.forventet))}</td>
                <td>{fmt(Math.round(k.faktisk))}</td>
                <td>
                  {k.kal ? (
                    <span className="undertittel" title={`Basert på ${k.kal.n} dager`}>
                      ×{k.kal.korreksjon.toFixed(2)} {k.kal.korreksjon > 1.02 ? '(løfter)' : k.kal.korreksjon < 0.98 ? '(demper)' : '(nøytral)'}
                    </span>
                  ) : <span className="undertittel">—</span>}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>
    )
  }

  // NIVÅ 1 — svaret. To prosenttall og den kategorien det er mest å hente
  // på. Uten den siste må leseren skanne to tabeller sortert stigende for
  // å finne det samme.
  const svakest = [
    ...prod.kategorier.map((k) => ({ ...k, type: 'produksjonsplan' as Type })),
    ...salg.kategorier.map((k) => ({ ...k, type: 'salgsprognose' as Type })),
  ].reduce<{ kode: string; treff: number; type: Type } | null>(
    (a, k) => (a == null || k.treff < a.treff ? k : a), null)

  const snittDeler: string[] = []
  if (prod.snitt != null) snittDeler.push(`produksjonsplanen ${prod.snitt} %`)
  if (salg.snitt != null) snittDeler.push(`salgsprognosen ${salg.snitt} %`)
  const maalteDager = Math.max(prod.dager, salg.dager)
  const svar = snittDeler.length === 0
    ? null
    : `Treffer ${snittDeler.join(' og ')}${maalteDager ? ` over ${maalteDager} målte dager` : ''}`
      + (svakest ? `. Svakest på ${katNavn(svakest.type, svakest.kode)} (${svakest.treff} %)` : '')

  return (
    <>
      <Sidehode
        tittel="Treffsikkerhet"
        undertittel={[
          svar
            ? `${svar}. Målt ved å kjøre motorene bakover på din egen historikk.`
            : 'Hvor godt traff prognosene faktisk salg? Målt ved å kjøre motorene bakover på din egen historikk («backtest»).',
          // HVILKEN STASJON GJELDER TALLENE? Sida sa det ikke - den
          // maalte en stasjon uten aa navngi den. Da kan brukeren
          // hverken stole paa tallet eller se at toppstripen er enig.
          stasjon ? `${stasjon.butikknummer} ${stasjon.navn}` : null,
        ].filter(Boolean).join(' · ')}
        handlinger={<Link href="/produksjonsplan" className="sq-knapp">Tilbake til planen</Link>}
      />

      {/* SKJEMAET ER BORTE. Det inneholdt bare en stasjonsvelger og en
          «Vis»-knapp - samme jobb som velgeren i toppstripen, med et
          annet svar. Ruta beholder `?butikknummer=` for delte lenker.

          Admin-knappen under staar igjen: den kjorer backtesten paa
          nytt, og har ingenting med stasjonsvalget aa gjore. */}
      <section className="kort">
        {bruker.rolle === 'retailer_admin' && (
          <div style={{ marginTop: '0.9rem' }}>
            <OppdaterKnapp />
            <p className="undertittel" style={{ marginTop: '0.4rem' }}>
              Kjører backtesten på nytt for alle dine stasjoner og oppdaterer selvlæringen. Skjer også automatisk hver natt.
            </p>
          </div>
        )}
      </section>

      {!harData ? (
        <Tomtilstand
          tittel="Ingen treffdata ennå for denne stasjonen"
          forklaring={bruker.rolle === 'retailer_admin'
            ? 'Backtesten kjører motorene bakover på stasjonens egen historikk og sammenligner med det som faktisk ble solgt. Trykk «Oppdater treffsikkerhet» over for å kjøre den første gang.'
            : 'Backtesten kjøres hver natt og sammenligner prognosene med det som faktisk ble solgt. Tallene kommer etter nattens kjøring.'}
        />
      ) : (
        <>
          <section className="nokkeltall">
            <div className="kpi">
              <span className={`kpi-tall ${prod.snitt != null ? klasse(prod.snitt) : ''}`}>{prod.snitt != null ? `${prod.snitt} %` : '—'}</span>
              <span className="kpi-merke">Produksjonsplan (antall)</span>
            </div>
            <div className="kpi">
              <span className={`kpi-tall ${salg.snitt != null ? klasse(salg.snitt) : ''}`}>{salg.snitt != null ? `${salg.snitt} %` : '—'}</span>
              <span className="kpi-merke">Salgsprognose (omsetning)</span>
            </div>
          </section>

          {renderSeksjon('Produksjonsplan', 'produksjonsplan', prod, (n) => tall.format(n))}
          {renderSeksjon('Salgsprognose', 'salgsprognose', salg, (n) => kr.format(n))}

          {trendDager.length > 0 && (
            <section className="kort">
              <h2>Dag for dag (siste {trendDager.length})</h2>
              <table className="tabell">
                <thead><tr><th>Dag</th><th>Produksjonsplan</th><th>Salgsprognose</th></tr></thead>
                <tbody>
                  {trendDager.map(([dato, v]) => (
                    <tr key={dato}>
                      <td>{datoLang.format(new Date(`${dato}T12:00:00Z`))}</td>
                      <td>{v.prod != null ? <span className={`status-pip ${klasse(v.prod)}`}>{v.prod} %</span> : '—'}</td>
                      <td>{v.salg != null ? <span className={`status-pip ${klasse(v.salg)}`}>{v.salg} %</span> : '—'}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </section>
          )}

          <Forklaring sporsmaal="Hva betyr selvlæring-kolonnen?">
            <p>
              Bommer prognosen systematisk på en kategori, lærer systemet en
              korreksjonsfaktor for den. Den ganges inn i framtidige forslag, og står
              i tabellen som «×1,12 (løfter)» eller «×0,91 (demper)».
            </p>
            <p>
              Faktoren er klemt mellom 0,6 og 1,6 og krever minst 8 målte dager bak
              seg. Begge deler for å hindre at noen få rare dager får lov til å dra
              prognosen langt av gårde. Den oppdateres hver natt, så treffsikkerheten
              skal stige over tid.
            </p>
            <p>
              Kategoriene står med svakeste treff øverst — det er der det er mest å
              hente, ikke der tallene er størst.
            </p>
          </Forklaring>
        </>
      )}
    </>
  )
}
