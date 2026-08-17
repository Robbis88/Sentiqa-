import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { lesAktivAnsatt } from '@/lib/ansatt'
import {
  KONTROLLTILTAK_VERSJON, maaBekrefte, RETTIGHETER, TILTAK,
} from '@/lib/personvern/kontrolltiltak'
import { BekreftSkjema } from './bekreft'

// Informasjonsplikten etter aml. § 9-2 andre ledd, gjort til en side.
//
// Den er skrevet TIL den ansatte, ikke om henne. Det er hele forskjellen
// mellom å informere og å dekke seg.

export default async function MineOpplysninger() {
  const bruker = await hentInnloggetBruker()
  const supabase = await lagSupabaseServerKlient()
  const ansatt = bruker.rolle === 'butikkbruker_tablet' ? await lesAktivAnsatt() : null

  let bekreftet: string | null = null
  if (ansatt || bruker.rolle !== 'butikkbruker_tablet') {
    const sp = supabase
      .from('kontrolltiltak_bekreftelse')
      .select('versjon, bekreftet_tid')
      .order('bekreftet_tid', { ascending: false })
      .limit(1)
    const { data } = ansatt
      ? await sp.eq('ansatt_id', ansatt.id).maybeSingle<{ versjon: string }>()
      : await sp.eq('bruker_id', bruker.id).maybeSingle<{ versjon: string }>()
    bekreftet = data?.versjon ?? null
  }
  const trengerBekreftelse = maaBekrefte(bekreftet)

  return (
    <>
      <h1>Slik måler vi</h1>
      <p className="undertittel">
        Dette er hva Sentiqa registrerer om deg som jobber her, hvorfor, hvem som
        ser det, og hvor lenge det lagres. Du skal ikke måtte gjette.
      </p>

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
          <p style={{ margin: 0 }}>
            <span className="status-pip gronn">Lest</span>{' '}
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
          {t.merk && <p className="notis" style={{ marginBottom: 0 }}>{t.merk}</p>}
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
        <p className="notis" style={{ marginBottom: 0 }}>
          Alle oppslag på personopplysninger logges — hvem som så hva, og når. Spør
          du butikksjefen hvem som har sett opplysningene dine, finnes det et svar.
        </p>
      </section>

      <p className="undertittel">
        Versjon {KONTROLLTILTAK_VERSJON}. Endres teksten vesentlig, blir du bedt om
        å lese den på nytt.
      </p>
    </>
  )
}
