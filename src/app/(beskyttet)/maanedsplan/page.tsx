import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { maanedsnavn } from '@/lib/kurs/plan'
import { Sidehode, Tomtilstand, Forklaring } from '@/components/ui/side'
import { Sideramme } from '@/components/ui/sideramme'
import { Plankort, type Punkt } from './plankort'

// =====================================================================
// Månedsplanene — eierens godkjenningskø.
//
// Systemet skriver utkastene når regnskapet importeres. Her ser du dem,
// og du slipper dem eller lar være. **Butikksjefen ser ingenting før du
// har tatt stilling** — det står i RLS (0200), ikke i denne sida.
//
// ---------------------------------------------------------------------
// HVORFOR EN EGEN SIDE OG IKKE EN FANE PÅ /REGNSKAP
//
// /regnskap svarer på «hva ble tallene?». Denne svarer på «hva skal de
// gjøre med dem?», og den har en HANDLING i seg: noe forlater systemet
// når du trykker. En side der man bare leser, og en der man sender noe
// til et menneske, skal ikke være samme side.
//
// ---------------------------------------------------------------------
// BARE EIER
//
// Butikksjefen er mottakeren, ikke avsenderen. Hun leser planen sin der
// hun leser tallene sine; hun skal ikke se køen, og slett ikke de andre
// stasjonenes utkast.
// =====================================================================

type Planrad = {
  id: string
  maaned: string
  dom: 'medvind' | 'motvind' | 'flat'
  ingress: string
  punkter: Punkt[]
  merknad: string | null
  status: string
  stasjoner: { navn: string } | null
}

export default async function MaanedsplanSide() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin') return <p>Du har ikke tilgang.</p>

  const supabase = await lagSupabaseServerKlient()
  // GRENSEN ER EKSPLISITT. Tolv måneder × rimelig antall stasjoner. Et
  // avkortet svar ville sett ut som «ingen flere planer» — og da hadde
  // en stasjon ligget usluppet uten at noe sa fra.
  const { data } = await supabase
    .from('maanedsplan')
    .select('id, maaned, dom, ingress, punkter, merknad, status, stasjoner(navn)')
    .order('maaned', { ascending: false })
    .order('status')
    .limit(240)
    .overrideTypes<Planrad[]>()

  const alle = data ?? []
  const utkast = alle.filter((p) => p.status === 'utkast')
  const avgjort = alle.filter((p) => p.status !== 'utkast')
  const nyeste = alle[0]?.maaned

  return (
    <Sideramme>
      <Sidehode
        tittel="Månedsplaner"
        undertittel={
          nyeste
            ? `Siste: ${maanedsnavn(nyeste)} ${nyeste.slice(0, 4)}`
            : 'Ingen planer ennå'
        }
      />

      {alle.length === 0 && (
        <Tomtilstand
          tittel="Ingen månedsplaner ennå"
          forklaring={
            'Planene bygges når regnskapet importeres. De trenger minst tre '
            + 'måneder med tall før retningen betyr noe — to punkter er en '
            + 'strek, ikke en retning.'
          }
        />
      )}

      {utkast.length > 0 && (
        <section>
          <h2>Venter på deg</h2>
          <Forklaring>
            Butikksjefen ser ingenting før du slipper. Et brev som ikke er
            sluppet er ikke et brev — det er et forslag til deg.
          </Forklaring>
          <div className="sq-plankort-liste">
            {utkast.map((p) => (
              <Plankort
                key={p.id}
                id={p.id}
                stasjon={p.stasjoner?.navn ?? 'Ukjent stasjon'}
                dom={p.dom}
                ingress={p.ingress}
                punkter={p.punkter ?? []}
                merknad={p.merknad}
                status={p.status}
              />
            ))}
          </div>
        </section>
      )}

      {avgjort.length > 0 && (
        <section>
          <h2>Avgjort</h2>
          <Forklaring>
            En sluppet plan kan ikke skrives om — heller ikke av en ny
            regnskapsimport. Et brev butikksjefen har lest skal ikke endre
            seg under henne.
          </Forklaring>
          <div className="sq-plankort-liste">
            {avgjort.map((p) => (
              <Plankort
                key={p.id}
                id={p.id}
                stasjon={p.stasjoner?.navn ?? 'Ukjent stasjon'}
                dom={p.dom}
                ingress={p.ingress}
                punkter={p.punkter ?? []}
                merknad={p.merknad}
                status={p.status}
              />
            ))}
          </div>
        </section>
      )}
    </Sideramme>
  )
}
