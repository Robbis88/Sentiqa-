import { hentInnloggetBruker } from '@/lib/auth/dal'
import { SlettKnapp } from '@/components/ui/slett-knapp'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { leggTilKunnskap, slettKunnskap } from './handlinger'
import { Sidehode, Tomtilstand } from '@/components/ui/side'
import { Sidepanel } from '@/components/ui/sidepanel'
import { Knapp } from '@/components/ui/knapp'
import { Felt, Velg } from '@/components/ui/felt'
import { Sideramme } from '@/components/ui/sideramme'

type Artikkel = { id: string; kategori: string; tittel: string; innhold: string; kilde: string | null }

const KATEGORIER: [string, string][] = [
  ['rutine', 'Rutine'], ['prosedyre', 'Prosedyre'], ['hms', 'HMS'], ['arbeidsrett', 'Arbeidsrett'],
  ['tariff', 'Tariff'], ['lonn', 'Lønn'], ['annet', 'Annet'],
]
/**
 * Kategorinavnet, uten ikon.
 *
 * SYV EMOJI UT, INGEN STATUS INN. En kategori er ikke en tilstand -
 * «Tariff» er ikke mer eller mindre alvorlig enn «HMS». Aa bruke
 * `Status` her ville laant et semantisk spraak til noe som ikke har
 * semantikk, og da slutter fargene aa bety noe der de faktisk gjor det.
 *
 * Merkelappen er derfor bare et ord.
 */
const KAT_NAVN: Record<string, string> = Object.fromEntries(KATEGORIER)

export default async function KunnskapSide() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'plattform_redaktor') {
    return <Sideramme><p>Kunnskapsbasen vedlikeholdes av plattform-redaktøren. Ansatte og ledere får svar gjennom AI-assistenten.</p></Sideramme>
  }
  const supabase = await lagSupabaseServerKlient()
  const { data } = await supabase.from('kunnskap').select('id, kategori, tittel, innhold, kilde').is('slettet_tid', null).order('kategori').order('tittel').overrideTypes<Artikkel[]>()
  const artikler = data ?? []

  const nyPanel = (
    <Sidepanel
      knapp="Ny artikkel"
      tittel="Ny artikkel"
      beskrivelse="Skriv innholdet slik du vil at chatboten skal svare."
    >
      {/* FELTENE HADDE INGEN ETIKETTER - bare plassholdere, som
          forsvinner idet man begynner aa skrive. Samme felter, samme
          navn, samme serverhandling; det som er nytt er at de har navn
          ogsaa etter at man har fylt dem ut. */}
      <form action={leggTilKunnskap} className="sq-skjema">
        <Felt etikett="Tittel" name="tittel" placeholder="Kasseoppgjør ved dagsslutt" required />
        <Velg etikett="Kategori" name="kategori" defaultValue="rutine">
          {KATEGORIER.map(([v, t]) => <option key={v} value={v}>{t}</option>)}
        </Velg>
        <Felt etikett="Kilde" name="kilde" hjelp="Valgfri — hvor står dette skrevet?" />
        <label className="felt"><span>Innhold</span>
          <textarea
            name="innhold" rows={8} required
            placeholder="Beskriv slik du vil at assistenten skal svare."
          />
        </label>
        <div className="knapperad">
          <Knapp type="submit" variant="primar">Legg til artikkel</Knapp>
        </div>
      </form>
    </Sidepanel>
  )

  return (
    <Sideramme>
      <Sidehode
        tittel="Kunnskapsbase"
        undertittel={artikler.length === 0
          ? 'Felles for alle kjeder. AI-assistenten svarer ut fra dette.'
          : `${artikler.length} artikler. AI-assistenten svarer ut fra dette — tariff, `
            + 'lønn, rutiner, HMS og beste praksis.'}
        handlinger={nyPanel}
      />

      {artikler.length === 0 ? (
        <Tomtilstand
          tittel="Ingen artikler ennå"
          forklaring={'Jo mer som ligger her, jo mer kan assistenten hjelpe — den '
            + 'svarer ut fra dette og ikke fra gjetning.'}
          handling={nyPanel}
        />
      ) : (
        // Artiklene er noe man slaar opp i, ikke rader man skanner:
        // sammenleggbar er riktig form, og den beholdes. Det som er
        // endret er ikonene og den handskrevne stilen.
        <ul className="kunnskap-liste">
          {artikler.map((a) => (
            <li key={a.id}>
              <details>
                <summary>
                  <span className="kunnskap-kat">{KAT_NAVN[a.kategori] ?? a.kategori}</span>
                  {' '}{a.tittel}
                  {a.kilde ? <span className="undertittel"> · {a.kilde}</span> : null}
                </summary>
                <p className="sq-brodtekst">{a.innhold}</p>
                <div className="knapperad">
                  <SlettKnapp hva={a.tittel} handling={slettKunnskap} id={a.id} bekreftelse="Artikkelen slettet" />
                </div>
              </details>
            </li>
          ))}
        </ul>
      )}
    </Sideramme>
  )
}
