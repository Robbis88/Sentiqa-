import Link from 'next/link'
import type { InnloggetBruker } from '@/lib/auth/typer'
import type { SupabaseClient } from '@supabase/supabase-js'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { kr, manedAar, datoLang } from '@/lib/format'
import {
  klyngebilde, pulsOverskrift, rangerSignaler,
  // Aliaset fordi `Signal` ogsaa er navnet paa primitiven som tegner ETT
  // budskap. Typen her er et RANGERT funn - to ulike ting med samme ord.
  type RaaSignal, type Signal as RangertSignal,
} from '@/lib/signaler'
import { filtrerLukkede, treffSignaler, utsolgtSignaler } from '@/lib/signalkilder'
import { Nokkeltall, Sidehode, Tomtilstand } from '@/components/ui/side'
import { Liste, Rad } from '@/components/ui/liste'
import { Signal, Status } from '@/components/ui/status'
import { Ferskhetsstatus } from './ferskhet-status'
import { Oppmerksomhet } from './oppmerksomhet'
import { Maal } from './sq-maal'
import { hentEllerLagUkerapport, type UkeRapport } from '@/lib/ukerapport'
import { UkeKort } from './uke-kort'
import { Sammenleggbar } from './sammenleggbar'
import { AiKort } from './ai-kort'
import { Stasjonsrangering, type RangRad } from './stasjonsrangering'
import { Budsjettstatus, type BudsjettRad } from './budsjettstatus'
import { AVDELINGER } from '@/lib/avdelinger'
import { hentRegnskapVarsler } from '@/lib/regnskap-varsler'

const KRITISK = new Set(['uhell', 'krenkelse'])

// Samme tolv prosentpoeng som `klyngebilde()` bruker for aa avgjore om en
// stasjon i det hele tatt blir en sak (STASJON_AVVIK_PP i signaler.ts).
// Sto tidligere som to naakne 12-tall midt i JSX-en.
const STASJONSAVVIK = 12

function minus30(iso: string): string {
  const d = new Date(`${iso}T12:00:00Z`)
  d.setUTCDate(d.getUTCDate() - 30)
  return d.toISOString().slice(0, 10)
}

type Oppgave = { id: string; stasjon_id: string; tittel: string; frist: string | null; status: string; fullfort_tid: string | null }
type Tilbake = { id: string; stasjon: string; alvorlighet: string; tekst: string; kritisk: boolean }
/**
 * Ett regnskapstall mot budsjett.
 *
 * `overErBra` er ikke pynt. Omsetning over budsjett er bra;
 * PERSONALKOSTNAD over budsjett er det motsatte, og sto likevel med
 * groenn pil opp. Retningen og dommen maa kunne peke hver sin vei.
 */
type Kpi = { merke: string; verdi: string; avvik: number | null; overErBra: boolean }
type Konk = { id: string; navn: string; premie_kr: number | null; periode_slutt: string }
type FPunkt = { tittel: string | null; tekst: string }
type FokusGruppe = { id: string; navn: string; forbedring: FPunkt[]; positivt: FPunkt[] }
type DashData = {
  stasjonsListe: { id: string; navn: string; butikknummer: string }[]
  navnFor: Map<string, string>
  sistePeriode: string | null
  rangRader: RangRad[]
  avdListe: typeof AVDELINGER
  tilbake: Tilbake[]
  aapne: Oppgave[]
  forsinkede: Oppgave[]
  fullfort30: number
  fokusGrupper: FokusGruppe[]
  aktivKonk: Konk | null
  ukerapporter: UkeRapport[]
  sisteSalg: { dato: string } | null
  kpiStrip: Kpi[]
  driftsstatus: { navn: string; status: string; grunn: string }[]
  feil: string | null
}

