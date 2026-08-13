import Link from 'next/link'
import type { SupabaseClient } from '@supabase/supabase-js'
import type { InnloggetBruker } from '@/lib/auth/typer'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { kr, datoLang, iDag } from '@/lib/format'
import { hentEllerLagUkerapport, type UkeRapport } from '@/lib/ukerapport'
import {
  avdelingsSignaler, pulsOverskrift, rangerSignaler, type RaaSignal, type Signal,
} from '@/lib/signaler'
import { Oppmerksomhet } from './oppmerksomhet'

// =====================================================================
// Butikksjefens forside.
//
// Rekkefølgen er hele poenget: OPPMERKSOMHET → FORSTÅELSE → HANDLING.
// Før lå åtte likestilte seksjoner her — snarveier, fire KPI-kort, et
// AI-avsnitt, konkurranser, fokuspunkter, arrangementer — uten at noe av
// det sa hva som hastet. Snarveiene er borte fordi menyen gjør den jobben
// nå; alt annet er beholdt, men rangert.
//
// Salgsdata er ikke sanntid — de kommer dagen etter. Derfor står
// ferskheten øverst, og «Resultater» og «I dag» er holdt fra hverandre.
// =====================================================================

type FokusPunkt = { type: string; tekst: string; tittel: string | null }
type Konk = { id: string; navn: string; premie_kr: number | null; periode_slutt: string }
type Arr = { id: string; navn: string; dato: string }
type Oppgave = { id: string; tittel: string; frist: string | null }
type Avvik = { id: string; beskrivelse: string; frist: string | null }
type Varsel = { id: string; tittel: string; tekst: string | null; type: string; lenke: string | null }

type Data = {
  stasjonsnavn: string
  apneOppgaver: number
  forsinkede: Oppgave[]
  uleste: number
  harKrenkelse: boolean
  premieIgjen: number
  sisteDato: string | null
  rutTot: number
  rutGjort: number
  sjekkTot: number
  sjekkSvart: number
  fokus: FokusPunkt[]
  ukerapport: UkeRapport | null
  konk: Konk[]
  arr: Arr[]
  avvik: Avvik[]
  varsler: Varsel[]
}

const TOM: Data = {
  stasjonsnavn: 'Stasjonen', apneOppgaver: 0, forsinkede: [], uleste: 0, harKrenkelse: false,
  premieIgjen: 0, sisteDato: null, rutTot: 0, rutGjort: 0, sjekkTot: 0, sjekkSvart: 0,
  fokus: [], ukerapport: null, konk: [], arr: [], avvik: [], varsler: [],
}

const dagerSiden = (iso: string, idag: string) =>
  Math.round((Date.parse(`${idag}T12:00:00Z`) - Date.parse(`${iso}T12:00:00Z`)) / 86400000)

