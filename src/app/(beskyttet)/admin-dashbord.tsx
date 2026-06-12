import Link from 'next/link'
import type { InnloggetBruker } from '@/lib/auth/typer'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { kr, manedAar } from '@/lib/format'
import { hentEllerLagUkerapport } from '@/lib/ukerapport'
import { UkeKort } from './uke-kort'
import { Sammenleggbar } from './sammenleggbar'
import { AiKort } from './ai-kort'
import { Stasjonsrangering, AVDELINGER, type RangRad } from './stasjonsrangering'

const SNARVEIER = [
  { sti: '/regnskap', tekst: 'Regnskap', ikon: '📒' },
  { sti: '/analyse', tekst: 'Analyse', ikon: '🧠' },
  { sti: '/import', tekst: 'Import', ikon: '📥' },
  { sti: '/konkurranser', tekst: 'Konkurranser', ikon: '🏆' },
  { sti: '/oppgaver', tekst: 'Oppgaver', ikon: '✅' },
  { sti: '/stasjoner', tekst: 'Stasjoner', ikon: '⛽' },
]
const ALVOR_IKON: Record<string, string> = { generelt: '💬', uhell: '🩹', nestenuhell: '⚠️', krenkelse: '🚫' }
const KRITISK = new Set(['uhell', 'krenkelse'])

function minus30(iso: string): string {
  const d = new Date(`${iso}T12:00:00Z`)
  d.setUTCDate(d.getUTCDate() - 30)
  return d.toISOString().slice(0, 10)
}

