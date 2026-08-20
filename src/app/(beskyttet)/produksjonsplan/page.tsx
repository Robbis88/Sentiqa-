import Link from 'next/link'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { datoLang, iDag } from '@/lib/format'
import { lagProduksjonsplan, leggTilDager, PRODUKSJON_KODER as KODER, type SalgsPunkt, type Vaerdag } from '@/lib/produksjonsplan'
import { hentKalibrering } from '@/lib/backtest'
import { hentVaerKoeff } from '@/lib/vaerprofil'
import { erHelligdag, helligdagNavn } from '@/lib/helligdager'
import { PlanTabell, type Gruppe, type Produkt } from './plan-tabell'
import { TabletPlan, type TabletGruppe } from './tablet-plan'
import { Sidehode, Tomtilstand, Forklaring } from '@/components/ui/side'
import { husketStasjon } from '@/lib/stasjonskontekst'
import { stasjonFraUrl } from '@/lib/stasjonsvalg'
import { Signal } from '@/components/ui/status'
import { Felt } from '@/components/ui/felt'
import { Knapp } from '@/components/ui/knapp'

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
    const { data: hode } = await supabase.from('produksjonsplan_hode').select('notat, publisert_tid').eq('stasjon_id', st.id).eq('dato', idag).maybeSingle<{ notat: string | null; publisert_tid: string | null }>()
    if (!hode?.publisert_tid) {
      return <section className="tablet-seksjon"><h2>Produksjon</h2><p>Ingen produksjonsplan publisert i dag.</p></section>
    }
    const { data: linjer } = await supabase
      .from('produksjonsplan_linjer').select('varenavn, varegruppe_navn, planlagt, start_antall, lagd_hittil')
      .eq('stasjon_id', st.id).eq('dato', idag).eq('ekskludert', false).gt('planlagt', 0)
      .order('varegruppe_navn').overrideTypes<{ varenavn: string; varegruppe_navn: string | null; planlagt: number; start_antall: number; lagd_hittil: number }[]>()
    const gmap = new Map<string, TabletGruppe>()
    for (const l of linjer ?? []) {
      const navn = l.varegruppe_navn ?? 'Produksjon'
      let g = gmap.get(navn)
      if (!g) { g = { navn, produkter: [] }; gmap.set(navn, g) }
      g.produkter.push({ varenavn: l.varenavn, planlagt: l.planlagt, start_antall: l.start_antall, lagd_hittil: l.lagd_hittil })
    }
    return (
      <>
        <h1>Produksjon i dag</h1>
        <TabletPlan stasjonId={st.id} dato={idag} notat={hode.notat} grupper={[...gmap.values()]} />
      </>
    )
  }

  if (!erLeder(bruker.rolle)) {
    return <p>Du har ikke tilgang til produksjonsplan.</p>
  }
  const sp = await searchParams

  const { data: alleStasjoner } = await supabase
    .from('stasjoner')
    .select('id, butikknummer, navn, stasjonstype, vaerfolsomhet, vaerfolsomhet_laert')
    .is('slettet_tid', null)
    .order('butikknummer')
    .overrideTypes<{ id: string; butikknummer: string; navn: string; stasjonstype: string; vaerfolsomhet: number | null; vaerfolsomhet_laert: number | null }[]>()

  // Butikksjef låses til egne stasjoner (admin ser alle).
  let stasjoner = alleStasjoner ?? []
  if (bruker.rolle === 'butikksjef') {
    const { data: tilgang } = await supabase.from('butikksjef_stasjoner').select('stasjon_id').eq('profil_id', bruker.id)
    const ids = new Set((tilgang ?? []).map((t) => t.stasjon_id))
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

  const imorgen = new Date()
  imorgen.setDate(imorgen.getDate() + 1)
  const dato = sp.dato && /^\d{4}-\d{2}-\d{2}$/.test(sp.dato) ? sp.dato : imorgen.toISOString().slice(0, 10)
  const ukedag = new Date(dato).getUTCDay()

  let grupper: Gruppe[] = []
  let datadybde = 0
  let vaer: Vaerdag | null = null
  let advarsler: string[] = []
  let hodeData: { notat: string | null; publisert_tid: string | null } | null = null
  let arrangementer: { id: string; navn: string; faktor: number }[] = []

  if (stasjon) {
    const fjorBase = leggTilDager(dato, -364)
    // Siste dag med faktisk salg (ikke «i dag») — så manglende dager bakerst
    // ikke trekker snittet ned.
    const { data: sisteRad } = await supabase
      .from('v_butikksalg').select('dato').eq('stasjon_id', stasjon.id).in('varegruppe_kode', KODER).is('slettet_tid', null)
      .order('dato', { ascending: false }).limit(1).maybeSingle<{ dato: string }>()
    const sisteSalgsdato = sisteRad?.dato ?? leggTilDager(dato, -1)
    const fra = leggTilDager(dato, -392) // dekker fjor-vindu + nylig + fjor-trend

    const [{ data: vMaal }, { data: vFjor }, { data: lagrede }, { data: hode }, { data: arr }] = await Promise.all([
      supabase.from('vaer').select('temp_maks, nedbor_mm').eq('stasjon_id', stasjon.id).eq('dato', dato).maybeSingle<Vaerdag>(),
      supabase.from('vaer').select('temp_maks, nedbor_mm').eq('stasjon_id', stasjon.id).eq('dato', fjorBase).maybeSingle<Vaerdag>(),
      supabase.from('produksjonsplan_linjer').select('varenavn, planlagt, start_antall, ekskludert').eq('stasjon_id', stasjon.id).eq('dato', dato).overrideTypes<{ varenavn: string; planlagt: number; start_antall: number; ekskludert: boolean }[]>(),
      supabase.from('produksjonsplan_hode').select('notat, publisert_tid').eq('stasjon_id', stasjon.id).eq('dato', dato).maybeSingle<{ notat: string | null; publisert_tid: string | null }>(),
      // Kun BEKREFTEDE arrangementer løfter planen (forslag styres på /arrangementer).
      supabase.from('arrangementer').select('id, navn, faktor, stasjon_id').eq('dato', dato).neq('status', 'forslag').is('slettet_tid', null).overrideTypes<{ id: string; navn: string; faktor: number; stasjon_id: string | null }[]>(),
    ])

    // PostgREST kapper på 1000 rader. Et helt års produksjonssalg (~12k rader) må
    // derfor hentes i SIDER — ellers får motoren ikke fjorårets dager, og
    // år-mot-år-matchen blir feil. Ordnet på (dato, ean) for stabil paginering.
    const salg: SalgRad[] = []
    for (let side = 0; side < 100; side++) {
      const { data, error } = await supabase
        .from('v_butikksalg').select('varenavn, varegruppe_kode, varegruppe_navn, antall, dato')
        .eq('stasjon_id', stasjon.id).in('varegruppe_kode', KODER).gte('dato', fra).lte('dato', sisteSalgsdato).is('slettet_tid', null)
        .order('dato').order('ean').range(side * 1000, side * 1000 + 999).overrideTypes<SalgRad[]>()
      if (error || !data || data.length === 0) break
      salg.push(...data)
      if (data.length < 1000) break
    }

    vaer = vMaal ?? null
    hodeData = hode ?? null
    arrangementer = (arr ?? []).filter((a) => a.stasjon_id === null || a.stasjon_id === stasjon.id).map((a) => ({ id: a.id, navn: a.navn, faktor: a.faktor }))
    const arrangementFaktor = arrangementer.reduce((f, a) => f * a.faktor, 1)
    const punkter: SalgsPunkt[] = salg
      .map((r) => ({ dato: r.dato, varenavn: (r.varenavn ?? '').trim(), varegruppeKode: r.varegruppe_kode, varegruppeNavn: r.varegruppe_navn, antall: r.antall ?? 0 }))
      .filter((p) => p.varenavn)
    datadybde = new Set(punkter.map((p) => p.dato)).size

    const vaerKoeff = await hentVaerKoeff(supabase, stasjon.id, 'varegruppe')
    const plan = lagProduksjonsplan({ maalDato: dato, sisteSalgsdato, salg: punkter, vaerMaal: vMaal ?? null, vaerFjor: vFjor ?? null, vaerfolsomhet: stasjon.vaerfolsomhet_laert ?? stasjon.vaerfolsomhet ?? 0.5, vaerKoeff, arrangementFaktor, helligdag: erHelligdag(dato) })
    // Selvlæring: gang inn korreksjon pr varegruppe fra egen treffhistorikk (§7).
    const kalibrering = await hentKalibrering(supabase, stasjon.id, 'produksjonsplan')
    advarsler = plan.advarsler
    if (kalibrering.size > 0) advarsler.push('Selvlært kalibrering aktiv — forslaget er justert mot stasjonens egen treffhistorikk.')
    if (helligdagNavn(dato)) advarsler.push(`${helligdagNavn(dato)} — forslaget bygger på fjorårets samme helligdag, ikke vanlige ukedager.`)
    if (arrangementer.length > 0) advarsler.push(`Arrangement-dag: ${arrangementer.map((a) => `${a.navn} (×${a.faktor})`).join(', ')} — forslaget er løftet.`)

    const lagretFor = new Map((lagrede ?? []).map((l) => [l.varenavn, l]))
    const grupperMap = new Map<string, Gruppe>()
    for (const f of plan.forslag) {
      const l = lagretFor.get(f.varenavn)
      const korr = kalibrering.get(f.varegruppeKode ?? '') ?? 1
      const justert = Math.max(0, Math.round(f.foreslatt * korr))
      const produkt: Produkt = {
        varenavn: f.varenavn, baseline: f.basis,
        faktor: korr !== 1 ? Math.round(f.samletfaktor * korr * 100) / 100 : f.samletfaktor,
        foreslatt: justert,
        planlagt: l?.planlagt ?? justert, start_antall: l?.start_antall ?? 0, ekskludert: l?.ekskludert ?? false, flagg: f.flagg,
      }
      const nokkel = f.varegruppeKode ?? f.varegruppeNavn ?? '—'
      let g = grupperMap.get(nokkel)
      if (!g) { g = { kode: f.varegruppeKode, navn: f.varegruppeNavn ?? `Varegruppe ${f.varegruppeKode ?? '?'}`, produkter: [] }; grupperMap.set(nokkel, g) }
      g.produkter.push(produkt)
    }
    grupper = [...grupperMap.values()].sort((a, b) => (a.kode ?? '').localeCompare(b.kode ?? ''))
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

  return (
    <>
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
          forklaring="Planen bygger på hva stasjonen faktisk har solgt av bakevarer og varmmat (varegruppe 1201–1221). Behandle en Salgsstatistikk-fil under Import, så regnes forslaget ut."
          handling={<Link href="/import" className="sq-knapp primar">Gå til Import</Link>}
        />
      ) : (
        <>
          <PlanTabell grupper={grupper} stasjonId={stasjon!.id} dato={dato} notat={hodeData?.notat ?? null} publisertTid={hodeData?.publisert_tid ?? null} />

          {/* NIVÅ 4 — grunnlaget. Sto som undertittel over hele siden. */}
          <Forklaring sporsmaal="Hvor kommer forslaget fra?">
            <p>
              Grunnlaget er fjorårets samme ukedag (median), justert med nylig trend og
              værvarselet for dagen. Kampanjer oppdages og trekkes fra, så en uke med
              halv pris på boller ikke blir til en permanent forventning.
            </p>
            <p>
              Baseline er regnet på <strong>{datadybde} salgsdag{datadybde === 1 ? '' : 'er'}</strong>.
              {datadybde < 14
                ? ' Det er tynt — forslaget blir merkbart mer presist med mer historikk, og bør leses som en pekepinn inntil videre.'
                : ' Det er nok til at medianen står imot enkeltdager som skiller seg ut.'}
              {' '}Stasjonen er av type {stasjon?.stasjonstype}, som avgjør hvor hardt været slår inn.
            </p>
            <p>
              Treffsikkerheten måles i etterkant ved å kjøre motoren bakover på stasjonens
              egen historikk, og der forslaget bommer systematisk læres en korreksjon per
              varegruppe. Den er i så fall nevnt blant meldingene over.
            </p>
          </Forklaring>
        </>
      )}
    </>
  )
}
