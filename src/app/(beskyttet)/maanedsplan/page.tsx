import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { maanedsnavn } from '@/lib/kurs/plan'
import { Sidehode, Tomtilstand, Feiltilstand, Forklaring } from '@/components/ui/side'
import { maaVaereHele } from '@/lib/supabase/datobolker'
import { nyesteKompletteMaaned } from '@/lib/kurs/regenerer'
import { Sideramme } from '@/components/ui/sideramme'
import { Plankort, type Punkt } from './plankort'
import { Byggknapp } from './byggknapp'

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

/** Se `/min-plan`: et tak aa oppdage avkorting paa, ikke en visningsgrense. */
const TAK_PLANER = 240

type Planrad = {
  id: string
  maaned: string
  dom: 'medvind' | 'motvind' | 'flat'
  ingress: string
  punkter: Punkt[]
  merknad: string | null
  status: string
  stasjoner: { navn: string } | null
  // ANALYSEN, SLIK DEN BLE BEREGNET. `null` paa planer som er eldre
  // enn `0216` - da sier kortet «ikke beregnet», ikke «blokkert».
  matkast: unknown
  usynlig: unknown
  /** `jsonb`. Gaar gjennom `lesRangering` i komponenten, ikke her. */
  rangering: unknown
}

export default async function MaanedsplanSide() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin') return <p>Du har ikke tilgang.</p>

  const supabase = await lagSupabaseServerKlient()
  // GRENSEN ER EKSPLISITT. Tolv måneder × rimelig antall stasjoner. Et
  // avkortet svar ville sett ut som «ingen flere planer» — og da hadde
  // en stasjon ligget usluppet uten at noe sa fra.
  const svar = await supabase
    .from('maanedsplan')
    .select('id, maaned, dom, ingress, punkter, merknad, status, matkast, usynlig, rangering, stasjoner(navn)')
    .order('maaned', { ascending: false })
    .order('status')
    .limit(TAK_PLANER)
    .overrideTypes<Planrad[]>()

  // KOEEN MAA VAERE HEL. Et avkortet svar ville skjult et usluppet
  // utkast, og et utkast ingen ser er en stasjon uten en plan - uten at
  // noe sa fra. `maaVaereHele` kaster paa `error` OG paa et svar som
  // treffer taket; begge tegnes som en feil, ikke som en tom koe.
  let alle: Planrad[]
  try {
    alle = maaVaereHele(svar, 'maanedsplanene', TAK_PLANER)
  } catch (e) {
    return (
      <Sideramme>
        <Sidehode tittel="Månedsplaner" undertittel="Kunne ikke hentes" />
        <Feiltilstand
          tittel="Køen kunne ikke hentes"
          detalj={e instanceof Error ? e.message : String(e)}
          forklaring={
            'Dette er ikke det samme som en tom kø. Et avkortet eller feilet '
            + 'svar ville skjult et usluppet utkast, og da hadde en stasjon '
            + 'ligget uten plan uten at noe sa fra.'
          }
        />
      </Sideramme>
    )
  }

  const utkast = alle.filter((p) => p.status === 'utkast')
  const avgjort = alle.filter((p) => p.status !== 'utkast')
  const nyeste = alle[0]?.maaned

  // MÅLMÅNEDEN OG FORVENTNINGEN, fra DATAGRUNNLAGET.
  //
  // To tall, og de skal stå hver for seg: hvor mange stasjoner
  // grunnlaget forventer, og hvor mange planer som allerede finnes.
  // Er de ulike, er det nettopp da man vil se begge — ett tall ville
  // skjult at noe mangler.
  //
  // Feiler oppslaget, faller knappen bort. En knapp som ikke vet hvilken
  // måned den gjelder, skal ikke stå der.
  let maal: { maaned: string | null; aktiveStasjoner: number } | null = null
  try {
    maal = await nyesteKompletteMaaned({ supabase, retailerId: bruker.retailerId! })
  } catch {
    maal = null
  }
  const planerIMaal = maal?.maaned
    ? alle.filter((p) => String(p.maaned).slice(0, 10) === maal!.maaned).length
    : 0

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

      {maal?.maaned && (
        <Byggknapp
          maaned={maal.maaned}
          forventet={maal.aktiveStasjoner}
          eksisterende={planerIMaal}
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
                matkast={p.matkast}
                usynlig={p.usynlig}
                rangering={p.rangering}
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
                matkast={p.matkast}
                usynlig={p.usynlig}
                rangering={p.rangering}
              />
            ))}
          </div>
        </section>
      )}
    </Sideramme>
  )
}
