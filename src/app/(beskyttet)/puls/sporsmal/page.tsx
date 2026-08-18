import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { settOppStandard, leggTilSporsmal, vekslAktivSporsmal, slettSporsmal } from '../handlinger'
import { Sidehode, Tomtilstand } from '@/components/ui/side'
import { Sidepanel } from '@/components/ui/sidepanel'

type Sporsmal = { id: string; kategori: string; tekst: string; aktiv: boolean }

export default async function SporsmalSide() {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return <p>Ingen tilgang.</p>
  const supabase = await lagSupabaseServerKlient()
  const { data: sporsmal } = await supabase.from('puls_sporsmal').select('id, kategori, tekst, aktiv').is('slettet_tid', null).order('sortering').overrideTypes<Sporsmal[]>()

  const liste = sporsmal ?? []
  const aktive = liste.filter((s) => s.aktiv).length
  const nyPanel = (
    <Sidepanel knapp="Nytt spørsmål" tittel="Nytt puls-spørsmål">
      <form action={leggTilSporsmal} className="skjema">
        <label className="felt"><span>Kategori</span><input name="kategori" placeholder="Trivsel" defaultValue="Trivsel" /></label>
        <label className="felt"><span>Spørsmål</span><input name="tekst" placeholder="Hvordan har uka vært?" required /></label>
        <button type="submit" className="sq-knapp primar">Legg til spørsmål</button>
      </form>
    </Sidepanel>
  )

  return (
    <>
      <Sidehode
        tittel="Puls-spørsmål"
        undertittel={liste.length === 0
          ? 'Biblioteket du starter målinger fra.'
          : `${aktive} aktive av ${liste.length}. Du starter målinger fra dette biblioteket.`}
        handlinger={nyPanel}
      />

      {liste.length === 0 ? (
        <Tomtilstand
          tittel="Tomt bibliotek"
          forklaring="Start med ti standardspørsmål, så kan du endre og legge til etterpå."
          handling={<form action={settOppStandard}><button type="submit" className="sq-knapp primar">Sett opp standardspørsmål</button></form>}
        />
      ) : (
        <div className="tabellramme">
          <table className="tabell">
            <thead><tr><th>Kategori</th><th>Spørsmål</th><th>Aktiv</th><th></th></tr></thead>
            <tbody>
              {liste.map((s) => (
                <tr key={s.id} className={s.aktiv ? '' : 'gjort'}>
                  <td>{s.kategori}</td>
                  <td>{s.tekst}</td>
                  <td>
                    <form action={vekslAktivSporsmal}>
                      <input type="hidden" name="id" value={s.id} />
                      <input type="hidden" name="til" value={s.aktiv ? 'nei' : 'ja'} />
                      <button type="submit" className="liten">{s.aktiv ? 'På' : 'Av'}</button>
                    </form>
                  </td>
                  <td className="tall">
                    <form action={slettSporsmal}><input type="hidden" name="id" value={s.id} /><button type="submit" className="liten slett">Slett</button></form>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </>
  )
}
