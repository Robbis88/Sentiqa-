import Link from 'next/link'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { datoLang, iDag } from '@/lib/format'
import { lagProduksjonsplan, leggTilDager, produksjonsdag, produksjonsreferanse, medMargin, startAntall, effektivProsent, STANDARD_KODE, type PlanForklaring, type SalgsPunkt, type Vaerdag } from '@/lib/produksjonsplan'
import { hentProduksjonskoder, IKKE_KONFIGURERT_TEKST } from '@/lib/produksjonskoder'
import { hentKalibreringDetaljer } from '@/lib/backtest'
import { hentVaerKoeff } from '@/lib/vaerprofil'
import { erHelligdag, fjorHelligdag, helligdagNavn } from '@/lib/helligdager'
import { PlanTabell, type Gruppe, type Produkt } from './plan-tabell'
import { TabletPlan, type TabletGruppe } from './tablet-plan'
import { TabletMorgendag } from './tablet-morgendag'
import { TabletHode } from '../tablet-hode'
import { Sidehode, Tomtilstand, Forklaring } from '@/components/ui/side'
import { husketStasjon } from '@/lib/stasjonskontekst'
import { hentPerDato, maaVaereHele } from '@/lib/supabase/datobolker'
import { stasjonFraUrl } from '@/lib/stasjonsvalg'
import { Signal } from '@/components/ui/status'
import { Felt } from '@/components/ui/felt'
import { Knapp } from '@/components/ui/knapp'
import { Sideramme } from '@/components/ui/sideramme'

// =====================================================================
// Pilot C: arbeidsflytmonsteret paa primitivene.
//
// Tredje monster, tredje pilot. Liste (A) og analyse (B) er gjort; dette
// er sida monsterkartet selv bruker som eksempel paa fella - «viser
// beregningen for anbefalingen».
//
// NIVAA 1 OG 4 VAR ALLEREDE PAA PLASS fra redesignrunden: svaret staar i
// sidehodet (publisert eller utkast), og metoden ligger i Forklaring
// nederst. Det som stod igjen er nivaa 2 og 3:
//
//   NIVAA 2 - neste steg. «Publiser til tableten» laa som en NAKEN
//   <button> nederst paa sida, etter alle varegruppene, ved siden av et
//   notatfelt uten etikett. Handlingen hele sida sikter mot var den
//   eneste knappen uten variant.
//
//   NIVAA 3 - hva systemet foreslaar, og hvorfor. Advarslene laa som en
//   punktliste i et kort. De er signaler, og det finnes et primitiv for
//   signaler.
//
// SPORRINGENE OG MOTOREN ER URORT, som i pilot A og B. `lagProduksjonsplan`,
// kalibreringen, vaerkoeffisientene og alle tre serverhandlingene er ikke
// tatt i.
// =====================================================================

// Paginert henting av et helt års salg kan ta litt — gi handlingen tid.
export const maxDuration = 60

const UKEDAG = ['søndag', 'mandag', 'tirsdag', 'onsdag', 'torsdag', 'fredag', 'lørdag']

type SalgRad = { varenavn: string | null; varegruppe_kode: string | null; varegruppe_navn: string | null; antall: number | null; dato: string }

