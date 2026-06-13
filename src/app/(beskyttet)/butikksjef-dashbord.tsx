import Link from 'next/link'
import type { SupabaseClient } from '@supabase/supabase-js'
import type { InnloggetBruker } from '@/lib/auth/typer'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { kr, datoLang, iDag } from '@/lib/format'
import { hentEllerLagUkerapport, type UkeRapport } from '@/lib/ukerapport'
import { UkeKort } from './uke-kort'

type FokusPunkt = { type: string; tekst: string; tittel: string | null }
type Konk = { id: string; navn: string; premie_kr: number | null; periode_slutt: string }
type Arr = { id: string; navn: string; dato: string }

type Data = {
  apneOppgaver: number
  uleste: number
  harKrenkelse: boolean
  premieIgjen: number
  sisteDato: string | null
  salgOms: number
  rutTot: number
  rutGjort: number
  sjekkTot: number
  sjekkSvart: number
  fokus: FokusPunkt[]
  ukerapporter: UkeRapport[]
  konk: Konk[]
  arr: Arr[]
}

const TOM: Data = { apneOppgaver: 0, uleste: 0, harKrenkelse: false, premieIgjen: 0, sisteDato: null, salgOms: 0, rutTot: 0, rutGjort: 0, sjekkTot: 0, sjekkSvart: 0, fokus: [], ukerapporter: [], konk: [], arr: [] }

const SNARVEIER = [
  { sti: '/produksjonsplan', ikon: '📋', navn: 'Produksjonsplan' },
  { sti: '/regnskap', ikon: '📊', navn: 'Regnskap' },
  { sti: '/svinn', ikon: '📉', navn: 'Svinn' },
  { sti: '/oppgaver', ikon: '✅', navn: 'Oppgaver' },
  { sti: '/tilbakemeldinger', ikon: '💬', navn: 'Tilbakemeldinger' },
  { sti: '/meldinger', ikon: '📨', navn: 'Tablet-meldinger' },
]

async function samle(supabase: SupabaseClient, bruker: InnloggetBruker, idag: string): Promise<Data> {
  try {
    const om30 = (() => { const d = new Date(`${idag}T12:00:00Z`); d.setUTCDate(d.getUTCDate() + 30); return d.toISOString().slice(0, 10) })()
    const [oppg, tilb, prem, bruk, salgDag, rutT, rutG, sjT, sjS, fokusSiste, konk, arr, stasjoner] = await Promise.all([
      supabase.from('oppgaver').select('*', { count: 'exact', head: true }).eq('status', 'apen').is('slettet_tid', null),
      supabase.from('tilbakemelding').select('alvorlighet, lest_tid').is('lest_tid', null).limit(200).overrideTypes<{ alvorlighet: string; lest_tid: string | null }[]>(),
      supabase.from('pengepremie').select('belop_kr').overrideTypes<{ belop_kr: number | null }[]>(),
      supabase.from('pengepremie_bruk').select('belop_kr').overrideTypes<{ belop_kr: number | null }[]>(),
      supabase.from('v_salg_per_stasjon_dag').select('dato, omsetning').order('dato', { ascending: false }).limit(20).overrideTypes<{ dato: string; omsetning: number | null }[]>(),
      supabase.from('rutiner').select('*', { count: 'exact', head: true }).is('slettet_tid', null),
      supabase.from('rutine_utforinger').select('*', { count: 'exact', head: true }).eq('dato', idag),
      supabase.from('sjekkpunkter').select('*', { count: 'exact', head: true }).is('slettet_tid', null),
      supabase.from('sjekkpunkt_svar').select('*', { count: 'exact', head: true }).eq('dato', idag),
      supabase.from('fokuspunkter').select('periode').order('periode', { ascending: false }).limit(1).maybeSingle<{ periode: string }>(),
      supabase.from('konkurranser').select('id, navn, premie_kr, periode_slutt').eq('status', 'aktiv').gte('periode_slutt', idag).is('slettet_tid', null).limit(5).overrideTypes<Konk[]>(),
      supabase.from('arrangementer').select('id, navn, dato').gte('dato', idag).lte('dato', om30).is('slettet_tid', null).order('dato').limit(8).overrideTypes<Arr[]>(),
      supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null),
    ])

    let fokus: FokusPunkt[] = []
    if (fokusSiste.data?.periode) {
      const { data } = await supabase.from('fokuspunkter').select('type, tekst, tittel').eq('periode', fokusSiste.data.periode).limit(6).overrideTypes<FokusPunkt[]>()
      fokus = data ?? []
    }

    // Siste salgsdag + omsetning for brukerens stasjon(er)
    const salg = salgDag.data ?? []
    const sisteDato = salg[0]?.dato ?? null
    const salgOms = sisteDato ? salg.filter((r) => r.dato === sisteDato).reduce((a, r) => a + (r.omsetning ?? 0), 0) : 0

    const ulesteTilb = tilb.data ?? []
    const vunnet = (prem.data ?? []).reduce((a, r) => a + (r.belop_kr ?? 0), 0)
    const brukt = (bruk.data ?? []).reduce((a, r) => a + (r.belop_kr ?? 0), 0)

    let ukerapporter: UkeRapport[] = []
    if (bruker.retailerId) {
      try { ukerapporter = await hentEllerLagUkerapport(supabase, bruker.retailerId, stasjoner.data ?? []) } catch { ukerapporter = [] }
    }

    return {
      apneOppgaver: oppg.count ?? 0,
      uleste: ulesteTilb.length,
      harKrenkelse: ulesteTilb.some((m) => m.alvorlighet === 'krenkelse'),
      premieIgjen: vunnet - brukt,
      sisteDato,
      salgOms,
      rutTot: rutT.count ?? 0,
      rutGjort: rutG.count ?? 0,
      sjekkTot: sjT.count ?? 0,
      sjekkSvart: sjS.count ?? 0,
      fokus,
      ukerapporter,
      konk: konk.data ?? [],
      arr: arr.data ?? [],
    }
  } catch {
    return TOM
  }
}

