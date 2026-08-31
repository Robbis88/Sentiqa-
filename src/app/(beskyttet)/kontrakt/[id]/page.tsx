import Link from 'next/link'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { gjenskapKontrakt } from '@/lib/kontrakt/gjenskap'
import { docxTilTekst } from '@/lib/kontrakt/docx'
import { SigneringSkjema } from '../signering'
import { Status } from '@/components/ui/status'
import { Sidehode } from '@/components/ui/side'
import { Sideramme } from '@/components/ui/sideramme'

// Kontrakten som tekst, slik den faktisk ble fylt ut.
//
// Ikke en Word-visning — teksten, med feltene på plass. Det er den man
// skal lese før man sender noe fra seg: står navnet riktig, står
// stillingsprosenten riktig, ble noen klammer stående igjen.

type Params = Promise<{ id: string }>

export default async function KontraktVisning({ params }: { params: Params }) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return <p>Arbeidsavtaler er for butikksjef og eier.</p>

  const { id } = await params
  const supabase = await lagSupabaseServerKlient()

  const { data: rad } = await supabase
    .from('ansatt_kontrakt')
    .select('ansatt_navn, ansatt_nr, mal_versjon, gjelder_fra, status, opprettet_tid, verdier, storage_sti, signert_tid, signert_metode')
    .eq('id', id)
    .maybeSingle<{
      ansatt_navn: string; ansatt_nr: string; mal_versjon: number | null
      gjelder_fra: string | null; status: string; opprettet_tid: string
      verdier: Record<string, string>; storage_sti: string | null
      signert_tid: string | null; signert_metode: string | null
    }>()
  if (!rad) return <p>Fant ikke kontrakten.</p>

  const iDag = new Date().toISOString().slice(0, 10)

  const svar = await gjenskapKontrakt(supabase, id)
  const tekst = svar.ok ? docxTilTekst(svar.docx) : null

  // Klammer som står igjen er valgene malen stiller — de skal leses, ikke
  // fylles. Men de skal også ikke bli med videre uten at noen har sett dem.
  const igjen = tekst ? [...new Set(
    [...tekst.matchAll(/\[([^\]\[\n]{1,80}?)\]/g)].map((m) => m[1]),
  )] : []

  // NIVÅ 1 på en detaljside: hva er dette, og hvilken tilstand er det i.
  // Tilstanden er om den er signert, og om det står valg igjen som ingen
  // har tatt stilling til. Begge lå som egne seksjoner lenger nede — den
  // andre først etter signeringsfeltet man skulle bruke.
  const tilstand = [
    rad.signert_tid
      ? `Signert ${new Date(rad.signert_tid).toLocaleDateString('nb-NO')}`
      : 'Ikke signert',
    igjen.length > 0
      ? `${igjen.length} ${igjen.length === 1 ? 'valg står' : 'valg står'} igjen i dokumentet`
      : null,
  ].filter(Boolean).join(' · ')

  return (
    <Sideramme>
      <Sidehode
        tittel={rad.ansatt_navn}
        undertittel={`${tilstand}. Ansattnummer ${rad.ansatt_nr} · malversjon v${rad.mal_versjon ?? '—'} · skrevet ${new Date(rad.opprettet_tid).toLocaleDateString('nb-NO')}${rad.gjelder_fra ? ` · gjelder fra ${new Date(rad.gjelder_fra).toLocaleDateString('nb-NO')}` : ''}`}
        handlinger={
          <>
            <a className="sq-knapp primar" href={`/api/kontrakt/fil?id=${id}`}>Last ned .docx</a>
            <Link className="sq-knapp" href="/kontrakt">Alle avtaler</Link>
          </>
        }
      />

      <section className="kort">
        <p className="notis sq-tett">
          Dokumentet lagres ikke som fil. Det bygges på nytt fra verdiene og
          malversjonen hver gang — samme mal og samme verdier gir samme dokument.
          En kopi i tillegg ville vært en andre sannhet å holde i synk, og den dagen
          de to spriker vet ingen hvilken hun faktisk signerte.
        </p>
      </section>

      <section className="kort">
        <h2>Signering</h2>
        {rad.signert_tid ? (
          <>
            <p>
              {/* Signert er MAALET paa denne sida - men det er ogsaa
                  utgangspunktet naar den forst er naadd. `normal`, med
                  ordet som baerer. */}
              <Status nivaa="normal">Signert</Status>{' '}
              {new Date(rad.signert_tid).toLocaleDateString('nb-NO')}
              {rad.signert_metode === 'bekreftelse' && ' · signert utenfor systemet'}
            </p>
            {rad.storage_sti && (
              <div className="knapperad">
                <a className="sq-knapp" href={`/api/kontrakt/fil?id=${id}&signert=1`}>
                  Last ned signert eksemplar
                </a>
              </div>
            )}
          </>
        ) : (
          <p className="undertittel">
            Ikke signert ennå. Last ned dokumentet over, få det signert, og last
            det signerte eksemplaret opp her.
          </p>
        )}

        <SigneringSkjema
          kontraktId={id}
          iDag={iDag}
          alleredeSignert={rad.signert_tid !== null}
        />

        <p className="notis sq-tett">
          Dette er broen til BankID, ikke en erstatning for den: her er det et
          menneske som bekrefter at papiret finnes. Laster du opp på nytt, erstattes
          ikke det gamle — hver opplasting får sin egen fil, så et signert eksemplar
          aldri kan byttes ut i stillhet. En signert kontrakt kan heller ikke slettes.
        </p>
      </section>

      {igjen.length > 0 && (
        <section className="kort">
          <h2>{igjen.length} valg står igjen</h2>
          <p className="undertittel">
            Hele setninger med klammer rundt, som skal beholdes eller slettes i Word.
            Vi fjerner dem ikke automatisk — det ville vært å endre en juridisk
            gjennomgått avtale uten at noen leste den.
          </p>
          <ul className="undertittel sq-tett">
            {igjen.map((v) => <li key={v}>{v}</li>)}
          </ul>
        </section>
      )}

      <section className="kort">
        <h2>Slik ble den fylt ut</h2>
        {/* Utfyllingen skal leses som teksten den er, med linjeskiftene
            intakt. Fem inline-regler ble en klasse. */}
        {tekst ? (
          <pre className="sq-utfylt">
            {tekst}
          </pre>
        ) : (
          <p className="undertittel">{!svar.ok && svar.feil}</p>
        )}
      </section>

      <section className="kort">
        <h2>Verdiene som ble satt inn</h2>
        <div className="tabellramme">
          <table className="tabell">
            <thead><tr><th>Felt</th><th>Verdi</th></tr></thead>
            <tbody>
              {Object.entries(rad.verdier ?? {}).map(([k, v]) => (
                <tr key={k}><td>{k}</td><td>{v}</td></tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </Sideramme>
  )
}