export default async function ProduksjonsplanSide({
  searchParams,
}: {
  searchParams: Promise<{ butikknummer?: string; dato?: string }>
}) {
  const bruker = await hentInnloggetBruker()
  const supabase = await lagSupabaseServerKlient()

  // Tablet: ansatte ser den publiserte planen for i dag og logger «lagd hittil».
  if (bruker.rolle === 'butikkbruker_tablet') {
    const idag = iDag()
    const { data: st } = await supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null).limit(1).maybeSingle<{ id: string; navn: string; butikknummer: string }>()
    if (!st) return <section className="tablet-seksjon"><h2>Produksjon</h2><p>Ingen stasjon.</p></section>
    // ===============================================================
    // I MORGEN HENTES VED SIDEN AV I DAG
    // ===============================================================
    //
    // Startpartiet skal vaere ferdig naar doera aapner (`0149`), saa
    // noe maa tas opp kvelden foer. Fram til naa kunne de ikke se hvor
    // mye foer dagen det gjaldt.
    //
    // BEGGE HENTES FOER NOEN TIDLIG RETUR. Her sto en `return` paa
    // manglende publisering for i dag - den ville skjult morgendagen
    // ogsaa, og da ville funksjonen vaert borte noeyaktig de dagene
    // ingen rakk aa publisere dagens plan.
    const imorgen = leggTilDager(idag, 1)
    const [hodeSvar, imorgenHodeSvar] = await Promise.all([
      supabase.from('produksjonsplan_hode').select('notat, publisert_tid').eq('stasjon_id', st.id).eq('dato', idag).maybeSingle<{ notat: string | null; publisert_tid: string | null }>(),
      supabase.from('produksjonsplan_hode').select('notat, publisert_tid').eq('stasjon_id', st.id).eq('dato', imorgen).maybeSingle<{ notat: string | null; publisert_tid: string | null }>(),
    ])
    const hode = hodeSvar.data
    const imorgenHode = imorgenHodeSvar.data

    // PUBLISERINGEN ER PORTEN, OGSAA FOR I MORGEN. Et upublisert utkast
    // er tall butikksjefen fortsatt kan endre; aa vise dem ville bedt
    // noen ta opp et antall som ikke gjelder.
    const visIdag = Boolean(hode?.publisert_tid)
    const visImorgen = Boolean(imorgenHode?.publisert_tid)

    if (!visIdag && !visImorgen) {
      return <section className="tablet-seksjon"><h2>Produksjon</h2><p>Ingen produksjonsplan publisert.</p></section>
    }

    // Samme spoerring for begge dagene. Var den skrevet to ganger, ville
    // filtrene - `ekskludert`, `planlagt > 0` - kunnet skille lag, og da
    // ville de to listene vist ulike produkter uten at noe sa fra.
    const hentGrupper = async (d: string): Promise<TabletGruppe[]> => {
      const { data: linjer } = await supabase
        .from('produksjonsplan_linjer').select('varenavn, varegruppe_navn, planlagt, start_antall, lagd_hittil')
        .eq('stasjon_id', st.id).eq('dato', d).eq('ekskludert', false).gt('planlagt', 0)
        .order('varegruppe_navn').overrideTypes<{ varenavn: string; varegruppe_navn: string | null; planlagt: number; start_antall: number; lagd_hittil: number }[]>()
      const m = new Map<string, TabletGruppe>()
      for (const l of linjer ?? []) {
        const navn = l.varegruppe_navn ?? 'Produksjon'
        let g = m.get(navn)
        if (!g) { g = { navn, produkter: [] }; m.set(navn, g) }
        g.produkter.push({ varenavn: l.varenavn, planlagt: l.planlagt, start_antall: l.start_antall, lagd_hittil: l.lagd_hittil })
      }
      return [...m.values()]
    }

    const [idagGrupper, imorgenGrupper] = await Promise.all([
      visIdag ? hentGrupper(idag) : Promise.resolve([]),
      visImorgen ? hentGrupper(imorgen) : Promise.resolve([]),
    ])
    const gmap = new Map(idagGrupper.map((g) => [g.navn, g]))
    // Hodet, og bare hodet. Planen under — stepperen, «lagd hittil»,
    // serverhandlingen som lagrer — er urørt: dette er en UX-bølge.
    const planlagt = [...gmap.values()].reduce((n, g) => n + g.produkter.reduce((m, pr) => m + pr.planlagt, 0), 0)
    const lagd = [...gmap.values()].reduce((n, g) => n + g.produkter.reduce((m, pr) => m + pr.lagd_hittil, 0), 0)
    return (
      <>
        {/* Sto som «Produksjon i dag» — et modulnavn, i en rå <h1> som
            var den eneste på nettbrettet uten `.tablet-hode` rundt seg.
            Nettbrettets hode skal bære SVARET, slik /rutiner og /ikmat
            gjør det: hvor mange igjen å lage. Tallene er summer av de
            samme linjene planen viser — ingen ny beregning.

            HODET GJELDER I DAG. Er dagens plan ikke publisert, staar det
            ingenting her - morgendagen faar ikke laane et hode som sier
            «igjen aa lage», for i morgen er ingenting lagd ennaa. */}
        {visIdag && (
          <>
            <TabletHode
              tittel={planlagt === 0 ? 'Ingen varer i dagens plan' : lagd >= planlagt ? 'Alt er lagd' : `${planlagt - lagd} igjen å lage`}
              undertittel={`${lagd} av ${planlagt} lagd`}
            />
            <TabletPlan stasjonId={st.id} dato={idag} notat={hode?.notat ?? null} grupper={[...gmap.values()]} />
          </>
        )}
        {/* MORGENDAGEN UNDER, OG LESEVISNING. Se `tablet-morgendag.tsx`:
            `loggLagd` sjekker aldri datoen, saa fravaeret av knapper er
            hele vernet. */}
        {visImorgen && (
          <TabletMorgendag dato={imorgen} notat={imorgenHode?.notat ?? null} grupper={imorgenGrupper} />
        )}
      </>
    )
  }

  if (!erLeder(bruker.rolle)) {
    return <Sideramme><p>Du har ikke tilgang til produksjonsplan.</p></Sideramme>
  }
  const sp = await searchParams

  const { data: alleStasjoner, error: stasjonFeil } = await supabase
    .from('stasjoner')
    .select('id, butikknummer, navn, stasjonstype, vaerfolsomhet, vaerfolsomhet_laert')
    .is('slettet_tid', null)
    .order('butikknummer')
    .limit(1000)
    .overrideTypes<{ id: string; butikknummer: string; navn: string; stasjonstype: string; vaerfolsomhet: number | null; vaerfolsomhet_laert: number | null }[]>()

  // Butikksjef låses til egne stasjoner (admin ser alle).
  let stasjoner = maaVaereHele({ data: alleStasjoner, error: stasjonFeil }, 'produksjonsstasjonene')
  if (bruker.rolle === 'butikksjef') {
    const tilgangSvar = await supabase.from('butikksjef_stasjoner').select('stasjon_id').eq('profil_id', bruker.id).limit(1000)
    const ids = new Set(maaVaereHele(tilgangSvar, 'produksjonstilgangen').map((t) => t.stasjon_id))
    stasjoner = stasjoner.filter((s) => ids.has(s.id))
  }

  // STASJONEN KOMMER FRA DEN DELTE KONTRAKTEN, ikke fra sidas eget valg.
  //
  // For hadde sida en egen stasjonsvelger paa `?butikknummer=`, mens
  // appskallet viste sitt eget huskede valg. De to visste ikke om
  // hverandre, og skjermen kunne si «5102 Grenseby» i toppen mens planen
  // under gjaldt 4177. Naa gaar begge gjennom `husketStasjon` med samme
  // URL og samme kapsel, i samme rekkefolge: URL foran hukommelse foran
  // forste stasjon.
  //
  // `?butikknummer=` BESTAAR. Delte lenker skal fortsatt lande riktig,
  // og `stasjonFraUrl` oversetter nummeret til en id slik at resten av
  // systemet slipper aa kjenne sidas parameternavn.
  //
  // Ingen `tillatAlle`: en produksjonsplan for alle stasjoner er ikke en
  // plan noen kan bake etter. Staar det huskede valget paa «alle», faller
  // det tilbake til forste stasjon - samme sted som appskallet lander.
  const sok = new URLSearchParams()
  if (sp.butikknummer) sok.set('butikknummer', sp.butikknummer)
  const valgtId = await husketStasjon(stasjoner, stasjonFraUrl(sok, stasjoner))
  const stasjon = stasjoner.find((s) => s.id === valgtId) ?? stasjoner[0]
  const valgtNr = stasjon?.butikknummer ?? ''

  const dato = produksjonsdag(sp.dato)
  const ukedag = new Date(dato).getUTCDay()

  let grupper: Gruppe[] = []
  let datadybde = 0
  // 0152: kjeden maa ha mappet varegruppene sine. Ingen mapping gir ikke en
  // tom plan, men en forklaring - en tom plan er en gyldig plan og ville
  // sett ut som «ingenting skal produseres i dag».
  let ikkeKonfigurert = false
  let vaer: Vaerdag | null = null
  let advarsler: string[] = []
  let hodeData: { notat: string | null; publisert_tid: string | null } | null = null
  // Driftsreglene (0149). Settes inne i planblokka, leses i JSX-en under.
  let prosent = { start: 0, margin: 0 }
  let gruppeAvvik: Record<string, { start: number | null; margin: number | null }> = {}
  let arrangementer: { id: string; navn: string; faktor: number }[] = []
  let planForklaring: PlanForklaring | null = null

  const oppsett = await hentProduksjonskoder(supabase)
  ikkeKonfigurert = oppsett.status === 'ikke_konfigurert'
  const KODER = oppsett.status === 'mappet' ? oppsett.koder : []

  if (stasjon && !ikkeKonfigurert) {
    // Siste dag med faktisk salg (ikke «i dag») — så manglende dager bakerst
    // ikke trekker snittet ned.
    const { data: sisteRad, error: sisteFeil } = await supabase
      .from('v_butikksalg').select('dato').eq('stasjon_id', stasjon.id).in('varegruppe_kode', KODER).is('slettet_tid', null)
      .lt('dato', dato)
      .order('dato', { ascending: false }).limit(1).maybeSingle<{ dato: string }>()
    if (sisteFeil) throw new Error(`Siste salgsdag kunne ikke hentes: ${sisteFeil.message}`)
    const sisteSalgsdato = sisteRad?.dato ?? leggTilDager(dato, -1)
    const referanse = produksjonsreferanse(dato, sisteSalgsdato)

    const [maalSvar, fjorSvar, linjeSvar, hodeSvar, innstillingSvar, arrangementSvar] = await Promise.all([
      supabase.from('vaer').select('temp_maks, nedbor_mm').eq('stasjon_id', stasjon.id).eq('dato', dato).maybeSingle<Vaerdag>(),
      supabase.from('vaer').select('temp_maks, nedbor_mm').eq('stasjon_id', stasjon.id).eq('dato', referanse.fjorDato).maybeSingle<Vaerdag>(),
      supabase.from('produksjonsplan_linjer').select('varenavn, planlagt, start_antall, ekskludert').eq('stasjon_id', stasjon.id).eq('dato', dato).limit(1000).overrideTypes<{ varenavn: string; planlagt: number; start_antall: number; ekskludert: boolean }[]>(),
      supabase.from('produksjonsplan_hode').select('notat, publisert_tid').eq('stasjon_id', stasjon.id).eq('dato', dato).maybeSingle<{ notat: string | null; publisert_tid: string | null }>(),
      supabase.from('stasjon_produksjon_innstilling').select('varegruppe_kode, start_prosent, margin_prosent').eq('stasjon_id', stasjon.id).limit(1000).overrideTypes<{ varegruppe_kode: string; start_prosent: number | null; margin_prosent: number | null }[]>(),
      // Kun BEKREFTEDE arrangementer løfter planen (forslag styres på /arrangementer).
      supabase.from('arrangementer').select('id, navn, faktor, stasjon_id').eq('dato', dato).neq('status', 'forslag').is('slettet_tid', null).limit(1000).overrideTypes<{ id: string; navn: string; faktor: number; stasjon_id: string | null }[]>(),
    ])
    for (const [navn, svar] of [['værvarselet', maalSvar], ['referanseværet', fjorSvar], ['planhodet', hodeSvar]] as const) {
      if (svar.error) throw new Error(`Kunne ikke hente ${navn}: ${svar.error.message}`)
    }
    const vMaal = maalSvar.data, vFjor = fjorSvar.data, hode = hodeSvar.data
    const lagrede = maaVaereHele(linjeSvar, 'lagrede produksjonslinjer')
    const avvik = maaVaereHele(innstillingSvar, 'produksjonsinnstillingene')
    const arr = maaVaereHele(arrangementSvar, 'arrangementene')

    // ===================================================================
    // ET HELT AAR MED SALG, I DATOBOLKER - IKKE I DYPE OFFSETS
    //
    // Her sto tolv sekvensielle sider med `.range(side * 1000, ...)`. Det
    // virket, men det var baade sekvensielt og kvadratisk: hver side
    // ventet paa den forrige, og `range(11000, 11999)` tvang Postgres til
    // aa sortere HELE aarsmaterialet og saa kaste de elleve tusen foerste.
    // Siste side var den dyreste. Maalt paa én stasjon: 30-60 sekunder.
    //
    // `hentPerDato` deler perioden i datobolker som kjoerer samtidig. Hver
    // bolk har et smalt `between` som treffer indeksen paa (stasjon, dato)
    // og aldri hopper over noe.
    //
    // DEN GAMLE LOEKKA SVELGET DESSUTEN FEIL: `if (error || ...) break` ga
    // et HALVT aar uten at noe sa fra, og et halvt aar ser ut som en
    // rolig periode - ikke som en feil. `hentPerDato` kaster.
    //
    // Motoren er rekkefoelgeuavhengig (`median` sorterer sin egen kopi,
    // `snitt` er et gjennomsnitt, resten er summer og Map-oppslag), men
    // rekkefoelgen beholdes likevel: bolkene er kronologiske og
    // `Promise.all` beholder rekkefoelgen.
    // ===================================================================
    const salg = await hentPerDato<SalgRad>(
      (fraBolk, tilBolk) => supabase
        .from('v_butikksalg').select('varenavn, varegruppe_kode, varegruppe_navn, antall, dato')
        .eq('stasjon_id', stasjon.id).in('varegruppe_kode', KODER)
        .gte('dato', fraBolk).lte('dato', tilBolk).is('slettet_tid', null)
        .order('dato').order('ean').limit(1000).overrideTypes<SalgRad[]>(),
      referanse.fra,
      referanse.til,
    )

    vaer = vMaal ?? null
    hodeData = hode ?? null
    arrangementer = (arr ?? []).filter((a) => a.stasjon_id === null || a.stasjon_id === stasjon.id).map((a) => ({ id: a.id, navn: a.navn, faktor: a.faktor }))
    const arrangementFaktor = arrangementer.reduce((f, a) => f * a.faktor, 1)
    const punkter: SalgsPunkt[] = salg
      .map((r) => {
        if (r.antall === null || !Number.isFinite(r.antall)) throw new Error('Salgsantallet er ukjent. Produksjonsforslaget kan ikke beregnes.')
        return { dato: r.dato, varenavn: (r.varenavn ?? '').trim(), varegruppeKode: r.varegruppe_kode, varegruppeNavn: r.varegruppe_navn, antall: r.antall }
      })
      .filter((p) => p.varenavn)
    datadybde = new Set(punkter.map((p) => p.dato)).size

    const vaerKoeff = await hentVaerKoeff(supabase, stasjon.id, 'varegruppe')
    const plan = lagProduksjonsplan({ maalDato: dato, sisteSalgsdato, salg: punkter, vaerMaal: vMaal ?? null, vaerFjor: vFjor ?? null, vaerfolsomhet: stasjon.vaerfolsomhet_laert ?? stasjon.vaerfolsomhet ?? 0.5, vaerKoeff, arrangementFaktor, helligdag: erHelligdag(dato), fjorHelligdag: fjorHelligdag(dato) })
    planForklaring = plan.forklaring
    // Selvlæring: gang inn korreksjon pr varegruppe fra egen treffhistorikk (§7).
    const kalibreringDetaljer = await hentKalibreringDetaljer(supabase, stasjon.id, 'produksjonsplan')
    const kalibrering = new Map([...kalibreringDetaljer.entries()].map(([kode, verdi]) => [kode, verdi.korreksjon]))
    advarsler = plan.advarsler
    if (kalibrering.size > 0) advarsler.push('Selvlært kalibrering aktiv — forslaget er justert mot stasjonens egen treffhistorikk.')
    if (helligdagNavn(dato)) advarsler.push(`${helligdagNavn(dato)} — forslaget bygger på fjorårets samme helligdag, ikke vanlige ukedager.`)
    if (arrangementer.length > 0) advarsler.push(`Arrangement-dag: ${arrangementer.map((a) => `${a.navn} (×${a.faktor})`).join(', ')} — forslaget er løftet.`)

    const lagretFor = new Map((lagrede ?? []).map((l) => [l.varenavn, l]))
    // Avvik per varegruppe (0149). null i en kolonne betyr ARV fra
    // stasjonen; 0 betyr null prosent og vinner over standarden.
    const avvikFor = new Map((avvik ?? []).map((a) => [a.varegruppe_kode, a]))
    // '*' er stasjonens standard, samme konvensjon som prognose_treff.kategori.
    const standard = avvikFor.get(STANDARD_KODE)
    const grupperMap = new Map<string, Gruppe>()
    for (const f of plan.forslag) {
      const l = lagretFor.get(f.varenavn)
      const korr = kalibrering.get(f.varegruppeKode ?? '') ?? 1
      const justert = Math.max(0, Math.round(f.foreslatt * korr))

      // PROSENTENE SEEDER, DE STYRER IKKE. Finnes linja alt, har noen
      // tatt stilling til tallet - da skal ikke en innstilling flytte
      // det i stillhet. `l?.planlagt ?? ...` er hele regelen.
      const av = avvikFor.get(f.varegruppeKode ?? '')
      const marginPst = effektivProsent(standard?.margin_prosent, av?.margin_prosent)
      const startPst = effektivProsent(standard?.start_prosent, av?.start_prosent)
      // Marginen legges paa PLANLAGT, aldri paa foreslatt: backtesten
      // maaler foreslatt mot faktisk salg og ville lest paaslaget som
      // at modellen overvurderer.
      const automatiskPlanlagt = medMargin(justert, marginPst)
      const planlagt = l?.planlagt ?? automatiskPlanlagt
      const automatiskStart = startAntall(automatiskPlanlagt, startPst)

      const produkt: Produkt = {
        varenavn: f.varenavn, baseline: f.basis, fjorMedian: f.fjorMedian, nyligSnitt: f.nyligSnitt,
        faktor: korr !== 1 ? Math.round(f.samletfaktor * korr * 100) / 100 : f.samletfaktor,
        foreslatt: justert,
        planlagt,
        start_antall: l?.start_antall ?? automatiskStart,
        ekskludert: l?.ekskludert ?? false, flagg: f.flagg,
        forklaring: {
          ...f.forklaring,
          selvlaertKorreksjon: korr,
          selvlaertAntall: kalibreringDetaljer.get(f.varegruppeKode ?? '')?.n ?? null,
          marginProsent: marginPst,
          startProsent: startPst,
          automatiskForslag: justert,
          automatiskPlanlagt,
          automatiskStart,
          avvikerFraAutomatisk: l != null && l.planlagt !== automatiskPlanlagt,
          vaerfaktor: f.vaerfaktor,
          trendfaktor: f.trendfaktor,
          arrangementFaktor: plan.forklaring.arrangementFaktor,
        },
      }
      const nokkel = f.varegruppeKode ?? f.varegruppeNavn ?? '—'
      let g = grupperMap.get(nokkel)
      if (!g) { g = { kode: f.varegruppeKode, navn: f.varegruppeNavn ?? `Varegruppe ${f.varegruppeKode ?? '?'}`, produkter: [] }; grupperMap.set(nokkel, g) }
      g.produkter.push(produkt)
    }
    grupper = [...grupperMap.values()].sort((a, b) => (a.kode ?? '').localeCompare(b.kode ?? ''))
    prosent = { start: standard?.start_prosent ?? 0, margin: standard?.margin_prosent ?? 0 }
    gruppeAvvik = Object.fromEntries((avvik ?? [])
      .filter((a) => a.varegruppe_kode !== STANDARD_KODE)
      .map((a) => [a.varegruppe_kode, { start: a.start_prosent, margin: a.margin_prosent }]))
  }

  // NIVÅ 1 på en arbeidsflyt: hvor langt er jeg kommet.
  //
  // Siden åpnet med «Forslag bygd på fjorårets samme ukedag (median) +
  // nylig trend + værvarsel, med kampanje-deteksjon» — metoden, som
  // svar på et spørsmål ingen stiller. Rett under sto «baseline fra 391
  // salgsdager». Mønsterkartet bruker nettopp denne siden som eksempel
  // på fella: brukeren møter beregningen før anbefalingen.
  //
  // Det som faktisk er tilstanden her: er planen publisert, så de på
  // vakt ser den på nettbrettet — eller ligger den som utkast?
  const synlige = grupper.flatMap((g) => g.produkter.filter((p) => !p.ekskludert))
  const sumPlanlagt = synlige.reduce((n, p) => n + p.planlagt, 0)
  const publisert = hodeData?.publisert_tid != null
  const svar = grupper.length === 0
    ? null
    : publisert
      ? `Publisert — ${synlige.length} varer, ${sumPlanlagt} enheter`
      : `Utkast — ${synlige.length} varer, ${sumPlanlagt} enheter. Ikke synlig på nettbrettet ennå`

  const dagTekst = stasjon
    ? [
        `${UKEDAG[ukedag]} ${datoLang.format(new Date(dato))}`,
        `${stasjon.butikknummer} ${stasjon.navn}`,
        vaer?.temp_maks != null ? `varsel ${vaer.temp_maks.toFixed(0)}°` : 'ingen værvarsel',
      ].join(' · ')
    : ''

  // 0152: uten mapping viser vi HVORFOR, og ikke en plan uten forslag.
  // En tom plan er en gyldig plan - «ingenting skal produseres i dag» er
  // noe systemet kan mene - saa de to maa se forskjellige ut.
  if (ikkeKonfigurert) {
    return (
      <Sideramme>
        <Sidehode tittel="Produksjonsplan" undertittel="Venter paa oppsett" />
        <Tomtilstand
          tittel="Ikke satt opp for kjeden ennaa"
          forklaring={IKKE_KONFIGURERT_TEKST}
        />
      </Sideramme>
    )
  }

  return (
    <Sideramme>
      <Sidehode
        tittel="Produksjonsplan"
        undertittel={svar ? `${svar}. ${dagTekst}` : dagTekst || 'Velg stasjon og dag.'}
        handlinger={<Link href="/produksjonsplan/treffsikkerhet" className="sq-knapp">Treffsikkerhet</Link>}
      />

      {/* STASJONSVELGEREN ER BORTE HERFRA. Den gjorde samme jobb som den i
          toppstripen, med et annet svar - og to velgere for det samme er
          ikke et valg, det er en felle. Dagen staar igjen: den er sidas
          eget sporsmaal, og finnes ikke i appskallet.

          Butikknummeret folger med som skjult felt, saa et bytte av dag
          ikke stille bytter stasjon. */}
      <form method="get" className="sq-listetopp">
        {valgtNr && <input type="hidden" name="butikknummer" value={valgtNr} />}
        <Felt etikett="Dag" name="dato" type="date" defaultValue={dato} />
        <Knapp type="submit">Vis dagen</Knapp>
      </form>

      {/* NIVAA 3: hva systemet foreslaar, og hvorfor det ser slik ut.
          Motoren returnerer en FLAT liste - den rangerer dem ikke, og
          gjor de ikke det, skal ikke visningen finne paa en rangering
          heller. Alle staar derfor som `informasjon`. Skulle en av dem
          faktisk vaere viktigere enn de andre, hoerer den forskjellen
          hjemme i motoren, der den kan begrunnes.

          Delingen paa tankestreken er ren presentasjon: motoren skriver
          «tilstand — konsekvens», og Signal har plass til begge deler. */}
      {advarsler.map((a, i) => {
        const [tittel, ...resten] = a.split(' \u2014 ')
        return (
          <Signal key={i} nivaa="informasjon" tittel={tittel}>
            {resten.length > 0 ? resten.join(' \u2014 ') : undefined}
          </Signal>
        )
      })}

      {grupper.length === 0 ? (
        <Tomtilstand
          tittel="Ingen produksjonssalg registrert"
          forklaring={`Planen bygger på salget i varegruppene som er valgt som produksjonsvarer for kjeden. En Salgsstatistikk-fil må importeres før forslaget kan regnes ut.${bruker.rolle === 'retailer_admin' ? '' : ' Be kjedeansvarlig om å importere salgshistorikken.'}`}
          handling={bruker.rolle === 'retailer_admin' ? <Link href="/import" className="sq-knapp primar">Gå til Import</Link> : undefined}
        />
      ) : (
        <>
          <PlanTabell grupper={grupper} stasjonId={stasjon!.id} dato={dato} notat={hodeData?.notat ?? null} publisertTid={hodeData?.publisert_tid ?? null} prosent={prosent} gruppeAvvik={gruppeAvvik} planForklaring={planForklaring ?? undefined} />

          {/* NIVÅ 4 — grunnlaget. Sto som undertittel over hele siden. */}
          <Forklaring sporsmaal="Hvor kommer forslaget fra?">
            <p>
              Grunnlaget er fjorårets sammenlignbare dager (median), justert med nylig trend og
              værvarselet for dagen. Uvanlige salgsutslag markeres som mulig kampanjepåvirkning,
              slik at en uke med halv pris på boller ikke blir til en permanent forventning.
            </p>
            <p>
              Historikken inneholder <strong>{datadybde} salgsdag{datadybde === 1 ? '' : 'er'}</strong> totalt.
              {datadybde < 14
                ? ' Det er tynt — forslaget blir merkbart mer presist med mer historikk, og bør leses som en pekepinn inntil videre.'
                : ' Antall relevante observasjoner varierer per produkt; varer med lite grunnlag er merket.'}
              {' '}Værutslaget følger stasjonens værfølsomhet og tilgjengelige kategoriprofiler.
            </p>
            <p>
              Treffsikkerheten måles i etterkant ved å kjøre motoren bakover på stasjonens
              egen historikk, og der forslaget bommer systematisk læres en korreksjon per
              varegruppe. Den er i så fall nevnt blant meldingene over. Treffvisningen gjelder
              råmodellen med historisk vær og dagens profiler; den dokumenterer ikke alene
              at kalibreringen forbedrer fremtidige forslag.
            </p>
          </Forklaring>
        </>
      )}
    </Sideramme>
  )
}
