import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { tilLonnslinjer, LONNSART } from '@/lib/lonn/tidsband'
import { vismaFilnavn } from '@/lib/lonn/vismafil'
import { vurderSats } from '@/lib/lonn/tariff'
import { vurderEksponering, ALVOR } from '@/lib/ansatt/eksponering'

const MND = ['januar', 'februar', 'mars', 'april', 'mai', 'juni',
  'juli', 'august', 'september', 'oktober', 'november', 'desember']

// Navn på lønnsartene. Kodene er fasit — navnet varierer mellom stasjoner
// (9019 heter «Matpenger» på Bønes og «???» på Laguneparken), så det er
// kun til visning.
const LONNSARTNAVN: Record<string, string> = {
  '2': 'Timelønn',
  '1410': 'Helligdagsgodtgjørelse',
  '1429': 'Tillegg hverdag 18–21',
  '1430': 'Tillegg hverdag 21–24',
  '1431': 'Tillegg hverdag 00–06',
  '1432': 'Tillegg lørdag (fra 18)',
  '1433': 'Tillegg søndag 00–06',
  '1434': 'Tillegg søndag 06–18',
  '1435': 'Tillegg søndag 18–24',
}

type Sok = Promise<{ stasjon?: string; ar?: string; maned?: string }>

const tall = new Intl.NumberFormat('nb-NO', { minimumFractionDigits: 2, maximumFractionDigits: 2 })