// All datahenting samlet og wrappet — dashbordet skal aldri kunne krasje siden.
async function samleData(supabase: SupabaseClient, retailerId: string, idag: string): Promise<DashData> {
  const tomt: DashData = {
    stasjonsListe: [], navnFor: new Map(), sistePeriode: null, rangRader: [], avdListe: [],
    tilbake: [], aapne: [], forsinkede: [], fullfort30: 0, fokusGrupper: [],
    aktivKonk: null, ukerapporter: [], sisteSalg: null, kpiStrip: [], driftsstatus: [], feil: null,
  }
  try {
    const { data: stasjoner } = await supabase
      .from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null).order('butikknummer')
      .overrideTypes<{ id: string; navn: string; butikknummer: string }[]>()
    const stasjonsListe = stasjoner ?? []
    const navnFor = new Map(stasjonsListe.map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))

    const { data: sisteReg } = await supabase
      .from('regnskapslinjer').select('periode').is('stasjon_id', null).order('periode', { ascending: false }).limit(1).maybeSingle<{ periode: string }>()
    const sistePeriode = sisteReg?.periode ?? null

    const [rangLinjeRes, rangSvinnRes, tilbakeRes, konk, oppgRes, fokus] = await Promise.all([
      sistePeriode
        ? supabase.from('regnskapslinjer').select('stasjon_id, seksjon, kode, regnskap, budsjett').eq('periode', sistePeriode).in('seksjon', ['omsetning', 'bruttofortjeneste', 'driftskostnader']).not('stasjon_id', 'is', null).overrideTypes<{ stasjon_id: string; seksjon: string; kode: string | null; regnskap: number | null; budsjett: number | null }[]>()
        : Promise.resolve({ data: [] as { stasjon_id: string; seksjon: string; kode: string | null; regnskap: number | null; budsjett: number | null }[] }),
      sistePeriode
        ? supabase.from('regnskap_usynlig_svinn').select('stasjon_id, kast, usynlig_kr').eq('periode', sistePeriode).is('slettet_tid', null).overrideTypes<{ stasjon_id: string; kast: number | null; usynlig_kr: number | null }[]>()
        : Promise.resolve({ data: [] as { stasjon_id: string; kast: number | null; usynlig_kr: number | null }[] }),
      supabase.from('tilbakemelding').select('id, stasjon_id, alvorlighet, tekst, opprettet_tid').is('lest_tid', null).order('opprettet_tid', { ascending: false }).limit(12)
        .overrideTypes<{ id: string; stasjon_id: string; alvorlighet: string; tekst: string; opprettet_tid: string }[]>(),
      supabase.from('konkurranser').select('id, navn, premie_kr, periode_slutt').eq('status', 'aktiv').is('slettet_tid', null).lte('periode_start', idag).gte('periode_slutt', idag).order('opprettet_tid', { ascending: false }).limit(1).maybeSingle<Konk>(),
      supabase.from('oppgaver').select('id, stasjon_id, tittel, frist, status, fullfort_tid').is('slettet_tid', null).overrideTypes<Oppgave[]>(),
      (async () => {
        const { data: sf } = await supabase.from('fokuspunkter').select('periode').order('periode', { ascending: false }).limit(1).maybeSingle<{ periode: string }>()
        if (!sf) return [] as { stasjon_id: string; type: string; tittel: string | null; tekst: string }[]
        const { data } = await supabase.from('fokuspunkter').select('stasjon_id, type, tittel, tekst').eq('periode', sf.periode).overrideTypes<{ stasjon_id: string; type: string; tittel: string | null; tekst: string }[]>()
        return data ?? []
      })(),
    ])

    // Stasjonsrangering
    const rangMap = new Map<string, RangRad>()
    const avdMedData = new Set<string>()
    const sikre = (id: string) => {
      let r = rangMap.get(id)
      if (!r) { r = { navn: navnFor.get(id) ?? '—', oms: {}, brf: {}, kost: {}, kast: 0, usynlig: 0 }; rangMap.set(id, r) }
      return r
    }
    for (const l of rangLinjeRes.data ?? []) {
      if (!navnFor.has(l.stasjon_id)) continue
      const kode = (l.kode ?? '').trim()
      if (!kode || kode === '40') continue
      const r = sikre(l.stasjon_id)
      const mapp = l.seksjon === 'omsetning' ? r.oms : l.seksjon === 'bruttofortjeneste' ? r.brf : r.kost
      const eks = mapp[kode] ?? { regnskap: 0, budsjett: 0 }
      mapp[kode] = { regnskap: eks.regnskap + (l.regnskap ?? 0), budsjett: eks.budsjett + (l.budsjett ?? 0) }
      if (l.seksjon === 'omsetning') avdMedData.add(kode)
    }
    for (const s of rangSvinnRes.data ?? []) {
      if (!navnFor.has(s.stasjon_id)) continue
      const r = sikre(s.stasjon_id)
      r.kast += s.kast ?? 0
      r.usynlig += s.usynlig_kr ?? 0
    }
    const summer = (m: Record<string, { regnskap: number; budsjett: number }>) =>
      Object.values(m).reduce((a, v) => ({ regnskap: a.regnskap + v.regnskap, budsjett: a.budsjett + v.budsjett }), { regnskap: 0, budsjett: 0 })
    for (const r of rangMap.values()) { r.oms.total = summer(r.oms); r.brf.total = summer(r.brf) }
    const rangRader = [...rangMap.values()]
    const avdListe = AVDELINGER.filter((a) => avdMedData.has(a.kode))

    const tilbake: Tilbake[] = (tilbakeRes.data ?? []).map((t) => ({ id: t.id, alvorlighet: t.alvorlighet, tekst: t.tekst, stasjon: navnFor.get(t.stasjon_id) ?? '—', kritisk: KRITISK.has(t.alvorlighet) }))

    const oppgaver = oppgRes.data ?? []
    const aapne = oppgaver.filter((o) => o.status === 'apen')
    const forsinkede = aapne.filter((o) => o.frist && o.frist < idag).sort((a, b) => (a.frist! < b.frist! ? -1 : 1))
    const for30 = minus30(idag)
    const fullfort30 = oppgaver.filter((o) => o.status === 'fullfort' && o.fullfort_tid && o.fullfort_tid.slice(0, 10) >= for30).length

    const fokusMap = new Map<string, FokusGruppe>()
    for (const f of fokus) {
      if (!navnFor.has(f.stasjon_id)) continue
      let g = fokusMap.get(f.stasjon_id)
      if (!g) { g = { id: f.stasjon_id, navn: navnFor.get(f.stasjon_id)!, forbedring: [], positivt: [] }; fokusMap.set(f.stasjon_id, g) }
      ;(f.type === 'forbedring' ? g.forbedring : g.positivt).push({ tittel: f.tittel, tekst: f.tekst })
    }
    const fokusGrupper = [...fokusMap.values()]

    const aktivKonk = konk.data

    let ukerapporter: UkeRapport[] = []
    try { ukerapporter = await hentEllerLagUkerapport(supabase, retailerId, stasjonsListe) } catch { ukerapporter = [] }
    // Hentes ALLTID, ikke bare naar ukerapporten mangler: med automatisk
    // nattlig import er dette det eneste som roper at kjeden har stoppet.
    const { data: sisteSalgRad } = await supabase
      .from('v_butikksalg').select('dato').order('dato', { ascending: false }).limit(1)
      .maybeSingle<{ dato: string }>()
    const sisteSalg = sisteSalgRad

    // Regnskaps-nøkkeltall (cluster)
    type ClusterL = { seksjon: string; post: string; regnskap: number | null; budsjett: number | null }
    const { data: clusterL } = sistePeriode
      ? await supabase.from('regnskapslinjer').select('seksjon, post, regnskap, budsjett').eq('periode', sistePeriode).is('stasjon_id', null).overrideTypes<ClusterL[]>()
      : { data: null }
    const cl = clusterL ?? []
    const finnC = (seksjon: string, re: RegExp) => cl.find((l) => l.seksjon === seksjon && re.test(l.post))
    const avvikP = (l: ClusterL) => (l.budsjett ? (((l.regnskap ?? 0) - l.budsjett) / l.budsjett) * 100 : null)
    const omsT = finnC('omsetning', /^omsetning totalt/i)
    const bruttoT = finnC('bruttofortjeneste', /^bruttofortjeneste totalt/i)
    const resEx = finnC('resultat', /ex 9900/i)
    const persEx = finnC('driftskostnader', /personalkostnad ex 9900/i)
    const kpiStrip: Kpi[] = []
    // Emojiene som sto her ble strippet igjen ved utskrift
    // (`merke.replace(/^[^\p{L}]+/u, '')`) - de var altsaa aldri synlige,
    // bare baaret rundt.
    if (omsT) kpiStrip.push({ merke: 'Omsetning', verdi: kr.format(omsT.regnskap ?? 0), avvik: avvikP(omsT), overErBra: true })
    if (bruttoT) kpiStrip.push({ merke: 'Bruttofortjeneste', verdi: kr.format(bruttoT.regnskap ?? 0), avvik: avvikP(bruttoT), overErBra: true })
    if (resEx) kpiStrip.push({ merke: 'Resultat (ex 9900)', verdi: kr.format(resEx.regnskap ?? 0), avvik: avvikP(resEx), overErBra: true })
    // Lønn mot LØNNSBUDSJETT (ikke mot omsetning). Over budsjett er daarlig.
    if (persEx) kpiStrip.push({ merke: 'Lønn vs budsjett', verdi: kr.format(persEx.regnskap ?? 0), avvik: avvikP(persEx), overErBra: false })

    // Driftsstatus per stasjon (grønn/gul/rød) fra varsel-motoren — samme
    // «alt som ikke er bra»-logikk som /regnskap. Mest kritiske øverst.
    let driftsstatus: DashData['driftsstatus'] = []
    if (sistePeriode) {
      const varsler = await hentRegnskapVarsler(supabase, retailerId, sistePeriode).catch(() => [])
      const rang: Record<string, number> = { rod: 0, gul: 1, gronn: 2 }
      driftsstatus = stasjonsListe.map((s) => {
        const navn = `${s.butikknummer} ${s.navn}`
        const mine = varsler.filter((v) => v.omfang === navn)
        const rod = mine.find((v) => v.nivaa === 'rod')
        const gul = mine.find((v) => v.nivaa === 'gul')
        if (rod) return { navn, status: 'rod', grunn: rod.tittel }
        if (gul) return { navn, status: 'gul', grunn: gul.tittel }
        return { navn, status: 'gronn', grunn: 'Alt i rute' }
      }).sort((a, b) => rang[a.status] - rang[b.status])
    }

    return { stasjonsListe, navnFor, sistePeriode, rangRader, avdListe, tilbake, aapne, forsinkede, fullfort30, fokusGrupper, aktivKonk, ukerapporter, sisteSalg, kpiStrip, driftsstatus, feil: null }
  } catch (e) {
    console.error('AdminDashbord samleData feilet:', e)
    return { ...tomt, feil: e instanceof Error ? `${e.name}: ${e.message}` : String(e) }
  }
}

