import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { kr, prosent, manedAar, avviksKlasse } from '@/lib/format'
import { hentRegnskapVarsler } from '@/lib/regnskap-varsler'
import { byggPeriodeGrupper } from '@/lib/perioder'
import { RegnskapButikksjef } from './butikksjef-visning'
import { RegnskapVarsler } from './varsler-liste'
import { StasjonsVelger } from '../stasjonsvelger'
import { PeriodeVelger } from '../periode-velger'

type Linje = {
  seksjon: string
  kode: string | null
  post: string
  sortering: number | null
  regnskap: number | null
  budsjett: number | null
  avvik: number | null
  index_pct: number | null
  regnskap_hittil?: number | null
  budsjett_hittil?: number | null
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

  // Periode: enkeltmåned (YYYY-MM) eller hittil i år (YYYY-hittil). År skilles.
  const valgt = sp.periode
  const ytdAar = valgt && /^\d{4}-hittil$/.test(valgt) ? valgt.slice(0, 4) : null
  const hittil = ytdAar != null
  let aktivPeriode: string
  let valgtVerdi: string
  if (hittil) {
    const iAaret = liste.filter((p) => p.slice(0, 4) === ytdAar).sort()
    aktivPeriode = iAaret[iAaret.length - 1] ?? liste[0] // siste mnd i året = full hittil-sum
    valgtVerdi = `${ytdAar}-hittil`
  } else {
    const valgtIso = valgt && /^\d{4}-\d{2}$/.test(valgt) ? `${valgt}-01` : null
    aktivPeriode = valgtIso && liste.includes(valgtIso) ? valgtIso : liste[0]
    valgtVerdi = aktivPeriode.slice(0, 7)
  }
  // Periodevindu: hittil = sum av månedene jan→valgt; måned = den ene måneden.
  const fra = hittil ? `${ytdAar}-01-01` : aktivPeriode
  const til = aktivPeriode

  // Admin kan bore ned i én stasjon (?stasjon=<uuid>), ellers «alle samlet».
  const erUuid = (s?: string) => !!s && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s)
  const valgtStasjon = erUuid(sp.stasjon) ? sp.stasjon! : null

  // Én funksjon summerer linjene over perioden (RLS-scopet). Vi filtrerer
  // cluster vs. per-stasjon i JS. Summerer månedene selv — så måned/år henger
  // sammen og per-stasjon-hittil ikke blir null (Azets fyller hittil kun cluster).
  type SumRad = { stasjon_id: string | null; seksjon: string; kode: string | null; post: string; sortering: number | null; regnskap: number | null; budsjett: number | null }
  const [{ data: alle }, { data: stasjoner }, varsler] = await Promise.all([
    supabase.rpc('regnskap_sum', { p_fra: fra, p_til: til }),
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null),
    bruker.retailerId ? hentRegnskapVarsler(supabase, bruker.retailerId, aktivPeriode).catch(() => []) : Promise.resolve([]),
  ])

  const medAvvik = <T extends { regnskap: number | null; budsjett: number | null }>(r: T) => ({
    ...r, avvik: (r.regnskap ?? 0) - (r.budsjett ?? 0),
    index_pct: r.budsjett ? (((r.regnskap ?? 0) - r.budsjett) / r.budsjett) * 100 : null,
  })
  const etterSort = (a: { sortering: number | null }, b: { sortering: number | null }) => (a.sortering ?? 9999) - (b.sortering ?? 9999)
  const rader = (alle ?? []) as SumRad[]
  const linjer: Linje[] = rader.filter((r) => r.stasjon_id == null).map(medAvvik).sort(etterSort)
  const stasjonLinjer: Linje[] | null = valgtStasjon ? rader.filter((r) => r.stasjon_id === valgtStasjon).map(medAvvik).sort(etterSort) : null
  const erStasjon = valgtStasjon != null && (stasjonLinjer?.length ?? 0) > 0
  const visLinjer = erStasjon ? (stasjonLinjer ?? []) : linjer

  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))

  // Per stasjon: omsetning + brutto («40 CR» om den finnes, ellers sum basis) +
  // driftskostnader (sum) → driftsresultat = brutto − drift. Viser hva HVER
  // stasjon faktisk tjener, ikke bare omsetning.
  const perStasjon = rader.filter((r) => r.stasjon_id != null)
  const sumSeksjon = (sid: string, seks: string, brukCR: boolean) => {
    const ls = perStasjon.filter((r) => r.stasjon_id === sid && r.seksjon === seks)
    const kilde = brukCR && ls.some((r) => r.kode === '40') ? ls.filter((r) => r.kode === '40') : ls.filter((r) => r.kode !== '40')
    return kilde.reduce((a, r) => a + (r.regnskap ?? 0), 0)
  }
  const stasjonsrader = [...new Set(perStasjon.map((r) => r.stasjon_id as string))]
    .filter((id) => navnFor.has(id))
    .map((id) => {
      const brutto = sumSeksjon(id, 'bruttofortjeneste', true)
      const drift = sumSeksjon(id, 'driftskostnader', false)
      return { navn: navnFor.get(id)!, regnskap: sumSeksjon(id, 'omsetning', true), brutto, resultat: brutto - drift }
    })
    .sort((a, b) => b.resultat - a.resultat)

  // Driftskostnader per konto, summert over alle stasjoner (samlet-visning).
  const kontoMap = new Map<string, { post: string; sortering: number; regnskap: number; budsjett: number }>()
  if (!valgtStasjon) {
    for (const r of perStasjon.filter((r) => r.seksjon === 'driftskostnader')) {
      const key = `${r.kode ?? ''}|${r.post}`
      const k = kontoMap.get(key) ?? { post: r.post, sortering: r.sortering ?? 9999, regnskap: 0, budsjett: 0 }
      k.regnskap += r.regnskap ?? 0
      k.budsjett += r.budsjett ?? 0
      kontoMap.set(key, k)
    }
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
  // To resultatlinjer i Azets-rapporten: «RESULTAT EX 9900» (før eierlønn 9900 —
  // det bedriften faktisk tjener) og «RESULTAT» (bunnlinjen, etter eierlønn).
  // Vi viser begge så det ikke ser ut som tap når eierlønnen er trukket fra.
  const resultatInkl = seksjon('resultat').find((l) => /^resultat$/i.test(l.post.trim()))
  const resultatEks = seksjon('resultat').find((l) => /9900/.test(l.post))

  const kpi = [
    { merke: 'Omsetning', l: omsetningTotalt },
    { merke: 'Bruttofortjeneste', l: brutto },
    ...(erStasjon ? [] : [
      ...(resultatEks ? [{ merke: 'Resultat eks. 9900', l: resultatEks }] : []),
      { merke: 'Resultat inkl. 9900', l: resultatInkl },
    ]),
  ]

  // Varsler: stasjonsvisning viser kun valgt stasjons varsler; ellers alle.
  const visVarsler = erStasjon ? varsler.filter((v) => v.omfang === valgtNavn) : varsler

  return (
    <>
      <h1>Regnskap</h1>
      <p className="undertittel">{hittil ? `Hittil i år ${ytdAar}` : manedAar.format(new Date(aktivPeriode))} · {erStasjon ? (valgtNavn ?? 'valgt stasjon') : 'hele clusteret'}</p>

      <div className="regnskap-velgere">
        {(stasjoner ?? []).length > 0 && (
          <StasjonsVelger
            stasjoner={[...(stasjoner ?? [])].sort((a, b) => a.butikknummer.localeCompare(b.butikknummer)).map((s) => ({ id: s.id, navn: `${s.butikknummer} ${s.navn}` }))}
            valgtId={erStasjon ? valgtStasjon : null}
            basePath="/regnskap"
            bevar={{ periode: valgtVerdi }}
          />
        )}
        <PeriodeVelger
          valgt={valgtVerdi}
          grupper={byggPeriodeGrupper(liste, true)}
          basePath="/regnskap"
          bevar={valgtStasjon ? { stasjon: valgtStasjon } : {}}
        />
      </div>

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
          <h2>Per stasjon</h2>
          <table className="tabell">
            <thead>
              <tr><th>Stasjon</th><th>Omsetning</th><th className="mob-skjul">Brutto</th><th>Driftsresultat</th></tr>
            </thead>
            <tbody>
              {stasjonsrader.map((s) => (
                <tr key={s.navn}>
                  <td>{s.navn}</td>
                  <td>{kr.format(s.regnskap)}</td>
                  <td className="mob-skjul">{kr.format(s.brutto)}</td>
                  <td><span className={`status-pip ${s.resultat >= 0 ? 'gronn' : 'rod'}`}>{kr.format(s.resultat)}</span></td>
                </tr>
              ))}
            </tbody>
          </table>
          <p className="undertittel" style={{ marginTop: '0.5rem' }}>Driftsresultat = bruttofortjeneste − driftskostnader per stasjon (før felleskostnader på selskapsnivå).</p>
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
