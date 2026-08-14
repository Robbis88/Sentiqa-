import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import {
  fordelAaret, planleggKalender, maanedsvekter,
  vaktliste,
  type Krav, type Vindu, type FastVakt, type Dagsvekt,
} from '@/lib/bemanning'
import { dagsprofiler, datoerIMaaned } from '@/lib/dagtyper'
import {
  formendring, formendringTekst, historiskTak, justerProfil, kapasitet,
  planMotFaktisk, sammenlignStasjoner, stillingsanslag,
} from '@/lib/bemanningsanalyse'
import {
  FastVaktSkjema, FravaerSkjema, KravSkjema, StillingSkjema, TakSkjema, VinduSkjema,
} from './skjemaer'
import { slettFastVakt, slettFravaer, slettKrav, slettVindu } from './handlinger'

const UKEDAG = ['', 'man', 'tir', 'ons', 'tor', 'fre', 'lør', 'søn']
const MND = ['januar', 'februar', 'mars', 'april', 'mai', 'juni',
  'juli', 'august', 'september', 'oktober', 'november', 'desember']
const kl = (t: number) => `${String(t).padStart(2, '0')}:00`

type Sok = Promise<{ stasjon?: string; ar?: string; maned?: string }>

// Radene som de ligger i basen. Motoren bruker camelCase, så mappingen
// skjer ett sted (tilVindu/tilKrav/tilVakt) i stedet for spredt utover.
type VinduRad = {
  id: string; ukedag: number; fra_time: number; til_time: number
  min_bemanning: number; gjelder_fra: string
}
type KravRad = {
  id: string; ukedag: number; fra_time: number; til_time: number
  antall: number; begrunnelse: string | null
}
type VaktRad = {
  id: string; navn: string; ukedag: number; fra_time: number; til_time: number
  timelonnet: boolean
}

const tilVindu = (v: VinduRad): Vindu => ({
  ukedag: v.ukedag, fraTime: v.fra_time, tilTime: v.til_time, minBemanning: v.min_bemanning,
})
const tilKrav = (k: KravRad): Krav => ({
  ukedag: k.ukedag, fraTime: k.fra_time, tilTime: k.til_time, antall: k.antall,
})
const tilVakt = (v: VaktRad): FastVakt => ({
  ukedag: v.ukedag, fraTime: v.fra_time, tilTime: v.til_time, timelonnet: v.timelonnet,
})

// Stemplingene: hva stasjonen FAKTISK har hatt på jobb. To ting hentes ut —
// taket per ukedag × time (planen skal ikke foreslå to der de aldri har vært
// to), og dagstrykket, som gir helligdagsfaktorene.
async function hentStemplinger(
  supabase: Awaited<ReturnType<typeof lagSupabaseServerKlient>>,
  stasjonId: string,
  fra: string,
) {
  const { data } = await supabase
    .from('stempling')
    .select('dato, fra_tid, til_tid, minutter, ansatt_nr, ansatt_navn')
    .eq('stasjon_id', stasjonId)
    .eq('betalt', true)
    .gte('dato', fra)
  return (data ?? []) as {
    dato: string; fra_tid: string; til_tid: string; minutter: number
    ansatt_nr: string; ansatt_navn: string
  }[]
}

// Døgnkurven for en periode. Brukes to ganger med samme kalenderperiode i
// to ulike år, så det som måles er FORMENDRING og ikke sesong.
async function hentDognkurve(
  supabase: Awaited<ReturnType<typeof lagSupabaseServerKlient>>,
  stasjonId: string,
  fra: string,
  til: string,
): Promise<Map<string, number>> {
  const { data } = await supabase
    .from('timesalg')
    .select('dato, time, inne_kunder')
    .eq('stasjon_id', stasjonId)
    .is('slettet_tid', null)
    .not('inne_kunder', 'is', null)
    .gte('dato', fra)
    .lte('dato', til)
  const sum = new Map<string, { n: number; sum: number }>()
  for (const r of (data ?? []) as { dato: string; time: string; inne_kunder: number }[]) {
    const d = new Date(`${r.dato}T00:00:00Z`).getUTCDay()
    const noekkel = `${d === 0 ? 7 : d}:${Number.parseInt(r.time.split('-')[0], 10)}`
    const s = sum.get(noekkel) ?? { n: 0, sum: 0 }
    s.n++; s.sum += r.inne_kunder
    sum.set(noekkel, s)
  }
  return new Map([...sum].map(([k, v]) => [k, v.sum / v.n]))
}

// Kunder per DATO — grunnlaget for helligdagsfaktorene. Ikke per måned:
// skjærtorsdag er en dato, og det er den vi skal måle.
async function hentDagskunder(
  supabase: Awaited<ReturnType<typeof lagSupabaseServerKlient>>,
  stasjonId: string,
  fra: string,
): Promise<{ dato: string; kunder: number }[]> {
  const { data } = await supabase
    .from('timesalg')
    .select('dato, inne_kunder')
    .eq('stasjon_id', stasjonId)
    .is('slettet_tid', null)
    .not('inne_kunder', 'is', null)
    .gte('dato', fra)
  const sum = new Map<string, number>()
  for (const r of (data ?? []) as { dato: string; inne_kunder: number }[]) {
    sum.set(r.dato, (sum.get(r.dato) ?? 0) + r.inne_kunder)
  }
  return [...sum].map(([dato, kunder]) => ({ dato, kunder }))
}