// Eierens akse er en annen enn butikksjefens. Butikksjefen spør «hva
// trenger meg?». Eieren kan ikke spørre det fem ganger — da blir det fem
// dashbord. Eieren må spørre «er dette stasjonen eller er det markedet?»,
// og bare det første er noe en butikksjef kan gjøre noe med.
function byggSignaler(d: DashData, idag: string, klynge: ReturnType<typeof klyngebilde>, ekstra: RaaSignal[] = []): RangertSignal[] {
  const raa: RaaSignal[] = [...klynge.signaler, ...ekstra]

  for (const t of d.tilbake) {
    if (!t.kritisk) continue
    raa.push({
      id: `tilbake-${t.id}`, merke: 'Tilbakemelding', tittel: `${t.stasjon}`,
      detalj: t.tekst.slice(0, 160), niva: 'kritisk', lenke: '/tilbakemeldinger',
    })
  }

  // Regnskapsvarslene er allerede en signalmotor — rød/gul per stasjon med
  // begrunnelse. De trenger bare å rangeres sammen med resten.
  for (const s of d.driftsstatus) {
    if (s.status === 'gronn') continue
    raa.push({
      id: `drift-${s.navn}`, merke: 'Regnskap', tittel: s.navn, detalj: s.grunn,
      niva: s.status === 'rod' ? 'kritisk' : 'folg', lenke: '/regnskap',
    })
  }

  if (d.forsinkede.length > 0) {
    const eldst = d.forsinkede[0]
    raa.push({
      id: 'oppgaver-forsinket', merke: 'Oppgaver',
      tittel: `${d.forsinkede.length} ${d.forsinkede.length === 1 ? 'oppgave' : 'oppgaver'} over frist`,
      endring: eldst.frist ? `eldst ${eldst.frist}` : undefined,
      detalj: d.forsinkede.slice(0, 3).map((o) => `${d.navnFor.get(o.stasjon_id) ?? ''} · ${o.tittel}`).join(' — '),
      niva: 'folg', lenke: '/oppgaver',
      dager: eldst.frist
        ? Math.round((Date.parse(`${idag}T12:00:00Z`) - Date.parse(`${eldst.frist}T12:00:00Z`)) / 86400000)
        : null,
    })
  }

  const ulesteIkkeKritiske = d.tilbake.filter((t) => !t.kritisk).length
  if (ulesteIkkeKritiske > 0) {
    raa.push({
      id: 'tilbake-uleste', merke: 'Tilbakemelding',
      tittel: `${ulesteIkkeKritiske} uleste tilbakemeldinger`,
      detalj: 'Fra tabletene. Ingen av dem er merket som alvorlige.',
      niva: 'info', lenke: '/tilbakemeldinger',
    })
  }

  return rangerSignaler(raa)
}

