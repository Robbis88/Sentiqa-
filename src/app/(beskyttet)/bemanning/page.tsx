import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import {
  fordelAaret, planleggKalender, maanedsvekter,
  vaktliste,
  type Krav, type Vindu, type FastVakt, type Dagsvekt,
} from '@/lib/bemanning'
import { dagsprofiler, datoerIMaaned, ukerIMaaned } from '@/lib/dagtyper'
import {
  formendring, formendringTekst, justerProfil, kapasitet, planMotFaktisk,
  sammenlignStasjoner, stillingsanslag, takFraUkeprofil,
} from '@/lib/bemanningsanalyse'
import { borteTimerPerMaaned, plandekning } from '@/lib/ansatt/plandekning'
import {
  FastVaktSkjema, FravaerSkjema, KravSkjema, StillingSkjema, TakSkjema, VinduSkjema,
} from './skjemaer'
import { slettFastVakt, slettFravaer, slettKrav, slettVindu } from './handlinger'
import { husketStasjon } from '@/lib/stasjonskontekst'
import { nesteSteg } from '@/lib/bemanningssteg'
import { Sidehode, Tomtilstand, Forklaring } from '@/components/ui/side'
import { Sidepanel } from '@/components/ui/sidepanel'
import { Signal, Status } from '@/components/ui/status'
import { Liste, Rad } from '@/components/ui/liste'
import { Knapp } from '@/components/ui/knapp'
import { Felt, Velg } from '@/components/ui/felt'
import Link from 'next/link'

const UKEDAG = ['', 'man', 'tir', 'ons', 'tor', 'fre', 'lør', 'søn']
const MND = ['januar', 'februar', 'mars', 'april', 'mai', 'juni',
  'juli', 'august', 'september', 'oktober', 'november', 'desember']
const kl = (t: number) => `${String(t).padStart(2, '0')}:00`

type Sok = Promise<{ stasjon?: string; ar?: string; maned?: string; uke?: string }>

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

// Stemplingene: hva stasjonen FAKTISK har hatt på jobb.
//
// Aggregert i basen, ikke her. Første versjon hentet rå stemplingsrader —
// PostgREST kutter på 1000, og Dale har flere tusen. Taket,
// helligdagsfaktorene, stillingsanslaget og plan-mot-virkelighet ble da
// alle bygget på et tilfeldig utvalg. Ingen av dem feilet; de svarte bare
// litt galt, stille, helt til stillingslisten ble tom.
async function hentUkeprofil(
  supabase: Awaited<ReturnType<typeof lagSupabaseServerKlient>>,
  stasjonId: string,
) {
  const { data } = await supabase
    .from('v_stempling_ukeprofil')
    .select('ukedag, time, antall, ganger')
    .eq('stasjon_id', stasjonId)
  return (data ?? []) as { ukedag: number; time: number; antall: number; ganger: number }[]
}

// Faktisk bemanning per dato og time — bare for måneden vi ser på.
async function hentFaktisk(
  supabase: Awaited<ReturnType<typeof lagSupabaseServerKlient>>,
  stasjonId: string,
  fra: string,
  til: string,
) {
  const { data } = await supabase
    .from('v_stempling_time')
    .select('dato, time, antall')
    .eq('stasjon_id', stasjonId)
    .gte('dato', fra)
    .lte('dato', til)
  const ut = new Map<string, number>()
  for (const r of (data ?? []) as { dato: string; time: number; antall: number }[]) {
    ut.set(`${r.dato}:${r.time}`, r.antall)
  }
  return ut
}

