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
import { oversettMange } from '@/lib/oversett'

// Informasjonsplikten etter aml. § 9-2 andre ledd, gjort til en side.
//
// Den er skrevet TIL den ansatte, ikke om henne. Det er hele forskjellen
// mellom å informere og å dekke seg.

// Sidas egne tekster, samlet ett sted. To grunner: `oversettMange` skal
// få dem i ett kall, og den som legger til en setning skal se at den må
// med. Skrives de rett i JSX-en og gjentas i lista, skiller de lag.
const T = {
  tittel: 'Slik måler vi',
  nyTekst: 'Ny tekst — les gjennom og kvitter under. Dette er hva Sentiqa '
    + 'registrerer om deg som jobber her, hvorfor, hvem som ser det, og hvor '
    + 'lenge det lagres.',
  alleredeLest: 'Du har lest denne. Dette er hva Sentiqa registrerer om deg '
    + 'som jobber her, hvorfor, hvem som ser det, og hvor lenge det lagres. '
    + 'Du skal ikke måtte gjette.',
  lesGjennom: 'Les gjennom',
  paragraf: 'Arbeidsmiljøloven § 9-2 krever at du får vite hva som registreres '
    + 'før det gjøres. Trykk under når du har lest — det er ikke et samtykke, '
    + 'og du gir ikke fra deg noe ved å trykke. Det er en kvittering på at du '
    + 'har fått informasjonen.',
  lest: 'Lest',
  bekreftet: 'Du har bekreftet denne teksten. Endrer den seg, får du beskjed '
    + 'på nytt.',
  hvorfor: 'Hvorfor:',
  hvemSer: 'Hvem ser det:',
  hvorLenge: 'Hvor lenge:',
  ikkeGjor: 'Det vi ikke gjør',
  likeViktig: 'Like viktig som hva som registreres.',
  ingenKamera: 'Vi har ikke kameraovervåking eller GPS knyttet til Sentiqa.',
  ingenEpost: 'Vi leser ikke e-posten eller meldingene dine.',
  ingenSted: 'Vi registrerer ikke hvor du er når du ikke er på jobb.',
  ingenKolleger: 'Kolleger ser ikke lønna di, fødselsdatoen din eller '
    + 'fraværet ditt.',
  rettigheter: 'Dine rettigheter',
  logges: 'Alle oppslag på personopplysninger logges — hvem som så hva, og '
    + 'når. Spør du butikksjefen hvem som har sett opplysningene dine, finnes '
    + 'det et svar.',
  // FORBEHOLDET. Ikke en ansvarsfraskrivelse — den ene opplysningen en
  // oversatt juridisk tekst faktisk trenger.
  maskinoversatt: 'Denne teksten er maskinoversatt. Den norske versjonen er '
    + 'den som gjelder — du finner den ved å velge norsk flagg øverst.',
} as const

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

  // =================================================================
  // TEKSTEN PÅ HENNES SPRÅK, MEN NORSK ER DEN SOM GJELDER
  //
  // Denne sida var den siste uten oversetting, og den sto igjen med
  // vilje: aml. § 9-2 handler om at arbeidsgiver DOKUMENTERER at den
  // ansatte er informert, og en maskinoversettelse av juridisk tekst er
  // ikke uten videre noe man kan stå for.
  //
  // Avveiningen snur når man ser på hvem sida er for. Den som ikke leser
  // norsk får ellers et personvernvarsel hun ikke kan lese — og kvitterer
  // på det. En bekreftelse på en tekst hun ikke forsto dokumenterer
  // MINDRE enn en oversettelse med et forbehold.
  //
  // Derfor: oversatt, OG en linje som sier at den norske teksten er den
  // som gjelder og hvordan hun finner den.
  //
  // `oversettMange` og ikke `TABLET_ORD`: dette er få, lange avsnitt som
  // hører til én side, ikke faste UI-fraser. Cachen tar dem etter første
  // visning per språk.
  // =================================================================
  const { cookies } = await import('next/headers')
  const sprak = bruker.rolle === 'butikkbruker_tablet'
    ? ((await cookies()).get('sprak')?.value ?? 'no') : 'no'
  const oversatt = sprak !== 'no'
  const ord = await oversettMange([
    ...Object.values(T),
    ...TILTAK.flatMap((x) => [x.hva, x.hvorfor, x.hvemSer, x.hvorLenge, x.merk ?? '']),
    ...RETTIGHETER.flatMap((r) => [r.tittel, r.tekst]),
  ].filter(Boolean), sprak)
  const o = (x: string) => ord.get(x) ?? x

  return (
    <Sideramme>
      {/* Sidehodet sier tilstanden — lest eller ikke — i stedet for at den
          bare finnes som et kort lenger ned. På en detaljside er «hvilken
          tilstand er dette i» nivå 1, og her er tilstanden hele poenget:
          har du fått informasjonen, eller venter den på deg. */}
      <Sidehode
        tittel={o(T.tittel)}
        undertittel={o(trengerBekreftelse ? T.nyTekst : T.alleredeLest)}
      />

      {/* FORBEHOLDET STÅR ØVERST, ikke nederst. Den som leser en oversatt
          juridisk tekst skal vite det FØR hun leser den, ikke etter at
          hun har kvittert. */}
      {oversatt && <p className="notis sq-tett">{o(T.maskinoversatt)}</p>}

      {trengerBekreftelse ? (
        <section className="kort">
          <h2>{o(T.lesGjennom)}</h2>
          <p className="undertittel">{o(T.paragraf)}</p>
          <BekreftSkjema versjon={KONTROLLTILTAK_VERSJON} />
        </section>
      ) : (
        <section className="kort">
          <p className="sq-tett">
            <Status nivaa="normal">{o(T.lest)}</Status>{' '}
            <span className="undertittel">{o(T.bekreftet)}</span>
          </p>
        </section>
      )}

      {TILTAK.map((tiltak) => (
        <section className="kort" key={tiltak.hva}>
          <h2>{o(tiltak.hva)}</h2>
          <p><strong>{o(T.hvorfor)}</strong> {o(tiltak.hvorfor)}</p>
          <p><strong>{o(T.hvemSer)}</strong> {o(tiltak.hvemSer)}</p>
          <p><strong>{o(T.hvorLenge)}</strong> {o(tiltak.hvorLenge)}</p>
          {tiltak.merk && <p className="notis sq-tett">{o(tiltak.merk)}</p>}
        </section>
      ))}

      <section className="kort">
        <h2>{o(T.ikkeGjor)}</h2>
        <p className="undertittel">{o(T.likeViktig)}</p>
        <ul>
          <li>{o(T.ingenKamera)}</li>
          <li>{o(T.ingenEpost)}</li>
          <li>{o(T.ingenSted)}</li>
          <li>{o(T.ingenKolleger)}</li>
        </ul>
      </section>

      <section className="kort">
        <h2>{o(T.rettigheter)}</h2>
        {RETTIGHETER.map((r) => (
          <p key={r.tittel}>
            <strong>{o(r.tittel)}.</strong> {o(r.tekst)}
          </p>
        ))}
        <p className="notis sq-tett">{o(T.logges)}</p>
      </section>

      <p className="undertittel">
        Versjon {KONTROLLTILTAK_VERSJON}. Endres teksten vesentlig, blir du bedt om
        å lese den på nytt.
      </p>
    </Sideramme>
  )
}
