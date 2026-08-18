import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseAdminKlient } from '@/lib/supabase/admin'
import { kr, datoLang } from '@/lib/format'
import { maalKampanje, type KampanjeEffekt } from '@/lib/kampanjeeffekt'
import { opprettKampanje, slettKampanje } from './handlinger'
import { BekreftKnapp } from '../plattform/kunde-handlinger'
import { Sidehode } from '@/components/ui/side'
import { Sidepanel } from '@/components/ui/sidepanel'

type Kampanje = { id: string; retailer_id: string; navn: string; fra_dato: string; til_dato: string; eaner: string[] | null; stasjon_ider: string[] | null }
type Rad = { dato: string; antall: number; antall_tilbud: number; omsetning: number; innekunder: number; biler: number }

export default async function KampanjerSide() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'plattform_redaktor') return <p>Kampanjer styres av plattform-eier.</p>

  let admin
  try {
    admin = lagSupabaseAdminKlient()
  } catch {
    return <><h1>Kampanjer</h1><p className="undertittel">Mangler service-nøkkel.</p></>
  }

  const [{ data: retailers }, { data: kampanjer }] = await Promise.all([
    admin.from('retailers').select('id, navn').is('slettet_tid', null).order('navn').overrideTypes<{ id: string; navn: string }[]>(),
    admin.from('kampanjer').select('id, retailer_id, navn, fra_dato, til_dato, eaner, stasjon_ider').is('slettet_tid', null).order('fra_dato', { ascending: false }).overrideTypes<Kampanje[]>(),
  ])
  const kjedeNavn = new Map((retailers ?? []).map((r) => [r.id, r.navn]))

  // Kjør analysen for hver kampanje (RPC pre-aggregerer dagstall).
  const analyser = await Promise.all((kampanjer ?? []).map(async (k): Promise<{ k: Kampanje; e: KampanjeEffekt | null }> => {
    const { data, error } = await admin!.rpc('kampanje_analyse', { p_retailer: k.retailer_id, p_fra: k.fra_dato, p_til: k.til_dato, p_eaner: k.eaner, p_stasjoner: k.stasjon_ider })
    if (error || !data) return { k, e: null }
    const rader = data as Rad[]
    const e = maalKampanje({
      fraDato: k.fra_dato, tilDato: k.til_dato,
      salg: rader.map((r) => ({ dato: r.dato, antall: Number(r.antall), antallTilbud: Number(r.antall_tilbud), omsetning: Number(r.omsetning) })),
      kunder: rader.map((r) => ({ dato: r.dato, innekunder: Number(r.innekunder) })),
      trafikk: rader.map((r) => ({ dato: r.dato, biler: Number(r.biler) })),
    })
    return { k, e }
  }))

  const dag = (d: string) => datoLang.format(new Date(`${d}T12:00:00Z`))
  const pip = (v: number | null, godKalvHoy = true) => v == null ? <span className="status-pip">—</span> : <span className={`status-pip ${(godKalvHoy ? v >= 0 : v <= 0) ? 'gronn' : 'gul'}`}>{v >= 0 ? '+' : ''}{v} %</span>

  const nyPanel = (
    <Sidepanel
      knapp="Ny kampanje"
      tittel="Ny kampanje"
      beskrivelse={'Fangstrate beregnes kun der trafikkmåling er skrudd på. '
        + 'Kjeder uten trafikk får salgsløft uten fangstrate.'}
    >
      <form action={opprettKampanje} className="rutine-form arr-form" style={{ flexDirection: 'column', alignItems: 'stretch', gap: '0.6rem' }}>
          <div className="arr-form">
            <select name="retailer_id" required defaultValue="">
              <option value="" disabled>Velg kjede</option>
              {(retailers ?? []).map((r) => <option key={r.id} value={r.id}>{r.navn}</option>)}
            </select>
            <input name="navn" placeholder="Kampanjenavn (f.eks. Hamburger 49,-)" required style={{ flex: '1 1 14rem' }} />
          </div>
          <div className="arr-form">
            <label className="felt"><span>Fra</span><input name="fra_dato" type="date" required /></label>
            <label className="felt"><span>Til</span><input name="til_dato" type="date" required /></label>
          </div>
          <input name="eaner" placeholder="EAN (valgfritt, komma/mellomrom) — tomt = alle tilbudsvarer i perioden" />
          <button type="submit" className="liten" style={{ alignSelf: 'flex-start' }}>Opprett + analyser</button>
        </form>
    </Sidepanel>
  )

  return (
    <>
      <Sidehode
        tittel="Kampanjer"
        undertittel="Salgsløft og fangstrate per kampanje, på tvers av kjedene."
        handlinger={nyPanel}
      />
      <p className="undertittel">
        Mål St1-kampanjer mot ukene rett før: kampanjevarenes salg, innekunder og fangstrate (innekunder ÷ biler) der trafikk er målt.
        La EAN-feltet stå tomt for å bruke alle tilbudsvarer i perioden automatisk, eller lim inn bestemte EAN for å velge selv.
      </p>

      {analyser.length === 0 ? (
        <section className="kort"><p className="undertittel">Ingen kampanjer registrert ennå.</p></section>
      ) : analyser.map(({ k, e }) => (
        <section className="kort" key={k.id}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', gap: '1rem', flexWrap: 'wrap' }}>
            <h2 style={{ margin: 0 }}>{k.navn} <span className="undertittel">· {kjedeNavn.get(k.retailer_id)}</span></h2>
            <BekreftKnapp action={slettKampanje} id={k.id} etikett="Slett" klasse="liten slett" sporsmaal={`Slette kampanjen «${k.navn}»?`} />
          </div>
          <p className="undertittel">{dag(k.fra_dato)} – {dag(k.til_dato)} · {k.eaner?.length ? `${k.eaner.length} valgte varer` : 'alle tilbudsvarer i perioden'}{e ? ` · baseline ${dag(e.baselineFra)}–${dag(e.baselineTil)}` : ''}</p>
          {!e ? <p className="undertittel">Kunne ikke beregne (mangler data?).</p> : (
            <>
              <section className="nokkeltall">
                <div className="kpi"><span className="kpi-tall">{pip(e.antallLoft)}</span><span className="kpi-merke">Kampanjevarer (antall)</span></div>
                <div className="kpi"><span className="kpi-tall">{pip(e.innekunderLoft)}</span><span className="kpi-merke">Innekunder</span></div>
                <div className="kpi"><span className="kpi-tall">{e.fangstrateLoft != null ? pip(e.fangstrateLoft) : <span className="status-pip">ingen trafikk</span>}</span><span className="kpi-merke">Fangstrate{e.fangstrateKampanje != null ? ` (${e.fangstrateBaseline}→${e.fangstrateKampanje} %)` : ''}</span></div>
                <div className="kpi"><span className="kpi-tall">{e.trafikkEndring != null ? pip(e.trafikkEndring) : <span className="status-pip">—</span>}</span><span className="kpi-merke">Trafikk forbi</span></div>
              </section>
              <table className="tabell" style={{ marginTop: '0.5rem' }}>
                <thead><tr><th></th><th>Antall</th><th>På tilbud</th><th>Omsetning</th><th>Innekunder</th><th>Biler</th></tr></thead>
                <tbody>
                  <tr><td>Kampanje</td><td>{Math.round(e.kampanje.antall)}</td><td>{Math.round(e.kampanje.antallTilbud)}</td><td>{kr.format(e.kampanje.omsetning)}</td><td>{Math.round(e.kampanje.innekunder)}</td><td>{e.kampanje.biler ? Math.round(e.kampanje.biler) : '—'}</td></tr>
                  <tr><td>Ukene før</td><td>{Math.round(e.baseline.antall)}</td><td>{Math.round(e.baseline.antallTilbud)}</td><td>{kr.format(e.baseline.omsetning)}</td><td>{Math.round(e.baseline.innekunder)}</td><td>{e.baseline.biler ? Math.round(e.baseline.biler) : '—'}</td></tr>
                </tbody>
              </table>
              {e.konklusjon.length > 0 && (
                <div className="kort oppmerksomhet" style={{ marginTop: '0.6rem' }}>
                  <ul className="fokus-liste">{e.konklusjon.map((s, i) => <li key={i}>{s}</li>)}</ul>
                </div>
              )}
            </>
          )}
        </section>
      ))}
    </>
  )
}
