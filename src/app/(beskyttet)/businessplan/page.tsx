import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { husketStasjon } from '@/lib/stasjonskontekst'
import { stasjonFraUrl, tillatAlleFor } from '@/lib/stasjonsvalg'
import { kr, manedAar } from '@/lib/format'
import { Forklaring, Sidehode, Tomtilstand } from '@/components/ui/side'
import { delEtterKobling, sorterEtterAvvik, sumBakPlan } from '@/lib/regnskap/bp-dom'
import { BpAvdeling, type BpRad, type Abonnement } from './bp-rad'
import { Sideramme } from '@/components/ui/sideramme'

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
// ALL REGNING LIGGER I `v_bp_status_avdeling` (0113, rettet i 0114). Sida velger
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
    return <Sideramme><p>Kun eier og butikksjef har tilgang til businessplanen.</p></Sideramme>
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
      <Sideramme>
        <Sidehode tittel="Businessplan" undertittel="Ligger vi i rute?" />
        <Tomtilstand
          tittel="Ingen stasjon valgt"
          forklaring="Velg en butikk i toppstripen. «Bak plan» summert over flere butikker sier ingenting om hvor man skal gjøre noe."
        />
      </Sideramme>
    )
  }

  const { data: rader } = await supabase
    .from('v_bp_status_avdeling')
    .select('*')
    .eq('stasjon_id', stasjon)
    .in('periode_status', ['innevaerende', 'venter_regnskap'])
    .overrideTypes<(BpRad & { maned: string })[]>()

  const alle = rader ?? []

  // BILVASK HAR TO INNTEKTER, OG BARE DEN.
  //
  // En over kassa, og abonnementsvask som bare finnes i regnskapet.
  // Derfor sammenligner kortet to ulike inntektsgrunnlag for nettopp
  // den avdelingen: «Kassen, perfekt dag» ser bare kassa, «Regnskapet
  // viser» ser begge. I enhver annen avdeling er kassa et tak; her kan
  // regnskapet ligge over det uten at noe er galt.
  //
  // Vi HAR tallet for avlagte maaneder - regnskapets omsetning minus
  // kassas - saa kortet kan si det med kroner i stedet for aa be leseren
  // ta det paa tro. Se migrasjon 0160.
  const { data: aboRad } = await supabase
    .from('v_bilvask_abonnement')
    .select('aar, maaneder, kasse_kr, regnskap_kr, abonnement_kr, abonnement_pst')
    .eq('stasjon_id', stasjon)
    .order('aar', { ascending: false })
    .limit(1)
    .maybeSingle<Abonnement>()

  // Nyeste maaned foerst - den inneveaerende er den operative.
  const maned = alle.map((r) => r.maned).sort().reverse()[0]
  const iMnd = alle.filter((r) => r.maned === maned)

  // «INGEN BP» ER IKKE «I RUTE», OG DET STO DET NESTEN HER.
  //
  // Viewet gir en rad saa snart det finnes ENTEN budsjett ELLER salg for
  // en avdeling. En stasjon med salg og ingen businessplan gir derfor
  // fulle rader der `mot_bp_kr` er null hele veien - og da ble `sumBak`
  // null, og forsiden skrev «I rute mot planen».
  //
  // Det er den falske tryggheten hele sida finnes for aa hindre, snudd
  // mot brukeren: sterkest mulig formulering om at alt er bra, i
  // nøyaktig den situasjonen der ingenting er maalt.
  //
  // Funnet av CI, som har salg i seeden og aldri BP.
  const medDom = iMnd.filter((r) => r.mot_bp_kr != null)

  if (alle.length === 0 || medDom.length === 0) {
    return (
      <Sideramme>
        <Sidehode tittel="Businessplan" undertittel="Ligger vi i rute?" />
        <Tomtilstand
          tittel="Ingen businessplan for denne måneden"
          forklaring="Businessplanen lastes opp én gang i året og fordeles per måned og avdeling. Er den ikke lastet inn ennå, finnes det ingenting å måle mot."
          handling={<a className="sq-knapp" href="/import">Til import</a>}
        />
      </Sideramme>
    )
  }

  // NAVNET PAA STASJONEN. Uten det sa overskriften «28 400 kr bak plan
  // hittil i august» uten aa si HVEM - og da ser et stasjonsbytte ut som
  // ingenting. Robert meldte det som at velgeren ikke virket.
  const stasjonsnavnet = liste.find((s) => s.id === stasjon)
  const merke = stasjonsnavnet
    ? `${stasjonsnavnet.butikknummer} ${stasjonsnavnet.navn}`
    : ''

  // Ut av lista, ned i en fotnote - se `delEtterKobling`. Maalt i
  // produksjon: 0,12 % av budsjettet, og 146 kr salg uten plan.
  const { maalbare, umaaltBudsjett, salgUtenPlan } = delEtterKobling(iMnd)

  // DET SOM KREVER NOE STAAR OEVERST. Sortert paa kroner bak plan, ikke
  // alfabetisk og ikke paa stoerrelse: den avdelingen som mangler mest
  // mot planen er den hun bor se paa foerst.
  const sortert = sorterEtterAvvik(maalbare)

  // BARE DE NEGATIVE. Nettosummen ville sagt «vi er i rute» fordi
  // Tobakk gaar bra, mens Mat mangler 28 400.
  const sumBak = sumBakPlan(sortert)
  const bakPlan = sortert.filter((r) => (r.mot_bp_kr ?? 0) < 0)
  const verst = bakPlan[0]

  return (
    <Sideramme>
      <Sidehode
        tittel={sumBak < 0
          ? `${kr.format(Math.abs(Math.round(sumBak)))} bak plan hittil i ${manedAar.format(new Date(maned)).toLowerCase()}`
          : `I rute mot planen i ${manedAar.format(new Date(maned)).toLowerCase()}`}
        merke={merke}
        undertittel={verst
          ? `Størst avvik: ${verst.gruppe_navn ?? verst.gruppe_kode}. Businessplanen avgjør om vi er i rute — fjoråret forklarer utviklingen.`
          : 'Businessplanen avgjør om vi er i rute — fjoråret forklarer utviklingen.'}
      />

      <section className="bp-liste">
        {sortert.map((r) => (
          <BpAvdeling key={r.gruppe_kode} rad={r} abo={aboRad ?? null} />
        ))}
      </section>

      {/* FOTNOTEN, IKKE EN UTELATELSE. Kroner, ikke «noen linjer». Blir
          det som ikke kan måles en dag stort, vokser tallet her i stedet
          for å forsvinne - og det er hele forskjellen. */}
      {(umaaltBudsjett > 0 || salgUtenPlan > 0) && (
        <p className="undertittel sq-finstilt">
          {umaaltBudsjett > 0 && (
            <>
              {kr.format(Math.round(umaaltBudsjett))} av budsjettet måles
              ikke: koden finnes ikke i salgsdataene, så det finnes
              ingenting å sammenligne med.{' '}
            </>
          )}
          {salgUtenPlan > 0 && (
            <>
              {kr.format(Math.round(salgUtenPlan))} er solgt på avdelinger
              uten budsjett denne måneden.
            </>
          )}
        </p>
      )}

      <Forklaring sporsmaal="Hva er holdt utenfor, og hva måles mot hva?">
        <p>
          Drivstoff og pant, som i resten av lederanalysene: drivstoff
          betjener seg selv på pumpa og sier ingenting om hvordan
          butikken drives, og pant er gjennomgang uten margin.
        </p>
        <p>
          Omsetning måles mot omsetningsbudsjettet og brutto mot
          bruttobudsjettet — aldri på kryss. Fjoråret står ved siden av
          for å forklare utviklingen, men det er budsjettet som avgjør
          om stasjonen er i rute.
        </p>
        <p>
          Salget måles bare mot den delen av budsjettet som har rukket å
          bli målt: er det lastet opp 20 dager med salg, sammenliknes de
          med 20 dager av planen.
        </p>
      </Forklaring>
    </Sideramme>
  )
}
