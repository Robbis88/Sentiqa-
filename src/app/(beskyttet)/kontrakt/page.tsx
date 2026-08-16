import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { finnFelter } from '@/lib/kontrakt/docx'
import {
  alternativer, byggVerdier, erMindreaarig, manglerVerdi, FELTKILDER,
  type Ansettelsesform, type Rolle,
} from '@/lib/kontrakt/felter'
import {
  AnsattkortSkjema, MalSkjema, StandardfeltSkjema, FORMER, ROLLER,
} from './skjemaer'

type Sok = Promise<{ stasjon?: string; ansatt?: string; form?: string; rolle?: string }>

type Avtale = {
  ansatt_nr: string; navn: string; fodselsdato: string | null
  stillingsprosent: number | null; timesats: number | null
  skiftordning: 'ordinaer' | 'to_skift' | null
  stillingstittel: string | null; har_rammeavtale: boolean
}

const dato = (iso: string | null) =>
  (iso ? new Date(iso).toLocaleDateString('nb-NO') : '—')

export default async function KontraktSide({ searchParams }: { searchParams: Sok }) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return <p>Arbeidsavtaler er for butikksjef og eier.</p>
  const eier = bruker.rolle === 'retailer_admin'

  const sok = await searchParams
  const iDag = new Date().toISOString().slice(0, 10)
  const supabase = await lagSupabaseServerKlient()

  const { data: stasjoner } = await supabase
    .from('stasjoner').select('id, navn, butikknummer, adresse')
    .is('slettet_tid', null).order('butikknummer')
  const alle = (stasjoner ?? []) as
    { id: string; navn: string; butikknummer: string; adresse: string | null }[]
  if (alle.length === 0) return <p>Ingen stasjoner registrert.</p>
  const valgt = alle.find((s) => s.id === sok.stasjon) ?? alle[0]

  const [{ data: avtaler }, { data: stemplet }, { data: retailer }] = await Promise.all([
    supabase.from('ansatt_avtale')
      // Én linje: PostgREST utleder radtypen fra strengliteralen, og en
      // sammensatt streng gir bare GenericStringError.
      .select('ansatt_nr, navn, fodselsdato, stillingsprosent, timesats, skiftordning, stillingstittel, har_rammeavtale')
      .eq('stasjon_id', valgt.id),
    supabase.from('v_stempling_ansatt_mnd')
      .select('ansatt_nr, ansatt_navn').eq('stasjon_id', valgt.id),
    supabase.from('retailers')
      .select('navn, org_nr, tariffbundet, kontrakt_standardfelt')
      .maybeSingle<{
        navn: string; org_nr: string | null; tariffbundet: boolean
        kontrakt_standardfelt: Record<string, string>
      }>(),
  ])

  // Ansatte som finnes i stemplingene, men ennå ikke har ansattkort, skal
  // med i lista — det er nettopp dem man skal skrive kontrakt for.
  const kort = new Map<string, Avtale>()
  for (const a of (avtaler ?? []) as Avtale[]) kort.set(a.ansatt_nr, a)
  for (const s of (stemplet ?? []) as { ansatt_nr: string; ansatt_navn: string }[]) {
    if (!kort.has(s.ansatt_nr)) {
      kort.set(s.ansatt_nr, {
        ansatt_nr: s.ansatt_nr, navn: s.ansatt_navn, fodselsdato: null,
        stillingsprosent: null, timesats: null, skiftordning: null,
        stillingstittel: null, har_rammeavtale: false,
      })
    }
  }
  const ansatte = [...kort.values()].sort((a, b) => a.navn.localeCompare(b.navn, 'nb'))

  const person = ansatte.find((a) => a.ansatt_nr === sok.ansatt) ?? ansatte[0] ?? null
  const form = (FORMER.some((f) => f.verdi === sok.form) ? sok.form : 'fast') as Ansettelsesform
  const rolle = (ROLLER.some((r) => r.verdi === sok.rolle) ? sok.rolle : 'ansatt') as Rolle

  const mindreaarig = erMindreaarig(person?.fodselsdato ?? null, iDag)

  const { data: maler } = await supabase
    .from('kontraktmal')
    .select('id, ansettelsesform, rolle, mindreaarig, versjon, filnavn, storage_sti, aktiv')
    .eq('aktiv', true)
    .order('ansettelsesform')
  const aktive = (maler ?? []) as {
    id: string; ansettelsesform: string; rolle: string; mindreaarig: boolean
    versjon: number; filnavn: string; storage_sti: string
  }[]
  const mal = aktive.find((m) =>
    m.ansettelsesform === form && m.rolle === rolle && m.mindreaarig === mindreaarig)

  // Feltene leses ut av malfila, ikke hardkodes. Endrer Virke en setning,
  // følger skjemaet etter av seg selv.
  let feltIMal: string[] = []
  if (mal) {
    const ned = await supabase.storage.from('raa-filer').download(mal.storage_sti)
    if (ned.data) feltIMal = finnFelter(new Uint8Array(await ned.data.arrayBuffer()))
  }

  const verdier = person ? byggVerdier({
    kjede: {
      navn: retailer?.navn ?? '',
      orgNr: retailer?.org_nr ?? null,
      standardfelt: retailer?.kontrakt_standardfelt ?? {},
    },
    stasjon: { navn: valgt.navn, adresse: valgt.adresse },
    ansatt: {
      navn: person.navn,
      fodselsdato: person.fodselsdato,
      stillingsprosent: person.stillingsprosent,
      timesats: person.timesats != null ? Number(person.timesats) : null,
      skiftordning: person.skiftordning,
    },
    svar: person.stillingstittel ? { stillingstittel: person.stillingstittel } : {},
  }) : {}

  const mangler = manglerVerdi(feltIMal, verdier)
  const valg = alternativer(feltIMal)
  const fraKjeden = mangler.filter((m) => m.kilde === 'kjede')
  const maaSvares = mangler.filter((m) => m.kilde !== 'kjede')

  const { data: skrevne } = await supabase
    .from('ansatt_kontrakt')
    .select('id, ansatt_navn, mal_versjon, gjelder_fra, status, opprettet_tid')
    .eq('stasjon_id', valgt.id)
    .order('opprettet_tid', { ascending: false })
    .limit(20)
  const historikk = (skrevne ?? []) as {
    id: string; ansatt_navn: string; mal_versjon: number | null
    gjelder_fra: string | null; status: string; opprettet_tid: string
  }[]

  return (
    <>
      <h1>Arbeidsavtaler</h1>
      <p className="undertittel">
        Malene er Virkes, juridisk gjennomgått. Vi fyller ut originalen og lar
        ordlyden stå — den er hele grunnen til å bruke dem.
      </p>

      <section className="kort">
        <form className="rutine-form">
          <select name="stasjon" defaultValue={valgt.id}>
            {alle.map((s) => <option key={s.id} value={s.id}>{s.butikknummer} {s.navn}</option>)}
          </select>
          <select name="ansatt" defaultValue={person?.ansatt_nr ?? ''}>
            {ansatte.map((a) => (
              <option key={a.ansatt_nr} value={a.ansatt_nr}>{a.navn}</option>
            ))}
          </select>
          <select name="form" defaultValue={form}>
            {FORMER.map((f) => <option key={f.verdi} value={f.verdi}>{f.navn}</option>)}
          </select>
          <select name="rolle" defaultValue={rolle}>
            {ROLLER.map((r) => <option key={r.verdi} value={r.verdi}>{r.navn}</option>)}
          </select>
          <button type="submit" className="liten">Vis</button>
        </form>
      </section>

      {!person ? (
        <section className="kort">
          <p className="undertittel">
            Ingen ansatte på {valgt.navn}. Last opp Basis Export fra easy@work
            på <a href="/import">/import</a>, så kommer de med.
          </p>
        </section>
      ) : (
        <>
          <section className="kort">
            <h2>{person.navn}</h2>
            <p className="undertittel">
              Ansattnummer {person.ansatt_nr}
              {mindreaarig && ' · under 18 år — egen mal og egne arbeidstidsregler'}
            </p>
            <AnsattkortSkjema
              stasjonId={valgt.id}
              kort={{
                ansattNr: person.ansatt_nr,
                navn: person.navn,
                fodselsdato: person.fodselsdato,
                stillingstittel: person.stillingstittel,
                skiftordning: person.skiftordning,
                harRammeavtale: person.har_rammeavtale,
              }}
            />
          </section>

          {!mal ? (
            <section className="kort">
              <h2>Ingen mal for dette valget</h2>
              <p className="undertittel">
                Det finnes ingen aktiv mal for {FORMER.find((f) => f.verdi === form)!.navn.toLowerCase()}
                {' · '}{ROLLER.find((r) => r.verdi === rolle)!.navn.toLowerCase()}
                {mindreaarig && ' · under 18'}.
                {eier ? ' Last den opp nederst på siden.' : ' Be eier laste den opp.'}
              </p>
            </section>
          ) : (
            <section className="kort">
              <h2>Skriv kontrakt</h2>
              <p className="undertittel">
                {mal.filnavn} · versjon {mal.versjon} ·{' '}
                {feltIMal.length} felt i malen, {Object.keys(verdier).length} fylt fra
                data vi allerede har.
              </p>

              {fraKjeden.length > 0 && (
                <p className="notis">
                  {fraKjeden.length} felt mangler i kjedens innstillinger
                  ({fraKjeden.map((f) => f.forklaring).join(', ')}).
                  {eier ? ' Fyll dem ut nederst — da slipper du dem for alltid.'
                    : ' Be eier fylle dem ut én gang.'}
                </p>
              )}

              <form method="post" action="/api/kontrakt/generer" className="sq-skjema">
                <input type="hidden" name="stasjon" value={valgt.id} />
                <input type="hidden" name="ansatt" value={person.ansatt_nr} />
                <input type="hidden" name="form" value={form} />
                <input type="hidden" name="rolle" value={rolle} />

                <label className="felt sq-smalt">
                  <span>Tiltredelse</span>
                  <input type="date" name="tiltredelse" required />
                </label>

                {maaSvares
                  .filter((m) => m.navn !== 'dato, måned, år')
                  .map((m) => (
                    <label className="felt" key={m.navn}>
                      <span>{m.forklaring}</span>
                      <input name={`f.${m.navn}`} placeholder={m.navn} />
                    </label>
                  ))}

                <div className="knapperad">
                  <button type="submit" className="sq-knapp primar">
                    Generer og last ned
                  </button>
                </div>
              </form>

              {valg.length > 0 && (
                <>
                  <p className="notis">
                    <strong>{valg.length} valg står igjen i dokumentet</strong>, med klammer
                    rundt. De er hele setninger som skal beholdes eller slettes, ikke felt
                    som skal fylles — og å slette dem automatisk er å endre en juridisk
                    gjennomgått avtale uten at noen leste den. Ta stilling til dem i Word.
                  </p>
                  <ul className="undertittel">
                    {valg.map((v) => <li key={v}>{v}</li>)}
                  </ul>
                </>
              )}

              <p className="notis" style={{ marginBottom: 0 }}>
                Signering skjer utenfor systemet i dag. Kontrakten lagres med malversjon
                og verdier, så dokumentet kan gjenskapes nøyaktig slik det ble skrevet.
              </p>
            </section>
          )}
        </>
      )}

      {historikk.length > 0 && (
        <section className="kort">
          <h2>Skrevet på {valgt.navn}</h2>
          <div className="tabellramme">
            <table className="tabell">
              <thead>
                <tr>
                  <th>Ansatt</th><th>Gjelder fra</th><th className="tall">Mal</th>
                  <th>Status</th><th>Skrevet</th>
                </tr>
              </thead>
              <tbody>
                {historikk.map((k) => (
                  <tr key={k.id}>
                    <td>{k.ansatt_navn}</td>
                    <td>{dato(k.gjelder_fra)}</td>
                    <td className="tall">v{k.mal_versjon ?? '—'}</td>
                    <td>
                      <span className={`status-pip ${k.status === 'signert' ? 'gronn' : 'noytral'}`}>
                        {k.status}
                      </span>
                    </td>
                    <td>{dato(k.opprettet_tid.slice(0, 10))}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      )}

      {eier && (
        <>
          <section className="kort">
            <h2>Kjedens faste felt</h2>
            <p className="undertittel">
              Det som er likt i hver eneste kontrakt. Fylles ut én gang, og går inn
              i alle senere avtaler av seg selv.
            </p>
            <StandardfeltSkjema
              felt={FELTKILDER.filter((f) => f.kilde === 'kjede').map((f) => ({
                navn: f.navn,
                forklaring: f.forklaring === 'Fra kjedens innstillinger' ? f.navn : f.forklaring,
                verdi: retailer?.kontrakt_standardfelt?.[f.navn] ?? '',
              }))}
            />
          </section>

          <section className="kort">
            <h2>Maler</h2>
            <p className="undertittel">
              Last opp Virkes .docx som den er. Hver opplasting blir en ny versjon —
              den forrige deaktiveres, men slettes ikke. Du må kunne vise nøyaktig
              hvilken tekst hun signerte.
            </p>
            {aktive.length > 0 && (
              <div className="tabellramme">
                <table className="tabell">
                  <thead>
                    <tr><th>Gjelder</th><th>Rolle</th><th>Fil</th><th className="tall">Versjon</th></tr>
                  </thead>
                  <tbody>
                    {aktive.map((m) => (
                      <tr key={m.id}>
                        <td>
                          {FORMER.find((f) => f.verdi === m.ansettelsesform)?.navn
                            ?? m.ansettelsesform}
                          {m.mindreaarig && ' · under 18'}
                        </td>
                        <td>{ROLLER.find((r) => r.verdi === m.rolle)?.navn ?? m.rolle}</td>
                        <td>{m.filnavn}</td>
                        <td className="tall">v{m.versjon}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
            <MalSkjema />
          </section>
        </>
      )}
    </>
  )
}
