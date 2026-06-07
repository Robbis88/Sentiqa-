import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { kr, prosent, manedAar, avviksKlasse } from '@/lib/format'

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

export default async function RegnskapSide() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin') {
    return <p>Kun eier har tilgang til regnskap.</p>
  }

  const supabase = await lagSupabaseServerKlient()

  const { data: siste } = await supabase
    .from('regnskapslinjer')
    .select('periode')
    .is('stasjon_id', null)
    .order('periode', { ascending: false })
    .limit(1)
    .maybeSingle<{ periode: string }>()

  if (!siste) {
    return (
      <>
        <h1>Regnskap</h1>
        <p className="undertittel">
          Ingen regnskapsdata ennå. Last opp regnskapsrapporten under Import og trykk Behandle.
        </p>
      </>
    )
  }

  const [{ data }, { data: perStasjon }, { data: stasjoner }] = await Promise.all([
    supabase
      .from('regnskapslinjer')
      .select('seksjon, kode, post, sortering, regnskap, budsjett, avvik, index_pct')
      .eq('periode', siste.periode)
      .is('stasjon_id', null)
      .order('sortering', { ascending: true })
      .overrideTypes<Linje[]>(),
    supabase
      .from('regnskapslinjer')
      .select('stasjon_id, regnskap, budsjett')
      .eq('periode', siste.periode)
      .eq('seksjon', 'omsetning')
      .not('stasjon_id', 'is', null)
      .overrideTypes<{ stasjon_id: string; regnskap: number | null; budsjett: number | null }[]>(),
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null),
  ])

  const linjer = data ?? []

  // Aggreger omsetning per stasjon (basis-avdelinger → ren sum, ingen dobbelttelling)
  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))
  const perStasjonSum = new Map<string, { regnskap: number; budsjett: number }>()
  for (const r of perStasjon ?? []) {
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
  const seksjon = (navn: string) => linjer.filter((l) => l.seksjon === navn)
  const finn = (re: RegExp, s = 'omsetning') =>
    seksjon(s).find((l) => re.test(l.post))

  const omsetningTotalt = finn(/^omsetning totalt/i)
  const brutto = seksjon('bruttofortjeneste').find((l) => /^bruttofortjeneste/i.test(l.post))
  const resultat = seksjon('resultat').find((l) => /^resultat$/i.test(l.post))

  const kpi = [
    { merke: 'Omsetning', l: omsetningTotalt },
    { merke: 'Bruttofortjeneste', l: brutto },
    { merke: 'Resultat', l: resultat },
  ]

  return (
    <>
      <h1>Regnskap</h1>
      <p className="undertittel">{manedAar.format(new Date(siste.periode))} · hele clusteret</p>

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

      {stasjonsrader.length > 0 && (
        <section className="kort">
          <h2>Omsetning per stasjon</h2>
          <table className="tabell">
            <thead>
              <tr><th>Stasjon</th><th>Regnskap</th><th>Budsjett</th><th>Mot budsjett</th></tr>
            </thead>
            <tbody>
              {stasjonsrader.map((s) => (
                <tr key={s.navn}>
                  <td>{s.navn}</td>
                  <td>{kr.format(s.regnskap)}</td>
                  <td>{kr.format(s.budsjett)}</td>
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
                <th>Post</th><th>Regnskap</th><th>Budsjett</th><th>Avvik</th><th>Index</th>
              </tr>
            </thead>
            <tbody>
              {seksjon(navn).map((l, i) => {
                const visPip = navn !== 'driftskostnader' && l.index_pct != null && !/totalt$/i.test(l.post)
                return (
                  <tr key={i}>
                    <td>{l.post}</td>
                    <td>{kr.format(l.regnskap ?? 0)}</td>
                    <td>{kr.format(l.budsjett ?? 0)}</td>
                    <td>{kr.format(l.avvik ?? 0)}</td>
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
    </>
  )
}
