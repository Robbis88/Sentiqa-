import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { maanedsnavn } from '@/lib/kurs/plan'
import { Sidehode, Tomtilstand, Feiltilstand, Forklaring } from '@/components/ui/side'
import { maaVaereHele } from '@/lib/supabase/datobolker'
import { Sideramme } from '@/components/ui/sideramme'
import { Planlesing } from './planlesing'
import type { Punkt } from '../maanedsplan/plankort'

// =====================================================================
// Butikksjefens månedsplan.
//
// =====================================================================
// HVORFOR DENNE FINNES
// =====================================================================
//
// `/maanedsplan` er EIERENS KØ — utkast som venter på at hun tar
// stilling. Butikksjefen er mottakeren, ikke avsenderen, og skal hverken
// se køen eller de andre stasjonenes utkast.
//
// Fram til nå hadde hun ingen flate i det hele tatt. RLS-policyen i
// `0200` ga henne LESETILGANG til sluppede planer, og koden sa «hun
// leser sin egen plan når den er sluppet» — men det fantes ingen rute
// som viste den, og ingen e-post ble sendt. En tilgang er ikke en flate.
//
// ---------------------------------------------------------------------
// BARE SLUPPET OG SENDT
//
// Et utkast er eierens forslag til seg selv. Ser butikksjefen det, er
// godkjenningen meningsløs — og et brev hun har lest skal ikke kunne
// skrives om. Filteret her er det samme som RLS håndhever; det står
// begge steder med vilje.
// =====================================================================

/**
 * Et TAK, ikke et oenske.
 *
 * 240 er tjue stasjoner i tolv maaneder, eller fem stasjoner i fire aar.
 * En kjede som naar det faar en feilmelding, ikke en avkortet liste.
 */
const TAK_PLANER = 240

type Planrad = {
  id: string
  maaned: string
  dom: 'medvind' | 'motvind' | 'flat'
  ingress: string
  punkter: Punkt[]
  merknad: string | null
  status: string
  matkast: unknown
  usynlig: unknown
  /** `jsonb`. Gaar gjennom `lesRangering` i komponenten, ikke her. */
  rangering: unknown
  stasjoner: { navn: string } | null
}

export default async function MinPlanSide() {
  const bruker = await hentInnloggetBruker()
  // Eieren slipper inn med vilje: hun skal kunne se NOEYAKTIG det
  // butikksjefen ser, uten aa be om en skjerm. RLS gir henne hele kjeden
  // her, men hvert kort baerer stasjonsnavnet sitt.
  const erButikksjef = bruker.rolle === 'butikksjef'
  const erEier = bruker.rolle === 'retailer_admin'
  if (!erButikksjef && !erEier) {
    return <p>Du har ikke tilgang.</p>
  }

  const supabase = await lagSupabaseServerKlient()
  // =====================================================================
  // GRENSEN SKAL KUNNE BEVISE AT SVARET ER HELT
  // =====================================================================
  //
  // Her sto `.limit(60)` og `data ?? []`. Begge deler loey paa samme
  // maate, i hver sin retning:
  //
  //   * 60 er NOEYAKTIG fem stasjoner ganger tolv maaneder. Et svar som
  //     treffer den grensen kan vaere avkortet, og en avkortet liste ser
  //     ut som en kortere historikk - ikke som en feil.
  //   * `data ?? []` gjorde en feilet spoerring til null rader, og null
  //     rader tegnes som «Ingen maanedsplan ennaa».
  //
  // `maaVaereHele` er husets vakt for begge: den kaster paa `error`, og
  // den kaster naar svaret TREFFER taket. Grensen er ikke et oenske om
  // faerre rader - den er et sted aa oppdage at det ble for mange.
  const svar = await supabase
    .from('maanedsplan')
    .select('id, maaned, dom, ingress, punkter, merknad, status, matkast, usynlig, rangering, stasjoner(navn)')
    .in('status', ['sluppet', 'sendt'])
    .order('maaned', { ascending: false })
    .limit(TAK_PLANER)
    .overrideTypes<Planrad[]>()

  let planer: Planrad[]
  try {
    planer = maaVaereHele(svar, 'maanedsplanene dine', TAK_PLANER)
  } catch (e) {
    return (
      <Sideramme>
        <Sidehode tittel="Månedsplanen din" undertittel="Kunne ikke hentes" />
        <Feiltilstand
          tittel="Planen kunne ikke hentes"
          detalj={e instanceof Error ? e.message : String(e)}
          forklaring={
            'Dette er ikke det samme som at du ikke har en plan. Spørringen '
            + 'nådde ikke fram, og sida viser derfor ingenting heller enn en '
            + 'tom liste som ser riktig ut. Prøv igjen, og si fra dersom den '
            + 'blir stående.'
          }
        />
      </Sideramme>
    )
  }

  const nyeste = planer[0]

  return (
    <Sideramme>
      <Sidehode
        tittel="Månedsplanen din"
        undertittel={
          nyeste
            ? `Siste: ${maanedsnavn(nyeste.maaned)} ${nyeste.maaned.slice(0, 4)}`
            : 'Ingen plan ennå'
        }
      />

      {planer.length === 0 && (
        <Tomtilstand
          tittel="Ingen månedsplan ennå"
          forklaring={
            'Planen skrives når regnskapet importeres, og blir synlig her '
            + 'når eier har lest den og sluppet den. Den trenger minst tre '
            + 'måneder med tall før retningen betyr noe.'
          }
        />
      )}

      {planer.length > 0 && (
        <>
          <Forklaring>
            Planen bygger på nivå mot budsjett, utvikling over tid og
            kvaliteten på datagrunnlaget. Den er kontrollert og sluppet av
            eier før den ble synlig her.
          </Forklaring>
          <div className="sq-plankort-liste">
            {planer.map((p) => (
              <Planlesing
                key={p.id}
                stasjon={p.stasjoner?.navn ?? 'Stasjonen din'}
                maaned={p.maaned}
                dom={p.dom}
                ingress={p.ingress}
                punkter={p.punkter ?? []}
                merknad={p.merknad}
                matkast={p.matkast}
                usynlig={p.usynlig}
                rangering={p.rangering}
              />
            ))}
          </div>
        </>
      )}
    </Sideramme>
  )
}
