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
import { lesMatkast } from '@/lib/kurs/snapshot'
import { matkastvisning } from '@/lib/kurs/analysevisning'
import type { Punkt } from '../maanedsplan/plankort'
import { maanedsstatus, naavaerendeFase, reisen, type Fase } from './reise'

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
  // FELTENE «VIS GRUNNLAGET» VISER
  //
  // Lista bygges ÉN gang og brukes to steder: radene i grunnlaget, og
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
  const avlagt = bilde.dekning.regnskap

  // ===================================================================
  // MATKAST — KUN FOR MÅNEDEN PLANEN FAKTISK GJELDER
  // ===================================================================
  //
  // Analysen er et FROSSET øyeblikksbilde på den sluppede månedsplanen
  // (`0216`), regnet av `kastvurdering.ts` med sine ni porter. Den hører
  // til planens måned, ikke til måneden som står i velgeren.
  //
  // Viste vi juli-planens matkast på september, ville et tall fra en
  // ferdig måned stått blant septembers egne — den farligste formen i
  // dette systemet. Derfor `planForMaaneden`, ikke `plan`.
  const matkast = planForMaaneden
    ? matkastvisning(lesMatkast(planForMaaneden.matkast))
    : null
  const kastrad = (navn: string) =>
    (matkast && 'rader' in matkast ? matkast.rader.find((r) => r.navn === navn) : undefined)

  // ===================================================================
  // «IKKE KLART ENNÅ» — FELTENE SOM MANGLER, MED SIN EGEN GRUNN
  // ===================================================================
  //
  // TEKSTEN ER `bilde.ts` SIN, IKKE SIDAS. Hvert `Felt` bærer `grunn`
  // når det mangler — «Royalty leses av regnskapet. Ingen tidlig kilde.»
  // Å skrive en egen setning her, som «lønnsfila kommer dagen etter
  // måneden», ville vært en påstand ingen kontrakt eier.
  //
  // SEKUNDÆRT OG KOMPAKT. En pågående måned skal ikke organiseres rundt
  // hva Sentiqa mangler. Mangelen er en sannhet, ikke hovedhistorien.
  const ikkeKlart = rader.filter((r) => r.felt.kilde === 'mangler')

  return (
    <Sideramme>
      <Sidehode
        tittel="Måneden"
        merke={stasjonsnavn}
        undertittel={`${manedAar.format(new Date(tilIso(maaned)))} · ${maanedsstatus(bilde)}`}
        handlinger={
          <Maanedsvelger
            maaneder={tilgjengelige.map(tilIso)}
            valgt={tilIso(maaned)}
            skjulte={{ stasjon: sp.stasjon }}
            knapp="Vis måneden"
          />
        }
      />

      {/* ===================================================================
          NIVÅ 1 — HVOR STOR VAR MÅNEDEN

          Omsetning og brutto står UTEN dom. Ingen motor eier en
          sammenligning for dem: `mot-budsjett.ts` kan regelen, men
          `bilde.ts` har ikke noe budsjettfelt, og brutto har ingen
          budsjettkolonne noe sted. En pil uten et budsjett bak ville
          vært flatens egen mening.
          =================================================================== */}
      <h2 className="sq-mm-bolk">{avlagt ? 'Dette ble måneden' : 'Dette vet vi så langt'}</h2>
      <div className="sq-mm-hovedtall">
        <Hovedtall navn="Omsetning" felt={bilde.omsetning} avlagt={avlagt} />
        <Hovedtall navn="Bruttofortjeneste" felt={bilde.brutto} avlagt={avlagt} />
        {!avlagt && (
          <Hovedtall navn="Lønnsrom så langt" felt={bilde.lonnsrom} avlagt={avlagt} />
        )}
      </div>

      {/* ===================================================================
          NIVÅ 2 — HVORDAN GIKK DEN

          Bare de to feltene som HAR en dom fra en motor: lønna mot
          rommet (`styringsavvik`) og matkastet mot det omsetnings-
          justerte kastbudsjettet (`kastvurdering`). De skal se
          annerledes ut enn tallene over, fordi de sier noe tallene over
          ikke sier.
          =================================================================== */}
      {(avlagt || matkast !== null) && (
        <>
          <h2 className="sq-mm-bolk">Hvordan gikk det</h2>
          <div className="sq-mm-hovedtall">
            {avlagt && (
              <div className={`sq-mm-tall${avvik.kroner === null ? ''
                : avvik.kroner <= 0 ? ' sq-mm-god' : ' sq-mm-darlig'}`}>
                <span className="sq-mm-tall-navn">Lønn mot rommet</span>
                <span className="sq-mm-tall-verdi">
                  {bilde.styringskost.verdi === null
                    ? '—' : kr.format(Math.round(bilde.styringskost.verdi))}
                </span>
                {/* DOMMEN ER `styringsavvik()` SIN. Ordet «innenfor» og
                    «over» følger fortegnet den satte; flaten snur det
                    ikke og finner ikke på en terskel. */}
                <span className="sq-mm-tall-dom">
                  {avvik.kroner === null
                    ? (avvik.mangler ?? '')
                    : `${kr.format(Math.abs(Math.round(avvik.kroner)))} kr `
                      + `${avvik.kroner <= 0 ? 'innenfor' : 'over'} lønnsrommet`}
                </span>
                {bilde.styringsavvik.kilde !== 'fasit' && (
                  <Kildemerke kilde={bilde.styringsavvik.kilde} />
                )}
              </div>
            )}

            {matkast !== null && 'rader' in matkast && (
              <div className={`sq-mm-tall${
                matkast.slag === 'tiltak' ? ' sq-mm-darlig'
                  : matkast.slag === 'bekreftelse' ? ' sq-mm-god' : ''}`}>
                <span className="sq-mm-tall-navn">Matkast</span>
                <span className="sq-mm-tall-verdi">{kastrad('Kastprosent')?.verdi ?? '—'}</span>
                {/* AVVIKET ER `kasttall()` SITT, i prosentpoeng og kroner.
                    `bi` bærer allerede ordet «bedre enn» eller «over». */}
                <span className="sq-mm-tall-dom">
                  {kastrad('Avvik')?.verdi} · {kastrad('Avvik')?.bi}
                </span>
              </div>
            )}

            {matkast !== null && !('rader' in matkast) && (
              <div className="sq-mm-tall">
                <span className="sq-mm-tall-navn">Matkast</span>
                <span className="sq-mm-tall-verdi">—</span>
                {/* BLOKKERT ER IKKE NULL. `gate()` sier hvorfor, og
                    årsaken vises i stedet for et tall. */}
                <span className="sq-mm-tall-dom">{matkast.tekst}</span>
              </div>
            )}
          </div>
        </>
      )}

      {/* ===================================================================
          NIVÅ 3 — HVA KREVER OPPMERKSOMHET

          `vite.ts` eier både hva som sies og rekkefølgen. Rendres ikke
          når lista er tom: en måned der alt er i orden skal ikke ha en
          overskrift som lover at noe er galt.
          =================================================================== */}
      <HvaBoerJegVite bilde={bilde} tittel="Dette bør du vite" />

      {/* ===================================================================
          NIVÅ 4 — HVA BØR JEG GJØRE

          KORT OPPSUMMERING, IKKE PLANEN PÅ NYTT. Hele `Planlesing` bor
          på fanen «Planen». To flater som tegner samme kort er to
          sannheter, og forskjellen viser seg først i et møte.
          =================================================================== */}
      <section className="sq-mm-handling">
        <h2>Dette bør du gjøre</h2>

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
        ) : planErEnAnnenMaaned ? (
          // ===============================================================
          // EN PLAN FRA EN ANNEN MÅNED VISES IKKE SOM ET TILTAK HER
          // ===============================================================
          //
          // Bare at den finnes, og veien dit. Sto juli-tiltaket i
          // klartekst under septembertall, ville det sett ut som et
          // septembertiltak — og ingenting på skjermen ville sagt at de
          // to måler ulike perioder.
          <p className="sq-mm-annen-plan">
            Siste sluppede plan er fra {manedAar.format(new Date(plan.maaned))}.
            {' '}
            <Link href="/min-plan">Se planen</Link>
          </p>
        ) : (
          <div className="sq-mm-tiltak">
            <span className={`sq-dom sq-dom-${plan.dom}`}>{DOMORD[plan.dom]}</span>
            {tiltaket(plan.punkter) ? (
              <>
                <p className="sq-mm-tiltak-tittel">{tiltaket(plan.punkter)!.tittel}</p>
                <p className="sq-mm-tiltak-tekst">{tiltaket(plan.punkter)!.tekst}</p>
              </>
            ) : (
              <p className="sq-mm-tiltak-tekst">{plan.ingress}</p>
            )}
            <p className="undertittel"><Link href="/min-plan">Se hele planen</Link></p>
          </div>
        )}
      </section>

      {/* ===================================================================
          IKKE KLART ENNÅ — SEKUNDÆRT OG KOMPAKT

          Står NEDERST og som én linje. En pågående måned skal ikke
          organiseres rundt hva Sentiqa mangler; mangelen er en sannhet,
          ikke hovedhistorien. Hver grunn er feltets egen.
          =================================================================== */}
      {!avlagt && ikkeKlart.length > 0 && (
        <section className="sq-mm-ikke-klart">
          <h2>Ikke klart ennå</h2>
          <dl>
            {ikkeKlart.map((r) => (
              <div key={r.navn}>
                <dt>{r.navn}</dt>
                <dd>{r.felt.grunn ?? ''}</dd>
              </div>
            ))}
          </dl>
        </section>
      )}

      {/* ===================================================================
          VIS GRUNNLAGET — HELE SPORBARHETEN, ETT NIVÅ NED

          Ingenting av sannheten forsvinner. PLAN → PROGNOSE → FASIT,
          kilde, grunnlag, royalty, påvirkbare kostnader, BP-lønn og hele
          lønnskosten står her, for den som ber om beviset.
          =================================================================== */}
      <Forklaring sporsmaal="Vis grunnlaget">
        <Reisestripe faser={faser} naa={naa} />

        <Datatabell tittel="Hvert tall, med kilden sin">
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
            <tr>
              <th scope="row">Styringsavvik</th>
              <td className="tall">
                {avvik.kroner === null ? '—' : kr.format(Math.round(avvik.kroner))}
              </td>
              <td><Kildemerke kilde={bilde.styringsavvik.kilde} /></td>
              <td className="undertittel">{avvik.mangler ?? ''}</td>
            </tr>
          </tbody>
        </Datatabell>

        <p>
          Et tall er <strong>fasit</strong> når regnskapet har ført det,{' '}
          <strong>prognose</strong> når det er anslått av tidlige tall som kan
          flytte seg, og <strong>plan</strong> når det er hva budsjettet sa —
          ikke et anslag på hva som faktisk skjer. <strong>Mangler</strong>{' '}
          betyr at tallet ikke finnes ennå; det er aldri det samme som null
          kroner. <strong>Skjult</strong> er heller ikke et hull: tallet finnes,
          men hører ikke til din rolle.
        </p>
        <p>
          Et avledet tall arver den svakeste av kildene det bygger på. Et
          styringsavvik regnet av et anslått lønnsrom er et anslag, uansett hvor
          sikkert lønnstallet er.
        </p>
      </Forklaring>
    </Sideramme>
  )
}

