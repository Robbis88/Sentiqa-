import Link from 'next/link'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { AVDELINGER } from '@/lib/avdelinger'
import { AiKontekst } from '../ai-kontekst'
import { Sidehode, Tomtilstand, Nokkeltall, Datatabell, Forklaring } from '@/components/ui/side'
import { motNormalen, verdtEtBlikk } from '@/lib/salg/normalen'
import { husketStasjon } from '@/lib/stasjonskontekst'
import { lesDag } from '@/lib/periode'
import { hentDagvindu, sisteDag } from '@/lib/dagvindu'
import { Dagsvelger } from '@/components/ui/periode'
import { maanedenTil } from '@/lib/periode'
import { SKJUL_OMS_KODER } from '@/lib/avdelinger'
import { fordelBp, hittil, motpartFor, motpartsvindu, dageneI } from '@/lib/salg/bp-per-dag'
import { hentAlle } from '@/lib/supabase/sider'
import { hentForventet, erPrognosedag } from '@/lib/salg/forventet'
import { leggTilDager } from '@/lib/produksjonsplan'
import { iDag } from '@/lib/format'
import { stasjonFraUrl, tillatAlleFor } from '@/lib/stasjonsvalg'

const kr = new Intl.NumberFormat('nb-NO', {
  style: 'currency',
  currency: 'NOK',
  maximumFractionDigits: 0,
})
const tall = new Intl.NumberFormat('nb-NO', { maximumFractionDigits: 0 })
const datoFmt = new Intl.DateTimeFormat('nb-NO', { dateStyle: 'long', timeZone: 'Europe/Oslo' })

type StasjonRad = {
  stasjon_id: string
  omsetning: number
  antall: number
  mat_omsetning: number | null
}
type VaregruppeRad = { varegruppe_navn: string | null; omsetning: number; antall: number }