async function samle(supabase: SupabaseClient, bruker: InnloggetBruker, idag: string): Promise<Data> {
  try {
    const om30 = (() => {
      const d = new Date(`${idag}T12:00:00Z`); d.setUTCDate(d.getUTCDate() + 30)
      return d.toISOString().slice(0, 10)
    })()

    const [oppgRes, tilb, prem, bruk, salgDag, rutT, rutG, sjT, sjS, fokusSiste, konk, arr, stasjoner, avvikRes, varslerRes] =
      await Promise.all([
        supabase.from('oppgaver').select('id, tittel, frist, status').eq('status', 'apen').is('slettet_tid', null)
          .overrideTypes<{ id: string; tittel: string; frist: string | null; status: string }[]>(),
        supabase.from('tilbakemelding').select('alvorlighet, lest_tid').is('lest_tid', null).limit(200)
          .overrideTypes<{ alvorlighet: string; lest_tid: string | null }[]>(),
        supabase.from('pengepremie').select('belop_kr').overrideTypes<{ belop_kr: number | null }[]>(),
        supabase.from('pengepremie_bruk').select('belop_kr').overrideTypes<{ belop_kr: number | null }[]>(),
        supabase.from('v_salg_per_stasjon_dag').select('dato').order('dato', { ascending: false }).limit(1)
          .overrideTypes<{ dato: string }[]>(),
        supabase.from('rutiner').select('*', { count: 'exact', head: true }).is('slettet_tid', null),
        supabase.from('rutine_utforinger').select('*', { count: 'exact', head: true }).eq('dato', idag),
        supabase.from('sjekkpunkter').select('*', { count: 'exact', head: true }).is('slettet_tid', null),
        supabase.from('sjekkpunkt_svar').select('*', { count: 'exact', head: true }).eq('dato', idag),
        supabase.from('fokuspunkter').select('periode').order('periode', { ascending: false }).limit(1).maybeSingle<{ periode: string }>(),
        supabase.from('konkurranser').select('id, navn, premie_kr, periode_slutt').eq('status', 'aktiv')
          .gte('periode_slutt', idag).is('slettet_tid', null).limit(5).overrideTypes<Konk[]>(),
        supabase.from('arrangementer').select('id, navn, dato').gte('dato', idag).lte('dato', om30)
          .is('slettet_tid', null).order('dato').limit(8).overrideTypes<Arr[]>(),
        supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null),
        supabase.from('avvik').select('id, beskrivelse, frist').eq('gjennomfort', false).is('slettet_tid', null)
          .order('frist', { nullsFirst: false }).limit(10).overrideTypes<Avvik[]>(),
        supabase.from('varsler').select('id, tittel, tekst, type, lenke').eq('lest', false).is('slettet_tid', null)
          .order('opprettet_tid', { ascending: false }).limit(10).overrideTypes<Varsel[]>(),
      ])

    let fokus: FokusPunkt[] = []
    if (fokusSiste.data?.periode) {
      const { data } = await supabase.from('fokuspunkter').select('type, tekst, tittel')
        .eq('periode', fokusSiste.data.periode).limit(6).overrideTypes<FokusPunkt[]>()
      fokus = data ?? []
    }

    const stasjonsListe = stasjoner.data ?? []
    const stasjonsnavn = stasjonsListe.length === 1 ? stasjonsListe[0].navn : 'Dine stasjoner'

    const ulesteTilb = tilb.data ?? []
    const vunnet = (prem.data ?? []).reduce((a, r) => a + (r.belop_kr ?? 0), 0)
    const brukt = (bruk.data ?? []).reduce((a, r) => a + (r.belop_kr ?? 0), 0)

    let ukerapport: UkeRapport | null = null
    if (bruker.retailerId) {
      try {
        const r = await hentEllerLagUkerapport(supabase, bruker.retailerId, stasjonsListe)
        ukerapport = r[0] ?? null
      } catch { ukerapport = null }
    }

    const apne = oppgRes.data ?? []
    return {
      stasjonsnavn,
      apneOppgaver: apne.length,
      forsinkede: apne.filter((o) => o.frist && o.frist < idag),
      uleste: ulesteTilb.length,
      harKrenkelse: ulesteTilb.some((m) => m.alvorlighet === 'krenkelse'),
      premieIgjen: vunnet - brukt,
      sisteDato: salgDag.data?.[0]?.dato ?? null,
      rutTot: rutT.count ?? 0,
      rutGjort: rutG.count ?? 0,
      sjekkTot: sjT.count ?? 0,
      sjekkSvart: sjS.count ?? 0,
      fokus,
      ukerapport,
      konk: konk.data ?? [],
      arr: arr.data ?? [],
      avvik: avvikRes.data ?? [],
      varsler: varslerRes.data ?? [],
    }
  } catch {
    return TOM
  }
}

