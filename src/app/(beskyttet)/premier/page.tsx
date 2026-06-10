import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { kr, datoLang } from '@/lib/format'
import { registrerBruk, slettBruk, tildelPremie, vekslUtbetalt, slettTildeling } from './handlinger'

type Bruk = { id: string; stasjon_id: string; beskrivelse: string; belop_kr: number; dato: string }
type Tildeling = { id: string; stasjon_id: string; beskrivelse: string; belop_kr: number; dato: string; utbetalt: boolean }

export default async function PremierSide() {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return <p>Kun eier/butikksjef.</p>
  const supabase = await lagSupabaseServerKlient()
  const [{ data: stasjoner }, { data: tildelinger }, { data: bruk }] = await Promise.all([
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null).order('butikknummer'),
    supabase.from('pengepremie').select('id, stasjon_id, beskrivelse, belop_kr, dato, utbetalt').order('dato', { ascending: false }).limit(50).overrideTypes<Tildeling[]>(),
    supabase.from('pengepremie_bruk').select('id, stasjon_id, beskrivelse, belop_kr, dato').order('dato', { ascending: false }).limit(50).overrideTypes<Bruk[]>(),
  ])
  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))

  // Vunnet = alle tildelinger (konkurranse-vinnere oppretter en tildeling automatisk)
  const vunnetFor = new Map<string, number>()
  for (const t of tildelinger ?? []) vunnetFor.set(t.stasjon_id, (vunnetFor.get(t.stasjon_id) ?? 0) + Number(t.belop_kr))
  const bruktFor = new Map<string, number>()
  for (const b of bruk ?? []) bruktFor.set(b.stasjon_id, (bruktFor.get(b.stasjon_id) ?? 0) + Number(b.belop_kr))

  return (
    <>
      <h1>Premiesaldo</h1>
      <p className="undertittel">Vunnet (konkurranser + tildelinger) − brukt = igjen, per stasjon.</p>

      <section className="kort">
        <table className="tabell">
          <thead><tr><th>Stasjon</th><th>Vunnet</th><th>Brukt</th><th>Igjen</th></tr></thead>
          <tbody>
            {(stasjoner ?? []).map((s) => {
              const vunnet = vunnetFor.get(s.id) ?? 0
              const brukt = bruktFor.get(s.id) ?? 0
              return (
                <tr key={s.id}>
                  <td>{s.butikknummer} {s.navn}</td>
                  <td>{kr.format(vunnet)}</td>
                  <td>{kr.format(brukt)}</td>
                  <td><strong>{kr.format(vunnet - brukt)}</strong></td>
                </tr>
              )
            })}
          </tbody>
        </table>
      </section>

      <section className="kort">
        <h2>Tildel pengepremie</h2>
        <p className="undertittel">Gi en stasjon premiepenger utenom konkurranser (f.eks. ekstra innsats).</p>
        <form action={tildelPremie} className="rutine-form">
          <select name="stasjon_id" required defaultValue="">
            <option value="" disabled>Stasjon …</option>
            {(stasjoner ?? []).map((s) => <option key={s.id} value={s.id}>{s.butikknummer} {s.navn}</option>)}
          </select>
          <input name="beskrivelse" placeholder="f.eks. Toppinnsats i juli" required />
          <input name="belop_kr" type="number" min="1" step="1" placeholder="kr" required style={{ maxWidth: '7rem' }} />
          <input name="dato" type="date" />
          <button type="submit" className="liten">Tildel</button>
        </form>
      </section>

      {(tildelinger ?? []).length > 0 && (
        <section className="kort">
          <h2>Tildelinger</h2>
          <table className="tabell">
            <thead><tr><th>Stasjon</th><th>Beskrivelse</th><th>Beløp</th><th>Dato</th><th>Utbetalt</th><th></th></tr></thead>
            <tbody>
              {(tildelinger ?? []).map((t) => (
                <tr key={t.id}>
                  <td>{navnFor.get(t.stasjon_id) ?? '—'}</td>
                  <td>{t.beskrivelse}</td>
                  <td>{kr.format(Number(t.belop_kr))}</td>
                  <td>{datoLang.format(new Date(t.dato))}</td>
                  <td>
                    <form action={vekslUtbetalt}>
                      <input type="hidden" name="id" value={t.id} />
                      <input type="hidden" name="til" value={t.utbetalt ? 'nei' : 'ja'} />
                      <button type="submit" className={`status-pip ${t.utbetalt ? 'gronn' : 'gul'}`} style={{ border: 0, cursor: 'pointer' }}>{t.utbetalt ? 'Ja' : 'Nei'}</button>
                    </form>
                  </td>
                  <td><form action={slettTildeling}><input type="hidden" name="id" value={t.id} /><button type="submit" className="liten slett">✕</button></form></td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      )}

      <section className="kort">
        <h2>Registrer bruk</h2>
        <form action={registrerBruk} className="rutine-form">
          <select name="stasjon_id" required defaultValue="">
            <option value="" disabled>Stasjon …</option>
            {(stasjoner ?? []).map((s) => <option key={s.id} value={s.id}>{s.butikknummer} {s.navn}</option>)}
          </select>
          <input name="beskrivelse" placeholder="f.eks. Julebord" required />
          <input name="belop_kr" type="number" min="1" step="1" placeholder="kr" required style={{ maxWidth: '7rem' }} />
          <input name="dato" type="date" />
          <button type="submit" className="liten">Lagre</button>
        </form>
      </section>

      {(bruk ?? []).length > 0 && (
        <section className="kort">
          <h2>Siste bruk</h2>
          <table className="tabell">
            <thead><tr><th>Stasjon</th><th>Beskrivelse</th><th>Beløp</th><th>Dato</th><th></th></tr></thead>
            <tbody>
              {(bruk ?? []).map((b) => (
                <tr key={b.id}>
                  <td>{navnFor.get(b.stasjon_id) ?? '—'}</td>
                  <td>{b.beskrivelse}</td>
                  <td>{kr.format(Number(b.belop_kr))}</td>
                  <td>{datoLang.format(new Date(b.dato))}</td>
                  <td><form action={slettBruk}><input type="hidden" name="id" value={b.id} /><button type="submit" className="liten slett">✕</button></form></td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      )}
    </>
  )
}
