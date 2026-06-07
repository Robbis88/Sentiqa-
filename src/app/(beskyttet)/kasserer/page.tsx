import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { kr, tall, datoLang } from '@/lib/format'

type Kasserer = {
  stasjon_id: string
  kasserer_nr: string
  kasserer_navn: string | null
  omsetning_ink_mva: number | null
  bonger: number | null
  retur_belop: number | null
  makulerte_belop: number | null
  slettede_belop: number | null
}

export default async function KassererSide() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin' && bruker.rolle !== 'butikksjef') {
    return <p>Du har ikke tilgang til kassererstatistikk.</p>
  }

  const supabase = await lagSupabaseServerKlient()
  const { data: siste } = await supabase
    .from('kassererstatistikk')
    .select('dato')
    .order('dato', { ascending: false })
    .limit(1)
    .maybeSingle<{ dato: string }>()

  if (!siste) {
    return (
      <>
        <h1>Kasserer</h1>
        <p className="undertittel">
          Ingen kassererdata ennå. Last opp en CashierStatistics-fil under Import.
        </p>
      </>
    )
  }

  const [{ data: rader }, { data: stasjoner }] = await Promise.all([
    supabase
      .from('kassererstatistikk')
      .select('stasjon_id, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger, retur_belop, makulerte_belop, slettede_belop')
      .eq('dato', siste.dato)
      .order('omsetning_ink_mva', { ascending: false })
      .overrideTypes<Kasserer[]>(),
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null).order('butikknummer'),
  ])

  const perStasjon = new Map<string, Kasserer[]>()
  for (const r of rader ?? []) {
    const liste = perStasjon.get(r.stasjon_id) ?? []
    liste.push(r)
    perStasjon.set(r.stasjon_id, liste)
  }

  return (
    <>
      <h1>Kasserer</h1>
      <p className="undertittel">{datoLang.format(new Date(siste.dato))}</p>

      {(stasjoner ?? [])
        .filter((s) => perStasjon.has(s.id))
        .map((s) => (
          <section className="kort" key={s.id}>
            <h2>{s.butikknummer} {s.navn}</h2>
            <table className="tabell">
              <thead>
                <tr>
                  <th>Kasserer</th><th>Omsetning</th><th>Bonger</th>
                  <th>Retur</th><th>Makulert</th><th>Slettet</th>
                </tr>
              </thead>
              <tbody>
                {(perStasjon.get(s.id) ?? []).map((k) => (
                  <tr key={k.kasserer_nr}>
                    <td>{k.kasserer_navn ?? k.kasserer_nr}</td>
                    <td>{kr.format(k.omsetning_ink_mva ?? 0)}</td>
                    <td>{tall.format(k.bonger ?? 0)}</td>
                    <td>{kr.format(k.retur_belop ?? 0)}</td>
                    <td>{kr.format(k.makulerte_belop ?? 0)}</td>
                    <td>{kr.format(k.slettede_belop ?? 0)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </section>
        ))}
    </>
  )
}