// Alle kilder samles til én rangert liste. Rekkefølgen mellom dem avgjøres
// av signaler.ts, ikke av hvilken spørring som kom først.
function byggSignaler(d: Data, idag: string): Signal[] {
  const raa: RaaSignal[] = []

  if (d.harKrenkelse) {
    raa.push({
      id: 'krenkelse', merke: 'Tilbakemelding', tittel: 'Melding om krenkelse',
      detalj: 'En ansatt har meldt fra om noe alvorlig. Dette skal leses først.',
      niva: 'kritisk', lenke: '/tilbakemeldinger',
    })
  }

  if (d.ukerapport) {
    raa.push(...avdelingsSignaler({
      avdelinger: d.ukerapport.avdelinger,
      omsetning: d.ukerapport.omsetning,
      omsetningIfjor: d.ukerapport.omsetningIfjor,
    }))
  }

  for (const a of d.avvik) {
    const forsinket = Boolean(a.frist && a.frist < idag)
    raa.push({
      id: `avvik-${a.id}`, merke: 'IK-mat', tittel: forsinket ? 'Avvik over frist' : 'Åpent avvik',
      detalj: a.beskrivelse.slice(0, 160),
      niva: forsinket ? 'kritisk' : 'folg', lenke: '/ikmat',
      dager: a.frist ? Math.max(0, dagerSiden(a.frist, idag)) : null,
    })
  }

  if (d.forsinkede.length > 0) {
    const eldst = d.forsinkede.reduce((a, b) => ((a.frist ?? '') < (b.frist ?? '') ? a : b))
    raa.push({
      id: 'oppgaver-forsinket', merke: 'Oppgaver',
      tittel: `${d.forsinkede.length} ${d.forsinkede.length === 1 ? 'oppgave' : 'oppgaver'} over frist`,
      endring: `eldst ${eldst.frist}`,
      detalj: d.forsinkede.slice(0, 3).map((o) => o.tittel).join(' · '),
      niva: 'folg', lenke: '/oppgaver',
      dager: eldst.frist ? dagerSiden(eldst.frist, idag) : null,
    })
  }

  if (d.uleste > 0 && !d.harKrenkelse) {
    raa.push({
      id: 'tilbakemeldinger', merke: 'Tilbakemelding',
      tittel: `${d.uleste} ${d.uleste === 1 ? 'ulest melding' : 'uleste meldinger'}`,
      detalj: 'Fra tableten. De eldste ligger øverst når du åpner.',
      niva: 'info', lenke: '/tilbakemeldinger',
    })
  }

  // Varsler fra andre motorer — bemanning i dag, flere senere.
  for (const v of d.varsler) {
    raa.push({
      id: `varsel-${v.id}`,
      merke: v.type.startsWith('bemanning') ? 'Bemanning' : 'Varsel',
      tittel: v.tittel,
      detalj: v.tekst ?? '',
      niva: v.type === 'bemanning_ok' ? 'info' : 'folg',
      lenke: v.lenke ?? '/varsler',
    })
  }

  return rangerSignaler(raa)
}

function Maal({ merke, naa, ifjor }: { merke: string; naa: number; ifjor: number }) {
  const pst = ifjor > 0 ? ((naa - ifjor) / ifjor) * 100 : 0
  const opp = pst >= 0
  return (
    <div className="sq-maal">
      <span className="sq-merkelapp">{merke}</span>
      <span className="sq-verdi">{kr.format(naa)}</span>
      <span className="sq-under">
        <span className={`sq-delta ${opp ? 'opp' : 'ned'}`}>
          {opp ? '↑' : '↓'} {Math.abs(pst).toFixed(0)} %
        </span>
        <span className="sq-merkelapp">
          {opp ? '+' : '−'}{kr.format(Math.abs(naa - ifjor))} mot i fjor
        </span>
      </span>
    </div>
  )
}