export default async function LonnSide({ searchParams }: { searchParams: Sok }) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return <p>Lønnsgrunnlaget er for butikksjef og eier.</p>

  const sok = await searchParams
  const supabase = await lagSupabaseServerKlient()

  const { data: stasjoner } = await supabase
    .from('stasjoner').select('id, navn, butikknummer')
    .is('slettet_tid', null).order('butikknummer')
  const alle = (stasjoner ?? []) as { id: string; navn: string; butikknummer: string }[]
  if (alle.length === 0) return <p>Ingen stasjoner registrert.</p>

  const valgt = alle.find((s) => s.id === sok.stasjon) ?? alle[0]
  // Standard er FORRIGE måned — det er den man lønner.
  const naa = new Date()
  const forrige = naa.getUTCMonth() === 0
    ? { ar: naa.getUTCFullYear() - 1, maned: 12 }
    : { ar: naa.getUTCFullYear(), maned: naa.getUTCMonth() }
  const ar = Number(sok.ar) || forrige.ar
  const maned = Number(sok.maned) || forrige.maned

  const fra = `${ar}-${String(maned).padStart(2, '0')}-01`
  const til = `${ar}-${String(maned).padStart(2, '0')}-${new Date(Date.UTC(ar, maned, 0)).getUTCDate()}`

  const { data: stempl } = await supabase
    .from('stempling')
    .select('ansatt_nr, ansatt_navn, dato, fra_tid, til_tid')
    .eq('stasjon_id', valgt.id)
    .eq('betalt', true)
    .gte('dato', fra)
    .lte('dato', til)
    .order('dato')
  const rader = (stempl ?? []) as {
    ansatt_nr: string; ansatt_navn: string; dato: string; fra_tid: string; til_tid: string
  }[]

  const navnFor = new Map(rader.map((r) => [r.ansatt_nr, r.ansatt_navn]))
  const linjer = tilLonnslinjer(rader.map((r) => ({
    ansattNr: r.ansatt_nr,
    dato: r.dato,
    fraTid: r.fra_tid.slice(0, 5),
    tilTid: r.til_tid.slice(0, 5),
  })))

  // Bekreftede stillinger og satser — til tariffkontrollen.
  const { data: avtaler } = await supabase
    .from('ansatt_avtale')
    .select('ansatt_nr, stillingsprosent, timesats, har_rammeavtale')
    .eq('stasjon_id', valgt.id)
  const avtale = new Map(
    ((avtaler ?? []) as
      { ansatt_nr: string; stillingsprosent: number | null; timesats: number | null
        har_rammeavtale: boolean }[])
      .map((a) => [a.ansatt_nr, a]))

  const perArt = new Map<string, number>()
  for (const l of linjer) perArt.set(l.lonnsart, (perArt.get(l.lonnsart) ?? 0) + l.antall)
  const perAnsatt = new Map<string, number>()
  for (const l of linjer) {
    if (l.lonnsart === LONNSART.timelonn) perAnsatt.set(l.ansattNr, l.antall)
  }
  const timer = perArt.get(LONNSART.timelonn) ?? 0

  // Kontraktseksponering: hvem jobber mer enn papirene dekker. Regnes paa
  // hele historikken, ikke bare maaneden vi ser paa — en sesong er ikke
  // synlig i en enkelt maaned.
  const { data: hist } = await supabase
    .from('v_stempling_ansatt_mnd')
    .select('ansatt_nr, ansatt_navn, maaned, timer')
    .eq('stasjon_id', valgt.id)
  const perPerson = new Map<string, { navn: string; mnd: { maaned: string; timer: number }[] }>()
  for (const h of (hist ?? []) as
    { ansatt_nr: string; ansatt_navn: string; maaned: string; timer: number }[]) {
    const p = perPerson.get(h.ansatt_nr) ?? { navn: h.ansatt_navn, mnd: [] }
    p.navn = h.ansatt_navn
    p.mnd.push({ maaned: h.maaned.slice(0, 7), timer: Number(h.timer) })
    perPerson.set(h.ansatt_nr, p)
  }
  const eksponering = [...perPerson]
    .map(([nr, p]) => vurderEksponering({
      ansattNr: nr,
      navn: p.navn,
      kontraktProsent: avtale.get(nr)?.stillingsprosent ?? null,
      harRammeavtale: avtale.get(nr)?.har_rammeavtale ?? false,
    }, p.mnd))
    .filter((e) => e.maaneder >= 6 && e.vurdering !== 'ok')
    .sort((a, b) => ALVOR[a.vurdering] - ALVOR[b.vurdering] || b.toppProsent - a.toppProsent)

  return (
    <>
      <h1>Lønnsgrunnlag</h1>
      <p className="undertittel">
        Regnet fra stemplingene, med tilleggsbåndene i Energiavtalen. Fila har samme
        format som easy@work leverer til Azets i dag — én fil per stasjon.
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

      {rader.length === 0 ? (
        <section className="kort">
          <p className="undertittel">
            Ingen stemplinger for {MND[maned - 1]} {ar} på denne stasjonen. Last opp
            Basis Export fra easy@work på <a href="/import">/import</a> først.
          </p>
        </section>
      ) : (
        <>
          <section className="kort">
            <h2>{MND[maned - 1]} {ar} · {valgt.navn}</h2>
            <p>
              <strong>{tall.format(timer)} timer</strong> fordelt på {perAnsatt.size} ansatte
              og {linjer.length} lønnslinjer.
            </p>
            <div className="tabellramme">
              <table className="tabell">
                <thead>
                  <tr><th>Kode</th><th>Lønnsart</th><th className="tall">Timer</th></tr>
                </thead>
                <tbody>
                  {[...perArt].map(([kode, sum]) => (
                    <tr key={kode}>
                      <td><code>{kode}</code></td>
                      <td>{LONNSARTNAVN[kode] ?? kode}</td>
                      <td className="tall">{tall.format(sum)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <div className="knapperad" style={{ marginTop: '1rem' }}>
              <a
                className="sq-knapp primar"
                href={`/api/lonn/visma?stasjon=${valgt.id}&ar=${ar}&maned=${maned}`}
                download={vismaFilnavn(valgt.butikknummer, ar, maned)}
              >
                Last ned Visma-fil
              </a>
            </div>
            <p className="notis">
              <strong>Ikke åpne fila i Excel.</strong> Norsk Excel gjør 9.00 til 9,00 og
              stripper anførselstegnene, og da må Azets legge inn alt manuelt. Last den
              ned og send den videre uten å åpne den.
            </p>
          </section>

          {eksponering.length > 0 && (
            <section className="kort">
              <h2>Kontrakter som ikke dekker arbeidet</h2>
              <p className="undertittel">
                Målt på hele stemplingshistorikken, ikke bare denne måneden — en sesong
                er ikke synlig i én måned. Virke: en deltidsansatt som skal kunne ta en
                ekstravakt ved sykdom trenger rammeavtale om tilkalling i tillegg til
                den faste avtalen.
              </p>
              <div className="tabellramme">
                <table className="tabell">
                  <thead>
                    <tr>
                      <th>Ansatt</th><th className="tall">Kontrakt</th>
                      <th className="tall">Snitt</th><th className="tall">Topp</th>
                      <th>Hva mangler</th>
                    </tr>
                  </thead>
                  <tbody>
                    {eksponering.map((e) => {
                      const klasse = e.vurdering === 'bor_okes' ? 'rod'
                        : e.vurdering === 'mangler_ramme' ? 'gul'
                          : e.vurdering === 'sesong' ? 'bla' : 'noytral'
                      const ord = e.vurdering === 'bor_okes' ? 'Bør økes'
                        : e.vurdering === 'mangler_ramme' ? 'Mangler rammeavtale'
                          : e.vurdering === 'sesong' ? 'Midlertidig avtale'
                            : 'Ikke bekreftet'
                      return (
                        <tr key={e.ansattNr}>
                          <td>{e.navn}</td>
                          <td className="tall">
                            {e.kontraktProsent != null ? `${e.kontraktProsent} %` : '—'}
                          </td>
                          <td className="tall">{e.snittProsent} %</td>
                          <td className="tall">{e.toppProsent} %</td>
                          <td>
                            <span className={`status-pip ${klasse}`}>{ord}</span>
                            <br />
                            <span className="undertittel">{e.melding}</span>
                          </td>
                        </tr>
                      )
                    })}
                  </tbody>
                </table>
              </div>
              <p className="notis" style={{ marginBottom: 0 }}>
                <strong>Bør økes</strong> er den alvorligste: etter aml. § 14-4 a kan en
                deltidsansatt kreve stilling tilsvarende det hun faktisk har jobbet siste
                tolv måneder, og en rammeavtale beskytter ikke mot det.
              </p>
            </section>
          )}

          <section className="kort">
            <h2>Kontroll før sending</h2>
            <p className="undertittel">
              Timene er regnet fra stemplingene. Satsene er ikke — de registreres
              her, og måles mot Energiavtalens satser fra 01.07.2025.
            </p>
            <div className="tabellramme">
              <table className="tabell">
                <thead>
                  <tr>
                    <th>Ansatt</th><th className="tall">Timer</th>
                    <th className="tall">Stilling</th><th className="tall">Timesats</th>
                    <th>Mot Energiavtalen</th>
                  </tr>
                </thead>
                <tbody>
                  {[...perAnsatt].sort((a, b) => b[1] - a[1]).map(([nr, t]) => {
                    const a = avtale.get(nr)
                    const v = a?.timesats != null ? vurderSats(Number(a.timesats)) : null
                    const klasse = v?.status === 'under' ? 'rod'
                      : v?.status === 'mellom' ? 'gul'
                        : v?.status === 'tariff' ? 'gronn' : 'noytral'
                    return (
                      <tr key={nr}>
                        <td>{navnFor.get(nr) ?? nr}</td>
                        <td className="tall">{tall.format(t)}</td>
                        <td className="tall">
                          {a?.stillingsprosent != null ? `${a.stillingsprosent} %` : '—'}
                        </td>
                        <td className="tall">
                          {a?.timesats != null ? tall.format(Number(a.timesats)) : '—'}
                        </td>
                        <td>
                          {v ? (
                            <>
                              <span className={`status-pip ${klasse}`}>
                                {v.status === 'tariff' ? 'Tariff'
                                  : v.status === 'under' ? 'Under minstelønn'
                                    : v.status === 'mellom' ? 'Mellom trinn' : 'Lokal avtale'}
                              </span>
                              <br />
                              <span className="undertittel">{v.melding}</span>
                            </>
                          ) : (
                            <span className="undertittel">Timesats ikke registrert</span>
                          )}
                        </td>
                      </tr>
                    )
                  })}
                </tbody>
              </table>
            </div>
            <p className="notis" style={{ marginBottom: 0 }}>
              Fastlønnede og tilkallingsvikarer skal <strong>ikke</strong> være med i denne
              fila. I dag skiller ikke systemet dem ut — det kommer når ansattkortene er
              på plass. Sjekk lista før du sender.
            </p>
          </section>
        </>
      )}
    </>
  )
}