const DOMORD = { medvind: 'Medvind', motvind: 'Motvind', flat: 'Flatt' } as const

/**
 * Det ene tiltaket i planen, når det finnes.
 *
 * `plan.ts` gir høyst ett — «ÉN ting. Den største.» Bekreftelser er ikke
 * noe å gjøre, og hører ikke under denne overskriften.
 */
function tiltaket(punkter: Punkt[]): Punkt | undefined {
  return punkter.find((p) => p.slag === 'tiltak')
}

/**
 * Ett stort tall.
 *
 * KILDEMERKET STÅR BARE NÅR TALLET IKKE ER FASIT. En avlagt måned der
 * hvert eneste merke sier «Fasit» lærer leseren å se forbi dem alle — og
 * da er merket borte den dagen et tall faktisk er anslått. Samme regel
 * som `kilde.tsx` alt skriver om fargen: fasit er normaltilstanden.
 *
 * `null` blir en tankestrek. Et manglende tall og null kroner er ikke det
 * samme, og en null der det egentlig mangler er den slags feil som ser
 * rolig ut på en storskjerm.
 */
function Hovedtall({ navn, felt, avlagt }: { navn: string; felt: Felt; avlagt: boolean }) {
  return (
    <div className="sq-mm-tall">
      <span className="sq-mm-tall-navn">{navn}</span>
      <span className="sq-mm-tall-verdi">
        {felt.verdi === null ? '—' : kr.format(Math.round(felt.verdi))}
      </span>
      {felt.kilde !== 'fasit' && <Kildemerke kilde={felt.kilde} />}
      {!avlagt && felt.verdi !== null && (
        <span className="sq-mm-tall-dom">så langt i måneden</span>
      )}
    </div>
  )
}

/**
 * PLAN -> PROGNOSE -> FASIT.
 *
 * TEGNER `reisen()` SITT SVAR. Den regner ingenting selv; hvert steg har
 * alt fått sin tilstand av en avlesning i `reise.ts`.
 *
 * LIGGER UNDER «Vis grunnlaget». Stripa svarer på «kan jeg stole på
 * tallet», og det er ikke spørsmålet den som åpner siden har.
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