export async function AdminDashbord({ bruker, idag }: { bruker: InnloggetBruker; idag: string }) {
  const supabase = await lagSupabaseServerKlient()
  const fornavn = bruker.fulltNavn?.split(' ')[0] ?? bruker.fulltNavn ?? 'sjef'
  const d = await samleData(supabase, bruker.retailerId as string, idag)

  const klynge = klyngebilde(d.ukerapporter.map((r) => ({
    stasjonId: r.stasjonId, navn: r.navn,
    omsetning: r.omsetning, omsetningIfjor: r.omsetningIfjor,
  })))
  const stasjoner = d.stasjonsListe.map((x) => ({ id: x.id, navn: `${x.butikknummer} ${x.navn}` }))
  const [utsolgt, treff, { data: budsjett }] = await Promise.all([
    utsolgtSignaler(supabase, stasjoner, idag).catch(() => []),
    treffSignaler(supabase, stasjoner, idag).catch(() => []),
    // Hittil i maaneden mot BP. Aggregert i basen (0095) - klienten skal
    // ikke hente dagsrader for aa summere dem.
    supabase.from('v_budsjettstatus')
      .select('stasjon_id, butikknummer, navn, til_og_med, brutto_hittil, bp_maned, andel_av_maned, grunnlag, forventet_naa')
      .overrideTypes<BudsjettRad[]>(),
  ])
  const alle = byggSignaler(d, idag, klynge, [...utsolgt, ...treff])
  const signaler = await filtrerLukkede(supabase, alle, idag).catch(() => alle)
  const bruttoNaa = d.ukerapporter.reduce((a, r) => a + r.brutto, 0)
  const bruttoIfjor = d.ukerapporter.reduce((a, r) => a + r.bruttoIfjor, 0)
  const time = Number(new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Europe/Oslo', hour: '2-digit', hour12: false,
  }).format(new Date()))
  const hils = time < 5 ? 'God natt' : time < 10 ? 'God morgen' : time < 18 ? 'God dag' : 'God kveld'

  return (
    <div className="sq">
      {/* 1 · Kontekst. To ulike ferskheter: salg er dagen etter, regnskap er
          måneden etter. De skal aldri blandes. */}
      <Sidehode
        tittel={`${d.stasjonsListe.length} stasjoner`}
        undertittel={`${hils}, ${fornavn} · ${datoLang.format(new Date(`${idag}T12:00:00Z`))}`}
        handlinger={(
          <div className="sq-ferskhet">
            {d.sisteSalg && <Ferskhetsstatus dato={d.sisteSalg.dato} idag={idag} />}
            {d.sistePeriode && (
              <Status>Regnskap {manedAar.format(new Date(d.sistePeriode))}</Status>
            )}
          </div>
        )}
      />

      {/* EN SIDE SOM IKKE KUNNE LASTES ER IKKE ET KORT MED ROED KANT.
          Den sto som `kort oppmerksomhet` - alvoret laa i en kantfarge,
          og teksten begynte med «Kunne ikke». Naa er det et kritisk
          signal, som alt annet systemet ikke klarer aa svare paa. */}
      {d.feil && (
        <Signal nivaa="kritisk" tittel="Oversikten er ikke komplett">
          Noen av tallene under kunne ikke hentes, saa bildet kan mangle stasjoner
          eller saker. Teknisk: {d.feil}
        </Signal>
      )}

      {/* 2 · HVOR I PORTEFOLJEN SKAL BLIKKET.
          Sto tidligere under pulsen. Eieren kan ikke spore «hva trenger
          meg» fem ganger - han maa vite hvilken av stasjonene som ikke
          foelger de andre, og det svaret ligger her, ikke i to
          omsetningstall. Markedet er allerede skilt fra stasjonene av
          `klyngebilde()`. */}
      <Oppmerksomhet signaler={signaler} />

      {/* 4 · HVILKEN STASJON. Rangert etter AVVIK, ikke etter storrelse:
          at Dale er storre enn Bones hver maaned er ingen nyhet.

          Avviket sto som en farget pille med et tall i - «−14 pp» i
          roedt. Tallet er presist, men det sier ikke om det er bra
          eller daarlig uten at man kjenner fargekoden. Naa staar dommen
          i ord ved siden av. Grensene er de samme tolv prosentpoengene
          som for, og de samme som `klyngebilde()` bruker. */}
      {klynge.rader.length > 0 && (
        <section className="sq-seksjon">
          <div className="sq-seksjon-hode">
            <h2>Stasjonene mot hverandre</h2>
            <span className="sq-merkelapp">Avvik fra de øvrige · svakest først</span>
          </div>
          <Liste>
            {klynge.rader.map((r) => {
              // Fortegn velges paa det AVRUNDEDE tallet, ellers blir
              // -0,4 til "-0 pp".
              const pp = Math.round(r.avvikPp)
              const dom = r.avvikPp < -STASJONSAVVIK
                ? { nivaa: 'kritisk' as const, ord: 'Henger etter' }
                : r.avvikPp > STASJONSAVVIK
                  ? { nivaa: 'normal' as const, ord: 'Foran de andre' }
                  : { nivaa: 'endring' as const, ord: 'På linje' }
              return (
                <Rad
                  key={r.stasjonId}
                  primaer={r.navn}
                  sekundaer={`${pp >= 0 ? '+' : '−'}${Math.abs(pp)} prosentpoeng mot de øvrige`}
                  status={<Status nivaa={dom.nivaa}>{dom.ord}</Status>}
                  metadata={`${r.vekstPst >= 0 ? '+' : '−'}${Math.abs(r.vekstPst).toFixed(0)} % mot i fjor`}
                />
              )
            })}
          </Liste>
        </section>
      )}

      {/* 5 · Hvordan ligger vi an NÅ — ikke forrige uke, ikke forrige måned.
          Systemet har hatt begge tallene hele tiden uten å sette dem sammen. */}
      {(budsjett ?? []).length > 0 && (
        <section className="sq-seksjon">
          <div className="sq-seksjon-hode">
            <h2>Mot budsjett denne måneden</h2>
          </div>
          <Budsjettstatus rader={budsjett ?? []} />
        </section>
      )}

      {/* 6 · Pulsen kommer ETTER stasjonene naa.
          To omsetningstall for klyngen samlet er forstaaelse, ikke
          oppdrag: de forteller hvordan det gikk, ikke hvor han skal se.
          Sto de over lista, var det forste oyet moette et tall han ikke
          kan gjore noe med i dag. */}
      {klynge.omsetningIfjor > 0 && (
        <section className="sq-puls">
          <div>
            <h2>{pulsOverskrift('Klyngen', klynge.vekstPst)}</h2>
            <p className="sq-forklar">
              Forrige hele uke mot samme uke i fjor, alle stasjoner samlet.
              {klynge.rader.length > 1 &&
                ` Spennet mellom beste og svakeste stasjon er ${Math.abs(
                  klynge.rader[klynge.rader.length - 1].avvikPp - klynge.rader[0].avvikPp,
                ).toFixed(0)} prosentpoeng.`}
            </p>
          </div>
          <div className="sq-maal-par">
            <Maal merke="Omsetning · forrige uke" naa={klynge.omsetning} ifjor={klynge.omsetningIfjor} />
            <Maal merke="Bruttofortjeneste" naa={bruttoNaa} ifjor={bruttoIfjor} />
          </div>
        </section>
      )}

      {/* 7 · Regnskap — egen tidslinje, tydelig merket */}
      {d.kpiStrip.length > 0 && (
        <section className="sq-seksjon">
          <div className="sq-seksjon-hode">
            <h2>Regnskap</h2>
            <Link href="/regnskap" className="sq-merkelapp">
              {d.sistePeriode ? manedAar.format(new Date(d.sistePeriode)) : ''} · se alt →
            </Link>
          </div>
          <div className="sq-tallrad">
            {d.kpiStrip.map((k) => (
              <Nokkeltall
                key={k.merke}
                merkelapp={k.merke}
                verdi={k.verdi}
                sammenlignet={k.avvik == null ? undefined
                  : `${k.avvik >= 0 ? '+' : '−'}${Math.abs(k.avvik).toFixed(0)} % mot budsjett`}
                retning={k.avvik == null ? 'flat' : k.avvik >= 0 ? 'opp' : 'ned'}
                bra={k.avvik == null ? undefined
                  : k.overErBra ? k.avvik >= 0 : k.avvik <= 0}
              />
            ))}
          </div>
        </section>
      )}

      <AiKort />

      {d.ukerapporter.length > 0 ? (
        <Sammenleggbar tittel="Forrige uke per stasjon">
          <div className="uke-stabel">{d.ukerapporter.map((r) => <UkeKort key={r.stasjonId} rapport={r} />)}</div>
        </Sammenleggbar>
      ) : (
        <section className="sq-seksjon">
          <div className="sq-seksjon-hode">
            <h2>Forrige uke per stasjon</h2>
          </div>
          <Tomtilstand
            tittel="Ingen komplett uke å sammenligne ennå"
            forklaring={`Ukerapporten krever daglige salgsdata for en hel uke (man–søn), og samme uke i fjor. Det månedlige regnskapet har ikke dag-for-dag-tall. ${
              d.sisteSalg
                ? `Siste daglige salgsdag i systemet er ${d.sisteSalg.dato}.`
                : 'Ingen daglige salgsdata er lastet opp ennå.'
            }`}
            handling={<Link href="/import" className="sq-knapp">Gå til Import</Link>}
          />
        </section>
      )}

      {d.rangRader.length > 0 && (
        <Sammenleggbar tittel="Stasjonsrangering" apen={false}>
          <Stasjonsrangering rader={d.rangRader} avdelinger={d.avdListe} />
          {d.sistePeriode && <p className="undertittel sq-luft-over-liten">{manedAar.format(new Date(d.sistePeriode))} · fra regnskapet</p>}
        </Sammenleggbar>
      )}

      {d.fokusGrupper.length > 0 && (
        <Sammenleggbar tittel="Fokuspunkter per stasjon" apen={false}>
          {d.fokusGrupper.map((g) => (
            <div className="fokus-stasjon" key={g.id}>
              <h3>{g.navn}</h3>
              <div className="fokus-kol">
                <div>
                  <h4 className="fokus-tittel gronn">Bra jobbet</h4>
                  <ul className="fokus-liste">{g.positivt.map((p, i) => <li key={i}>{p.tittel ? <strong>{p.tittel}: </strong> : null}{p.tekst}</li>)}</ul>
                </div>
                <div>
                  <h4 className="fokus-tittel gul">Verdt et blikk</h4>
                  <ul className="fokus-liste">{g.forbedring.map((p, i) => <li key={i}>{p.tittel ? <strong>{p.tittel}: </strong> : null}{p.tekst}</li>)}</ul>
                </div>
              </div>
            </div>
          ))}
          <p className="undertittel"><Link href="/fokus">Se alle / historikk →</Link></p>
        </Sammenleggbar>
      )}

      {/* KONKURRANSEN ER ET OBJEKT - én ting med navn, premie og frist -
          og beholder derfor kortet sitt. Oppgavetallene er tre tall, og
          et tall hoerer hjemme i Nokkeltall. Forsinkede sto med roedt
          tall her; den saken staar allerede oeverst i lista naar den
          finnes, og to roede steder for samme sak laerer folk at roedt
          ikke betyr noe. */}
      <div className="dash-grid">
        <section className="kort">
          <h2>Månedens konkurranse</h2>
          {d.aktivKonk ? (
            <div className="konk-boks">
              <strong>{d.aktivKonk.navn}</strong>
              <p className="undertittel">
                {d.aktivKonk.premie_kr ? `Premie ${kr.format(d.aktivKonk.premie_kr)} · ` : ''}avsluttes {d.aktivKonk.periode_slutt}
              </p>
              <Link href="/konkurranser">Se stilling →</Link>
            </div>
          ) : (
            <p className="undertittel">Ingen aktiv konkurranse nå. <Link href="/konkurranser">Opprett →</Link></p>
          )}
        </section>

        <section className="sq-seksjon">
          <div className="sq-seksjon-hode">
            <h2>Oppgaver</h2>
            <Link href="/oppgaver" className="sq-merkelapp">Se alle →</Link>
          </div>
          <div className="sq-tallrad">
            <Nokkeltall merkelapp="Aktive" verdi={String(d.aapne.length)} />
            <Nokkeltall merkelapp="Over frist" verdi={String(d.forsinkede.length)} />
            <Nokkeltall merkelapp="Fullført siste 30 dager" verdi={String(d.fullfort30)} />
          </div>
        </section>
      </div>

    </div>
  )
}
