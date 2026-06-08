import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { NyAnsatt } from './ny-ansatt'
import { deaktiverAnsatt } from './handlinger'

type Ansatt = { id: string; navn: string; stasjon_id: string }

export default async function AnsatteSide() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin' && bruker.rolle !== 'butikksjef') {
    return <p>Ansatte administreres av eier/butikksjef.</p>
  }
  const supabase = await lagSupabaseServerKlient()
  const [{ data: ansatte }, { data: stasjoner }] = await Promise.all([
    supabase.from('ansatte').select('id, navn, stasjon_id').eq('aktiv', true).is('slettet_tid', null).order('navn').overrideTypes<Ansatt[]>(),
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null).order('butikknummer'),
  ])
  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))

  return (
    <>
      <h1>Ansatte</h1>
      <p className="undertittel">Ansatte sjekker inn med PIN på tableten, så ser du hvem som logger rutiner, sjekkpunkt og temperaturer.</p>

      <section className="kort">
        <h2>Ny ansatt</h2>
        <NyAnsatt stasjoner={(stasjoner ?? []).map((s) => ({ id: s.id, navn: `${s.butikknummer} ${s.navn}` }))} />
        <p className="undertittel" style={{ marginTop: '0.5rem' }}>PIN-en vises aldri igjen — den lagres kryptert. Velg en unik PIN per ansatt.</p>
      </section>

      <section className="kort">
        <h2>Aktive ({(ansatte ?? []).length})</h2>
        {(ansatte ?? []).length === 0 ? (
          <p className="undertittel">Ingen ansatte registrert.</p>
        ) : (
          <table className="tabell">
            <thead><tr><th>Navn</th><th>Stasjon</th><th></th></tr></thead>
            <tbody>
              {(ansatte ?? []).map((a) => (
                <tr key={a.id}>
                  <td>{a.navn}</td>
                  <td>{navnFor.get(a.stasjon_id) ?? '—'}</td>
                  <td>
                    <form action={deaktiverAnsatt}>
                      <input type="hidden" name="id" value={a.id} />
                      <button type="submit" className="liten">Deaktiver</button>
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
