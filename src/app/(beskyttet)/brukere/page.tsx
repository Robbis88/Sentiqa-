import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { ROLLE_ETIKETT } from '@/lib/auth/typer'
import { NyBruker } from './ny-bruker'
import { fjernBruker } from './handlinger'

type Profil = { id: string; fullt_navn: string | null; rolle: string }
type Kobling = { profil_id: string; stasjon_id: string }

export default async function BrukereSide() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin') return <p>Kun eier kan administrere brukere.</p>

  const supabase = await lagSupabaseServerKlient()
  const [{ data: profiler }, { data: koblinger }, { data: stasjoner }] = await Promise.all([
    supabase
      .from('profiler')
      .select('id, fullt_navn, rolle')
      .in('rolle', ['butikksjef', 'butikkbruker_tablet'])
      .is('slettet_tid', null)
      .overrideTypes<Profil[]>(),
    supabase.from('butikksjef_stasjoner').select('profil_id, stasjon_id').overrideTypes<Kobling[]>(),
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null).order('butikknummer'),
  ])

  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))
  const stasjonerForProfil = new Map<string, string[]>()
  for (const k of koblinger ?? []) {
    const l = stasjonerForProfil.get(k.profil_id) ?? []
    l.push(navnFor.get(k.stasjon_id) ?? '—')
    stasjonerForProfil.set(k.profil_id, l)
  }

  return (
    <>
      <h1>Brukere</h1>
      <p className="undertittel">Opprett butikksjefer og tablet-kontoer, og styr hvilke stasjoner de når.</p>

      <section className="kort">
        <h2>Ny bruker</h2>
        <NyBruker stasjoner={(stasjoner ?? []).map((s) => ({ id: s.id, navn: `${s.butikknummer} ${s.navn}` }))} />
        <p className="undertittel" style={{ marginTop: '0.5rem' }}>
          Tablet-kontoen er delt på nettbrettet — de ansatte skiller seg med PIN (se Ansatte).
        </p>
      </section>

      <section className="kort">
        <h2>Eksisterende ({(profiler ?? []).length})</h2>
        {(profiler ?? []).length === 0 ? (
          <p className="undertittel">Ingen butikksjefer eller tablet-kontoer ennå.</p>
        ) : (
          <table className="tabell">
            <thead><tr><th>Navn</th><th>Rolle</th><th>Stasjoner</th><th></th></tr></thead>
            <tbody>
              {(profiler ?? []).map((p) => (
                <tr key={p.id}>
                  <td>{p.fullt_navn ?? '—'}</td>
                  <td>{ROLLE_ETIKETT[p.rolle as keyof typeof ROLLE_ETIKETT] ?? p.rolle}</td>
                  <td>{(stasjonerForProfil.get(p.id) ?? []).join(', ') || '—'}</td>
                  <td>
                    <form action={fjernBruker}>
                      <input type="hidden" name="id" value={p.id} />
                      <button type="submit" className="liten slett">Fjern</button>
                    </form>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </section>
    </>
  )
}
