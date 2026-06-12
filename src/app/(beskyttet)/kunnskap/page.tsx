import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { leggTilKunnskap, slettKunnskap } from './handlinger'

type Artikkel = { id: string; retailer_id: string | null; kategori: string; tittel: string; innhold: string; kilde: string | null }

const KATEGORIER: [string, string][] = [
  ['rutine', 'Rutine'], ['prosedyre', 'Prosedyre'], ['hms', 'HMS'], ['arbeidsrett', 'Arbeidsrett'], ['annet', 'Annet'],
]
const KAT_MERKE: Record<string, string> = { tariff: '📜 Tariff', lonn: '💰 Lønn', arbeidsrett: '⚖️ Arbeidsrett', rutine: '📋 Rutine', prosedyre: '🔧 Prosedyre', hms: '🦺 HMS', annet: '📄 Annet' }

export default async function KunnskapSide() {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return <p>Du har ikke tilgang til kunnskapsbasen.</p>
  const supabase = await lagSupabaseServerKlient()
  const { data } = await supabase.from('kunnskap').select('id, retailer_id, kategori, tittel, innhold, kilde').is('slettet_tid', null).order('kategori').order('tittel').overrideTypes<Artikkel[]>()
  const artikler = data ?? []
  const globale = artikler.filter((a) => a.retailer_id === null)
  const egne = artikler.filter((a) => a.retailer_id !== null)

  return (
    <>
      <h1>Kunnskapsbase</h1>
      <p className="undertittel">AI-chatboten svarer ut fra dette: tariffavtale + lønnssatser (felles) og deres egne rutiner/HMS/prosedyrer. Jo mer dere legger inn, jo mer kan den svare på.</p>

      <section className="kort">
        <h2>Ny artikkel</h2>
        <form action={leggTilKunnskap} className="rutine-form">
          <input name="tittel" placeholder="Tittel (f.eks. «Kasseoppgjør ved dagsslutt»)" required />
          <select name="kategori" defaultValue="rutine" aria-label="Kategori">
            {KATEGORIER.map(([v, t]) => <option key={v} value={v}>{t}</option>)}
          </select>
          <input name="kilde" placeholder="Kilde (valgfri)" />
          <textarea name="innhold" rows={5} placeholder="Innhold — beskriv rutinen/prosedyren slik du vil at chatboten skal svare." required />
          <button type="submit" className="liten">Legg til</button>
        </form>
      </section>

      <section className="kort">
        <h2>Felles (tariff + lønn) <span className="undertittel">· {globale.length}</span></h2>
        {globale.length === 0 ? (
          <p className="undertittel">Ingen felles kunnskap lastet inn ennå (tariffavtalen seedes av oss).</p>
        ) : (
          <ul className="kunnskap-liste">
            {globale.map((a) => (
              <li key={a.id}>
                <details>
                  <summary><span className="kunnskap-kat">{KAT_MERKE[a.kategori] ?? a.kategori}</span> {a.tittel}{a.kilde ? <span className="undertittel"> · {a.kilde}</span> : null}</summary>
                  <p style={{ whiteSpace: 'pre-wrap' }}>{a.innhold}</p>
                </details>
              </li>
            ))}
          </ul>
        )}
      </section>

      <section className="kort">
        <h2>Egne artikler <span className="undertittel">· {egne.length}</span></h2>
        {egne.length === 0 ? (
          <p className="undertittel">Ingen egne artikler ennå.</p>
        ) : (
          <ul className="kunnskap-liste">
            {egne.map((a) => (
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