export async function ButikksjefDashbord({ bruker }: { bruker: InnloggetBruker }) {
  const supabase = await lagSupabaseServerKlient()
  const idag = iDag()
  const d = await samle(supabase, bruker, idag)
  const fornavn = bruker.fulltNavn?.split(' ')[0] ?? bruker.epost
  const tid = new Intl.DateTimeFormat('en-GB', { timeZone: 'Europe/Oslo', hour: '2-digit', hour12: false }).format(new Date())
  const t = Number(tid)
  const hils = t < 5 ? 'God natt' : t < 10 ? 'God morgen' : t < 18 ? 'God dag' : 'God kveld'

  return (
    <>
      <h1>{hils}, {fornavn} 👋</h1>
      <p className="undertittel">Din stasjon i dag{d.sisteDato ? ` · siste salgsdag ${datoLang.format(new Date(d.sisteDato))}` : ''}.</p>

      {/* Pott-banner */}
      {d.premieIgjen > 0 && (
        <Link href="/premier" className="kort pott-banner">
          <span>🎉 Dere har <strong>{kr.format(d.premieIgjen)}</strong> å bruke av premiepotten.</span>
          <span className="pott-pil">Se premier →</span>
        </Link>
      )}

      {/* Snarveier */}
      <section className="snarvei-grid">
        {SNARVEIER.map((s) => (
          <Link key={s.sti} href={s.sti} className="snarvei-kort">
            <span className="snarvei-ikon">{s.ikon}</span>
            <span>{s.navn}</span>
          </Link>
        ))}
      </section>

      {/* KPI / status */}
      <section className="nokkeltall">
        <Link href="/salg" className="kpi lenke">
          <span className="kpi-tall">{kr.format(d.salgOms)}</span>
          <span className="kpi-merke">Omsetning siste dag</span>
        </Link>
        <Link href="/oppgaver" className="kpi lenke">
          <span className={`kpi-tall ${d.apneOppgaver > 0 ? 'gul' : ''}`}>{d.apneOppgaver}</span>
          <span className="kpi-merke">Åpne oppgaver</span>
        </Link>
        <Link href="/tilbakemeldinger" className="kpi lenke">
          <span className={`kpi-tall ${d.harKrenkelse ? 'rod' : d.uleste > 0 ? 'gul' : ''}`}>{d.uleste}</span>
          <span className="kpi-merke">Uleste tilbakemeldinger{d.harKrenkelse ? ' 🚨' : ''}</span>
        </Link>
        {d.rutTot > 0 && (
          <Link href="/rutiner/oversikt" className="kpi lenke">
            <span className="kpi-tall">{d.rutGjort} / {d.rutTot}</span>
            <span className="kpi-merke">Rutiner gjort i dag</span>
          </Link>
        )}
      </section>

      {/* Ukerapport */}
      {d.ukerapporter.map((r) => <UkeKort key={r.stasjonId} rapport={r} />)}

      {/* Aktive konkurranser */}
      {d.konk.length > 0 && (
        <section className="kort">
          <h2>🏆 Aktive konkurranser</h2>
          <ul className="fokus-liste">
            {d.konk.map((k) => (
              <li key={k.id}>
                <strong>{k.navn}</strong>
                {k.premie_kr ? <span className="undertittel"> · {kr.format(Number(k.premie_kr))} i potten</span> : null}
                <span className="undertittel"> · til {datoLang.format(new Date(k.periode_slutt))}</span>
              </li>
            ))}
          </ul>
          <p className="undertittel" style={{ marginTop: '0.5rem' }}><Link href="/konkurranser">Se stillingen →</Link></p>
        </section>
      )}

      {/* Fokuspunkter */}
      {d.fokus.length > 0 && (
        <section className="kort">
          <h2>Dine fokuspunkter</h2>
          <ul className="fokus-liste">
            {d.fokus.map((f, i) => (
              <li key={i}>
                <span className={`status-pip ${f.type === 'positivt' ? 'gronn' : 'gul'}`}>{f.type === 'positivt' ? 'Bra' : 'Følg med'}</span>{' '}
                {f.tittel ? <strong>{f.tittel}: </strong> : null}{f.tekst}
              </li>
            ))}
          </ul>
          <p className="undertittel" style={{ marginTop: '0.5rem' }}><Link href="/fokus">Se alle fokuspunkter →</Link></p>
        </section>
      )}

      {/* Arrangementer */}
      {d.arr.length > 0 && (
        <section className="kort">
          <h2>📅 Kommende arrangementer</h2>
          <ul className="fokus-liste">
            {d.arr.map((a) => (
              <li key={a.id}><strong>{datoLang.format(new Date(a.dato))}</strong> · {a.navn}</li>
            ))}
          </ul>
        </section>
      )}
    </>
  )
}
