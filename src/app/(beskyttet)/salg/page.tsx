import Link from 'next/link'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { AVDELINGER } from '@/lib/avdelinger'
import { StasjonsVelger } from '../stasjonsvelger'
import { AiKontekst } from '../ai-kontekst'

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
  const valgtDato = sp.dato
  const erUuid = (s?: string) => !!s && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s)
  const valgtStasjon = erUuid(sp.stasjon) ? sp.stasjon! : null

  // Default: siste dato med data (RLS scoper til brukerens stasjoner)
  let dato = valgtDato && /^\d{4}-\d{2}-\d{2}$/.test(valgtDato) ? valgtDato : null
  if (!dato) {
    const { data } = await supabase
      .from('v_salg_per_stasjon_dag')
      .select('dato')
      .order('dato', { ascending: false })
      .limit(1)
      .maybeSingle<{ dato: string }>()
    dato = data?.dato ?? null
  }

  if (!dato) {
    return (
      <>
        <h1>Salg</h1>
        <p className="undertittel">
          Ingen salgsdata ennå. Last opp en Salgsstatistikk-fil under Import og trykk Behandle.
        </p>
      </>
    )
  }

  const [{ data: stasjonRader }, { data: stasjoner }] = await Promise.all([
    supabase
      .from('v_salg_per_stasjon_dag')
      .select('stasjon_id, omsetning, antall, mat_omsetning')
      .eq('dato', dato)
      .overrideTypes<StasjonRad[]>(),
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null),
  ])

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

  const [{ data: avdData }, { data: vgData }] = await Promise.all([
    avdelingQ.overrideTypes<{ avdeling_kode: string | null; avdeling_navn: string | null; omsetning: number | null; antall: number | null }[]>(),
    varegruppeQ.overrideTypes<VaregruppeRad[]>(),
  ])
  const varegrupper: VaregruppeRad[] = vgData ?? []

  // Avdeling-rader er per (avdeling, stasjon) → summer per avdeling. Pen navn/ikon
  // fra AVDELINGER (St1-kontoplan), fallback til viewets avdeling_navn.
  const ikonFor = new Map(AVDELINGER.map((a) => [a.kode, a.ikon]))
  const pentNavn = new Map(AVDELINGER.map((a) => [a.kode, a.navn]))
  const avdMap = new Map<string, { navn: string; omsetning: number; antall: number }>()
  for (const r of avdData ?? []) {
    const kode = r.avdeling_kode ?? ''
    const a = avdMap.get(kode) ?? { navn: pentNavn.get(kode) ?? r.avdeling_navn ?? kode, omsetning: 0, antall: 0 }
    a.omsetning += r.omsetning ?? 0
    a.antall += r.antall ?? 0
    avdMap.set(kode, a)
  }
  const avdelinger = [...avdMap.entries()]
    .map(([kode, a]) => ({ kode, ikon: ikonFor.get(kode) ?? '📦', ...a }))
    .sort((x, y) => y.omsetning - x.omsetning)
  const avdSum = avdelinger.reduce((s, a) => s + a.omsetning, 0)

  const totalOms = rader.reduce((a, r) => a + r.omsetning, 0)
  const totalAntall = rader.reduce((a, r) => a + r.antall, 0)

  return (
    <>
      <h1>Salg</h1>
      <AiKontekst tekst="Forklar utviklingen" sporsmal="Forklar utviklingen i salget for denne stasjonen den siste tiden. Hva driver den?" />
      <p className="undertittel">{datoFmt.format(new Date(dato))} · {erStasjon ? valgtNavn : 'alle stasjoner samlet'}</p>

      {(stasjoner ?? []).length > 0 && (
        <StasjonsVelger
          stasjoner={[...(stasjoner ?? [])].sort((a, b) => a.butikknummer.localeCompare(b.butikknummer)).map((s) => ({ id: s.id, navn: `${s.butikknummer} ${s.navn}` }))}
          valgtId={erStasjon ? valgtStasjon : null}
          basePath="/salg"
          bevar={{ dato }}
        />
      )}

      <section className="nokkeltall">
        <div className="kpi">
          <span className="kpi-tall">{kr.format(erStasjon ? (valgtRad?.omsetning ?? 0) : totalOms)}</span>
          <span className="kpi-merke">Omsetning eks. mva</span>
        </div>
        <div className="kpi">
          <span className="kpi-tall">{tall.format(erStasjon ? (valgtRad?.antall ?? 0) : totalAntall)}</span>
          <span className="kpi-merke">Antall solgt</span>
        </div>
        <div className="kpi">
          <span className="kpi-tall">{erStasjon ? kr.format(valgtRad?.mat_omsetning ?? 0) : tall.format(rader.length)}</span>
          <span className="kpi-merke">{erStasjon ? 'Matsalg' : 'Stasjoner med salg'}</span>
        </div>
      </section>

      <section className="kort">
        <h2>Per kategori{erStasjon ? ` · ${valgtNavn}` : ''}</h2>
        <table className="tabell">
          <thead>
            <tr><th>Kategori</th><th>Omsetning</th><th>Antall</th><th>Andel</th></tr>
          </thead>
          <tbody>
            {avdelinger.length === 0 ? (
              <tr><td colSpan={4} className="undertittel">Ingen kategori-salg denne dagen.</td></tr>
            ) : avdelinger.map((a) => (
              <tr key={a.kode}>
                <td>{a.ikon} {a.navn}</td>
                <td>{kr.format(a.omsetning)}</td>
                <td>{tall.format(a.antall)}</td>
                <td>{avdSum > 0 ? `${Math.round((a.omsetning / avdSum) * 100)} %` : '—'}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>

      {!erStasjon && (
        <section className="kort">
          <h2>Per stasjon</h2>
          <table className="tabell">
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
          </table>
        </section>
      )}

      <section className="kort">
        <h2>Topp varegrupper{erStasjon ? ` · ${valgtNavn}` : ''}</h2>
        <table className="tabell">
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
        </table>
      </section>
    </>
  )
}
