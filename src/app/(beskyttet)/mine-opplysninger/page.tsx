import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { lesAktivAnsatt } from '@/lib/ansatt'
import { sisteBekreftelse } from '@/lib/personvern/bekreftelse'
import {
  KONTROLLTILTAK_VERSJON, maaBekrefte, RETTIGHETER, TILTAK,
} from '@/lib/personvern/kontrolltiltak'
import { BekreftSkjema } from './bekreft'
import { Status } from '@/components/ui/status'
import { Sidehode } from '@/components/ui/side'
import { Sideramme } from '@/components/ui/sideramme'

// Informasjonsplikten etter aml. § 9-2 andre ledd, gjort til en side.
//
// Den er skrevet TIL den ansatte, ikke om henne. Det er hele forskjellen
// mellom å informere og å dekke seg.

export default async function MineOpplysninger() {
  const bruker = await hentInnloggetBruker()
  const supabase = await lagSupabaseServerKlient()
  const ansatt = bruker.rolle === 'butikkbruker_tablet' ? await lesAktivAnsatt(supabase) : null

  // TO VEIER, FORDI DE TO IDENTITETENE ER ULIKE.
  //
  // Den innloggede leser sin egen rad gjennom RLS — `bruker_id =
  // auth.uid()` er foerste gren i `0147`, og den virker.
  //
  // Nettbrettet skriver `ansatt_id` med `bruker_id = null`, og treffer da
  // ingen av grenene. Databasen kan ikke vite hvem som staar paa vakt:
  // `checkInn` setter en signert kapsel og etterlater ingen rad. Derfor
  // leses den ene raden serverside, med en identitet `lesAktivAnsatt`
  // alt har bevist med signatur OG oppslag gjennom nettbrettets egen RLS.
  // Se `personvern/bekreftelse.ts`.
  let bekreftet: string | null = null
  if (ansatt) {
    bekreftet = (await sisteBekreftelse(ansatt, bruker.retailerId ?? ''))?.versjon ?? null
  } else if (bruker.rolle !== 'butikkbruker_tablet') {
    const { data } = await supabase
      .from('kontrolltiltak_bekreftelse')
      .select('versjon, bekreftet_tid')
      .eq('bruker_id', bruker.id)
      .order('bekreftet_tid', { ascending: false })
      .limit(1)
      .maybeSingle<{ versjon: string }>()
    bekreftet = data?.versjon ?? null
  }
  const trengerBekreftelse = maaBekrefte(bekreftet)

  return (
    <Sideramme>
      {/* Sidehodet sier tilstanden — lest eller ikke — i stedet for at den
          bare finnes som et kort lenger ned. På en detaljside er «hvilken
          tilstand er dette i» nivå 1, og her er tilstanden hele poenget:
          har du fått informasjonen, eller venter den på deg. */}
      <Sidehode
        tittel="Slik måler vi"
        undertittel={trengerBekreftelse
          ? 'Ny tekst — les gjennom og kvitter under. Dette er hva Sentiqa registrerer om deg som jobber her, hvorfor, hvem som ser det, og hvor lenge det lagres.'
          : 'Du har lest denne. Dette er hva Sentiqa registrerer om deg som jobber her, hvorfor, hvem som ser det, og hvor lenge det lagres. Du skal ikke måtte gjette.'}
      />

      {trengerBekreftelse ? (
        <section className="kort">
          <h2>Les gjennom</h2>
          <p className="undertittel">
            Arbeidsmiljøloven § 9-2 krever at du får vite hva som registreres før
            det gjøres. Trykk under når du har lest — det er ikke et samtykke, og
            du gir ikke fra deg noe ved å trykke. Det er en kvittering på at du
            har fått informasjonen.
          </p>
          <BekreftSkjema versjon={KONTROLLTILTAK_VERSJON} />
        </section>
      ) : (
        <section className="kort">
          <p className="sq-tett">
            <Status nivaa="normal">Lest</Status>{' '}
            <span className="undertittel">
              Du har bekreftet denne teksten. Endrer den seg, får du beskjed på nytt.
            </span>
          </p>
        </section>
      )}

      {TILTAK.map((t) => (
        <section className="kort" key={t.hva}>
          <h2>{t.hva}</h2>
          <p><strong>Hvorfor:</strong> {t.hvorfor}</p>
          <p><strong>Hvem ser det:</strong> {t.hvemSer}</p>
          <p><strong>Hvor lenge:</strong> {t.hvorLenge}</p>
          {t.merk && <p className="notis sq-tett">{t.merk}</p>}
        </section>
      ))}

      <section className="kort">
        <h2>Det vi ikke gjør</h2>
        <p className="undertittel">
          Like viktig som hva som registreres.
        </p>
        <ul>
          <li>Vi har ikke kameraovervåking eller GPS knyttet til Sentiqa.</li>
          <li>Vi leser ikke e-posten eller meldingene dine.</li>
          <li>Vi registrerer ikke hvor du er når du ikke er på jobb.</li>
          <li>Kolleger ser ikke lønna di, fødselsdatoen din eller fraværet ditt.</li>
        </ul>
      </section>

      <section className="kort">
        <h2>Dine rettigheter</h2>
        {RETTIGHETER.map((r) => (
          <p key={r.tittel}>
            <strong>{r.tittel}.</strong> {r.tekst}
          </p>
        ))}
        <p className="notis sq-tett">
          Alle oppslag på personopplysninger logges — hvem som så hva, og når. Spør
          du butikksjefen hvem som har sett opplysningene dine, finnes det et svar.
        </p>
      </section>

      <p className="undertittel">
        Versjon {KONTROLLTILTAK_VERSJON}. Endres teksten vesentlig, blir du bedt om
        å lese den på nytt.
      </p>
    </Sideramme>
  )
}
