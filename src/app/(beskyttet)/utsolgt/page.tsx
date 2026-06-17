import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { iDag, datoLang, tall, kr } from '@/lib/format'
import { finnUtsolgt, type Kandidatrad, type UtsolgtHendelse } from '@/lib/utsolgt'

// Kjører deteksjon for alle tilgjengelige stasjoner (én RPC hver).
export const maxDuration = 60
const VINDU = 35

type Stasjon = { id: string; butikknummer: string; navn: string }
type StasjonResultat = { stasjon: Stasjon; hendelser: UtsolgtHendelse[]; tapt: number }

function dato(d: string): string {
  return datoLang.format(new Date(`${d}T12:00:00Z`))
}

export default async function UtsolgtSide({ searchParams }: { searchParams: Promise<{ butikknummer?: string }> }) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return <p>Du har ikke tilgang.</p>
  const supabase = await lagSupabaseServerKlient()
  const sp = await searchParams

  const { data: alleStasjoner } = await supabase
    .from('stasjoner').select('id, butikknummer, navn').is('slettet_tid', null).order('butikknummer')
    .overrideTypes<Stasjon[]>()
  let stasjoner = alleStasjoner ?? []
  if (bruker.rolle === 'butikksjef') {
    const { data: tilgang } = await supabase.from('butikksjef_stasjoner').select('stasjon_id').eq('profil_id', bruker.id)
    const ids = new Set((tilgang ?? []).map((t) => t.stasjon_id))
    stasjoner = stasjoner.filter((s) => ids.has(s.id))
  }

  const idag = iDag()
  const resultater: StasjonResultat[] = await Promise.all(
    stasjoner.map(async (stasjon) => {
      const { data } = await supabase.rpc('utsolgt_kandidater', { p_stasjon: stasjon.id, p_dager: VINDU })
      const hendelser = finnUtsolgt((data ?? []) as Kandidatrad[], idag, VINDU)
      return { stasjon, hendelser, tapt: hendelser.reduce((s, h) => s + h.tapt_kr, 0) }
    }),
  )

  const valgtNr = sp.butikknummer || stasjoner[0]?.butikknummer || ''
  const valgt = resultater.find((r) => r.stasjon.butikknummer === valgtNr) ?? resultater[0]
  const totaltHendelser = resultater.reduce((s, r) => s + r.hendelser.length, 0)

  return (
    <>
      <h1>Mulig utsolgt</h1>
      <p className="undertittel">
        Faste varer (selger jevnt, snitt ≥ 1,5/dag) som plutselig falt til <b>0 i minst 2 dager</b> og så var tilbake på normalen — typisk tegn på <b>utsolgt eller glemt bestilling</b>. Siste {VINDU} dager.
      </p>

      {stasjoner.length > 1 && (
        <section className="kort">
          <h2>Oversikt — hvor butikken mister salg på tom hylle</h2>
          <table className="tabell">
            <thead><tr><th>Stasjon</th><th>Hendelser</th><th>Estimert tapt</th></tr></thead>
            <tbody>
              {[...resultater].sort((a, b) => b.tapt - a.tapt).map((r) => (
                <tr key={r.stasjon.id}>
                  <td>{r.stasjon.butikknummer} {r.stasjon.navn}</td>
                  <td><span className={`status-pip ${r.hendelser.length === 0 ? 'gronn' : r.hendelser.length <= 3 ? 'gul' : 'rod'}`}>{r.hendelser.length}</span></td>
                  <td>{r.tapt > 0 ? kr.format(r.tapt) : '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
          <p className="undertittel" style={{ marginTop: '0.5rem' }}>Lavt tall = god kontroll på bestilling/produksjon. Estimatet er normalsalg × dager × snittpris.</p>
        </section>
      )}

      <section className="kort">
        <form method="get" className="plan-velg">
          <label className="felt">
            <span>Stasjon</span>
            <select name="butikknummer" defaultValue={valgtNr}>
              {stasjoner.map((s) => <option key={s.id} value={s.butikknummer}>{s.butikknummer} {s.navn}</option>)}
            </select>
          </label>
          <button type="submit">Vis</button>
        </form>
      </section>

      {!valgt || valgt.hendelser.length === 0 ? (
        <section className="kort">
          <p className="undertittel">
            {totaltHendelser === 0 && stasjoner.length <= 1
              ? '✅ Ingen tegn til utsolgt på faste varer de siste ukene — bra rutiner!'
              : '✅ Ingen flagg for denne stasjonen i perioden.'}
          </p>
        </section>
      ) : (
        <section className="kort">
          <div className="seksjon-topp">
            <h2>{valgt.stasjon.butikknummer} {valgt.stasjon.navn}</h2>
            <span className="undertittel">{valgt.hendelser.length} hendelse(r) · est. tapt {kr.format(valgt.tapt)}</span>
          </div>
          <table className="tabell">
            <thead><tr><th>Vare</th><th>Periode</th><th>Dager</th><th>Snitt/dag</th><th>Est. tapt</th></tr></thead>
            <tbody>
              {valgt.hendelser.map((h, i) => (
                <tr key={`${h.ean}-${i}`}>
                  <td>{h.varenavn}</td>
                  <td>{dato(h.fra)}{h.dager > 1 ? ` – ${dato(h.til)}` : ''}</td>
                  <td><span className="status-pip rod">{h.dager}</span></td>
                  <td>{tall.format(h.snitt)}</td>
                  <td>{h.tapt_kr > 0 ? kr.format(h.tapt_kr) : '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
          <p className="undertittel" style={{ marginTop: '0.6rem' }}>
            Hver rad er en vare som solgte normalt, falt til 0 i {`≥`}2 dager, og kom tilbake. Sjekk om det var reelt utsolgt (bestilling/produksjon) eller en annen forklaring.
          </p>
        </section>
      )}
    </>
  )
}
