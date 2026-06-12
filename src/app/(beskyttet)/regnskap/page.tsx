import Link from 'next/link'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { kr, prosent, manedAar, avviksKlasse } from '@/lib/format'
import { hentRegnskapVarsler } from '@/lib/regnskap-varsler'
import { RegnskapButikksjef } from './butikksjef-visning'
import { RegnskapVarsler } from './varsler-liste'

type Linje = {
  seksjon: string
  kode: string | null
  post: string
  sortering: number | null
  regnskap: number | null
  budsjett: number | null
  avvik: number | null
  index_pct: number | null
}

const SEKSJON_TITTEL: Record<string, string> = {
  omsetning: 'Omsetning',
  bruttofortjeneste: 'Bruttofortjeneste',
  driftskostnader: 'Driftskostnader',
  resultat: 'Resultat',
}

export default async function RegnskapSide({ searchParams }: { searchParams: Promise<{ periode?: string; butikknummer?: string; stasjon?: string }> }) {
  const bruker = await hentInnloggetBruker()
  const sp = await searchParams

  // Butikksjef får en skjermet visning av EGEN stasjon (kun påvirkbare kostnader).
  if (bruker.rolle === 'butikksjef') {
    return <RegnskapButikksjef bruker={bruker} periode={sp.periode} butikknummer={sp.butikknummer} />
  }
  if (bruker.rolle !== 'retailer_admin') {
    return <p>Kun eier/butikksjef har tilgang til regnskap.</p>
  }

  const supabase = await lagSupabaseServerKlient()

  // Alle perioder (rød tråd) — velg via ?periode=YYYY-MM, ellers siste.
  const { data: perioder } = await supabase
    .from('regnskapslinjer').select('periode').is('stasjon_id', null).order('periode', { ascending: false })
    .overrideTypes<{ periode: string }[]>()
  const liste = [...new Set((perioder ?? []).map((p) => p.periode))]

  if (liste.length === 0) {
    return (
      <>
        <h1>Regnskap</h1>
        <p className="undertittel">
          Ingen regnskapsdata ennå. Last opp regnskapsrapporten under Import og trykk Behandle.
        </p>
      </>
    )
  }

  const valgt = sp.periode
  const valgtIso = valgt ? `${valgt}-01` : null
  const aktivPeriode = valgtIso && liste.includes(valgtIso) ? valgtIso : liste[0]

  // Admin kan bore ned i én stasjon (?stasjon=<uuid>), ellers «alle samlet».
  const erUuid = (s?: string) => !!s && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s)
  const valgtStasjon = erUuid(sp.stasjon) ? sp.stasjon! : null

  const [{ data }, { data: perStasjon }, { data: stasjoner }, varsler, { data: stasjonLinjer }, { data: driftRader }] = await Promise.all([
    supabase
      .from('regnskapslinjer')
      .select('seksjon, kode, post, sortering, regnskap, budsjett, avvik, index_pct')
      .eq('periode', aktivPeriode)
      .is('stasjon_id', null)
      .order('sortering', { ascending: true })
      .overrideTypes<Linje[]>(),
    supabase
      .from('regnskapslinjer')
      .select('stasjon_id, kode, regnskap, budsjett')
      .eq('periode', aktivPeriode)
      .eq('seksjon', 'omsetning')
      .not('stasjon_id', 'is', null)
      .overrideTypes<{ stasjon_id: string; kode: string | null; regnskap: number | null; budsjett: number | null }[]>(),
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null),
    bruker.retailerId
      ? hentRegnskapVarsler(supabase, bruker.retailerId, aktivPeriode).catch(() => [])
      : Promise.resolve([]),
    valgtStasjon
      ? supabase
          .from('regnskapslinjer')
          .select('seksjon, kode, post, sortering, regnskap, budsjett, avvik, index_pct')
          .eq('periode', aktivPeriode)
          .eq('stasjon_id', valgtStasjon)
          .order('sortering', { ascending: true })
          .overrideTypes<Linje[]>()
      : Promise.resolve({ data: null as Linje[] | null }),
    // Samlet-visning: per-konto driftskostnader summert på tvers av stasjonene
    // (cluster-linjene er kun aggregerte totaler — dette gir full kontodetalj).
    valgtStasjon
      ? Promise.resolve({ data: null as { kode: string | null; post: string; sortering: number | null; regnskap: number | null; budsjett: number | null }[] | null })
      : supabase
          .from('regnskapslinjer')
          .select('kode, post, sortering, regnskap, budsjett')
          .eq('periode', aktivPeriode)
          .eq('seksjon', 'driftskostnader')
          .not('stasjon_id', 'is', null)
          .overrideTypes<{ kode: string | null; post: string; sortering: number | null; regnskap: number | null; budsjett: number | null }[]>(),
  ])

  const linjer = data ?? []
  // Aktiv visning: valgt stasjon (hvis den har data) ellers hele clusteret.
  const erStasjon = valgtStasjon != null && (stasjonLinjer?.length ?? 0) > 0
  const visLinjer = erStasjon ? (stasjonLinjer ?? []) : linjer

  // Aggreger omsetning per stasjon (basis-avdelinger → ren sum, ingen dobbelttelling)
  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))
  // «40 CR» er stasjonens total-linje (= sum av avdelingene). Bruk den når den
  // finnes, ellers sum av basis-avdelingene — aldri begge (unngå dobbelttelling).
  const omsRader = perStasjon ?? []
  const harCR = omsRader.some((r) => r.kode === '40')
  const kilde = harCR ? omsRader.filter((r) => r.kode === '40') : omsRader.filter((r) => r.kode !== '40')
  const perStasjonSum = new Map<string, { regnskap: number; budsjett: number }>()
  for (const r of kilde) {
    const p = perStasjonSum.get(r.stasjon_id) ?? { regnskap: 0, budsjett: 0 }
    p.regnskap += r.regnskap ?? 0
    p.budsjett += r.budsjett ?? 0
    perStasjonSum.set(r.stasjon_id, p)
  }
  const stasjonsrader = [...perStasjonSum.entries()]
    .filter(([id]) => navnFor.has(id))
    .map(([id, p]) => ({
      navn: navnFor.get(id)!,
      ...p,
      index: p.budsjett ? ((p.regnskap - p.budsjett) / p.budsjett) * 100 : 0,
    }))
    .sort((a, b) => b.regnskap - a.regnskap)

  // Driftskostnader per konto, summert over alle stasjoner (samlet-visning).
  const kontoMap = new Map<string, { post: string; sortering: number; regnskap: number; budsjett: number }>()
  for (const r of driftRader ?? []) {
    const key = `${r.kode ?? ''}|${r.post}`
    const k = kontoMap.get(key) ?? { post: r.post, sortering: r.sortering ?? 9999, regnskap: 0, budsjett: 0 }
    k.regnskap += r.regnskap ?? 0
    k.budsjett += r.budsjett ?? 0
    kontoMap.set(key, k)
  }
  const kostnadPerKonto = [...kontoMap.values()]
    .map((k) => ({ ...k, avvik: k.regnskap - k.budsjett, index: k.budsjett ? ((k.regnskap - k.budsjett) / k.budsjett) * 100 : null }))
    .sort((a, b) => a.sortering - b.sortering || b.regnskap - a.regnskap)

  const valgtNavn = valgtStasjon ? navnFor.get(valgtStasjon) ?? null : null
  const seksjon = (navn: string) => visLinjer.filter((l) => l.seksjon === navn)

  // KPI: cluster bruker navngitte totaler; stasjon bruker «40 CR»-linja.
  // Per stasjon finnes ingen «Resultat»-linje (kun cluster) → utelat den.
  const omsetningTotalt = erStasjon
    ? seksjon('omsetning').find((l) => l.kode === '40')
    : seksjon('omsetning').find((l) => /^omsetning totalt/i.test(l.post))
  const brutto = erStasjon
    ? seksjon('bruttofortjeneste').find((l) => l.kode === '40')
    : seksjon('bruttofortjeneste').find((l) => /^bruttofortjeneste/i.test(l.post))
  const resultat = seksjon('resultat').find((l) => /^resultat$/i.test(l.post))

  const kpi = [
    { merke: 'Omsetning', l: omsetningTotalt },
    { merke: 'Bruttofortjeneste', l: brutto },
    ...(erStasjon ? [] : [{ merke: 'Resultat', l: resultat }]),
  ]

  // Varsler: stasjonsvisning viser kun valgt stasjons varsler; ellers alle.
  const visVarsler = erStasjon ? varsler.filter((v) => v.omfang === valgtNavn) : varsler

  return (
    <>
      <h1>Regnskap</h1>
      <p className="undertittel">{manedAar.format(new Date(aktivPeriode))} · {erStasjon ? (valgtNavn ?? 'valgt stasjon') : 'hele clusteret'}</p>

      {(stasjoner ?? []).length > 0 && (
        <nav className="periode-trad" aria-label="Velg stasjon">
          <Link href={`/regnskap?periode=${aktivPeriode.slice(0, 7)}`} className={`periode-chip ${!erStasjon ? 'aktiv' : ''}`} aria-current={!erStasjon ? 'page' : undefined}>
            Alle samlet
          </Link>
          {[...(stasjoner ?? [])]
            .sort((a, b) => a.butikknummer.localeCompare(b.butikknummer))
            .map((s) => {
              const aktiv = s.id === valgtStasjon
              return (
                <Link key={s.id} href={`/regnskap?periode=${aktivPeriode.slice(0, 7)}&stasjon=${s.id}`} className={`periode-chip ${aktiv ? 'aktiv' : ''}`} aria-current={aktiv ? 'page' : undefined}>
                  {s.butikknummer} {s.navn}
                </Link>
              )
            })}
        </nav>
      )}

      {liste.length > 1 && (
        <nav className="periode-trad" aria-label="Tidligere regnskap">
          {liste.map((p) => {
            const ym = p.slice(0, 7)
            const aktiv = p === aktivPeriode
            return (
              <Link key={p} href={`/regnskap?periode=${ym}${valgtStasjon ? `&stasjon=${valgtStasjon}` : ''}`} className={`periode-chip ${aktiv ? 'aktiv' : ''}`} aria-current={aktiv ? 'page' : undefined}>
                {manedAar.format(new Date(p))}
              </Link>
            )
          })}
        </nav>
      )}

      <section className="nokkeltall">
        {kpi.map(({ merke, l }) => (
          <div className="kpi" key={merke}>
            <span className="kpi-tall">{kr.format(l?.regnskap ?? 0)}</span>
            <span className="kpi-merke">
              {merke}
              {l?.budsjett ? ` · budsjett ${kr.format(l.budsjett)}` : ''}
            </span>
          </div>
        ))}
      </section>

      <RegnskapVarsler varsler={visVarsler} />

      {!erStasjon && stasjonsrader.length > 0 && (
        <section className="kort">
          <h2>Omsetning per stasjon</h2>
          <table className="tabell">
            <thead>
              <tr><th>Stasjon</th><th>Regnskap</th><th className="mob-skjul">Budsjett</th><th>Mot budsjett</th></tr>
            </thead>
            <tbody>
              {stasjonsrader.map((s) => (
                <tr key={s.navn}>
                  <td>{s.navn}</td>
                  <td>{kr.format(s.regnskap)}</td>
                  <td className="mob-skjul">{kr.format(s.budsjett)}</td>
                  <td>
                    <span className={`status-pip ${avviksKlasse(s.index)}`}>
                      {prosent.format(s.index / 100)}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      )}

      {['omsetning', 'bruttofortjeneste', 'driftskostnader'].map((navn) => (
        <section className="kort" key={navn}>
          <h2>{SEKSJON_TITTEL[navn]}</h2>
          <table className="tabell">
            <thead>
              <tr>
                <th>Post</th><th>Regnskap</th><th className="mob-skjul">Budsjett</th><th className="mob-skjul">Avvik</th><th>Index</th>
              </tr>
            </thead>
            <tbody>
              {seksjon(navn).map((l, i) => {
                const visPip = navn !== 'driftskostnader' && l.index_pct != null && !/totalt$/i.test(l.post)
                return (
                  <tr key={i}>
                    <td>{l.post}</td>
                    <td>{kr.format(l.regnskap ?? 0)}</td>
                    <td className="mob-skjul">{kr.format(l.budsjett ?? 0)}</td>
                    <td className="mob-skjul">{kr.format(l.avvik ?? 0)}</td>
                    <td>
                      {visPip ? (
                        <span className={`status-pip ${avviksKlasse(l.index_pct!)}`}>
                          {prosent.format((l.index_pct ?? 0) / 100)}
                        </span>
                      ) : (
                        l.index_pct != null ? prosent.format((l.index_pct ?? 0) / 100) : '—'
                      )}
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </section>
      ))}

      {!erStasjon && kostnadPerKonto.length > 0 && (
        <section className="kort">
          <h2>Kostnader per konto · hele kjeden</h2>
          <p className="undertittel">Hver driftskostnad summert på tvers av alle stasjonene. Velg en stasjon over for å bryte ned per butikk.</p>
          <table className="tabell">
            <thead>
              <tr>
                <th>Konto</th><th>Regnskap</th><th className="mob-skjul">Budsjett</th><th className="mob-skjul">Avvik</th><th>Mot budsjett</th>
              </tr>
            </thead>
            <tbody>
              {kostnadPerKonto.map((k, i) => {
                // Kostnad: over budsjett = dårlig (rød), godt under = bra (grønn).
                const klasse = k.index == null ? '' : k.index > 5 ? 'rod' : k.index < -5 ? 'gronn' : 'gul'
                return (
                  <tr key={i}>
                    <td>{k.post}</td>
                    <td>{kr.format(k.regnskap)}</td>
                    <td className="mob-skjul">{kr.format(k.budsjett)}</td>
                    <td className="mob-skjul">{kr.format(k.avvik)}</td>
                    <td>
                      {k.index == null ? '—' : <span className={`status-pip ${klasse}`}>{prosent.format(k.index / 100)}</span>}
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </section>
      )}
    </>
  )
}
