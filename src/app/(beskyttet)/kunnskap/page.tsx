import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { leggTilKunnskap, slettKunnskap } from './handlinger'

type Artikkel = { id: string; kategori: string; tittel: string; innhold: string; kilde: string | null }

const KATEGORIER: [string, string][] = [
  ['rutine', 'Rutine'], ['prosedyre', 'Prosedyre'], ['hms', 'HMS'], ['arbeidsrett', 'Arbeidsrett'],
  ['tariff', 'Tariff'], ['lonn', 'Lønn'], ['annet', 'Annet'],
]
const KAT_MERKE: Record<string, string> = { tariff: '📜 Tariff', lonn: '💰 Lønn', arbeidsrett: '⚖️ Arbeidsrett', rutine: '📋 Rutine', prosedyre: '🔧 Prosedyre', hms: '🦺 HMS', annet: '📄 Annet' }

export default async function KunnskapSide() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'plattform_redaktor') {
    return <p>Kunnskapsbasen vedlikeholdes av plattform-redaktøren. Ansatte og ledere får svar gjennom AI-assistenten.</p>
  }
  const supabase = await lagSupabaseServerKlient()
  const { data } = await supabase.from('kunnskap').select('id, kategori, tittel, innhold, kilde').is('slettet_tid', null).order('kategori').order('tittel').overrideTypes<Artikkel[]>()
  const artikler = data ?? []

  return (
    <>
      <h1>Kunnskapsbase</h1>
      <p className="undertittel">Felles for alle kjeder. AI-assistenten svarer ut fra dette — tariff, lønn, rutiner, HMS og beste praksis. Jo mer du legger inn, jo mer kan den hjelpe alle.</p>

      <section className="kort">
        <h2>Ny artikkel</h2>
        <form action={leggTilKunnskap} className="rutine-form">
          <input name="tittel" placeholder="Tittel (f.eks. «Kasseoppgjør ved dagsslutt»)" required />
          <select name="kategori" defaultValue="rutine" aria-label="Kategori">
            {KATEGORIER.map(([v, t]) => <option key={v} value={v}>{t}</option>)}
          </select>
          <input name="kilde" placeholder="Kilde (valgfri)" />
          <textarea name="innhold" rows={5} placeholder="Innhold — beskriv slik du vil at chatboten skal svare." required />
          <button type="submit" className="liten">Legg til</button>
        </form>
      </section>

      <section className="kort">
        <h2>Artikler <span className="undertittel">· {artikler.length}</span></h2>
        {artikler.length === 0 ? (
          <p className="undertittel">Ingen artikler ennå.</p>
        ) : (
          <ul className="kunnskap-liste">
            {artikler.map((a) => (
              <li key={a.id}>
                <details>
                  <summary><span className="kunnskap-kat">{KAT_MERKE[a.kategori] ?? a.kategori}</span> {a.tittel}{a.kilde ? <span className="undertittel"> · {a.kilde}</span> : null}</summary>
                  <p style={{ whiteSpace: 'pre-wrap' }}>{a.innhold}</p>
                  <form action={slettKunnskap}><input type="hidden" name="id" value={a.id} /><button type="submit" className="liten slett">Slett</button></form>
                </details>
              </li>
            ))}
          </ul>
        )}
      </section>
    </>
  )
}
