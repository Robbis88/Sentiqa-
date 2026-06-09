import Link from 'next/link'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { settOppStandard, leggTilSporsmal, vekslAktivSporsmal, slettSporsmal } from '../handlinger'

type Sporsmal = { id: string; kategori: string; tekst: string; aktiv: boolean }

export default async function SporsmalSide() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin' && bruker.rolle !== 'butikksjef') return <p>Ingen tilgang.</p>
  const supabase = await lagSupabaseServerKlient()
  const { data: sporsmal } = await supabase.from('puls_sporsmal').select('id, kategori, tekst, aktiv').is('slettet_tid', null).order('sortering').overrideTypes<Sporsmal[]>()

  return (
    <>
      <h1>Puls-spørsmål</h1>
      <p className="undertittel">Biblioteket du starter målinger fra. <Link href="/puls">Tilbake</Link></p>

      {(sporsmal ?? []).length === 0 && (
        <section className="kort">
          <p className="undertittel">Tomt bibliotek. Start med 10 standardspørsmål.</p>
          <form action={settOppStandard}><button type="submit">Sett opp standardspørsmål</button></form>
        </section>
      )}

      <section className="kort">
        <h2>Nytt spørsmål</h2>
        <form action={leggTilSporsmal} className="rutine-form">
          <input name="kategori" placeholder="Kategori" defaultValue="Trivsel" style={{ maxWidth: '10rem' }} />
          <input name="tekst" placeholder="Spørsmål …" required />
          <button type="submit" className="liten">Legg til</button>
        </form>
      </section>

      {(sporsmal ?? []).length > 0 && (
        <section className="kort">
          <table className="tabell">
            <thead><tr><th>Kategori</th><th>Spørsmål</th><th>Aktiv</th><th></th></tr></thead>
            <tbody>
              {(sporsmal ?? []).map((s) => (
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
                  <td>
                    <form action={slettSporsmal}><input type="hidden" name="id" value={s.id} /><button type="submit" className="liten slett">✕</button></form>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      )}
    </>
  )
}
