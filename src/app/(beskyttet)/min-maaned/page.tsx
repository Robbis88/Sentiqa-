import Link from 'next/link'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { kr, manedAar } from '@/lib/format'
import { Sidehode, Tomtilstand, Feiltilstand, Datatabell, Forklaring } from '@/components/ui/side'
import { Sideramme } from '@/components/ui/sideramme'
import { Kildemerke } from '@/components/ui/kilde'
import { HvaBoerJegVite, Tallrad } from '@/components/ui/okonomi'
import { Maanedsvelger } from '@/components/ui/periode'
import { husketStasjon } from '@/lib/stasjonskontekst'
import { stasjonFraUrl, tillatAlleFor } from '@/lib/stasjonsvalg'
import { maaVaereHele } from '@/lib/supabase/datobolker'
import { lesMaaned, type Maaned } from '@/lib/periode'
import type { Felt } from '@/lib/okonomi/bilde'
import {
  byggMaanedsbilde, hentBildegrunnlag, maanederMedBilde, standardmaaned,
} from '@/lib/okonomi/sammenstill'
import { Planlesing } from '../min-plan/planlesing'
import type { Punkt } from '../maanedsplan/plankort'
import { naavaerendeFase, reisen, type Fase } from './reise'

// =====================================================================
// MIN MÅNED
// =====================================================================
//
// «Dette er måneden din. Dette vet vi. Dette er prognosen. Dette er
// fasiten. Dette bør du gjøre.»
//
// Sentiqa har tallene fra før. Det den ikke har hatt, er ett sted der de
// står i den rekkefølgen et menneske spør om dem. /regnskap svarer på én
// måned om gangen og i kontoer, /lonnskost på lønnsrommet, /svinn på
// svinnet, /min-plan på tiltaket. Fire riktige svar på fire spørsmål
// ingen stilte i den formen.
//
// ---------------------------------------------------------------------
// SIDA REGNER INGENTING, OG DEN DØMMER INGENTING
// ---------------------------------------------------------------------
//
// Hvert tall kommer fra `byggOkonomibilde` med kilden sin (lov 3), og
// hver beskjed kommer fra `hvaBoerJegViteNaa`. Sammenstillingen er delt
// med /lonnskost — `okonomi/sammenstill.ts` — nettopp fordi to flater
// som setter sammen det samme bildet hver for seg er to meninger om når
// et tall er fasit.
//
// HANDLINGENE ER IKKE SIDAS EGNE. Nederst står månedsplanen slik eieren
// slapp den, gjennom den samme komponenten butikksjefen leser den med på
// /min-plan. Et tiltak som SER bra ut i en demo, men som systemet ikke
// eier, er ikke et tiltak — det er en påstand om at noen har tenkt på
// det.
//
// ---------------------------------------------------------------------
// HVA SOM IKKE STÅR HER, OG HVORFOR
// ---------------------------------------------------------------------
//
//   SVINN som eget kildemerket tall. `bilde.ts` har ingen `svinn`-Felt,
//   og å sette en `Kilde` her ville vært en andre myndighet på hvor
//   sikkert et tall er — det E3 ble bygget for å hindre. Svinnet står
//   likevel: det bærer lønnsrommet (`ekstraSvinnKr`, forklart i radens
//   grunnlag), og det står som tall i månedsplanens egen analyseblokk,
//   der det er en godkjent, datert vurdering.
//
//   RESULTAT. Krever `brutto − royalty − lønn − drift − faste`, altså
//   domenearitmetikk som ingen motor eier ennå (E10).
// =====================================================================

export const metadata = { title: 'Min måned · Sentiqa' }

type Sok = { stasjon?: string; maned?: string; ar?: string }

/** Tretten måneder: nok til å se samme måned i fjor. Som /lonnskost. */
const FRA = new Date(Date.UTC(new Date().getUTCFullYear(), new Date().getUTCMonth() - 12, 1))
  .toISOString().slice(0, 10)

/**
 * Et TAK, ikke et ønske.
 *
 * Én plan per stasjon og måned (`maanedsplan_unik`), og vinduet er
 * tretten måneder. 60 er romslig nok til at et lovlig svar aldri treffer
 * det, og lavt nok til at `maaVaereHele` faktisk kan kaste.
 */
const TAK_PLANER = 60