// Kunder per måned i fjor. Dette er vektene årsrammen fordeles etter — ikke
// BP-kurven. BP-bruttoen er formet av hva stasjonen gjorde i fjor, inkludert
// timene butikksjefen brukte fordi hun hadde dem; kundene er formet av hvem
// som faktisk kom. Påske, fellesferie og utfartshelger ligger allerede i
// tallene uten at noen har måttet liste dem opp.
async function hentMaanedskunder(
  supabase: Awaited<ReturnType<typeof lagSupabaseServerKlient>>,
  stasjonId: string,
  ar: number,
): Promise<(number | null)[]> {
  const { data } = await supabase
    .from('timesalg')
    .select('dato, inne_kunder')
    .eq('stasjon_id', stasjonId)
    .is('slettet_tid', null)
    .not('inne_kunder', 'is', null)
    .gte('dato', `${ar - 1}-01-01`)
    .lte('dato', `${ar - 1}-12-31`)
  const rader = (data ?? []) as { dato: string; inne_kunder: number }[]

  const sum = new Array(12).fill(0)
  const dager: Set<string>[] = Array.from({ length: 12 }, () => new Set<string>())
  for (const r of rader) {
    const m = Number(r.dato.slice(5, 7)) - 1
    sum[m] += r.inne_kunder
    dager[m].add(r.dato)
  }
  // En måned med tre opplastede dager er ikke en måned. Under 20 dager
  // regnes som ingen data, så vekten hentes fra BP i stedet for å bli
  // et tilfeldig lavt tall.
  return sum.map((s, m) => (dager[m].size >= 20 ? s : null))
}

// Kundeformen. Samme måned i fjor er riktigst — januar planlegges ikke etter
// septembertall. Finnes den ikke, faller vi tilbake på siste 90 dager og sier
// ifra i UI-et, for da er formen sesongforskjøvet.
async function hentProfil(
  supabase: Awaited<ReturnType<typeof lagSupabaseServerKlient>>,
  stasjonId: string,
  ar: number,
  maned: number,
): Promise<{ profil: Map<string, number>; kilde: string; dager: number }> {
  const les = async (fra: string, til: string) => {
    const { data } = await supabase
      .from('timesalg')
      .select('dato, time, inne_kunder')
      .eq('stasjon_id', stasjonId)
      .is('slettet_tid', null)
      .not('inne_kunder', 'is', null)
      .gte('dato', fra)
      .lte('dato', til)
    return (data ?? []) as { dato: string; time: string; inne_kunder: number }[]
  }

  const sisteDag = new Date(Date.UTC(ar - 1, maned, 0)).getUTCDate()
  let rader = await les(`${ar - 1}-${String(maned).padStart(2, '0')}-01`,
    `${ar - 1}-${String(maned).padStart(2, '0')}-${sisteDag}`)
  let kilde = `${MND[maned - 1]} ${ar - 1}`

  if (new Set(rader.map((r) => r.dato)).size < 20) {
    const til = new Date()
    const fra = new Date(til.getTime() - 90 * 24 * 3600 * 1000)
    rader = await les(fra.toISOString().slice(0, 10), til.toISOString().slice(0, 10))
    kilde = 'siste 90 dager'
  }

  const sum = new Map<string, { n: number; sum: number }>()
  for (const r of rader) {
    const d = new Date(`${r.dato}T00:00:00Z`).getUTCDay()
    const noekkel = `${d === 0 ? 7 : d}:${Number.parseInt(r.time.split('-')[0], 10)}`
    const s = sum.get(noekkel) ?? { n: 0, sum: 0 }
    s.n++; s.sum += r.inne_kunder
    sum.set(noekkel, s)
  }
  const profil = new Map<string, number>()
  for (const [k, s] of sum) profil.set(k, s.sum / s.n)
  return { profil, kilde, dager: new Set(rader.map((r) => r.dato)).size }
}