export default async function SalgSide({
  searchParams,
}: {
  searchParams: Promise<{ dato?: string; stasjon?: string }>
}) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) {
    return <p>Du har ikke tilgang til salgsoversikten.</p>
  }

  const supabase = await lagSupabaseServerKlient()
  const sp = await searchParams

  // Default: siste dato med data (RLS scoper til brukerens stasjoner).
  //
  // VALIDERINGEN LAA HER SOM `/^\d{4}-\d{2}-\d{2}$/`, og den godtok
  // `2026-13-45`. Videre nede blir datoen til en `Date` og trukket 56
  // dager - paa en ugyldig dato gir det `RangeError: Invalid time value`,
  // altsaa hvit side. `lesDag` gjor rundturen gjennom `Date` og faller
  // tilbake til siste dag med data i stedet.
  const siste = await sisteDag(supabase, 'v_salg_per_stasjon_dag')
  // I MORGEN, fra kalenderen - ikke fra siste salgsdag. Importen ligger
  // gjerne to dager bak, saa «dagen etter siste salgsdag» kan vaere en dag
  // som alt er forbi. Prognosen svarer for kalenderens i morgen, og det
  // er den samme dagen /salgsprognose svarer for.
  const imorgen = leggTilDager(iDag(), 1)
  const dato = siste ? lesDag(sp, siste) : null

  if (!dato) {
    return (
      <>
        <Sidehode tittel="Salg" undertittel="Omsetning, kategorier og varegrupper." />
        <Tomtilstand
          tittel="Ingen salgsdata ennå"
          forklaring="Last opp en Salgsstatistikk-fil under Import og trykk Behandle, så fylles siden."
          handling={<Link href="/import" className="sq-knapp primar">Gå til Import</Link>}
        />
      </>
    )
  }

  const [{ data: stasjonRader }, { data: stasjoner }] = await Promise.all([
    supabase
      .from('v_salg_per_stasjon_dag')
      .select('stasjon_id, omsetning, antall, mat_omsetning')
      .eq('dato', dato)
      .overrideTypes<StasjonRad[]>(),
    supabase.from('stasjoner')
      .select('id, navn, butikknummer, stasjonstype, vaerfolsomhet, vaerfolsomhet_laert')
      .is('slettet_tid', null),
  ])

  // Aatte uker tilbake — nok til at fire like ukedager finnes selv om
  // noen dager mangler. 56 dager x 5 stasjoner er godt under
  const stasjonsliste = (stasjoner ?? []) as {
    id: string; navn: string; butikknummer: string
    stasjonstype: string; vaerfolsomhet: number | null; vaerfolsomhet_laert: number | null
  }[]
  // Stasjonen kommer fra den felles kontrakten (trinn 09): URL foran
  // hukommelse foran forste stasjon. Sida leste for bare `?stasjon=`, og
  // ignorerte dermed valget i toppstripen - skallet kunne vise en stasjon
  // mens tallene her gjaldt alle.
  //
  // `null` betyr fortsatt «alle stasjoner samlet», og at sida TAALER det
  // staar i rutetabellen. Den samme tabellen appskallet leser, saa
  // velgeren tilbyr «Alle stasjoner» noyaktig der den finnes.
  const sok = new URLSearchParams()
  if (sp.stasjon) sok.set('stasjon', sp.stasjon)
  const valgtStasjon = await husketStasjon(
    stasjonsliste, stasjonFraUrl(sok, stasjonsliste),
    tillatAlleFor('/salg', bruker.rolle, stasjonsliste.length),
  )

  // Dagene aa gaa til. Etter stasjonsvalget, fordi velgeren maa baere
  // `stasjon` videre - uten det bytter et datobytte stille stasjon.
  const vindu = await hentDagvindu(supabase, 'v_salg_per_stasjon_dag', dato)

  // PostgREST-taket paa tusen rader.
  const fraDato = new Date(`${dato}T12:00:00Z`)
  fraDato.setUTCDate(fraDato.getUTCDate() - 56)
  const { data: historikk } = await supabase
    .from('v_salg_per_stasjon_dag')
    .select('stasjon_id, dato, omsetning')
    .gte('dato', fraDato.toISOString().slice(0, 10))
    .lte('dato', dato)

  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))
  const rader = (stasjonRader ?? []).sort((a, b) => b.omsetning - a.omsetning)
  const erStasjon = valgtStasjon != null && navnFor.has(valgtStasjon)
  const valgtNavn = erStasjon ? navnFor.get(valgtStasjon!)! : null
  const valgtRad = erStasjon ? rader.find((r) => r.stasjon_id === valgtStasjon) ?? null : null

  // Salg per AVDELING (kategori) + topp VAREGRUPPER. Begge fra views som
  // aggregerer i databasen. Per stasjon → filtrer på stasjon_id; ellers kjede.
  const avdelingQ = supabase
    .from('v_salg_per_avdeling_dag')
    .select('avdeling_kode, avdeling_navn, omsetning, antall')
    .eq('dato', dato)
  const varegruppeQ = erStasjon
    ? supabase
        .from('v_salg_per_varegruppe_stasjon_dag')
        .select('varegruppe_navn, omsetning, antall')
        .eq('dato', dato)
        .eq('stasjon_id', valgtStasjon!)
        .order('omsetning', { ascending: false })
        .limit(10)
    : supabase
        .from('v_salg_per_varegruppe_dag')
        .select('varegruppe_navn, omsetning, antall')
        .eq('dato', dato)
        .order('omsetning', { ascending: false })
        .limit(10)
  if (erStasjon) avdelingQ.eq('stasjon_id', valgtStasjon!)

  // ---- BP PER DAG ------------------------------------------------
  //
  // Maanedens BP finnes per avdeling; fordelingen paa dagene skjer i
  // `fordelBp`, etter ukedagsmedianen i motpartsvinduet. Vinduet er IKKE
  // fjoraarets maaned - se kommentaren i bp-per-dag.ts.
  const maaned = maanedenTil(dato)
  const mpVindu = motpartsvindu(maaned)
  const maanedSlutt = dageneI(maaned).slice(-1)[0]

  const bpQ = supabase
    .from('regnskapslinjer')
    .select('kode, post, seksjon, budsjett')
    .eq('periode', maaned)
    .is('slettet_tid', null)
    .in('seksjon', ['omsetning', 'bp_omsetning'])
  const fjorDagQ = supabase
    .from('v_salg_per_avdeling_dag')
    .select('avdeling_kode, omsetning')
    .eq('dato', motpartFor(dato))
  if (erStasjon) {
    bpQ.eq('stasjon_id', valgtStasjon!)
    fjorDagQ.eq('stasjon_id', valgtStasjon!)
  }

  const [{ data: avdData }, { data: vgData }] = await Promise.all([
    avdelingQ.overrideTypes<{ avdeling_kode: string | null; avdeling_navn: string | null; omsetning: number | null; antall: number | null }[]>(),
    varegruppeQ.overrideTypes<VaregruppeRad[]>(),
  ])
  const varegrupper: VaregruppeRad[] = vgData ?? []

  // Vinduet og maaneden hentes SIDEVIS. En rad per (stasjon, dag,
  // avdeling) blir over tusen for hele kjeden, og PostgREST kutter i
  // stillhet - da ville medianen vaert regnet av et tilfeldig utvalg.
  const [{ data: bpData }, { data: fjorDagData }, fjorVindu, salgMnd] = await Promise.all([
    bpQ.overrideTypes<{ kode: string | null; post: string | null; seksjon: string; budsjett: number | null }[]>(),
    fjorDagQ.overrideTypes<{ avdeling_kode: string | null; omsetning: number | null }[]>(),
    hentAlle<{ dato: string; avdeling_kode: string | null; omsetning: number | null }>(
      () => {
        const q = supabase.from('v_salg_per_avdeling_dag')
          .select('dato, avdeling_kode, omsetning')
          .gte('dato', mpVindu.fra).lte('dato', mpVindu.til).order('dato')
        return erStasjon ? q.eq('stasjon_id', valgtStasjon!) : q
      }),
    hentAlle<{ dato: string; omsetning: number | null }>(
      () => {
        const q = supabase.from('v_salg_per_stasjon_dag')
          .select('dato, omsetning')
          .gte('dato', maaned).lte('dato', maanedSlutt).order('dato')
        return erStasjon ? q.eq('stasjon_id', valgtStasjon!) : q
      }),
  ])

  // Avdeling-rader er per (avdeling, stasjon) → summer per avdeling. Pen navn/ikon
  // fra AVDELINGER (St1-kontoplan), fallback til viewets avdeling_navn.
  const pentNavn = new Map(AVDELINGER.map((a) => [a.kode, a.navn]))
  const avdMap = new Map<string, { navn: string; omsetning: number; antall: number }>()
  for (const r of avdData ?? []) {
    const kode = r.avdeling_kode ?? ''
    const a = avdMap.get(kode) ?? { navn: pentNavn.get(kode) ?? r.avdeling_navn ?? kode, omsetning: 0, antall: 0 }
    a.omsetning += r.omsetning ?? 0
    a.antall += r.antall ?? 0
    avdMap.set(kode, a)
  }

  // Sammenligningen mot en vanlig ukedag. Per stasjon naar en er valgt,
  // ellers for kjeden samlet - historikken filtreres likt som tallet.
  const histRader = ((historikk ?? []) as { stasjon_id: string; dato: string; omsetning: number }[])
  const perDag = new Map<string, number>()
  for (const h of histRader) {
    if (erStasjon && h.stasjon_id !== valgtStasjon) continue
    perDag.set(h.dato, (perDag.get(h.dato) ?? 0) + Number(h.omsetning ?? 0))
  }

  const totalOms = rader.reduce((a, r) => a + r.omsetning, 0)

  // SAMMENLIGNINGER SOM FINNES I DATAENE, ikke oppfunnet.
  // Snittbong er omsetning delt paa antall - begge staar allerede i
  // raden. Matandelen likedan. Ingen av dem er et nytt tall; de er det
  // samme tallet sagt slik at det betyr noe.
  const visOms = erStasjon ? (valgtRad?.omsetning ?? 0) : totalOms
  // ---- BP: maanedens tall, og dagens andel av den ----------------
  //
  // Avlagt foerst, aapen som reserve - samme regel `v_bp_status_avdeling`
  // bruker tre steder. To sider som viser ulik BP for samme maaned er
  // verre enn en side som mangler den.
  //
  // DRIFT, pant og grand total er ute. De har ingen BP aa maales mot, og
  // en rad med tom BP-kolonne ser ut som manglende data.
  // De to seksjonene samles hver for seg, og avlagt velges naar den
  // finnes. Blandes de i samme sum, dobbelttelles en avlagt maaned.
  const bpAvlagt = new Map<string, number>()
  const bpAapen = new Map<string, number>()
  for (const r of bpData ?? []) {
    const kode = r.kode ?? ''
    if (!kode || SKJUL_OMS_KODER.has(kode)) continue
    const m = r.seksjon === 'omsetning' ? bpAvlagt : bpAapen
    m.set(kode, (m.get(kode) ?? 0) + (r.budsjett ?? 0))
  }
  const bpPerAvd = new Map<string, number>()
  for (const kode of new Set([...bpAvlagt.keys(), ...bpAapen.keys()])) {
    const v = bpAvlagt.get(kode) ?? bpAapen.get(kode) ?? 0
    if (v > 0) bpPerAvd.set(kode, v)
  }

  const fjorPerAvdDag = new Map<string, number>()
  for (const r of fjorDagData ?? []) {
    const kode = r.avdeling_kode ?? ''
    if (!kode || SKJUL_OMS_KODER.has(kode)) continue
    fjorPerAvdDag.set(kode, (fjorPerAvdDag.get(kode) ?? 0) + (r.omsetning ?? 0))
  }

  // Fordelingen regnes PER AVDELING, ikke ved aa dele stasjonens
  // dagsandel. Varm drikke topper paa hverdager og mat i helga - en
  // felles form ville flyttet penger mellom kategoriene.
  const bpDagPerAvd = new Map<string, number>()
  let bpDagSum = 0
  for (const [kode, bpMnd] of bpPerAvd) {
    const ifjor = fjorVindu
      .filter((r) => (r.avdeling_kode ?? '') === kode)
      .map((r) => ({ dato: r.dato, omsetning: r.omsetning ?? 0 }))
    const dag = fordelBp(maaned, bpMnd, ifjor).find((d) => d.dato === dato)
    if (dag) { bpDagPerAvd.set(kode, dag.bp); bpDagSum += dag.bp }
  }

  // Hittil: stasjonens egne dagstall mot BP og mot MOTPARTENE. Fjoraaret
  // hittil er ikke 1.-27. i fjor - samme antall dager er ikke samme
  // ukedager, og forskjellen var 3,4 prosentpoeng paa Dale.
  const bpMndSum = [...bpPerAvd.values()].reduce((a, b) => a + b, 0)
  const vinduPerDag = new Map<string, number>()
  for (const r of fjorVindu) {
    if (SKJUL_OMS_KODER.has(r.avdeling_kode ?? '')) continue
    vinduPerDag.set(r.dato, (vinduPerDag.get(r.dato) ?? 0) + (r.omsetning ?? 0))
  }
  const budsjettDager = fordelBp(maaned, bpMndSum,
    [...vinduPerDag].map(([d, o]) => ({ dato: d, omsetning: o })))
  const salgPerDag = new Map<string, number>()
  for (const r of salgMnd) {
    salgPerDag.set(r.dato, (salgPerDag.get(r.dato) ?? 0) + (r.omsetning ?? 0))
  }
  const hittilTall = hittil(budsjettDager, salgPerDag)

  // ---- FORVENTET: BARE FOR I MORGEN ------------------------------
  //
  // Prognosen bygger paa vaervarselet og trenden fram til siste
  // salgsdag. For en dag som har vaert ville den regnet med tall fra
  // ETTER dagen den skal forutsi - et etterpaaklokt anslag som ser ut
  // som en prognose. Da staar kolonnen heller tom.
  //
  // Den regnes PER STASJON, saa «alle stasjoner samlet» har ingen: et
  // snitt over kjeden ville skjult den ene som skiller seg ut. Samme
  // begrunnelse som /salgsprognose gir for aa ikke tilby «alle».
  const erPrognose = erPrognosedag(dato, iDag())
  const stasjonProfil = erStasjon ? stasjonsliste.find((s) => s.id === valgtStasjon) : undefined
  const forventet = stasjonProfil && vindu.siste
    ? await hentForventet(supabase, stasjonProfil, dato, vindu.siste)
    : null

  // RADENE ER UNIONEN AV DE FIRE KILDENE, ikke bare salget.
  //
  // Bygges lista av salget alene, staar tabellen tom paa prognosedagen -
  // og paa dagene importen ligger bak. Da forsvinner BP, fjoraaret og
  // prognosen akkurat den dagen de er det eneste vi har.
  //
  // Det var slik den var da jeg skrev den, og feilen viste seg foerst
  // naar man gikk til i morgen.
  const radKoder = new Set<string>([
    ...avdMap.keys(),
    ...bpDagPerAvd.keys(),
    ...fjorPerAvdDag.keys(),
    ...(forventet?.perAvdeling.keys() ?? []),
  ])
  const avdelinger = [...radKoder]
    .filter((kode) => kode && !SKJUL_OMS_KODER.has(kode))
    .map((kode) => ({
      kode,
      navn: avdMap.get(kode)?.navn ?? pentNavn.get(kode) ?? kode,
      omsetning: avdMap.get(kode)?.omsetning ?? 0,
      antall: avdMap.get(kode)?.antall ?? 0,
    }))
    // Salget sorterer naar det finnes; ellers budsjettet. Uten det andre
    // leddet ville prognosedagen faatt en tilfeldig rekkefolge.
    .sort((x, y) => (y.omsetning - x.omsetning)
      || ((bpDagPerAvd.get(y.kode) ?? 0) - (bpDagPerAvd.get(x.kode) ?? 0)))

  // «+4,9 %», ikke «+4.9 %». toFixed skriver engelsk uansett hvor den
  // staar, og hele systemet er norsk.
  const pstFmt = new Intl.NumberFormat('nb-NO', { minimumFractionDigits: 1, maximumFractionDigits: 1 })
  const pstTekst = (x: number) =>
    `${x >= 0 ? '+' : '−'}${pstFmt.format(Math.abs(x * 100))} %`

  const mot = motNormalen(
    dato,
    erStasjon ? (valgtRad?.omsetning ?? 0) : totalOms,
    [...perDag].map(([d, o]) => ({ dato: d, omsetning: o })),
  )

  return (
    <>
      <Sidehode
        tittel="Salg"
        undertittel={erPrognose
          ? `Prognose. ${datoFmt.format(new Date(dato))} · ${erStasjon ? valgtNavn : 'alle stasjoner samlet'}`
          : mot.tekst
          ? `${mot.tekst}. ${datoFmt.format(new Date(dato))} · ${erStasjon ? valgtNavn : 'alle stasjoner samlet'}`
          : `${datoFmt.format(new Date(dato))} · ${erStasjon ? valgtNavn : 'alle stasjoner samlet'}`}
        handlinger={<AiKontekst tekst="Forklar utviklingen" sporsmal="Forklar utviklingen i salget for denne stasjonen den siste tiden. Hva driver den?" />}
      />

      {/* TAKET ER SISTE SALGSDAG + 1, ikke siste salgsdag.
          Prognosen finnes for i morgen, og da skal man kunne gaa dit.
          Lenger fram finnes verken vaervarsel eller budsjettdekning vi
          vil staa for, saa der stopper det. */}
      <Dagsvelger
        dag={dato}
        forste={vindu.forste}
        siste={imorgen}
        forrige={vindu.forrige}
        neste={vindu.neste ?? (dato < imorgen ? leggTilDager(dato, 1) : null)}
        skjulte={{ stasjon: erStasjon ? valgtStasjon! : undefined }}
      />

      {/* TRE TALL BLE TO.
          «Antall solgt» sto som eget nokkeltall uten noe aa maales mot -
          femten tusen varer er hverken bra eller daarlig for man vet mot
          hva. Tallet er ikke borte: det staar naa som sammenligning paa
          omsetningen, der det svarer paa noe («snittbong»), og i
          kategoritabellen der det kan leses mot omsetningen per rad.

          «Stasjoner med salg» var ikke et resultat, det var en
          opplysning om datagrunnlaget. Den hoerer hjemme i Forklaring
          nederst, ikke i nivaa 1.

          RETNING OG DOM PEKER SAMME VEI HER - salg opp er bra - men de
          settes fortsatt hver for seg, saa /salg og /svinn bruker samme
          spraak selv om dommen faller motsatt. */}
      <div className="sq-nokkelrad">
        {/* PAA PROGNOSEDAGEN FINNES INGEN OMSETNING. Et nullkort med
            «−100 % mot en vanlig torsdag» ville vaert bokstavelig sant
            og fullstendig misvisende. */}
        {erPrognose ? (
          forventet && (
            <Nokkeltall
              merkelapp="Forventet omsetning"
              verdi={kr.format(forventet.total)}
              sammenlignet={bpDagSum > 0
                ? `${pstTekst(forventet.total / bpDagSum - 1)} mot BP for dagen`
                : undefined}
              retning={bpDagSum > 0 && forventet.total >= bpDagSum ? 'opp' : 'ned'}
              bra={bpDagSum > 0 ? forventet.total >= bpDagSum : undefined}
            />
          )
        ) : (
          <Nokkeltall
            merkelapp="Omsetning eks. mva"
            verdi={kr.format(erStasjon ? (valgtRad?.omsetning ?? 0) : totalOms)}
            sammenlignet={mot.tekst ?? undefined}
            retning={mot.avvikProsent > 0 ? 'opp' : mot.avvikProsent < 0 ? 'ned' : 'flat'}
            bra={verdtEtBlikk(mot) ? mot.avvikProsent > 0 : undefined}
          />
        )}
        {bpDagSum > 0 && (
          <Nokkeltall
            merkelapp="BP denne dagen"
            verdi={kr.format(bpDagSum)}
            sammenlignet={erPrognose
              ? 'måltall for i morgen'
              : `${visOms - bpDagSum >= 0 ? '+' : '−'}${kr.format(Math.abs(visOms - bpDagSum))} mot måltallet`}
            retning={erPrognose ? 'flat' : visOms >= bpDagSum ? 'opp' : 'ned'}
            bra={erPrognose ? undefined : visOms >= bpDagSum}
          />
        )}
        {hittilTall.dager > 0 && hittilTall.bp > 0 && (
          <Nokkeltall
            merkelapp="Hittil i måneden"
            verdi={kr.format(hittilTall.salg)}
            sammenlignet={`${pstTekst(hittilTall.salg / hittilTall.bp - 1)} mot BP · ${hittilTall.dager} dager`}
            retning={hittilTall.salg >= hittilTall.bp ? 'opp' : 'ned'}
            bra={hittilTall.salg >= hittilTall.bp}
          />
        )}
        {/* BEGGE SUMMENE I SAMME KORT. Prosenten alene tvinger leseren
            til aa hente aarets sum fra nabokortet - et nokkeltall skal
            vaere til aa lese alene. */}
        {hittilTall.dager > 0 && hittilTall.ifjor > 0 && (
          <Nokkeltall
            merkelapp="Hittil mot i fjor"
            verdi={pstTekst(hittilTall.salg / hittilTall.ifjor - 1)}
            sammenlignet={`${kr.format(hittilTall.ifjor)} → ${kr.format(hittilTall.salg)}`}
            retning={hittilTall.salg >= hittilTall.ifjor ? 'opp' : 'ned'}
            bra={hittilTall.salg >= hittilTall.ifjor}
          />
        )}
        {hittilTall.landing != null && bpMndSum > 0 && (
          <Nokkeltall
            merkelapp="Måneden lander på"
            verdi={kr.format(hittilTall.landing)}
            sammenlignet={`${pstTekst(hittilTall.landing / bpMndSum - 1)} mot BP på ${kr.format(bpMndSum)}`}
            retning={hittilTall.landing >= bpMndSum ? 'opp' : 'ned'}
            bra={hittilTall.landing >= bpMndSum}
          />
        )}
      </div>

      {/* Kortet rundt tabellen var en ramme, ikke et objekt. Datatabell
          gir overskrift, vannrett rulling og tom tilstand - de tre
          tingene hver handskrevne tabell maatte loese selv. */}
      {/* ANTALL OG ANDEL UT, FIRE KRONETALL INN.
          «Antall» og «andel» svarte paa spoersmaal ingen stilte: femten
          kioskvarer er hverken bra eller daarlig, og andelen sier bare
          at mat er stoerst - noe den er hver dag.

          Inn kom de to tallene en dag faktisk maales mot: hva vi gjorde
          i fjor, og hva budsjettet sa.

          «FORVENTET» HAR TALL BARE FOR I MORGEN. Prognosen bygger paa
          vaervarselet og trenden fram til siste salgsdag; for en dag som
          har vaert ville den regnet med tall fra ETTER dagen den skal
          forutsi. En tom celle er et aerligere svar enn et etterpaaklokt
          anslag som ser ut som en prognose.

          Og motsatt: paa prognosedagen er det SALG-kolonnen som staar
          tom. De to konkurrerer aldri om samme celle.

          DRIFT og pant er ute (SKJUL_OMS_KODER). De har ingen BP aa
          maales mot, og en rad med tom BP-kolonne ser ut som manglende
          data i stedet for en kode som ikke hoerer hjemme. */}
      <Datatabell tittel={`Per kategori${erStasjon ? ` · ${valgtNavn}` : ''}`} antall={avdelinger.length}>
          <thead>
            <tr>
              <th>Kategori</th><th>Salg</th><th>Forventet</th>
              <th>Salg i fjor</th><th>BP denne dagen</th>
            </tr>
          </thead>
          <tbody>
            {avdelinger.length === 0 ? (
              <tr><td colSpan={5} className="undertittel">
                {vindu.siste != null && dato > vindu.siste
                  ? 'Salgstallene for denne dagen er ikke importert ennå.'
                  : 'Ingen kategori-salg denne dagen.'}
              </td></tr>
            ) : avdelinger.map((a) => {
              const bpDag = bpDagPerAvd.get(a.kode)
              const forv = forventet?.perAvdeling.get(a.kode)
              return (
                <tr key={a.kode}>
                  <td>{a.navn}</td>
                  <td>{erPrognose ? '—' : kr.format(a.omsetning)}</td>
                  <td>{forv != null ? kr.format(forv) : '—'}</td>
                  <td>{kr.format(fjorPerAvdDag.get(a.kode) ?? 0)}</td>
                  <td>{bpDag != null ? kr.format(bpDag) : '—'}</td>
                </tr>
              )
            })}
          </tbody>
      </Datatabell>

      {!erStasjon && (
        <Datatabell tittel="Per stasjon" antall={rader.length}>
            <thead>
              <tr><th>Stasjon</th><th>Omsetning</th><th>Antall</th><th>Matsalg</th></tr>
            </thead>
            <tbody>
              {rader.map((r) => (
                <tr key={r.stasjon_id}>
                  <td><Link href={`/salg?dato=${dato}&stasjon=${r.stasjon_id}`}>{navnFor.get(r.stasjon_id) ?? '—'}</Link></td>
                  <td>{kr.format(r.omsetning)}</td>
                  <td>{tall.format(r.antall)}</td>
                  <td>{kr.format(r.mat_omsetning ?? 0)}</td>
                </tr>
              ))}
            </tbody>
        </Datatabell>
      )}

      <Datatabell tittel={`Topp varegrupper${erStasjon ? ` · ${valgtNavn}` : ''}`} antall={varegrupper.length}>
          <thead>
            <tr><th>Varegruppe</th><th>Omsetning</th><th>Antall</th></tr>
          </thead>
          <tbody>
            {varegrupper.length === 0 ? (
              <tr><td colSpan={3} className="undertittel">Ingen varegruppe-salg denne dagen.</td></tr>
            ) : varegrupper.map((v, i) => (
              <tr key={i}>
                <td>{v.varegruppe_navn ?? '—'}</td>
                <td>{kr.format(v.omsetning)}</td>
                <td>{tall.format(v.antall)}</td>
              </tr>
            ))}
          </tbody>
      </Datatabell>
      {/* NIVAA 4: grunnlaget. «Stasjoner med salg» sto som nokkeltall -
          det er en opplysning om datagrunnlaget, ikke et resultat, og
          hoerer hjemme her. */}
      <Forklaring sporsmaal="Hva er tallene regnet på?">
        <p>
          {tall.format(rader.length)} {rader.length === 1 ? 'stasjon' : 'stasjoner'} hadde
          salg {datoFmt.format(new Date(dato))}. Omsetningen er eks. mva, og drivstoff
          er holdt utenfor: det betjener seg selv paa pumpa og hoerer ikke med naar
          butikkens tall skal leses.
        </p>
        <p>
          Sammenligningen er mot MEDIANEN for samme ukedag aatte uker tilbake, ikke mot
          snittet. En 17. mai eller en dag med veiarbeid utenfor drar snittet nok til at
          «normalen» blir noe som aldri har skjedd.
        </p>
        <p>
          <strong>BP denne dagen</strong> er maanedens budsjett fordelt paa dagene etter
          medianen for ukedagen i fjor. Hver dag peker 364 dager tilbake — 52 uker, saa
          soendag alltid treffer soendag — og dagene summerer til maanedens BP paa krona.
          Fordelingen skjer per kategori: varm drikke topper paa hverdager og mat i helga,
          saa en felles form ville flyttet penger mellom dem.
        </p>
        <p>
          Medianen, ikke fjoraarets enkeltdag. Var stasjonen stengt en loerdag i fjor, skal
          ikke maaltallet for den loerdagen i aar arve det. <strong>Salg i fjor</strong> viser
          derimot den ekte dagen: budsjettet er et maal og skal taale at fjoraaret var i
          stykker, fjoraaret er et faktum og skal vise hva som skjedde.
        </p>
        <p>
          <strong>Hittil mot i fjor</strong> maaler de dagene som har vaert mot MOTPARTENE
          deres, ikke mot den 1. til den samme datoen i fjor. Samme antall dager er ikke
          samme ukedager, og forskjellen er flere prosentpoeng.
        </p>
      </Forklaring>

    </>
  )
}