// Timer per ansatt per måned. Grunnlaget for stillingsanslaget.
async function hentAnsattmaaneder(
  supabase: Awaited<ReturnType<typeof lagSupabaseServerKlient>>,
  stasjonId: string,
  fra: string,
) {
  const { data } = await supabase
    .from('v_stempling_ansatt_mnd')
    .select('ansatt_nr, ansatt_navn, maaned, timer')
    .eq('stasjon_id', stasjonId)
    .gte('maaned', fra)
  return (data ?? []) as
    { ansatt_nr: string; ansatt_navn: string; maaned: string; timer: number }[]
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

  // Stasjonen velges i toppstripen og huskes. URL-en vinner fortsatt,
  // saa en delt lenke viser det den lovet.
  const valgtId = await husketStasjon(alle, sok.stasjon)
  const valgt = alle.find((s) => s.id === valgtId) ?? alle[0]
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

  // Maaneden som ISO-datoer, for periodefiltrene under.
  const forsteDagIMnd = `${ar}-${String(maned).padStart(2, '0')}-01`
  const sisteDagIMnd = new Date(Date.UTC(ar, maned, 0)).toISOString().slice(0, 10)
  const iDag = naa.toISOString().slice(0, 10)

  const [{ data: rammer }, { data: vinduer }, { data: krav }, { data: vakter },
    { data: grenser }, profilen, maanedskunder, dagskunder, ukeprofil, faktisk, ansattMnd,
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
      // BARE VAKTENE SOM GJALDT DEN MAANEDEN. For 0123 hadde faste
      // vakter ingen periode, saa mars ble planlagt med dagens vakter -
      // og en butikksjef i permisjon i vaar sto likevel oppfoert som
      // dekning. Perioden maa OVERLAPPE maaneden: en vakt som sluttet
      // 15. mars gjaldt i mars.
      supabase.from('bemanning_fast_vakt')
        .select('id, navn, ukedag, fra_time, til_time, timelonnet, gjelder_fra, gjelder_til')
        .eq('stasjon_id', valgt.id)
        .lte('gjelder_fra', sisteDagIMnd)
        .or(`gjelder_til.is.null,gjelder_til.gte.${forsteDagIMnd}`)
        .order('navn').order('ukedag'),
      supabase.from('bemanning_stasjon').select('maks_bemanning')
        .eq('stasjon_id', valgt.id).maybeSingle<{ maks_bemanning: number | null }>(),
      hentProfil(supabase, valgt.id, ar, maned),
      hentMaanedskunder(supabase, valgt.id, ar),
      // To år tilbake: da har vi hver røde dag minst én gang, ofte to.
      hentDagskunder(supabase, valgt.id, `${ar - 2}-01-01`),
      hentUkeprofil(supabase, valgt.id),
      hentFaktisk(supabase, valgt.id, `${ar}-${String(maned).padStart(2, '0')}-01`,
        `${ar}-${String(maned).padStart(2, '0')}-31`),
      hentAnsattmaaneder(supabase, valgt.id, `${ar - 2}-01-01`),
      // Samme kalenderperiode to år på rad. Stasjonene endrer seg hele
      // tiden, og en plan som arver fjorårets form uten å se etter om den
      // fortsatt stemmer, blir gradvis feil uten at noen merker det.
      hentDognkurve(supabase, valgt.id, `${ar - 1}-01-01`, `${ar - 1}-${forrigeMnd}-28`),
      hentDognkurve(supabase, valgt.id, `${ar}-01-01`, `${ar}-${forrigeMnd}-28`),
      supabase.from('ansatt_avtale')
        .select('ansatt_nr, navn, stillingsprosent, har_rammeavtale, lonnsform')
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
  const tak = ukeprofil.length > 0 ? takFraUkeprofil(ukeprofil) : undefined

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

  // Én uke om gangen. En hel måned nedover er ikke noe man planlegger
  // etter — man setter opp én uke, så neste.
  const ukeDatoer = ukerIMaaned(ar, maned)
  const perDato = new Map(profiler.map((p) => [p.dato, p]))
  const alleUker = ukeDatoer.map((datoer, i) => ({
    nr: i + 1,
    profiler: datoer.map((d) => perDato.get(d)!).filter(Boolean),
  }))
  // Standard er uka vi står i, ikke den første i måneden.
  const iDagsUke = alleUker.findIndex((u) => u.profiler.some((p) => p.dato >= iDag)) + 1
  const valgtUkeNr = Math.min(
    alleUker.length,
    Math.max(1, Number(sok.uke) || (iDagsUke > 0 ? iDagsUke : 1)),
  )
  const uker = alleUker.filter((u) => u.nr === valgtUkeNr)
  const ukeLenke = (nr: number) =>
    `?stasjon=${valgt.id}&ar=${ar}&maned=${maned}&uke=${nr}`
  const ukeSpenn = (u: (typeof alleUker)[number]) => {
    const f = u.profiler[0]
    const t = u.profiler[u.profiler.length - 1]
    return `${Number(f.dato.slice(8))}.–${Number(t.dato.slice(8))}. ${MND[maned - 1]}`
  }
  const dagsum = new Map<string, number>()
  for (const t of plan?.timer ?? []) dagsum.set(t.dato, (dagsum.get(t.dato) ?? 0) + t.sum)
  // Vaktene, ikke tallene. «3 personer klokka 12» kan ingen sette opp;
  // «10–15 og 11–16» er en timeplan.
  // Plan mot virkelighet. Bare for dager som har vært — en plan for
  // september kan ikke måles mot stemplinger som ikke finnes ennå.
  const gaatt = plan?.timer.filter((t) => t.dato < iDag) ?? []
  const avvik = gaatt.length > 0 && faktisk.size > 0 ? planMotFaktisk(gaatt, faktisk) : null

  // Stillingsprosent: anslått fra stemplingene, overstyrt av det
  // butikksjefen har bekreftet. Et lagret tall er et menneskes ord og
  // skal aldri overskrives av en ny beregning.
  const avtaleRader = (avtaler ?? []) as {
    ansatt_nr: string; navn: string; stillingsprosent: number | null
    har_rammeavtale: boolean; lonnsform: string | null
  }[]
  const lagredeAvtaler = new Map(avtaleRader.map((a) => [a.ansatt_nr, a]))
  const anslag = stillingsanslag(
    ansattMnd.map((a) => ({
      ansattNr: a.ansatt_nr, navn: a.ansatt_navn, dato: a.maaned, timer: Number(a.timer),
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

  // Kontraktdekningen: bærer PAPIRENE planen, ikke bare menneskene?
  //
  // Planen kan godt være gjennomførbar — stasjonen ringer noen inn, alle
  // stiller opp, gulvet blir dekket. Regningen kommer et annet sted: de
  // timene ble jobbet uten at kontrakten dekket dem, og etter § 14-4 a
  // kan de senere kreves som fast stilling.
  //
  // Bare bekreftede stillingsprosenter teller. Anslaget fra stemplingene
  // duger til å planlegge med, men ikke til å svare på om papirene
  // holder — anslaget ER jo nettopp timene som kanskje manglet dekning.
  const timelonnede = avtaleRader
    .filter((a) => a.lonnsform !== 'fastlonn' && a.lonnsform !== 'tilkalling')
    .map((a) => ({
      ansattNr: a.ansatt_nr,
      navn: a.navn,
      kontraktProsent: a.stillingsprosent,
      harRammeavtale: a.har_rammeavtale,
    }))
  const borte = borteTimerPerMaaned(
    fravaerListe.map((f) => ({ navn: f.navn, fraDato: f.fra_dato, tilDato: f.til_dato })),
    timelonnede,
    ar,
  )
  const dekning = aar && timelonnede.length > 0
    ? plandekning(timelonnede, aar.maaneder.map((m) => ({
      maned: m.maned,
      timer: m.disponible,
      borteTimer: borte.get(m.maned) ?? 0,
    })))
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

  // NIVÅ 1 og 2 på en arbeidsflyt: hvor langt er jeg kommet, og hva
  // stopper meg. Siden hadde fem tilstander som hver gjør planen
  // ubrukelig, spredt over tretten seksjoner — manglende vindu som en
  // setning i seksjon tre mens skjemaet lå i seksjon seks, og
  // kontraktunderdekningen i seksjon elleve. Rekkefølgen mellom dem er
  // testet i bemanningssteg.test.ts.
  const steg = nesteSteg({
    harRamme: disponible !== null,
    gjennomforbar: aar?.gjennomforbar ?? true,
    underskudd: aar?.underskudd ?? 0,
    harVindu: gjeldende.size > 0,
    disponible,
    kontraktTiltak: dekning?.tiltak ?? null,
    kontraktUdekket: dekning?.sumUdekket ?? 0,
    stillingsdekning: kap?.dekning ?? null,
  })

  return (
    <>
      <Sidehode
        tittel="Bemanning"
        undertittel={`${steg.tittel}. ${MND[maned - 1]} ${ar} · ${valgt.butikknummer} ${valgt.navn}`}
        handlinger={
          <form className="sq-listetopp">
            <Velg etikett="Måned" name="maned" defaultValue={maned} skjultEtikett>
              {MND.map((m, i) => <option key={m} value={i + 1}>{m}</option>)}
            </Velg>
            <Felt
              etikett="År" name="ar" type="number" defaultValue={ar}
              skjultEtikett className="sq-smalt-felt"
            />
            <Knapp type="submit">Vis</Knapp>
          </form>
        }
      />

      {/* NIVÅ 2 — det ene neste steget. Ikke fem likeverdige knapper. */}
      {/* NIVAA 1: hva stopper meg. Dette ER definisjonen paa et signal -
          systemet har regnet ut at noe hindrer planen, og sier hva.
          `nesteSteg` rangerer de fem blokkeringene (bemanningssteg.ts);
          det som er nytt er at alvoret staar i NIVAAET og ikke bare i
          en kortkant, og at veien videre ligger i signalet.

          `stopper` betyr at planen ikke kan lages i det hele tatt -
          derfor `kritisk`. De ovrige er ting som gjor forslaget
          daarligere, ikke umulig. */}
      {steg.blokkering !== 'klar' && (
        <Signal
          nivaa={steg.stopper ? 'kritisk' : 'oppmerksomhet'}
          tittel={steg.tittel}
          handling={steg.handling === 'import'
            ? <Link href="/import" className="sq-knapp primar">Gå til Import</Link>
            : undefined}
        >
          {steg.forklaring}
        </Signal>
      )}

      {plan && plan.gjennomforbar && (
        <section>
          <h2>Forslag for uke {valgtUkeNr}</h2>
          <nav className="bem-ukevelger" aria-label="Bytt uke">
            {alleUker.map((u) => (
              <a
                key={u.nr}
                href={ukeLenke(u.nr)}
                className={u.nr === valgtUkeNr ? 'valgt' : undefined}
                aria-current={u.nr === valgtUkeNr ? 'page' : undefined}
              >
                {ukeSpenn(u)}
                {u.profiler.some((p) => p.navn) && <span className="rod-prikk" aria-label="rød dag"> ●</span>}
              </a>
            ))}
          </nav>
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
                          // DOBBEL LONN STO BARE SOM EN SVAK ROED FLATE og
                          // en tittel-tekst. Tittelen finnes ikke paa
                          // beroring, og skjermlesere leser den ikke
                          // paalitelig - saa for den som ikke saa fargen,
                          // fantes ikke opplysningen. Naa staar det et
                          // merke i cella, og fargen forsterker det.
                          <td
                            key={p.dato}
                            className={c.kostnad > 1 ? 'rod-time' : undefined}
                            title={`${Math.round(c.kunder)} kunder i snitt`
                              + (c.kostnad > 1 ? ' · dobbel lønn' : '')}
                          >
                            {c.sum}{c.fast > 0 ? '*' : ''}
                            {c.kostnad > 1 && (
                              <abbr className="bem-dyr" title="Dobbel lønn denne timen">kr²</abbr>
                            )}
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
              {(uker[0]?.profiler ?? []).map((p) => {
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

      {/* NIVÅ 3 — hva systemet foreslår, og hvorfor. Dette sto ØVER planen
          før: man møtte regnestykket bak forslaget før forslaget. */}
      {disponible !== null && plan !== null && (
        <section>
          <h2>Slik er timene fordelt</h2>
          <p>
            <strong>{Math.round(disponible)} timer</strong> til disposisjon i {MND[maned - 1]}.
            {' '}{Math.round(plan.bundneTimer)} går til minimumsbemanning, timer som krever
            flere, og faste vakter. {Math.round(plan.brukteTimer)} er fordelt etter kundetrykk.
          </p>
          {iMnd && raaRamme !== null && Math.abs(disponible - raaRamme) >= 1 && (
            <p className="undertittel">
              {disponible > raaRamme
                ? `Måneden låner ${Math.round(disponible - raaRamme)} timer fra resten av året — minimumsbemanningen her koster ${Math.round(iMnd.bundne)} timer, mer enn bruttokurven alene ville gitt.`
                : `Måneden avgir ${Math.round(raaRamme - disponible)} timer til måneder med tyngre gulv.`}
            </p>
          )}
          {plan.fasteTimer >= 1 && (
            <p className="undertittel">
              Faste vakter bærer {Math.round(plan.fasteTimer)} timer i denne måneden. De
              belaster ikke timerammen, men de er arbeid — går de bort i ferie eller sykdom,
              må timene hentes et annet sted.
            </p>
          )}
          {plan.frieTimer - plan.brukteTimer >= 1 && (
            <p className="undertittel">
              {Math.round(plan.frieTimer - plan.brukteTimer)} timer er ikke fordelt — taket på{' '}
              {maksBemanning} er nådd i de timene kundene er der. Bruk dem på opplæring,
              vareflytting eller vask, eller gi dem tilbake.
            </p>
          )}

          <Forklaring sporsmaal="Hvor kommer formen fra?">
            <p>
              Kundeformen er hentet fra {profilen.kilde} ({profilen.dager} dager). Samme måned
              i fjor er riktigst — januar planlegges ikke etter septembertall. Finnes den ikke,
              brukes siste 90 dager, og da er formen sesongforskjøvet.
            </p>
            {aarsrammer.length > 0 && (
              <p>
                {malteMaaneder > 0
                  ? `Årets timer er fordelt utover månedene etter hvor mange kunder stasjonen faktisk hadde i ${ar - 1} (${malteMaaneder} av 12 måneder målt), ikke etter BP-kurven. BP-bruttoen er formet av hva stasjonen gjorde i fjor, inkludert timene butikksjefen brukte fordi hun hadde dem; kundene er formet av hvem som faktisk kom.`
                  : `Ingen kundehistorikk for ${ar - 1} ennå — fordelingen følger BP-kurven inntil videre.`}
              </p>
            )}
            {driftTekst && <p>{driftTekst}</p>}
          </Forklaring>
        </section>
      )}

      {avvik && (avvik.overforbruk >= 1 || avvik.underforbruk >= 1) && (
        <section>
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

      {sammenligning.some((s) => s.vurdering !== 'for lite data') && (
        <section>
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

      {stillinger.length > 0 && (
        <section>
          <h2>Hvor mye går folk i?</h2>
          <p className="undertittel">
            Anslått fra stemplingene — medianmåneden, så ferie og sykdom ikke drar tallet ned.
            Merk at dette er <strong>arbeidede</strong> timer, ikke kontrakt: ekstravakter og
            vikartimer teller med, så en som dekker for en sykemeldt ser større ut enn hun er.
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
                    {s.merknad ? <><br />{s.merknad}</> : null}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      )}

      {dekning && (
        <section>
          <h2>Bærer kontraktene planen?</h2>
          <p className="undertittel">
            Det forrige spørsmålet var om det finnes folk nok. Dette er om det finnes{' '}
            <strong>papir</strong> nok. Planen kan gå opp likevel — noen ringes inn, alle
            stiller opp, gulvet blir dekket — og regningen kommer et helt annet sted:
            timene ble jobbet uten at kontrakten dekket dem. Målt på hele året, fordi
            forskjellen på en travel måned og en sesong er nettopp hvor mange måneder
            det er.
          </p>

          <div
            className={`varsel ${dekning.tiltak === 'ny_stilling' ? 'rod'
              : dekning.tiltak === 'dekket' ? '' : 'gul'}`}
          >
            <span className="varsel-dott" aria-hidden />
            <div className="varsel-tekst">
              <div className="varsel-topp">
                <strong>
                  {dekning.tiltak === 'dekket' ? 'Kontraktene dekker planen'
                    : dekning.tiltak === 'ramme' ? 'Rammeavtale om tilkalling'
                      : dekning.tiltak === 'midlertidig' ? 'Midlertidige avtaler for sesongen'
                        : dekning.tiltak === 'ny_stilling' ? 'Stillingene er for små'
                          : 'Ikke nok bekreftede stillinger til å svare'}
                </strong>
                {dekning.sumUdekket > 0 && (
                  <span className="varsel-omfang">
                    {Math.round(dekning.sumUdekket)} timer i året
                  </span>
                )}
              </div>
              <p className="varsel-detalj">{dekning.melding}</p>
            </div>
          </div>

          {dekning.korte.length > 0 && (
            <div className="tabellramme sq-luft-over-liten">
              <table className="tabell">
                <thead>
                  <tr>
                    <th>Måned</th>
                    <th className="tall">Planen trenger</th>
                    <th className="tall">Kontrakter dekker</th>
                    <th className="tall">Udekket</th>
                  </tr>
                </thead>
                <tbody>
                  {dekning.maaneder.filter((m) => m.udekket > 0).map((m) => (
                    <tr key={m.maned} className={m.maned === dekning.verstMaaned ? 'valgt-rad' : undefined}>
                      <td>{MND[m.maned - 1]}</td>
                      <td className="tall">{Math.round(m.behov)} t</td>
                      <td className="tall">{Math.round(m.kapasitet)} t</td>
                      <td className="tall">{Math.round(m.udekket)} t</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}

          {dekning.utenKontrakt.length > 0 && (
            <p className="notis sq-tett">
              Uten bekreftet stillingsprosent: {dekning.utenKontrakt.join(', ')}. Bekreft
              dem i tabellen over — så lenge de står tomme, er kapasiteten et anslag bygget
              på nettopp de timene som kanskje manglet dekning.
            </p>
          )}
        </section>
      )}

      {/* NIVÅ 4 — grunnlaget bak forslaget.
          De fem skjemaene sto spredt mellom analysene, hvert med et tomt
          skjema over sin egen tabell. Nå leder hver seksjon med det som
          FAKTISK er satt opp, og skjemaet ligger bak en knapp. Forklaringene
          er beholdt ordrett — de er sidens beste tekst. */}
      <h2 className="bem-oppsett-tittel">Oppsett</h2>
      <p className="undertittel">
        Slik jobber dere fast. Planen fyller resten. Endrer noe seg her, regnes forslaget
        over på nytt med en gang.
      </p>

      <section>
        <h3>Når står det folk i butikken?</h3>
        <p className="undertittel">
          Når står det folk der — ikke når døra åpner. Begynner noen en time før åpning, er det den
          timen som skal stå. Endrer dere åpningstid permanent, legg inn en ny rad med dato fra
          endringen; den gamle blir stående som historikk.
        </p>
        {/* OBJEKTER, IKKE EN MATRISE. Ingen leser «fra»-kolonnen mot
            «min.»-kolonnen; man leter etter EN rad og retter eller
            sletter den.

            «Gjelder fra i framtida» sto som halv gjennomsiktighet - en
            inline-stil, og en tilstand baaret av opasitet alene. Naa
            staar det som tilstand med ord. */}
        {alleVinduer.length > 0 ? (
          <Liste merkelapp="Bemannede vinduer">
            {alleVinduer.map((v) => (
              <Rad
                key={v.id}
                primaer={`${UKEDAG[v.ukedag]} ${kl(v.fra_time)}–${kl(v.til_time)}`}
                sekundaer={`minst ${v.min_bemanning} på jobb · gjelder fra ${v.gjelder_fra}`}
                status={v.gjelder_fra > iDag
                  ? <Status nivaa="endring">Trer i kraft senere</Status>
                  : undefined}
                handlinger={(
                  <form action={slettVindu}>
                    <input type="hidden" name="id" value={v.id} />
                    <Knapp type="submit" variant="destruktiv" liten>Slett</Knapp>
                  </form>
                )}
              />
            ))}
          </Liste>
        ) : (
          <Tomtilstand
            tittel="Ingen bemannede vinduer"
            forklaring="Dette er det eneste planen ikke kan gjettes fram til. Uten minst én rad regnes det ikke ut noe forslag i det hele tatt."
          />
        )}
        <div className="knapperad">
          <Sidepanel knapp="Nytt vindu" tittel="Nytt bemannet vindu" beskrivelse="Én rad per ukedag. Minimumsbemanning er hvor mange som må stå der uansett hvor stille det er.">
            <VinduSkjema stasjonId={valgt.id} iDag={iDag} />
          </Sidepanel>
        </div>
      </section>

      <section>
        <h3>Hvor mange får plass?</h3>
        <p className="undertittel">
          Flest personer planen har lov å foreslå i én time. Har dere to kasser, er det ingen
          vits i sju. Uten tak fordeles hele rammen etter kundetrykk, og da havner slakken på
          den travleste dagen. Står feltet tomt, er det intet tak.
        </p>
        <p>
          {maksBemanning != null
            ? <>Taket er <strong>{maksBemanning}</strong> personer i timen.</>
            : <span className="undertittel">Intet tak satt — hele rammen fordeles etter kundetrykk.</span>}
        </p>
        <TakSkjema stasjonId={valgt.id} naa={grenser?.maks_bemanning ?? null} />
      </section>

      <section>
        <h3>Faste vakter</h3>
        <p className="undertittel">
          Deg selv, NK, eller andre som alltid står. De går på fastlønn og bruker ikke av timerammen,
          men dekker minimumsbemanningen i timene de står. En timelønnet NK med fast vakt hører
          også hjemme her — velg da timelønn, så trekkes timene fra rammen selv om vakten er fast.
        </p>
        {/* LONNSFORMEN ER DET SOM BETYR NOE HER: en timelonnet fast vakt
            trekkes fra rammen, en fastlonnet gjor det ikke. Den sto som
            en kolonne blant fem; naa staar den som tilstand, fordi det
            er den som avgjor om vakten koster av timene dine. */}
        {vaktListe.length > 0 ? (
          <Liste merkelapp="Faste vakter">
            {vaktListe.map((v) => (
              <Rad
                key={v.id}
                primaer={v.navn}
                sekundaer={`${UKEDAG[v.ukedag]} ${kl(v.fra_time)}–${kl(v.til_time)}`}
                status={(
                  <Status nivaa={v.timelonnet ? 'endring' : 'normal'}>
                    {v.timelonnet ? 'Timelønn — trekkes fra rammen' : 'Fastlønn'}
                  </Status>
                )}
                handlinger={(
                  <form action={slettFastVakt}>
                    <input type="hidden" name="id" value={v.id} />
                    <Knapp type="submit" variant="destruktiv" liten>Slett</Knapp>
                  </form>
                )}
              />
            ))}
          </Liste>
        ) : (
          <p className="undertittel">Ingen faste vakter lagt inn. Da må hele gulvet dekkes av timerammen.</p>
        )}
        <div className="knapperad">
          <Sidepanel knapp="Ny fast vakt" tittel="Ny fast vakt" beskrivelse="Velg timelønn hvis vakten skal trekkes fra rammen selv om den er fast.">
            <FastVaktSkjema stasjonId={valgt.id} />
          </Sidepanel>
        </div>
      </section>

      <section>
        <h3>Timer der én ikke holder</h3>
        <p className="undertittel">
          Varemottak, eller andre timer der én ikke holder. Uten en rad her foreslås aldri to
          personer på en rolig time — de ekstra hendene går dit kundene faktisk er.
        </p>
        {kravListe.length > 0 ? (
          <Liste merkelapp="Timer der én ikke holder">
            {kravListe.map((k) => (
              <Rad
                key={k.id}
                primaer={`${UKEDAG[k.ukedag]} ${kl(k.fra_time)}–${kl(k.til_time)}`}
                sekundaer={k.begrunnelse ?? 'ingen begrunnelse'}
                metadata={`${k.antall} personer`}
                handlinger={(
                  <form action={slettKrav}>
                    <input type="hidden" name="id" value={k.id} />
                    <Knapp type="submit" variant="destruktiv" liten>Slett</Knapp>
                  </form>
                )}
              />
            ))}
          </Liste>
        ) : (
          <p className="undertittel">Ingen slike timer lagt inn.</p>
        )}
        <div className="knapperad">
          <Sidepanel knapp="Nytt krav" tittel="Timer der én ikke holder" beskrivelse="Varemottak, vask etter stengetid, eller andre timer der én person ikke er nok.">
            <KravSkjema stasjonId={valgt.id} />
          </Sidepanel>
        </div>
      </section>

      <section>
        <h3>Ferie og fravær</h3>
        <p className="undertittel">
          Er en fast vakt borte, dekker den ikke minimumsbemanningen lenger, og timene må
          kjøpes av rammen. Fem ukers ferie <strong>henter</strong> timer — den sparer dem ikke.
        </p>
        {/* FRAVAER HENTER TIMER, det sparer dem ikke - og hvem som er
            borte er det man leter etter naar planen ikke gaar opp.
            Navnet er derfor primaert, perioden sekundaer. */}
        {fravaerListe.length > 0 ? (
          <Liste merkelapp="Ferie og fravær">
            {fravaerListe.map((f) => (
              <Rad
                key={f.id}
                primaer={f.navn}
                sekundaer={`${f.fra_dato} – ${f.til_dato}${f.arsak ? ` · ${f.arsak}` : ''}`}
                handlinger={(
                  <form action={slettFravaer}>
                    <input type="hidden" name="id" value={f.id} />
                    <Knapp type="submit" variant="destruktiv" liten>Slett</Knapp>
                  </form>
                )}
              />
            ))}
          </Liste>
        ) : (
          <p className="undertittel">Ingen fravær registrert.</p>
        )}
        <div className="knapperad">
          <Sidepanel knapp="Nytt fravær" tittel="Ferie eller fravær" beskrivelse="Gjelder de faste vaktene. Er de borte, må timene deres kjøpes av rammen.">
            <FravaerSkjema stasjonId={valgt.id} navn={[...new Set(vaktListe.map((v) => v.navn))]} />
          </Sidepanel>
        </div>
      </section>
    </>
  )
}
