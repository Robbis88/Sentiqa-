import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { tilLonnslinjer, LONNSART } from '@/lib/lonn/tidsband'
import { vismaFilnavn } from '@/lib/lonn/vismafil'
import { vurderSats } from '@/lib/lonn/tariff'
import { vurderEksponering, ALVOR } from '@/lib/ansatt/eksponering'
import { delEtterLonnsform, UTELATT_FORDI, type Lonnsform } from '@/lib/lonn/lonnsform'
import { LonnsformVelger } from './lonnsform-velger'
import { TimesatsFelt } from './timesats-felt'
import { husketStasjon } from '@/lib/stasjonskontekst'
import { Sidehode, Tomtilstand, Forklaring } from '@/components/ui/side'
import Link from 'next/link'

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

  // Stasjonen velges i toppstripen og huskes. URL-en vinner fortsatt,
  // saa en delt lenke viser det den lovet.
  const valgtId = await husketStasjon(alle, sok.stasjon)
  const valgt = alle.find((s) => s.id === valgtId) ?? alle[0]
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
    .select('ansatt_nr, stillingsprosent, timesats, har_rammeavtale, lonnsform')
    .eq('stasjon_id', valgt.id)
  const avtale = new Map(
    ((avtaler ?? []) as
      { ansatt_nr: string; stillingsprosent: number | null; timesats: number | null
        har_rammeavtale: boolean; lonnsform: Lonnsform | null }[])
      .map((a) => [a.ansatt_nr, a]))

  // Fastlønnede og tilkallingsvikarer skal ikke i fila. Det var hele
  // avviket på Bønes i mai: 191,68 timer, butikksjefen og Carmen.
  const fordeling = delEtterLonnsform(
    linjer,
    new Map([...avtale].map(([nr, a]) => [nr, a.lonnsform ?? null])),
    LONNSART.timelonn,
  )
  const klar = fordeling.uavklart.length === 0

  // Tallene over fila beskriver fila — altså bare de som faktisk er med.
  const perArt = new Map<string, number>()
  for (const l of fordeling.med) perArt.set(l.lonnsart, (perArt.get(l.lonnsart) ?? 0) + l.antall)
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

  // NIVÅ 1 og 2 på en arbeidsflyt: hvor langt er jeg kommet, og hva
  // stopper meg. Sida sa metoden i sidehodet, og gjemte det ene
  // spørsmålet som avgjør alt — er fila klar? — nede i seksjon tre,
  // under en tabell over lønnsarter.
  const uavklarteTimer = fordeling.uavklart.reduce((s, u) => s + u.timer, 0)
  const svar = rader.length === 0
    ? 'Ingen stemplinger denne måneden'
    : klar
      ? `Klar for sending — ${tall.format(timer)} timer på ${new Set(fordeling.med.map((l) => l.ansattNr)).size} ansatte`
      : `${fordeling.uavklart.length} ${fordeling.uavklart.length === 1 ? 'ansatt mangler' : 'ansatte mangler'} lønnsform — fila lages ikke før det er avklart`

  return (
    <>
      <Sidehode
        tittel="Lønnsgrunnlag"
        undertittel={`${svar}. ${MND[maned - 1]} ${ar} · ${valgt.butikknummer} ${valgt.navn}`}
        handlinger={
          <form className="rutine-form">
            <select name="maned" defaultValue={maned} aria-label="Måned">
              {MND.map((m, i) => <option key={m} value={i + 1}>{m}</option>)}
            </select>
            <input name="ar" type="number" defaultValue={ar} style={{ width: '5rem' }} aria-label="År" />
            <button type="submit" className="sq-knapp">Vis</button>
          </form>
        }
      />

      {rader.length === 0 ? (
        <Tomtilstand
          tittel={`Ingen stemplinger for ${MND[maned - 1]} ${ar}`}
          forklaring="Lønnsgrunnlaget regnes fra stemplingene, så det må finnes stemplinger å regne på. Last opp Basis Export fra easy@work under Import."
          handling={<Link href="/import" className="sq-knapp primar">Gå til Import</Link>}
        />
      ) : (
        <>
          {/* NIVÅ 2 — det ene neste steget. Enten er fila klar, eller så
              er det én ting som stopper den. Begge deler sto tidligere
              under lønnsarttabellen, altså etter begrunnelsen. */}
          {klar ? (
            <section className="kort">
              <h2>Fila er klar</h2>
              <div className="knapperad">
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
          ) : (
            <section className="kort oppmerksomhet">
              <div className="varsel rod">
                <span className="varsel-dott" aria-hidden />
                <div className="varsel-tekst">
                  <div className="varsel-topp">
                    <strong>
                      {fordeling.uavklart.length}{' '}
                      {fordeling.uavklart.length === 1 ? 'ansatt mangler' : 'ansatte mangler'}
                      {' '}lønnsform
                    </strong>
                    <span className="varsel-omfang">{tall.format(uavklarteTimer)} timer</span>
                  </div>
                  <p className="varsel-detalj">
                    Fila lages ikke før det er avklart. En fil som mangler noens timer
                    betyr at hun ikke får lønn den måneden, og det oppdages først på
                    kontoutskriften. Sett lønnsformen i «Kontroll før sending» under — én
                    gang per ansatt, ikke én gang per måned.
                  </p>
                </div>
              </div>
            </section>
          )}

          <section className="kort">
            <h2>Dette ligger i fila</h2>
            <p>
              <strong>{tall.format(timer)} timer</strong> fordelt på{' '}
              {new Set(fordeling.med.map((l) => l.ansattNr)).size} ansatte
              og {fordeling.med.length} lønnslinjer.
            </p>

            {fordeling.utelatt.length > 0 && (
              <p className="undertittel">
                Holdt utenfor:{' '}
                {fordeling.utelatt.map((u, i) => (
                  <span key={u.ansattNr}>
                    {i > 0 && ', '}
                    {navnFor.get(u.ansattNr) ?? u.ansattNr} ({tall.format(u.timer)} t,{' '}
                    {u.lonnsform === 'fastlonn' ? 'fastlønn' : 'tilkalling'})
                  </span>
                ))}.
              </p>
            )}
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

            <Forklaring sporsmaal="Hvordan er timene regnet?">
              <p>
                Timene kommer fra stemplingene, delt opp etter tilleggsbåndene i
                Energiavtalen — hverdag 18–21, lørdag fra 18, søndag i tre bånd, og så
                videre. Fila har samme format som easy@work leverer til Azets i dag, én
                fil per stasjon.
              </p>
              <p>
                Fastlønnede og tilkallingsvikarer holdes utenfor. Det var hele avviket på
                Bønes i mai: 191,68 timer, butikksjefen fordi han er fastlønn og Carmen
                fordi hun er tilkallingsvikar. Laguneparken stemte samtidig på hundredelen
                mot easy@works egen fil.
              </p>
            </Forklaring>
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
              Timene er regnet fra stemplingene. Satsene er ikke — skriv dem inn i
              tabellen, så måles de mot Energiavtalen fra 01.07.2025. Satsen brukes
              ikke til å regne ut lønn: fila bærer timer, og Azets holder satsene.
              Den står her for å <strong>oppdage</strong> avvik, og kan derfor rettes
              når som helst — etter et oppgjør, eller når noen har skrevet feil.
            </p>
            <div className="tabellramme">
              <table className="tabell">
                <thead>
                  <tr>
                    <th>Ansatt</th><th className="tall">Timer</th>
                    <th>Lønnsform</th>
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
                        <td>
                          <LonnsformVelger
                            stasjonId={valgt.id}
                            ansattNr={nr}
                            navn={navnFor.get(nr) ?? nr}
                            verdi={a?.lonnsform ?? null}
                          />
                          {a?.lonnsform && a.lonnsform !== 'timelonn' && (
                            <span className="undertittel">
                              {UTELATT_FORDI[a.lonnsform]}
                            </span>
                          )}
                        </td>
                        <td className="tall">
                          {a?.stillingsprosent != null ? `${a.stillingsprosent} %` : '—'}
                        </td>
                        <td className="tall">
                          <TimesatsFelt
                            stasjonId={valgt.id}
                            ansattNr={nr}
                            navn={navnFor.get(nr) ?? nr}
                            verdi={a?.timesats != null ? Number(a.timesats) : null}
                          />
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
              Lønnsformen settes én gang per ansatt og huskes — ikke én gang per måned.
              <br />
              <strong>Åpen post:</strong> vi utelater fastlønnede helt, også
              tilleggene deres, fordi det er slik easy@work gjør det i dag. Om en
              fastlønnet som jobber julaften skal ha 1410 er et spørsmål til Azets,
              ikke noe vi bør avgjøre på egen hånd.
            </p>
          </section>
        </>
      )}
    </>
  )
}