/** Samme slags tak, for stasjonslista. Se kommentaren ved spørringen. */
const TAK_STASJONER = 200

type Planrad = {
  id: string
  maaned: string
  dom: 'medvind' | 'motvind' | 'flat'
  ingress: string
  punkter: Punkt[]
  merknad: string | null
  matkast: unknown
  usynlig: unknown
  rangering: unknown
}

/** `yyyy-mm` -> `yyyy-mm-01`, formen `Maanedsvelger` og `lesMaaned` bruker. */
const tilIso = (m: string): Maaned => `${m}-01`

export default async function MinMaanedSide({ searchParams }: { searchParams: Promise<Sok> }) {
  const bruker = await hentInnloggetBruker()
  // ROLLEPORTEN ER DEN SAMME SOM /lonnskost.
  //
  // `erLeder` slipper inn eier og butikksjef. Nettbrettet og
  // plattformredaktøren skal ikke se økonomi i det hele tatt, og de skal
  // ikke komme hit via en lenke heller. RLS er den egentlige muren —
  // denne porten er laget over, og den finnes for at siden ikke skal
  // tegne et tomt skall for noen som aldri skulle vært her.
  if (!erLeder(bruker.rolle)) {
    return <Sideramme><p>Du har ikke tilgang til Min måned.</p></Sideramme>
  }

  const sp = await searchParams
  const supabase = await lagSupabaseServerKlient()

  // STASJONSLISTA MÅ VÆRE HEL.
  //
  // En avkortet liste ser ut som en kjede med færre stasjoner — og den
  // som mangler, mangler også i velgeren. Da tegner siden en annen
  // stasjons måned uten at noe sier fra. Samme felle som 0090, 0166 og
  // 0175, ett hakk lenger opp.
  //
  // 200 er romslig for en kjede og godt under `max_rows = 1000`, så
  // `maaVaereHele` faktisk kan utløses.
  const stasjonssvar = await supabase
    .from('stasjoner')
    .select('id, navn, butikknummer')
    .is('slettet_tid', null)
    .order('butikknummer')
    .limit(TAK_STASJONER)
    .overrideTypes<{ id: string; navn: string; butikknummer: string }[]>()

  let stasjonsliste: { id: string; navn: string; butikknummer: string }[]
  try {
    stasjonsliste = maaVaereHele(stasjonssvar, 'stasjonene', TAK_STASJONER)
  } catch (e) {
    return (
      <Sideramme>
        <Sidehode tittel="Min måned" />
        <Feiltilstand
          tittel="Stasjonene kunne ikke hentes"
          detalj={e instanceof Error ? e.message : String(e)}
          forklaring={
            'Uten stasjonslista vet ikke siden hvilken måned den skal vise. '
            + 'Den viser derfor ingenting heller enn en vilkårlig stasjon.'
          }
        />
      </Sideramme>
    )
  }
  const sok = new URLSearchParams()
  if (sp.stasjon) sok.set('stasjon', sp.stasjon)
  // INGEN «ALLE STASJONER». Lønnsrommet og månedsplanen er én stasjons
  // ansvar, og en kjedesum ville vært et tall ingen kan gjøre noe med.
  //
  // SPØR OM SIN EGEN RUTE. Her sto `/lonnskost` — samme svar i dag,
  // siden ingen av dem står i `TAALER_AGGREGAT` og standarden er «krever
  // én stasjon». Men et svar som gjelder naboens skjerm er riktig ved et
  // uhell, og slutter å være det i det øyeblikket noen tar stilling til
  // /lonnskost. `stasjonsvakt.test.ts` felte det.
  const tillatAlle = tillatAlleFor('/min-maaned', bruker.rolle, stasjonsliste.length)
  const valgtStasjon = await husketStasjon(
    stasjonsliste, stasjonFraUrl(sok, stasjonsliste), tillatAlle,
  )
  const navnFor = new Map(stasjonsliste.map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))
  const erStasjon = valgtStasjon != null && navnFor.has(valgtStasjon)

  if (!erStasjon) {
    return (
      <Sideramme>
        <Sidehode tittel="Min måned" />
        <Tomtilstand
          tittel="Velg en stasjon"
          forklaring={
            'Måneden hører til én stasjon. Lønnsrommet, planen og tiltakene '
            + 'er stasjonens ansvar, og en sum over kjeden ville vært et tall '
            + 'ingen har ansvar for.'
          }
        />
      </Sideramme>
    )
  }

  const stasjonsnavn = navnFor.get(valgtStasjon!)!

  // EN FEILET SPØRRING SKAL ROPE, IKKE BLI TOM.
  //
  // `hentBildegrunnlag` kaster på feil og på avkorting. Svelget vi det,
  // ville siden tegnet «ingen tall ennå» — en rolig, riktig-utseende
  // beskjed om at måneden ikke er begynt, mens sannheten er at spørringen
  // ikke nådde fram.
  let grunnlag: Awaited<ReturnType<typeof hentBildegrunnlag>>
  try {
    grunnlag = await hentBildegrunnlag(supabase, valgtStasjon!, FRA)
  } catch (e) {
    return (
      <Sideramme>
        <Sidehode tittel="Min måned" merke={stasjonsnavn} />
        <Feiltilstand
          tittel="Tallene kunne ikke hentes"
          detalj={e instanceof Error ? e.message : String(e)}
          forklaring={
            'Dette er ikke det samme som at måneden er tom. Spørringen nådde '
            + 'ikke fram, og siden viser derfor ingenting heller enn nuller '
            + 'som ser riktige ut. Prøv igjen, og si fra om den blir stående.'
          }
        />
      </Sideramme>
    )
  }

  const tilgjengelige = maanederMedBilde(grunnlag)
  const standard = standardmaaned(grunnlag)

  if (!standard) {
    return (
      <Sideramme>
        <Sidehode tittel="Min måned" merke={stasjonsnavn} />
        <Tomtilstand
          tittel="Ingen måned å vise ennå"
          forklaring={
            'Verken BP-budsjett eller avlagt regnskap er lastet inn for denne '
            + 'stasjonen, og uten en av delene finnes det ingen ramme å måle '
            + 'måneden mot. Last opp BP-en og regnskapsrapporten under Import.'
          }
        />
      </Sideramme>
    )
  }

  // MÅNEDEN FRA URL-EN, MEN BARE EN SOM FINNES.
  //
  // `lesMaaned` godtar hva som helst gyldig-formet; kilden bestemmer hva
  // som faktisk finnes. En måned utenfor lista ville gitt et tomt bilde
  // som så ut som en stasjon uten tall.
  const onsket = lesMaaned(sp, tilIso(standard)).slice(0, 7)
  const maaned = tilgjengelige.includes(onsket) ? onsket : standard

  const valgt = byggMaanedsbilde(grunnlag, {
    maaned, rolle: bruker.rolle, naa: new Date(),
  })

  if (!valgt) {
    return (
      <Sideramme>
        <Sidehode tittel="Min måned" merke={stasjonsnavn} />
        <Tomtilstand
          tittel={`Ingen ramme for ${manedAar.format(new Date(tilIso(maaned)))}`}
          forklaring={
            'Måneden har hverken brutto eller BP, så det finnes ikke noe '
            + 'lønnsrom å vise. Velg en annen måned.'
          }
        />
      </Sideramme>
    )
  }

  const { bilde } = valgt

  // PLANEN FOR STASJONEN, SLIK EIEREN SLAPP DEN.
  //
  // BARE `sluppet` OG `sendt`. Et utkast er eierens forslag til seg selv;
  // ser butikksjefen det, er godkjenningen meningsløs. Filteret her er
  // det samme RLS håndhever i `0200` — det står begge steder med vilje.
  const plansvar = await supabase
    .from('maanedsplan')
    .select('id, maaned, dom, ingress, punkter, merknad, matkast, usynlig, rangering')
    .eq('stasjon_id', valgtStasjon!)
    .in('status', ['sluppet', 'sendt'])
    .order('maaned', { ascending: false })
    .limit(TAK_PLANER)
    .overrideTypes<Planrad[]>()

  let planer: Planrad[] = []
  let planfeil: string | null = null
  try {
    planer = maaVaereHele(plansvar, 'månedsplanene', TAK_PLANER)
  } catch (e) {
    planfeil = e instanceof Error ? e.message : String(e)
  }

  // SAMME MÅNED FØRST. Finnes den ikke, står den nyeste — med sin egen
  // måned skrevet på seg. To tall som ser sammenlignbare ut og ikke er
  // det, er den farligste formen i dette systemet, og en plan fra juli
  // ved siden av septembertall er nettopp det.
  const planForMaaneden = planer.find((p) => p.maaned.slice(0, 7) === maaned)
  const plan = planForMaaneden ?? planer[0] ?? null
  const planErEnAnnenMaaned = plan !== null && plan.maaned.slice(0, 7) !== maaned

  // ===================================================================
  // FELTENE FLATEN VISER
  //
  // Lista bygges ÉN gang og brukes to steder: radene under, og
  // `reisen()`, som spør om noen av dem er et anslag. Skrev vi den opp
  // to ganger, kunne stripa sagt «prognose» om et felt tabellen ikke
  // viste — eller tie om ett den viste.
  // ===================================================================
  const rader: { navn: string; felt: Felt }[] = [
    { navn: 'Omsetning', felt: bilde.omsetning },
    { navn: 'Bruttofortjeneste', felt: bilde.brutto },
    { navn: 'Lønnsrom', felt: bilde.lonnsrom },
    // LØNN MOT BUDSJETT, IKKE HELE LØNNSKOSTEN. Rommet er regnet av
    // BP-lønn (fem konti); holdt vi ni mot det, ville sykelønn spist av
    // et rom som aldri var satt av til den.
    { navn: 'Lønn mot budsjett', felt: bilde.styringskost },
    { navn: 'Hele lønnskosten', felt: bilde.lonn },
    { navn: 'Lønnsbudsjett (BP)', felt: bilde.bpLonn },
    { navn: 'Påvirkbare driftskostnader', felt: bilde.paavirkbarDrift },
    { navn: 'Royalty', felt: bilde.royalty },
  ]

  const faser = reisen(bilde, rader.map((r) => r.felt))
  const naa = naavaerendeFase(faser)
  const avvik = bilde.styringsavvik.avvik

  return (
    <Sideramme>
      <Sidehode
        tittel="Min måned"
        merke={stasjonsnavn}
        undertittel={
          naa
            ? `${manedAar.format(new Date(tilIso(maaned)))} · ${naa.forklaring}`
            : manedAar.format(new Date(tilIso(maaned)))
        }
        handlinger={
          <Maanedsvelger
            maaneder={tilgjengelige.map(tilIso)}
            valgt={tilIso(maaned)}
            skjulte={{ stasjon: sp.stasjon }}
            knapp="Vis måneden"
          />
        }
      />

      {/* --- 1. HVOR STÅR MÅNEDEN NÅ? ------------------------------- */}
      <Reisestripe faser={faser} naa={naa} />

      <div className="sq-mm-hovedtall">
        <Hovedtall navn="Bruttofortjeneste" felt={bilde.brutto} />
        <Hovedtall navn="Lønnsrom" felt={bilde.lonnsrom} />
        <div className="sq-mm-tall">
          <span className="sq-mm-tall-navn">Styringsavvik</span>
          <span className="sq-mm-tall-verdi">
            {avvik.kroner === null ? '—' : kr.format(Math.round(avvik.kroner))}
          </span>
          {/* KILDEN FØLGER MED, OGSÅ HER. `Avviksfelt` bærer sin egen —
              lov 2: den svakeste av rommets og lønnas. */}
          <Kildemerke kilde={bilde.styringsavvik.kilde} />
          <span className="sq-mm-tall-grunn">
            {avvik.mangler ?? 'Over rommet er positivt. Innenfor er negativt.'}
          </span>
        </div>
      </div>

      {/* --- 2. HVA BEVEGER RESULTATET? ------------------------------ */}
      <Datatabell tittel="Hva beveger resultatet?">
        <thead>
          <tr>
            <th>Post</th>
            <th className="tall">Kroner</th>
            <th>Kilde</th>
            <th>Grunnlag</th>
          </tr>
        </thead>
        <tbody>
          {rader.map((r) => <Tallrad key={r.navn} navn={r.navn} felt={r.felt} />)}
        </tbody>
      </Datatabell>

      <Forklaring sporsmaal="Hvorfor står det «Prognose» på noen av tallene?">
        <p>
          Et tall er <strong>fasit</strong> når regnskapet har ført det,{' '}
          <strong>prognose</strong> når det er anslått av tidlige tall som kan
          flytte seg, og <strong>plan</strong> når det er hva budsjettet sa —
          ikke et anslag på hva som faktisk skjer. <strong>Mangler</strong>{' '}
          betyr at tallet ikke finnes ennå; det er aldri det samme som null
          kroner.
        </p>
        <p>
          Et avledet tall arver den svakeste av kildene det bygger på. Et
          styringsavvik regnet av et anslått lønnsrom er et anslag, uansett hvor
          sikkert lønnstallet er.
        </p>
        <p>
          <strong>Skjult</strong> er ikke et hull. Tallet finnes, men hører ikke
          til din rolle — royalty er en kjedeavtale eieren forhandler.
        </p>
      </Forklaring>

      {/* --- 3. HVA BØR JEG VITE? ------------------------------------
          Rendres ikke når lista er tom. En overskrift som alltid står
          lover at noe er galt, og da leses den ikke den dagen det er
          det. Rekkefølgen er `vite.ts` sin. */}
      <HvaBoerJegVite bilde={bilde} />

      {/* --- 4. HVA BØR JEG GJØRE NÅ? ------------------------------- */}
      <section className="sq-mm-handling">
        <h2>Hva bør jeg gjøre nå?</h2>

        {planfeil !== null ? (
          <Feiltilstand
            tittel="Planen kunne ikke hentes"
            detalj={planfeil}
            forklaring={
              'Dette betyr ikke at du ikke har en plan. Siden viser ingenting '
              + 'heller enn en tom liste som ser riktig ut.'
            }
          />
        ) : plan === null ? (
          <Tomtilstand
            tittel="Ingen sluppet månedsplan for denne stasjonen"
            forklaring={
              'Månedsplanen skrives når regnskapet er importert, og eieren tar '
              + 'stilling til den før den slippes. Sentiqa finner ikke på et '
              + 'tiltak i mellomtiden — et råd ingen har godkjent er ikke et '
              + 'råd.'
            }
          />
        ) : (
          <>
            {planErEnAnnenMaaned && (
              <p className="undertittel">
                Den nyeste sluppede planen gjelder{' '}
                {manedAar.format(new Date(plan.maaned))}, ikke{' '}
                {manedAar.format(new Date(tilIso(maaned)))}. Tallene over og
                tiltaket under måler altså ikke samme periode.
              </p>
            )}
            <Planlesing
              stasjon={stasjonsnavn}
              maaned={plan.maaned}
              dom={plan.dom}
              ingress={plan.ingress}
              punkter={plan.punkter}
              merknad={plan.merknad}
              matkast={plan.matkast}
              usynlig={plan.usynlig}
              rangering={plan.rangering}
            />
            <p className="undertittel">
              <Link href="/min-plan">Se alle månedsplanene dine</Link>
            </p>
          </>
        )}
      </section>
    </Sideramme>
  )
}

