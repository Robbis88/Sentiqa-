import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { settOppStandard, leggTilSporsmal, vekslAktivSporsmal, slettSporsmal } from '../handlinger'
import { Sidehode, Tomtilstand } from '@/components/ui/side'
import { Sidepanel } from '@/components/ui/sidepanel'
import { Liste, Rad } from '@/components/ui/liste'
import { Status } from '@/components/ui/status'
import { Knapp } from '@/components/ui/knapp'
import { SlettKnapp } from '@/components/ui/slett-knapp'

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
        // Biblioteket er en LISTE over sporsmaal man skrur av og paa.
        // Ingen leser kategorikolonnen mot aktiv-kolonnen; man leter
        // etter ETT sporsmaal. «Aktiv» er tilstanden, og den staar naa
        // som tilstand - `normal` naar den er paa, for det er
        // utgangspunktet, og `endring` naar den er tatt ut av bruk.
        <Liste merkelapp="Puls-spørsmål">
          {liste.map((sp) => (
            <Rad
              key={sp.id}
              primaer={sp.tekst}
              sekundaer={sp.kategori}
              status={(
                <Status nivaa={sp.aktiv ? 'normal' : 'endring'}>
                  {sp.aktiv ? 'I bruk' : 'Av'}
                </Status>
              )}
              handlinger={(
                <>
                  <form action={vekslAktivSporsmal}>
                    <input type="hidden" name="id" value={sp.id} />
                    <input type="hidden" name="til" value={sp.aktiv ? 'nei' : 'ja'} />
                    <Knapp type="submit" variant="ghost" liten>
                      {sp.aktiv ? 'Ta ut av bruk' : 'Ta i bruk'}
                    </Knapp>
                  </form>
                  <SlettKnapp hva={sp.tekst} handling={slettSporsmal} id={sp.id} merke="Slett" />
                </>
              )}
            />
          ))}
        </Liste>
      )}
    </>
  )
}