export async function AdminDashbord({ bruker, idag }: { bruker: InnloggetBruker; idag: string }) {
  const supabase = await lagSupabaseServerKlient()
  const retailerId = bruker.retailerId as string

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
    supabase.from('konkurranser').select('id, navn, premie_kr, periode_slutt').eq('status', 'aktiv').is('slettet_tid', null).lte('periode_start', idag).gte('periode_slutt', idag).order('opprettet_tid', { ascending: false }).limit(1).maybeSingle<{ id: string; navn: string; premie_kr: number | null; periode_slutt: string }>(),
    supabase.from('oppgaver').select('id, stasjon_id, tittel, frist, status, fullfort_tid').is('slettet_tid', null)
      .overrideTypes<{ id: string; stasjon_id: string; tittel: string; frist: string | null; status: string; fullfort_tid: string | null }[]>(),
    (async () => {
      const { data: sf } = await supabase.from('fokuspunkter').select('periode').order('periode', { ascending: false }).limit(1).maybeSingle<{ periode: string }>()
      if (!sf) return [] as { stasjon_id: string; type: string }[]
      const { data } = await supabase.from('fokuspunkter').select('stasjon_id, type').eq('periode', sf.periode).overrideTypes<{ stasjon_id: string; type: string }[]>()
      return data ?? []
    })(),
  ])

  // Stasjonsrangering: oms/BRF per avdeling + svinn per stasjon (siste regnskapsmåned)
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
    if (!kode || kode === '40') continue // hopp rollup «40 CR totalt»
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

  // Uleste tilbakemeldinger
  const tilbake = (tilbakeRes.data ?? []).map((t) => ({ ...t, stasjon: navnFor.get(t.stasjon_id) ?? '—', kritisk: KRITISK.has(t.alvorlighet) }))

  // Oppgaver
  const oppgaver = oppgRes.data ?? []
  const aapne = oppgaver.filter((o) => o.status === 'apen')
  const forsinkede = aapne.filter((o) => o.frist && o.frist < idag).sort((a, b) => (a.frist! < b.frist! ? -1 : 1))
  const for30 = minus30(idag)
  const fullfort30 = oppgaver.filter((o) => o.status === 'fullfort' && o.fullfort_tid && o.fullfort_tid.slice(0, 10) >= for30).length

  // Fokuspunkter aktive per stasjon
  const fokusPer = new Map<string, number>()
  for (const f of fokus) fokusPer.set(f.stasjon_id, (fokusPer.get(f.stasjon_id) ?? 0) + 1)

  const aktivKonk = konk.data
  let ukerapporter: Awaited<ReturnType<typeof hentEllerLagUkerapport>> = []
  try { ukerapporter = await hentEllerLagUkerapport(supabase, retailerId, stasjonsListe) } catch { ukerapporter = [] }
  // Diagnose til tom-tilstanden: har vi daglige salgsdata i det hele tatt?
  const { data: sisteSalg } = ukerapporter.length === 0
    ? await supabase.from('daglig_salg').select('dato').order('dato', { ascending: false }).limit(1).maybeSingle<{ dato: string }>()
    : { data: null }

  // Regnskaps-nøkkeltall (cluster, siste måned)
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
  const lonnPst = omsT?.regnskap && persEx?.regnskap ? (persEx.regnskap / omsT.regnskap) * 100 : null
  const kpiStrip: { merke: string; verdi: string; avvik: number | null }[] = []
  if (omsT) kpiStrip.push({ merke: '💰 Omsetning', verdi: kr.format(omsT.regnskap ?? 0), avvik: avvikP(omsT) })
  if (bruttoT) kpiStrip.push({ merke: '📈 Bruttofortjeneste', verdi: kr.format(bruttoT.regnskap ?? 0), avvik: avvikP(bruttoT) })
  if (resEx) kpiStrip.push({ merke: '💵 Resultat (ex 9900)', verdi: kr.format(resEx.regnskap ?? 0), avvik: avvikP(resEx) })
  if (lonnPst != null) kpiStrip.push({ merke: '👥 Lønn % av omsetning', verdi: `${lonnPst.toFixed(1)} %`, avvik: null })

  const fornavn = bruker.fulltNavn?.split(' ')[0] ?? bruker.fulltNavn ?? 'sjef'

  return (
    <>
      <h1>God dag, {fornavn} 👋</h1>
      <p className="undertittel">
        {sistePeriode ? `${manedAar.format(new Date(sistePeriode))} · ` : ''}{stasjonsListe.length} stasjoner
      </p>

      <AiKort />

      <nav className="snarveier" aria-label="Snarveier">
        {SNARVEIER.map((s) => (
          <Link key={s.sti} href={s.sti} className="snarvei-kort">
            <span className="snarvei-ikon">{s.ikon}</span>
            <span>{s.tekst}</span>
          </Link>
        ))}
      </nav>

      {kpiStrip.length > 0 && (
        <section className="nokkeltall">
          {kpiStrip.map((k) => (
            <Link key={k.merke} href="/regnskap" className="kpi lenke">
              <span className="kpi-tall">{k.verdi}</span>
              <span className="kpi-merke">
                {k.merke}{k.avvik != null ? ` · ${k.avvik >= 0 ? '+' : '−'}${Math.abs(k.avvik).toFixed(0)} % vs budsjett` : ''}
              </span>
            </Link>
          ))}
        </section>
      )}

      {ukerapporter.length > 0 ? (
        <Sammenleggbar tittel="Forrige uke per stasjon" ikon="📅">
          <div className="uke-stabel">{ukerapporter.map((r) => <UkeKort key={r.stasjonId} rapport={r} />)}</div>
        </Sammenleggbar>
      ) : (
        <section className="kort">
          <h2>📅 Forrige uke per stasjon</h2>
          <p className="undertittel">
            Ukerapporten («forrige uke vs i fjor») dukker opp automatisk når det finnes <strong>daglige salgsdata</strong> for
            en komplett uke (man–søn). Det krever salgsstatistikken — det månedlige regnskapet inneholder ikke dag-for-dag-tall.
            Last den opp under <Link href="/import">Import</Link>.
          </p>
          <p className="undertittel" style={{ marginTop: '0.5rem' }}>
            {sisteSalg
              ? `Siste daglige salgsdag i systemet: ${sisteSalg.dato}. Mangler du en komplett man–søn-uke (eller fjorårsuka), kommer rapporten først når den er på plass.`
              : '⚠️ Ingen daglige salgsdata er lastet opp ennå — derfor er rapporten tom.'}
          </p>
        </section>
      )}

      {tilbake.length > 0 && (
        <section className="kort oppmerksomhet">
          <h2>🔔 Trenger oppmerksomhet</h2>
          <ul className="tilbake-liste">
            {tilbake.map((t) => (
              <li key={t.id} className={t.kritisk ? 'kritisk' : ''}>
                <span>{t.kritisk ? '🚨' : ALVOR_IKON[t.alvorlighet] ?? '💬'}</span>
                <span className="tilbake-tekst"><strong>{t.stasjon}</strong> — {t.tekst}</span>
                <Link href="/tilbakemeldinger" className="tilbake-lenke">Åpne</Link>
              </li>
            ))}
          </ul>
        </section>
      )}

      {rangRader.length > 0 && (
        <Sammenleggbar tittel="Stasjonsrangering" ikon="📊" apen={false}>
          <Stasjonsrangering rader={rangRader} avdelinger={avdListe} />
          {sistePeriode && <p className="undertittel" style={{ marginTop: '0.6rem' }}>{manedAar.format(new Date(sistePeriode))} · fra regnskapet</p>}
        </Sammenleggbar>
      )}

      {fokusPer.size > 0 && (
        <Sammenleggbar tittel="Fokuspunkter per stasjon" ikon="🎯">
          <ul className="fokus-per-liste">
            {stasjonsListe.filter((s) => fokusPer.get(s.id)).map((s) => (
              <li key={s.id}>
                <span>{s.butikknummer} {s.navn}</span>
                <span className="fokus-antall">{fokusPer.get(s.id)} aktive</span>
              </li>
            ))}
          </ul>
          <p className="undertittel"><Link href="/fokus">Se alle fokuspunkter →</Link></p>
        </Sammenleggbar>
      )}

      <div className="dash-grid">
        <section className="kort">
          <h2>🏆 Månedens konkurranse</h2>
          {aktivKonk ? (
            <div className="konk-boks">
              <strong>{aktivKonk.navn}</strong>
              <p className="undertittel">
                {aktivKonk.premie_kr ? `Premie ${kr.format(aktivKonk.premie_kr)} · ` : ''}avsluttes {aktivKonk.periode_slutt}
              </p>
              <Link href="/konkurranser">Se stilling →</Link>
            </div>
          ) : (
            <p className="undertittel">Ingen aktiv konkurranse nå. <Link href="/konkurranser">Opprett →</Link></p>
          )}
        </section>

        <section className="kort">
          <h2>✅ Oppgaver</h2>
          <div className="oppg-tall">
            <div><span className="oppg-stor">{aapne.length}</span><span className="oppg-merke">Aktive</span></div>
            <div><span className="oppg-stor rod">{forsinkede.length}</span><span className="oppg-merke">Forsinkede</span></div>
            <div><span className="oppg-stor gronn">{fullfort30}</span><span className="oppg-merke">Fullført 30 d</span></div>
          </div>
          <p className="undertittel"><Link href="/oppgaver">Se alle →</Link></p>
        </section>
      </div>

      {forsinkede.length > 0 && (
        <section className="kort oppmerksomhet">
          <h2>⚠️ Forsinkede oppgaver</h2>
          <ul className="forsinket-liste">
            {forsinkede.slice(0, 5).map((o) => (
              <li key={o.id}>
                <span className="forsinket-frist">{o.frist}</span>
                <span>{o.tittel}</span>
                <span className="undertittel">{navnFor.get(o.stasjon_id) ?? ''}</span>
              </li>
            ))}
          </ul>
        </section>
      )}
    </>
  )
}