/**
 * Ett stort tall, med kilden ved siden av.
 *
 * `null` blir en tankestrek. Et manglende tall og null kroner er ikke det
 * samme, og en null der det egentlig mangler er den slags feil som ser
 * rolig ut på en storskjerm.
 */
function Hovedtall({ navn, felt }: { navn: string; felt: Felt }) {
  return (
    <div className="sq-mm-tall">
      <span className="sq-mm-tall-navn">{navn}</span>
      <span className="sq-mm-tall-verdi">
        {felt.verdi === null ? '—' : kr.format(Math.round(felt.verdi))}
      </span>
      <Kildemerke kilde={felt.kilde} />
      <span className="sq-mm-tall-grunn">{felt.grunn ?? ''}</span>
    </div>
  )
}

/**
 * PLAN -> PROGNOSE -> FASIT.
 *
 * TEGNER `reisen()` SITT SVAR. Den regner ingenting selv; hvert steg har
 * alt fått sin tilstand av en avlesning i `reise.ts`.
 */
function Reisestripe({ faser, naa }: { faser: Fase[]; naa: Fase | null }) {
  return (
    <ol className="sq-reise" aria-label="Hvor måneden står">
      {faser.map((f) => (
        <li
          key={f.id}
          className={`sq-reise-steg sq-reise-${f.tilstand}${
            naa?.id === f.id ? ' sq-reise-naa' : ''}`}
          aria-current={naa?.id === f.id ? 'step' : undefined}
        >
          <span className="sq-reise-tittel">{f.tittel}</span>
          <span className="sq-reise-forklaring">{f.forklaring}</span>
        </li>
      ))}
    </ol>
  )
}
