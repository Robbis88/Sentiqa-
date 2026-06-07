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

  const { data } = await supabase
    .from('regnskapslinjer')
    .select('seksjon, kode, post, sortering, regnskap, budsjett, avvik, index_pct')
    .eq('periode', siste.periode)
    .is('stasjon_id', null)
    .order('sortering', { ascending: true })
    .overrideTypes<Linje[]>()

  const linjer = data ?? []
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
