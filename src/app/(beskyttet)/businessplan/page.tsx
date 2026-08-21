import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { husketStasjon } from '@/lib/stasjonskontekst'
import { stasjonFraUrl, tillatAlleFor } from '@/lib/stasjonsvalg'
import { kr, manedAar } from '@/lib/format'
import { Sidehode, Tomtilstand } from '@/components/ui/side'
import { sorterEtterAvvik, sumBakPlan } from '@/lib/regnskap/bp-dom'
import { BpAvdeling, type BpRad } from './bp-rad'

// =====================================================================
// «Ligger vi i rute mot businessplanen?»
//
// PRODUKTREGELEN, OG HELE GRUNNEN TIL AT SIDA FINNES:
//
//   BP avgjor om vi er i rute. Fjoraaret forklarer utviklingen.
//
// En stasjon kan ligge +8 % mot fjoraaret og samtidig vaere 70 000 bak
// planen. Timebudsjettet hun faar er bygget paa BP-en, ikke paa
// fjoraaret. `/salg` viser omsetning, `/regnskap` viser maaneden som er
// avsluttet - ingen av dem svarer paa spoersmaalet hun faktisk stiller
// midt i maaneden.
//
// NIVAAET ER AVDELING, OG DET ER BEVIST. Mappingen mot produksjonsdata
// ga ni SIKKER-treff, alle paa `avdeling_kode`. Vareomraade er tvetydig
// (kodene 10-14 gaar igjen i hver avdeling), og varegruppe har intet
// budsjett. Sida lover derfor ikke et finere nivaa enn dataene har.
//
// ALL REGNING LIGGER I `v_bp_status_avdeling` (0113). Sida velger
// rekkefolge og ord - den regner ikke. Da kan tallene bevises i SQL, der
// de faktisk bor, og skjermen kan ikke komme til aa si noe annet enn
// viewet.
// =====================================================================

export const dynamic = 'force-dynamic'

type Stasjon = { id: string; navn: string; butikknummer: string }

export default async function BusinessplanSide(
  { searchParams }: { searchParams: Promise<{ stasjon?: string; butikknummer?: string }> },
) {
  const bruker = await hentInnloggetBruker()
  // `erLeder` og ikke `rolle !== A && rolle !== B`: repoet har alt en
  // fasit for «eier eller butikksjef», og rollevakten leser kilden.
  // En femte skrivemaate for det samme er en form vakten ikke kjenner
  // - og en vakt som ikke forstaar det den ser, sier fra i stedet for
  // aa anta at alt er i orden. Den gjorde nettopp det.
  if (!erLeder(bruker.rolle)) {
    return <p>Kun eier og butikksjef har tilgang til businessplanen.</p>
  }

  const supabase = await lagSupabaseServerKlient()
  const sp = await searchParams

  const { data: mine } = await supabase
    .from('stasjoner').select('id, navn, butikknummer')
    .is('slettet_tid', null).order('butikknummer')
  const liste = (mine ?? []) as Stasjon[]

  // Samme stasjonskontekst som resten av systemet: URL foer hukommelse
  // foer det fornuftige. Sida taaler ikke aggregat - «bak plan» summert
  // over fem butikker sier ingenting om hvor man skal gjore noe.
  const sok = new URLSearchParams()
  if (sp.stasjon) sok.set('stasjon', sp.stasjon)
  if (sp.butikknummer) sok.set('butikknummer', sp.butikknummer)
  const stasjon = await husketStasjon(
    liste, stasjonFraUrl(sok, liste),
    tillatAlleFor('/businessplan', bruker.rolle, liste.length),
  )

  if (!stasjon) {
    return (
      <>
        <Sidehode tittel="Businessplan" undertittel="Ligger vi i rute?" />
        <Tomtilstand
          tittel="Ingen stasjon valgt"
          forklaring="Velg en butikk i toppstripen. «Bak plan» summert over flere butikker sier ingenting om hvor man skal gjøre noe."
        />
      </>
    )
  }

  const { data: rader } = await supabase
    .from('v_bp_status_avdeling')
    .select('*')
    .eq('stasjon_id', stasjon)
    .in('periode_status', ['innevaerende', 'venter_regnskap'])
    .overrideTypes<(BpRad & { maned: string })[]>()

  const alle = rader ?? []

  if (alle.length === 0) {
    return (
      <>
        <Sidehode tittel="Businessplan" undertittel="Ligger vi i rute?" />
        <Tomtilstand
          tittel="Ingen businessplan for denne måneden"
          forklaring="Businessplanen lastes opp én gang i året og fordeles per måned og avdeling. Er den ikke lastet inn ennå, finnes det ingenting å måle mot."
          handling={<a className="sq-knapp" href="/import">Til import</a>}
        />
      </>
    )
  }

  // Nyeste maaned foerst - den inneveaerende er den operative.
  const maned = alle.map((r) => r.maned).sort().reverse()[0]
  const iMnd = alle.filter((r) => r.maned === maned)

  // DET SOM KREVER NOE STAAR OEVERST. Sortert paa kroner bak plan, ikke
  // alfabetisk og ikke paa stoerrelse: den avdelingen som mangler mest
  // mot planen er den hun bor se paa foerst.
  const sortert = sorterEtterAvvik(iMnd)

  // BARE DE NEGATIVE. Nettosummen ville sagt «vi er i rute» fordi
  // Tobakk gaar bra, mens Mat mangler 28 400.
  const sumBak = sumBakPlan(sortert)
  const bakPlan = sortert.filter((r) => (r.mot_bp_kr ?? 0) < 0)
  const verst = bakPlan[0]

  return (
    <>
      <Sidehode
        tittel={sumBak < 0
          ? `${kr.format(Math.abs(Math.round(sumBak)))} bak plan hittil i ${manedAar.format(new Date(maned)).toLowerCase()}`
          : `I rute mot planen i ${manedAar.format(new Date(maned)).toLowerCase()}`}
        undertittel={verst
          ? `Størst avvik: ${verst.gruppe_navn ?? verst.gruppe_kode}. Businessplanen avgjør om vi er i rute — fjoråret forklarer utviklingen.`
          : 'Businessplanen avgjør om vi er i rute — fjoråret forklarer utviklingen.'}
      />

      <section className="bp-liste">
        {sortert.map((r) => (
          <BpAvdeling key={r.gruppe_kode} rad={r} />
        ))}
      </section>

      <p className="undertittel sq-finstilt">
        Drivstoff og pant er holdt utenfor, som i resten av
        lederanalysene: drivstoff betjener seg selv på pumpa, og pant er
        gjennomgang uten margin.
      </p>
    </>
  )
}