export async function ButikksjefDashbord({ bruker }: { bruker: InnloggetBruker }) {
  const supabase = await lagSupabaseServerKlient()
  const idag = iDag()
  const d = await samle(supabase, bruker, idag)
  const signaler = byggSignaler(d, idag)

  const fornavn = bruker.fulltNavn?.split(' ')[0] ?? bruker.epost
  const time = Number(new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Europe/Oslo', hour: '2-digit', hour12: false,
  }).format(new Date()))
  const hils = time < 5 ? 'God natt' : time < 10 ? 'God morgen' : time < 18 ? 'God dag' : 'God kveld'

  const r = d.ukerapport
  const vekst = r && r.omsetningIfjor > 0 ? ((r.omsetning - r.omsetningIfjor) / r.omsetningIfjor) * 100 : null

  return (
    <div className="sq">
      {/* 1 · Kontekst og ferskhet */}
      <header className="sq-hode">
        <p className="sq-hils">{hils}, {fornavn}</p>
        <h1>{d.stasjonsnavn}</h1>
        <div className="sq-ferskhet">
          <span className="sq-merkelapp">{datoLang.format(new Date(`${idag}T12:00:00Z`))}</span>
          {d.sisteDato && (
            <span className="sq-merkelapp sq-pip">
              Siste salgsdag {datoLang.format(new Date(`${d.sisteDato}T12:00:00Z`))}
            </span>
          )}
        </div>
      </header>

      {/* 2 · Puls — resultater til og med siste salgsdag */}
      {r && vekst != null ? (
        <section className="sq-puls">
          <div>
            <h2>{pulsOverskrift(d.stasjonsnavn, vekst)}</h2>
            <p className="sq-forklar">
              Tallene gjelder forrige hele uke mot samme uke i fjor.
              {signaler.length > 0 && ` ${signaler.length} ${signaler.length === 1 ? 'sak' : 'saker'} under trenger et blikk.`}
            </p>
            {/* Sammendraget fra ukerapporten er beholdt, men foldet bort.
                Et avsnitt skal ikke være det første øyet møter — det er
                tallene og sakene som skal svare på fem sekunder. */}
            {r.sammendrag && (
              <details className="sq-ai">
                <summary>Sentiqas oppsummering av uken</summary>
                <p>{r.sammendrag}</p>
              </details>
            )}
            <p className="undertittel sq-kilde">
              <Link href="/salg">Se salget →</Link>
            </p>
          </div>
          <div className="sq-maal-par">
            <Maal merke="Omsetning · forrige uke" naa={r.omsetning} ifjor={r.omsetningIfjor} />
            <Maal merke="Bruttofortjeneste" naa={r.brutto} ifjor={r.bruttoIfjor} />
          </div>
        </section>
      ) : (
        <section className="sq-puls">
          <div>
            <h2>Venter på en komplett uke</h2>
            <p className="sq-forklar">
              Ukesammenligningen dukker opp når det finnes daglige salgsdata for en hel uke
              (mandag–søndag), og samme uke i fjor.
              {d.sisteDato ? ` Siste salgsdag i systemet er ${datoLang.format(new Date(`${d.sisteDato}T12:00:00Z`))}.` : ''}
            </p>
          </div>
        </section>
      )}

      {/* 3 · Oppmerksomhet */}
      <Oppmerksomhet signaler={signaler} />

      {/* 4 · I dag og fremover — holdt fra resultatene over */}
      <div className="sq-to">
        <section>
          <div className="sq-seksjon-hode">
            <h2>I dag</h2>
            <span className="sq-merkelapp">Sanntid</span>
          </div>
          <ul className="sq-liste">
            {d.rutTot > 0 && (
              <li>
                <span>Rutiner</span>
                <Link href="/rutiner/oversikt" className="sq-h">{d.rutGjort} / {d.rutTot}</Link>
              </li>
            )}
            {d.sjekkTot > 0 && (
              <li>
                <span>Sjekkpunkt</span>
                <Link href="/sjekkpunkt" className="sq-h">{d.sjekkSvart} / {d.sjekkTot}</Link>
              </li>
            )}
            <li>
              <span>Åpne oppgaver</span>
              <Link href="/oppgaver" className="sq-h">{d.apneOppgaver}</Link>
            </li>
            {d.premieIgjen > 0 && (
              <li>
                <span>Premiepott å bruke</span>
                <Link href="/premier" className="sq-h">{kr.format(d.premieIgjen)}</Link>
              </li>
            )}
          </ul>
        </section>

        <section>
          <div className="sq-seksjon-hode">
            <h2>Fremover</h2>
            <span className="sq-merkelapp">Neste 30 dager</span>
          </div>
          <ul className="sq-liste">
            {d.arr.map((a) => (
              <li key={a.id}>
                <span>{a.navn}</span>
                <span className="sq-h">{datoLang.format(new Date(`${a.dato}T12:00:00Z`))}</span>
              </li>
            ))}
            {d.konk.map((k) => (
              <li key={k.id}>
                <span>{k.navn}</span>
                <Link href="/konkurranser" className="sq-h">
                  {k.premie_kr ? kr.format(Number(k.premie_kr)) : 'Se stilling'}
                </Link>
              </li>
            ))}
            {d.arr.length === 0 && d.konk.length === 0 && (
              <li><span className="undertittel">Ingenting planlagt de neste 30 dagene.</span></li>
            )}
          </ul>
        </section>
      </div>

      {/* 5 · Fokuspunkter — sjefens egne prioriteringer, beholdt */}
      {d.fokus.length > 0 && (
        <section className="sq-seksjon">
          <div className="sq-seksjon-hode">
            <h2>Dine fokuspunkter</h2>
            <Link href="/fokus" className="sq-merkelapp">Se alle →</Link>
          </div>
          <ul className="sq-liste">
            {d.fokus.map((f, i) => (
              <li key={i}>
                <span className={`status-pip ${f.type === 'positivt' ? 'gronn' : 'gul'}`}>
                  {f.type === 'positivt' ? 'Bra' : 'Følg med'}
                </span>
                <span>{f.tittel ? <strong>{f.tittel}: </strong> : null}{f.tekst}</span>
              </li>
            ))}
          </ul>
        </section>
      )}
    </div>
  )
}