export default async function BemanningSide({ searchParams }: { searchParams: Sok }) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) {
    return <p>Bemanningsplanen er for butikksjef og eier.</p>
  }
  const sok = await searchParams
  const supabase = await lagSupabaseServerKlient()

  const { data: stasjoner } = await supabase
    .from('stasjoner').select('id, navn, butikknummer')
    .is('slettet_tid', null).order('butikknummer')
  const alle = (stasjoner ?? []) as { id: string; navn: string; butikknummer: string }[]
  if (alle.length === 0) return <p>Ingen stasjoner registrert.</p>

  const valgt = alle.find((s) => s.id === sok.stasjon) ?? alle[0]
  // Standard er NESTE måned — det er den man planlegger. Ruller over årsskiftet.
  const naa = new Date()
  // Overlappet vi kan sammenligne: fra nyttår til forrige hele måned, i
  // begge år. Inneværende måned er ikke ferdig og ville dratt skjevt.
  const forrigeMnd = String(Math.max(1, naa.getUTCMonth())).padStart(2, '0')
  const nesteNr = naa.getUTCMonth() + 2
  const nesteManed = nesteNr > 12 ? 1 : nesteNr
  const nesteAr = nesteNr > 12 ? naa.getUTCFullYear() + 1 : naa.getUTCFullYear()
  const ar = Number(sok.ar) || nesteAr
  const maned = Number(sok.maned) || nesteManed
  const iDag = naa.toISOString().slice(0, 10)

  const [{ data: rammer }, { data: vinduer }, { data: krav }, { data: vakter },
    { data: grenser }, profilen, maanedskunder, dagskunder, stemplinger,
    kurveIFjor, kurveIAar, { data: avtaler }, { data: fravaerRader },
    { data: forbrukRader }] =
    await Promise.all([
      // Hele året, ikke bare måneden: gulvet må trekkes fra i alle tolv før
      // noe kan fordeles. En døgnåpen stasjon kan trenge mer i juni enn
      // bruttokurven gir den, og de timene finnes i en roligere måned.
      supabase.from('bemanning_maned').select('maned, disponible_timer')
        .eq('stasjon_id', valgt.id).eq('ar', ar).order('maned'),
      supabase.from('bemanning_vindu').select('id, ukedag, fra_time, til_time, min_bemanning, gjelder_fra')
        .eq('stasjon_id', valgt.id).order('ukedag').order('gjelder_fra', { ascending: false }),
      supabase.from('bemanning_krav').select('id, ukedag, fra_time, til_time, antall, begrunnelse')
        .eq('stasjon_id', valgt.id).order('ukedag'),
      supabase.from('bemanning_fast_vakt').select('id, navn, ukedag, fra_time, til_time, timelonnet')
        .eq('stasjon_id', valgt.id).order('navn').order('ukedag'),
      supabase.from('bemanning_stasjon').select('maks_bemanning')
        .eq('stasjon_id', valgt.id).maybeSingle<{ maks_bemanning: number | null }>(),
      hentProfil(supabase, valgt.id, ar, maned),
      hentMaanedskunder(supabase, valgt.id, ar),
      // To år tilbake: da har vi hver røde dag minst én gang, ofte to.
      hentDagskunder(supabase, valgt.id, `${ar - 2}-01-01`),
      hentStemplinger(supabase, valgt.id, `${ar - 2}-01-01`),
      // Samme kalenderperiode to år på rad. Stasjonene endrer seg hele
      // tiden, og en plan som arver fjorårets form uten å se etter om den
      // fortsatt stemmer, blir gradvis feil uten at noen merker det.
      hentDognkurve(supabase, valgt.id, `${ar - 1}-01-01`, `${ar - 1}-${forrigeMnd}-28`),
      hentDognkurve(supabase, valgt.id, `${ar}-01-01`, `${ar}-${forrigeMnd}-28`),
      supabase.from('ansatt_avtale').select('ansatt_nr, navn, stillingsprosent')
        .eq('stasjon_id', valgt.id),
      supabase.from('bemanning_fravaer').select('id, navn, fra_dato, til_dato, arsak')
        .eq('stasjon_id', valgt.id).order('fra_dato', { ascending: false }),
      // ALLE stasjoner, ikke bare den valgte: en stasjon alene sier
      // ingenting om den bruker for mange timer. Målestokken er de andre.
      supabase.from('v_stasjonsforbruk_mnd')
        .select('stasjon_id, maaned, timer, kunder, omsetning, mat_omsetning')
        .gte('maaned', `${ar - 1}-01-01`),
    ])
  const maksBemanning = grenser?.maks_bemanning ?? undefined

  // Databasen er snake_case, motoren camelCase. Mappingen står her, ett sted.
  const alleVinduer = (vinduer ?? []) as VinduRad[]
  // Én rad per ukedag: den nyeste som har trådt i kraft.
  const gjeldende = new Map<number, (typeof alleVinduer)[number]>()
  for (const v of alleVinduer) {
    if (v.gjelder_fra > iDag) continue
    if (!gjeldende.has(v.ukedag)) gjeldende.set(v.ukedag, v)
  }

  const kravListe = (krav ?? []) as KravRad[]
  const vaktListe = (vakter ?? []) as VaktRad[]
  // Kjeden bestemmer hvor mange timer året har. Hvordan de ligger utover
  // månedene er vår analyse, ikke BP-ens: samme årsramme, fordelt etter
  // stasjonens egne kunder. Radene fra bemanning_maned brukes derfor som
  // årssum og som reservevekt, ikke som fasit per måned.
  const lagret = ((rammer ?? []) as { maned: number; disponible_timer: number }[])
  const aarssum = lagret.reduce((a, r) => a + r.disponible_timer, 0)
  const bpVekt = new Array(12).fill(0)
  for (const r of lagret) bpVekt[r.maned - 1] = r.disponible_timer
  const vekter = maanedsvekter(maanedskunder, bpVekt)
  const malteMaaneder = maanedskunder.filter((k) => k !== null).length
  const aarsrammer = lagret.length > 0
    ? vekter.map((v, i) => ({ maned: i + 1, timer: v * aarssum }))
    : []

  // Fraværet er det som gjør at butikksjefens fem uker HENTER timer i
  // stedet for å spare dem: står han ikke der, dekker ikke den faste
  // vakten gulvet, og timene må kjøpes.
  const fravaerListe = (fravaerRader ?? []) as
    { id: string; navn: string; fra_dato: string; til_dato: string; arsak: string | null }[]
  const oppsett = {
    vinduer: [...gjeldende.values()].map(tilVindu),
    krav: kravListe.map(tilKrav),
    fasteVakter: vaktListe.map((v) => ({ ...tilVakt(v), navn: v.navn })),
    fravaer: fravaerListe.map((f) => ({ navn: f.navn, fraDato: f.fra_dato, tilDato: f.til_dato })),
  }
  // Årsfordelingen først — gulvet i alle tolv månedene, så resten etter
  // bruttokurven. Det er den som avgjør hva denne måneden faktisk har.
  const aar = aarsrammer.length > 0
    ? fordelAaret({ ar, rammer: aarsrammer, ...oppsett })
    : null
  const iMnd = aar?.maaneder.find((m) => m.maned === maned) ?? null
  const disponible = iMnd?.disponible ?? null
  const raaRamme = aarsrammer.find((r) => r.maned === maned)?.timer ?? null

  // Dagtypene: helligdager fra kalenderen, effekten målt fra stasjonens
  // egen historikk. Ingen liste over utfartsdager — de ER dagene som
  // avviker oppover, og det faller ut av tallene.
  const profiler = dagsprofiler(datoerIMaaned(ar, maned), dagskunder)
  const dagsvekter: Dagsvekt[] = profiler.map((p) => ({
    dato: p.dato, ukedag: p.ukedag, faktor: p.faktor, rodFraTime: p.rodFraTime,
  }))
  // Taket: har de aldri vært to tirsdag 09, skal planen ikke foreslå det.
  const tak = stemplinger.length > 0
    ? historiskTak(stemplinger.map((s) => ({
      dato: s.dato, fraTid: s.fra_tid.slice(0, 5), tilTid: s.til_tid.slice(0, 5),
    })))
    : undefined

  // Har formen flyttet seg siden i fjor, skal septemberplanen vite det —
  // ikke bare arve september i fjor. Er driften liten, står profilen som den er.
  const drift = formendring(kurveIFjor, kurveIAar)
  const driftTekst = formendringTekst(drift, UKEDAG)
  const brukProfil = justerProfil(profilen.profil, drift)

  const plan = disponible !== null && gjeldende.size > 0 && aar?.gjennomforbar
    ? planleggKalender({
      disponibleTimer: disponible, dager: dagsvekter, ...oppsett,
      profil: brukProfil, maksBemanning, tak,
    })
    : null
  const rutenett = new Map(plan?.timer.map((t) => [`${t.dato}:${t.time}`, t]) ?? [])
  const timerVist = plan ? [...new Set(plan.timer.map((t) => t.time))].sort((a, b) => a - b) : []

  // Uke for uke. Mandag først, og en uke som starter i forrige måned vises
  // med de dagene den faktisk har — påskeuka skal se ut som påskeuka.
  const uker: { nr: number; profiler: typeof profiler }[] = []
  for (const p of profiler) {
    const forrige = uker[uker.length - 1]
    if (forrige && p.ukedag !== 1) forrige.profiler.push(p)
    else uker.push({ nr: uker.length + 1, profiler: [p] })
  }
  const dagsum = new Map<string, number>()
  for (const t of plan?.timer ?? []) dagsum.set(t.dato, (dagsum.get(t.dato) ?? 0) + t.sum)
  // Vaktene, ikke tallene. «3 personer klokka 12» kan ingen sette opp;
  // «10–15 og 11–16» er en timeplan.
  // Plan mot virkelighet. Bare for dager som har vaert — en plan for
  // september kan ikke måles mot stemplinger som ikke finnes ennå.
  const faktisk = new Map<string, number>()
  for (const st of stemplinger) {
    const fra = Number(st.fra_tid.slice(0, 2))
    let til = st.til_tid.startsWith('00:') ? 24 : Number(st.til_tid.slice(0, 2))
    if (til <= fra) til += 24
    for (let t = fra; t < til; t++) {
      const dato = t < 24
        ? st.dato
        : new Date(Date.parse(`${st.dato}T12:00:00Z`) + 86400000).toISOString().slice(0, 10)
      const n = `${dato}:${t % 24}`
      faktisk.set(n, (faktisk.get(n) ?? 0) + 1)
    }
  }
  const gaatt = plan?.timer.filter((t) => t.dato < iDag) ?? []
  const avvik = gaatt.length > 0 && stemplinger.length > 0
    ? planMotFaktisk(gaatt, faktisk)
    : null

  // Stillingsprosent: anslått fra stemplingene, overstyrt av det
  // butikksjefen har bekreftet. Et lagret tall er et menneskes ord og
  // skal aldri overskrives av en ny beregning.
  const lagredeAvtaler = new Map(
    ((avtaler ?? []) as { ansatt_nr: string; navn: string; stillingsprosent: number | null }[])
      .map((a) => [a.ansatt_nr, a]))
  const anslag = stillingsanslag(
    stemplinger.map((st) => ({
      ansattNr: st.ansatt_nr, navn: st.ansatt_navn, dato: st.dato, timer: st.minutter / 60,
    })),
    iDag,
  )
  const stillinger = anslag.map((a) => ({
    ...a,
    lagret: lagredeAvtaler.get(a.ansattNr)?.stillingsprosent ?? null,
  }))
  const kap = plan
    ? kapasitet(
      stillinger.map((s) => ({ anslagProsent: s.lagret ?? s.anslagProsent, aktiv: s.aktiv })),
      plan.bundneTimer + plan.brukteTimer,
    )
    : null

  // Sammenligningen: siste tolv hele måneder, summert per stasjon.
  // Enkeltmåneder svinger for mye — en ferieuke eller et varemottak flytter
  // tallet nok til at rangeringen blir tilfeldig.
  const forbruk = new Map<string, { timer: number; kunder: number; oms: number; mat: number }>()
  for (const r of (forbrukRader ?? []) as {
    stasjon_id: string; maaned: string; timer: number; kunder: number
    omsetning: number; mat_omsetning: number
  }[]) {
    const f = forbruk.get(r.stasjon_id) ?? { timer: 0, kunder: 0, oms: 0, mat: 0 }
    f.timer += Number(r.timer ?? 0)
    f.kunder += Number(r.kunder ?? 0)
    f.oms += Number(r.omsetning ?? 0)
    f.mat += Number(r.mat_omsetning ?? 0)
    forbruk.set(r.stasjon_id, f)
  }
  const sammenligning = sammenlignStasjoner(alle.map((st) => {
    const f = forbruk.get(st.id) ?? { timer: 0, kunder: 0, oms: 0, mat: 0 }
    return {
      stasjonId: st.id,
      navn: st.navn,
      timer: f.timer,
      kunder: f.kunder,
      omsetning: f.oms,
      matOmsetning: f.mat,
    }
  }))

  const vakterPerDag = new Map<string, ReturnType<typeof vaktliste>>()
  for (const v of plan ? vaktliste(plan.timer) : []) {
    const liste = vakterPerDag.get(v.dato) ?? []
    liste.push(v)
    vakterPerDag.set(v.dato, liste)
  }

  return (
    <>
      <h1>Bemanning</h1>
      <p className="undertittel">
        Timerammen fordeles der kundene faktisk er. Du legger inn hvordan dere jobber fast —
        systemet fyller resten.
      </p>

      <section className="kort">
        <form className="rutine-form">
          <select name="stasjon" defaultValue={valgt.id}>
            {alle.map((s) => <option key={s.id} value={s.id}>{s.butikknummer} {s.navn}</option>)}
          </select>
          <select name="maned" defaultValue={maned}>
            {MND.map((m, i) => <option key={m} value={i + 1}>{m}</option>)}
          </select>
          <input name="ar" type="number" defaultValue={ar} style={{ width: '5rem' }} />
          <button type="submit" className="liten">Vis</button>
        </form>
      </section>

      <section className="kort">
        <h2>{MND[maned - 1]} {ar}</h2>
        {disponible === null ? (
          <p className="undertittel">
            Ingen ramme for denne måneden ennå. Eier må laste opp forretningsplanen på <a href="/import">/import</a>.
          </p>
        ) : aar && !aar.gjennomforbar ? (
          <p className="feil">
            Minimumsbemanningen koster {Math.round(aar.sumBundne)} timer i året — {Math.round(aar.underskudd)} mer
            enn hele årsrammen på {Math.round(aar.pool)}. Dette løses ikke ved å flytte timer mellom
            måneder. Enten må åpningstiden kortes ned, eller så er rammen for stram. Si ifra til eier.
          </p>
        ) : (
          <>
            <p><strong>{Math.round(disponible)} timer</strong> til disposisjon.</p>
            {iMnd && raaRamme !== null && Math.abs(disponible - raaRamme) >= 1 && (
              <p className="undertittel">
                {disponible > raaRamme
                  ? `Måneden låner ${Math.round(disponible - raaRamme)} timer fra resten av året — minimumsbemanningen her koster ${Math.round(iMnd.bundne)} timer, mer enn bruttokurven alene ville gitt.`
                  : `Måneden avgir ${Math.round(raaRamme - disponible)} timer til måneder med tyngre gulv.`}
              </p>
            )}
            {plan === null ? (
              <p className="undertittel">Legg inn bemannet vindu nedenfor, så regner jeg ut forslaget.</p>
            ) : (
              <p className="undertittel">
                {Math.round(plan.bundneTimer)} timer går til minimumsbemanning, timer som krever flere, og faste vakter.
                {' '}{Math.round(plan.brukteTimer)} er fordelt etter kundetrykk.
                {' '}Kundeformen er hentet fra {profilen.kilde} ({profilen.dager} dager).
              </p>
            )}
            {driftTekst && (
              <p className="undertittel">{driftTekst}</p>
            )}
            {aarsrammer.length > 0 && (
              <p className="undertittel">
                {malteMaaneder > 0
                  ? `Årets timer er fordelt utover månedene etter hvor mange kunder stasjonen faktisk hadde i ${ar - 1} (${malteMaaneder} av 12 måneder målt), ikke etter BP-kurven.`
                  : `Ingen kundehistorikk for ${ar - 1} ennå — fordelingen følger BP-kurven inntil videre.`}
              </p>
            )}
            {plan !== null && plan.fasteTimer >= 1 && (
              <p className="undertittel">
                Faste vakter bærer {Math.round(plan.fasteTimer)} timer i denne måneden. De
                belaster ikke timerammen, men de er arbeid — går de bort i ferie eller sykdom,
                må timene hentes et annet sted.
              </p>
            )}
            {plan !== null && plan.frieTimer - plan.brukteTimer >= 1 && (
              <p className="undertittel">
                {Math.round(plan.frieTimer - plan.brukteTimer)} timer er ikke fordelt — taket på{' '}
                {maksBemanning} er nådd i de timene kundene er der. Bruk dem på opplæring,
                vareflytting eller vask, eller gi dem tilbake.
              </p>
            )}
          </>
        )}
      </section>

      {plan && plan.gjennomforbar && (
        <section className="kort">
          <h2>Forslag, uke for uke</h2>
          <p className="undertittel">
            Tallet er antall personer den timen. * betyr at en fast vakt dekker en av dem.
            Røde dager er merket — de koster dobbelt, så en time der spiser to av rammen.
            Hold musen over for kundetrykket.
          </p>
          {uker.map((uke) => (
            <div key={uke.nr} className="bem-uke">
              <table className="tabell bem-kalender">
                <thead>
                  <tr>
                    <th></th>
                    {uke.profiler.map((p) => (
                      <th key={p.dato} className={p.type === 'rod' ? 'rod-dag' : undefined}>
                        {UKEDAG[p.ukedag]} {Number(p.dato.slice(8))}.
                        <br />
                        <span className="undertittel">
                          {p.navn
                            ? `${p.navn}${p.type === 'aften' ? ' (rød fra 15)' : ''}`
                            : `${Math.round(dagsum.get(p.dato) ?? 0)} t`}
                        </span>
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {timerVist.map((t) => (
                    <tr key={t}>
                      <td>{kl(t)}</td>
                      {uke.profiler.map((p) => {
                        const c = rutenett.get(`${p.dato}:${t}`)
                        if (!c) return <td key={p.dato} className="undertittel">—</td>
                        return (
                          <td
                            key={p.dato}
                            className={c.kostnad > 1 ? 'rod-time' : undefined}
                            title={`${Math.round(c.kunder)} kunder i snitt`
                              + (c.kostnad > 1 ? ' · dobbel lønn' : '')}
                          >
                            {c.sum}{c.fast > 0 ? '*' : ''}
                          </td>
                        )
                      })}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ))}
          <h3 className="bem-vakt-tittel">Vaktene dette blir</h3>
          <p className="undertittel">
            Samme plan, lest som en timeplan. Overlapper to vakter, står det tre personer
            i rutenettet over den timen — det er et vaktbytte, ikke tre som må skaffes.
          </p>
          <table className="tabell">
            <thead><tr><th>Dag</th><th>Grunnbemanning</th><th>I tillegg</th><th>Timer</th></tr></thead>
            <tbody>
              {profiler.map((p) => {
                const v = vakterPerDag.get(p.dato) ?? []
                if (v.length === 0) return null
                const tid = (x: { fraTime: number; tilTime: number }) =>
                  `${kl(x.fraTime)}–${x.tilTime === 24 ? '24:00' : kl(x.tilTime)}`
                return (
                  <tr key={p.dato} className={p.type === 'rod' ? 'rod-dag' : undefined}>
                    <td>
                      {UKEDAG[p.ukedag]} {Number(p.dato.slice(8))}.
                      {p.navn ? <><br /><span className="undertittel">{p.navn}</span></> : null}
                    </td>
                    <td>{v.filter((x) => x.kilde === 'gulv').map(tid).join(' · ') || '—'}</td>
                    <td>{v.filter((x) => x.kilde === 'ekstra').map(tid).join(' · ') || '—'}</td>
                    <td>{Math.round(dagsum.get(p.dato) ?? 0)}</td>
                  </tr>
                )
              })}
            </tbody>
          </table>
          {plan.rodtPaaslag >= 1 && (
            <p className="undertittel">
              De røde timene denne måneden koster <strong>{Math.round(plan.rodtPaaslag)} timer
              ekstra</strong> av rammen, fordi de betales med 100 % tillegg. Det er allerede
              trukket fra før resten ble fordelt.
            </p>
          )}
          {profiler.some((p) => p.navn && p.grunnlag === 0) && (
            <p className="undertittel">
              {profiler.filter((p) => p.navn && p.grunnlag === 0).map((p) => p.navn).join(', ')}
              {' '}har vi ikke sett før i tallene deres — bemanningen der er et anslag fra de
              andre røde dagene, ikke en måling.
            </p>
          )}
        </section>
      )}

      {avvik && (avvik.overforbruk >= 1 || avvik.underforbruk >= 1) && (
        <section className="kort">
          <h2>Planen mot det som faktisk skjedde</h2>
          <p className="undertittel">
            Kun dagene som har vært. Over- og underforbruk står hver for seg med vilje —
            to timer for mye tirsdag og to for lite mandag er ikke riktig bemannet, det er
            to feil som skjuler hverandre.
          </p>
          <p>
            <strong>{Math.round(avvik.faktiskeTimer)} timer</strong> stemplet mot{' '}
            <strong>{Math.round(avvik.planlagteTimer)}</strong> planlagt.
            {' '}{Math.round(avvik.overforbruk)} timer over, {Math.round(avvik.underforbruk)} under.
          </p>
          {avvik.verstetimer.length > 0 && (
            <p className="undertittel">
              Går igjen på klokkeslettet:{' '}
              {avvik.verstetimer.map((t) =>
                `${kl(t.time)} (${t.avvik > 0 ? '+' : ''}${Math.round(t.avvik)} t)`).join(', ')}.
              {' '}Det er et mønster i vaktoppsettet, ikke enkeltdager.
            </p>
          )}
          {avvik.verstedager.length > 0 && (
            <p className="undertittel">
              Dagene som ligger lengst unna:{' '}
              {avvik.verstedager.map((d) =>
                `${Number(d.dato.slice(8))}. (${d.avvik > 0 ? '+' : ''}${Math.round(d.avvik)} t)`).join(', ')}.
            </p>
          )}
        </section>
      )}

      <section className="kort">
        <h2>Når står det folk i butikken?</h2>
        <p className="undertittel">
          Når står det folk der — ikke når døra åpner. Begynner noen en time før åpning, er det den
          timen som skal stå. Endrer dere åpningstid permanent, legg inn en ny rad med dato fra
          endringen; den gamle blir stående som historikk.
        </p>
        <VinduSkjema stasjonId={valgt.id} iDag={iDag} />
        {alleVinduer.length > 0 && (
          <table className="tabell">
            <thead><tr><th>Dag</th><th>Fra</th><th>Til</th><th>Min.</th><th>Gjelder fra</th><th></th></tr></thead>
            <tbody>
              {alleVinduer.map((v) => (
                <tr key={v.id} style={{ opacity: v.gjelder_fra > iDag ? 0.5 : 1 }}>
                  <td>{UKEDAG[v.ukedag]}</td>
                  <td>{kl(v.fra_time)}</td>
                  <td>{kl(v.til_time)}</td>
                  <td>{v.min_bemanning}</td>
                  <td>{v.gjelder_fra}</td>
                  <td>
                    <form action={slettVindu}>
                      <input type="hidden" name="id" value={v.id} />
                      <button type="submit" className="liten slett">Slett</button>
                    </form>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </section>

      <section className="kort">
        <h2>Hvor mange får plass?</h2>
        <p className="undertittel">
          Flest personer planen har lov å foreslå i én time. Har dere to kasser, er det ingen
          vits i sju. Uten tak fordeles hele rammen etter kundetrykk, og da havner slakken på
          den travleste dagen. Står feltet tomt, er det intet tak.
        </p>
        <TakSkjema stasjonId={valgt.id} naa={grenser?.maks_bemanning ?? null} />
      </section>

      {sammenligning.some((s) => s.vurdering !== 'for lite data') && (
        <section className="kort">
          <h2>Stasjonene mot hverandre</h2>
          <p className="undertittel">
            Siste halvannet år. En stasjon alene sier ingenting om den bruker for mange timer —
            målestokken er de andre. Mat teller med, fordi tilberedt mat tar lengst tid: to
            stasjoner med like mange kunder kan ha helt ulikt arbeid.
          </p>
          <table className="tabell">
            <thead>
              <tr>
                <th>Stasjon</th><th>Timer</th><th>Timer per 100 kunder</th>
                <th>Matandel</th><th>Vurdering</th>
              </tr>
            </thead>
            <tbody>
              {[...sammenligning]
                .sort((a, b) => b.timerPer100Kunder - a.timerPer100Kunder)
                .map((s) => (
                  <tr key={s.stasjonId} className={s.stasjonId === valgt.id ? 'valgt-rad' : undefined}>
                    <td>{s.navn}</td>
                    <td>{Math.round(s.timer)}</td>
                    <td>{s.timerPer100Kunder.toFixed(1)}</td>
                    <td>{Math.round(s.matandel * 100)} %</td>
                    <td>
                      <strong>{s.vurdering}</strong>
                      <br />
                      <span className="undertittel">{s.begrunnelse}</span>
                    </td>
                  </tr>
                ))}
            </tbody>
          </table>
        </section>
      )}

      <section className="kort">
        <h2>Ferie og fravær</h2>
        <p className="undertittel">
          Er en fast vakt borte, dekker den ikke minimumsbemanningen lenger, og timene må
          kjøpes av rammen. Fem ukers ferie <strong>henter</strong> timer — den sparer dem ikke.
        </p>
        <FravaerSkjema stasjonId={valgt.id} navn={[...new Set(vaktListe.map((v) => v.navn))]} />
        {fravaerListe.length > 0 && (
          <table className="tabell">
            <thead><tr><th>Hvem</th><th>Fra</th><th>Til</th><th>Hvorfor</th><th></th></tr></thead>
            <tbody>
              {fravaerListe.map((f) => (
                <tr key={f.id}>
                  <td>{f.navn}</td>
                  <td>{f.fra_dato}</td>
                  <td>{f.til_dato}</td>
                  <td>{f.arsak ?? '—'}</td>
                  <td>
                    <form action={slettFravaer}>
                      <input type="hidden" name="id" value={f.id} />
                      <button type="submit" className="liten slett">Slett</button>
                    </form>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </section>

      {stillinger.length > 0 && (
        <section className="kort">
          <h2>Hvor mye går folk i?</h2>
          <p className="undertittel">
            Anslått fra stemplingene — medianmåneden, så ferie og sykdom ikke drar tallet ned.
            Står feltet tomt, gjelder anslaget. Skriver du et tall, er det ditt, og systemet
            regner aldri over det.
          </p>
          {kap && (
            <p>
              <strong>{Math.round(kap.tilgjengelig)} timer</strong> i stillinger mot{' '}
              <strong>{Math.round(kap.planlagt)}</strong> planlagt.
              {kap.dekning < 0.95
                ? ' Stillingene rekker ikke — noen må ta ekstravakter uansett hvor god planen er.'
                : kap.dekning > 1.15
                  ? ' Det er mer stilling enn plan — noen får ikke timene sine denne måneden.'
                  : ' Det går opp.'}
            </p>
          )}
          <table className="tabell">
            <thead>
              <tr><th>Navn</th><th>Median/mnd</th><th>Anslag</th><th>Bekreftet</th><th>Grunnlag</th></tr>
            </thead>
            <tbody>
              {stillinger.map((s) => (
                <tr key={s.ansattNr} className={s.aktiv ? undefined : 'undertittel'}>
                  <td>{s.navn}{s.aktiv ? '' : ' (sluttet?)'}</td>
                  <td>{Math.round(s.medianMnd)} t</td>
                  <td>{s.anslagProsent} %</td>
                  <td>
                    <StillingSkjema
                      stasjonId={valgt.id}
                      ansattNr={s.ansattNr}
                      navn={s.navn}
                      lagret={s.lagret}
                      anslag={s.anslagProsent}
                    />
                  </td>
                  <td className="undertittel">
                    {s.maaneder} {s.maaneder === 1 ? 'måned' : 'måneder'}
                    {s.maaneder < 3 ? ' — tynt' : ''}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      )}

      <section className="kort">
        <h2>Faste vakter</h2>
        <p className="undertittel">
          Deg selv, NK, eller andre som alltid står. De går på fastlønn og bruker ikke av timerammen,
          men dekker minimumsbemanningen i timene de står. En timelønnet NK med fast vakt hører
          også hjemme her — velg da timelønn, så trekkes timene fra rammen selv om vakten er fast.
        </p>
        <FastVaktSkjema stasjonId={valgt.id} />
        {vaktListe.length > 0 && (
          <table className="tabell">
            <thead><tr><th>Hvem</th><th>Dag</th><th>Fra</th><th>Til</th><th>Lønn</th><th></th></tr></thead>
            <tbody>
              {vaktListe.map((v) => (
                <tr key={v.id}>
                  <td>{v.navn}</td>
                  <td>{UKEDAG[v.ukedag]}</td>
                  <td>{kl(v.fra_time)}</td>
                  <td>{kl(v.til_time)}</td>
                  <td>{v.timelonnet ? 'Timelønn' : 'Fastlønn'}</td>
                  <td>
                    <form action={slettFastVakt}>
                      <input type="hidden" name="id" value={v.id} />
                      <button type="submit" className="liten slett">Slett</button>
                    </form>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </section>

      <section className="kort">
        <h2>Timer der én ikke holder</h2>
        <p className="undertittel">
          Varemottak, eller andre timer der én ikke holder. Uten en rad her foreslås aldri to
          personer på en rolig time — de ekstra hendene går dit kundene faktisk er.
        </p>
        <KravSkjema stasjonId={valgt.id} />
        {kravListe.length > 0 && (
          <table className="tabell">
            <thead><tr><th>Dag</th><th>Fra</th><th>Til</th><th>Antall</th><th>Hvorfor</th><th></th></tr></thead>
            <tbody>
              {kravListe.map((k) => (
                <tr key={k.id}>
                  <td>{UKEDAG[k.ukedag]}</td>
                  <td>{kl(k.fra_time)}</td>
                  <td>{kl(k.til_time)}</td>
                  <td>{k.antall}</td>
                  <td>{k.begrunnelse ?? '—'}</td>
                  <td>
                    <form action={slettKrav}>
                      <input type="hidden" name="id" value={k.id} />
                      <button type="submit" className="liten slett">Slett</button>
                    </form>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </section>
    </>
  )
}
