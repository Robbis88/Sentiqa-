import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { registrerSkills, slettSkills } from './handlinger'

type Score = { id: string; stasjon_id: string; prosent: number; kommentar: string | null; registrert_tid: string }
const tid = new Intl.DateTimeFormat('nb-NO', { timeZone: 'Europe/Oslo', dateStyle: 'short' })

export default async function SkillsSide() {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return <p>Kun eier/butikksjef.</p>
  const supabase = await lagSupabaseServerKlient()
  const [{ data: scorer }, { data: stasjoner }] = await Promise.all([
    supabase.from('skills_score').select('id, stasjon_id, prosent, kommentar, registrert_tid').order('registrert_tid', { ascending: false }).limit(50).overrideTypes<Score[]>(),
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null).order('butikknummer'),
  ])
  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))

  return (
    <>
      <h1>Skills-score</h1>
      <p className="undertittel">Registrer teamets treningsapp-score (%) per stasjon. Vises på tableten.</p>

      <section className="kort">
        <h2>Ny score</h2>
        <form action={registrerSkills} className="rutine-form">
          <label className="felt"><span>Stasjon</span>
          <select name="stasjon_id" required defaultValue="">
            <option value="" disabled>Stasjon …</option>
            {(stasjoner ?? []).map((s) => <option key={s.id} value={s.id}>{s.butikknummer} {s.navn}</option>)}
          </select>
          </label>
          <label className="felt sq-smalt"><span>Skills-score i prosent</span>
            <input name="prosent" type="number" min="0" max="100" step="0.1" required />
          </label>
          <label className="felt"><span>Kommentar (valgfri)</span>
            <input name="kommentar" />
          </label>
          <button type="submit" className="liten">Lagre</button>
        </form>
      </section>

      {(scorer ?? []).length > 0 && (
        <section className="kort">
          <table className="tabell">
            <thead><tr><th>Stasjon</th><th>Score</th><th>Dato</th><th>Kommentar</th><th></th></tr></thead>
            <tbody>
              {(scorer ?? []).map((s) => (
                <tr key={s.id}>
                  <td>{navnFor.get(s.stasjon_id) ?? '—'}</td>
                  <td>{Number(s.prosent)} %</td>
                  <td>{tid.format(new Date(s.registrert_tid))}</td>
                  <td>{s.kommentar ?? ''}</td>
                  <td><form action={slettSkills}><input type="hidden" name="id" value={s.id} /><button type="submit" className="liten slett">✕</button></form></td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      )}
    </>
  )
}
