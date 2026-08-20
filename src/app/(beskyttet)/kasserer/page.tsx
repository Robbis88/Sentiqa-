import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { kr, tall, datoLang } from '@/lib/format'
import Link from 'next/link'
import { Sidehode, Tomtilstand, Nokkeltall, Forklaring } from '@/components/ui/side'
import { husketStasjon } from '@/lib/stasjonskontekst'
import { stasjonFraUrl, tillatAlleFor } from '@/lib/stasjonsvalg'

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

export default async function KassererSide({ searchParams }: { searchParams: Promise<{ stasjon?: string }> }) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) {
    return <p>Du har ikke tilgang til kassererstatistikk.</p>
  }

  const sp = await searchParams

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
        <Sidehode tittel="Kasserer" undertittel="Avvik i kassa, per kasserer." />
        <Tomtilstand
          tittel="Ingen kassererdata ennå"
          forklaring="Last opp en CashierStatistics-fil under Import, så ser du retur, makulerte og slettede beløp per kasserer."
          handling={<Link href="/import" className="sq-knapp primar">Gå til Import</Link>}
        />
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

  const medData = (stasjoner ?? []).filter((s) => perStasjon.has(s.id))
  // Felles stasjonskontrakt (trinn 09): URL foran hukommelse foran
  // forste stasjon. `null` er «alle stasjoner samlet», og at sida taaler
  // det staar i rutetabellen - samme tabell appskallet leser.
  const sok = new URLSearchParams()
  if (sp.stasjon) sok.set('stasjon', sp.stasjon)
  const valgtStasjon = await husketStasjon(
    medData, stasjonFraUrl(sok, medData),
    tillatAlleFor('/kasserer', bruker.rolle, medData.length),
  )

  const erStasjon = valgtStasjon != null && perStasjon.has(valgtStasjon)
  const valgtNavn = erStasjon ? medData.find((s) => s.id === valgtStasjon)?.navn ?? null : null
  const vis = erStasjon ? medData.filter((s) => s.id === valgtStasjon) : medData

  // Nivaa 1: avvikene er grunnen til at siden finnes. De laa som tre av
  // seks kolonner, og maatte legges sammen i hodet for aa bety noe.
  const synlige = vis.flatMap((s2) => perStasjon.get(s2.id) ?? [])
  const omsetning = synlige.reduce((n, k) => n + (k.omsetning_ink_mva ?? 0), 0)
  const bonger = synlige.reduce((n, k) => n + (k.bonger ?? 0), 0)
  const avvik = synlige.reduce(
    (n, k) => n + (k.retur_belop ?? 0) + (k.makulerte_belop ?? 0) + (k.slettede_belop ?? 0), 0)

  return (
    <>
      <Sidehode
        tittel="Kasserer"
        undertittel={avvik === 0
          ? `Ingen retur, makulering eller sletting registrert. ${datoLang.format(new Date(siste.dato))} · ${erStasjon ? valgtNavn : 'alle stasjoner'}`
          : `${kr.format(avvik)} i retur, makulering og sletting. ${datoLang.format(new Date(siste.dato))} · ${erStasjon ? valgtNavn : 'alle stasjoner'}`}
      />

      <div className="sq-nokkelrad">
        <Nokkeltall merkelapp="Omsetning" verdi={kr.format(omsetning)} sammenlignet={`${tall.format(bonger)} bonger`} />
        <Nokkeltall
          merkelapp="Retur, makulert og slettet"
          verdi={kr.format(avvik)}
          sammenlignet={omsetning > 0 ? `${(avvik / omsetning * 100).toFixed(1)} % av omsetningen` : undefined}
          bra={omsetning > 0 ? avvik / omsetning < 0.02 : undefined}
        />
      </div>

      <Forklaring sporsmaal="Hva betyr makulert og slettet?">
        <strong>Retur</strong> er en vare kunden leverte tilbake.{' '}
        <strong>Makulert</strong> er en bong som ble annullert før betaling.{' '}
        <strong>Slettet</strong> er en linje som ble fjernet fra en bong underveis.
        Alle tre er normale i drift — det er nivået og fordelingen som er verdt
        et blikk, ikke enkelttilfellene.
      </Forklaring>

      {vis.map((s) => (
          <section key={s.id} style={{ marginBottom: '2rem' }}>
            <h2>{s.butikknummer} {s.navn}</h2>
            <div className="tabellramme">
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
            </div>
          </section>
        ))}
    </>
  )
}
