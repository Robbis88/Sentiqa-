import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { maanedsnavn } from '@/lib/kurs/plan'
import { Sidehode, Tomtilstand, Feiltilstand, Forklaring } from '@/components/ui/side'
import { maaVaereHele } from '@/lib/supabase/datobolker'
import { Sideramme } from '@/components/ui/sideramme'
import { husketStasjon } from '@/lib/stasjonskontekst'
import { stasjonFraUrl, tillatAlleFor } from '@/lib/stasjonsvalg'
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

// =====================================================================
// PLANEN GJELDER DEN VALGTE STASJONEN
// =====================================================================
//
// MAALT I PRODUKSJON 2026-09-16. Toppvelgeren sto paa «9038 St1
// Laguneparken» mens denne fanen viste «St1 Dale · juli 2026» oeverst.
//
// Aarsaken var ikke en feil i et tall: spoerringen hadde INGEN
// `stasjon_id`-filter i det hele tatt, og sorterte bare paa `maaned
// desc`. Rekkefoelgen innenfor juli var den Postgres tilfeldigvis ga.
//
// Det var en bevisst avgjoerelse - «RLS gir henne hele kjeden her, men
// hvert kort baerer stasjonsnavnet sitt» - og den var usynlig saa lenge
// `/min-plan` laa som en egen menylinje langt nede. Naa ligger den som
// fane ved siden av «Maaneden», som RESPEKTERER velgeren. To naboer som
// svarer ulikt paa «hvilken stasjon ser jeg paa» er ikke en akseptabel
// brukerreise.
//
// «Butikken min» er ÉN kontekst: staar du paa Laguneparken, handler alle
// tre fanene om Laguneparken.
//
// EIERENS KJEDEBEHOV ER IKKE FJERNET. `/maanedsplan` er
// godkjenningskoeen paa tvers av stasjoner, og den er uendret. Det er to
// spoersmaal: «hva skal DENNE butikken gjoere» og «hvilke utkast venter
// paa meg». De hoerer ikke paa samme flate.
//
// RLS ER FORTSATT SIKKERHETEN. Filteret her er en INNSNEVRING av det
// policyen alt tillater (`0200`), aldri en utvidelse - butikksjefen naar
// bare `mine_stasjoner()` uansett hva URL-en sier.
// =====================================================================

export default async function MinPlanSide(
  { searchParams }: { searchParams: Promise<{ stasjon?: string }> },
) {
  const bruker = await hentInnloggetBruker()
  const erButikksjef = bruker.rolle === 'butikksjef'
  const erEier = bruker.rolle === 'retailer_admin'
  if (!erButikksjef && !erEier) {
    return <p>Du har ikke tilgang.</p>
  }

  const sp = await searchParams
  const supabase = await lagSupabaseServerKlient()

  // SAMME STASJONSVALG SOM «Maaneden». Skallet husker valget; sida leser
  // det paa noeyaktig samme maate, ellers kan de to fanene skille lag
  // igjen uten at noe sier fra.
  const { data: stasjonsrader } = await supabase
    .from('stasjoner')
    .select('id, navn, butikknummer')
    .is('slettet_tid', null)
    .order('butikknummer')
    .limit(200)
    .overrideTypes<{ id: string; navn: string; butikknummer: string }[]>()
  const stasjonsliste = stasjonsrader ?? []
  const sok = new URLSearchParams()
  if (sp.stasjon) sok.set('stasjon', sp.stasjon)
  const valgtStasjon = await husketStasjon(
    stasjonsliste,
    stasjonFraUrl(sok, stasjonsliste),
    tillatAlleFor('/min-plan', bruker.rolle, stasjonsliste.length),
  )
  const navnFor = new Map(stasjonsliste.map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))
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
    .eq('stasjon_id', valgtStasjon ?? '')   // innsnevring, aldri utvidelse
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
        merke={valgtStasjon ? navnFor.get(valgtStasjon) : undefined}
        undertittel={
          nyeste
            ? `Siste: ${maanedsnavn(nyeste.maaned)} ${nyeste.maaned.slice(0, 4)}`
            : 'Ingen plan ennå'
        }
      />

      {planer.length === 0 && (
        <Tomtilstand
          // STASJONEN STAAR I OVERSKRIFTEN, OG DET ER IKKE PYNT.
          //
          // `omfangsfasit.json` bar en skrevet begrunnelse for at
          // spoerringen IKKE filtrerte paa stasjon: «et filter i UI-et
          // ville skjult den ene planen hun faktisk hadde, og en
          // manglende plan ser likedan ut som en plan som ikke er
          // sluppet».
          //
          // Den innvendingen er ekte for en butikksjef med FLERE
          // stasjoner. Den er besvart her, ikke ignorert: tomtilstanden
          // navngir stasjonen, saa «ingen plan» aldri kan leses som
          // «ingen plan noe sted». Velgeren i toppen er veien til de
          // andre.
          tittel={`Ingen månedsplan for ${valgtStasjon ? navnFor.get(valgtStasjon) : 'stasjonen'}`}
          forklaring={
            'Planen skrives når regnskapet importeres, og blir synlig her '
            + 'når eier har lest den og sluppet den. Den trenger minst tre '
            + 'måneder med tall før retningen betyr noe. Har du flere '
            + 'stasjoner, bytt stasjon i toppen for å se deres planer.'
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
