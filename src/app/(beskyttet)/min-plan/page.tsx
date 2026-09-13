import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { maanedsnavn } from '@/lib/kurs/plan'
import { Sidehode, Tomtilstand, Forklaring } from '@/components/ui/side'
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
  rangering: { mulig: boolean; kandidater: string[] } | null
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
  // TOLV MÅNEDER × rimelig antall stasjoner. En butikksjef har som regel
  // én, men kan ha flere — og et avkortet svar ville sett ut som «ingen
  // plan», ikke som en manglende rad.
  const { data } = await supabase
    .from('maanedsplan')
    .select('id, maaned, dom, ingress, punkter, merknad, status, matkast, usynlig, rangering, stasjoner(navn)')
    .in('status', ['sluppet', 'sendt'])
    .order('maaned', { ascending: false })
    .limit(60)
    .overrideTypes<Planrad[]>()

  const planer = data ?? []
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
                rangering={p.rangering ?? { mulig: true, kandidater: [] }}
              />
            ))}
          </div>
        </>
      )}
    </Sideramme>
  )
}
