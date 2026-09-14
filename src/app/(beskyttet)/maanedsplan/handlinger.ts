'use server'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { kvitter, type Kvittering } from '@/lib/kvittering'
import {
  nyesteKompletteMaaned, regenererMaaned, regenereringsnotat, validerMaaned,
} from '@/lib/kurs/regenerer'

// =====================================================================
// Å slippe en månedsplan.
//
// Systemet skriver utkastet; eieren slipper det. Det er hele
// godkjenningsflyten, og den er ikke en formalitet: butikksjefens
// lesepolicy i 0200 krever `status in ('sluppet','sendt')`, så et utkast
// er usynlig for henne til noen har tatt stilling.
//
// ---------------------------------------------------------------------
// HVORFOR SERVERKLIENTEN OG IKKE ADMINNØKKELEN
//
// Skrivingen går gjennom den vanlige serverklienten, så RLS avgjør om
// planen er din. Er den ikke det, treffer oppdateringen null rader og
// handlingen sier «fant ikke planen» — ikke fordi vi sjekket, men fordi
// den ikke finnes for deg.
//
// En adminnøkkel her ville gjort rollesjekken til den eneste grensen, og
// en glemt sjekk ville sluppet en plan i en annen kjede.
//
// ---------------------------------------------------------------------
// INNHOLDET LÅSES AV EN TRIGGER, IKKE AV DENNE FILA
//
// `maanedsplan_laas_sluppet` (0200) hindrer at en sluppet plan skrives
// om — også av importen, som kjører med tjenestenøkkelen og aldri ser en
// policy. En regel som bare finnes her ville ikke gjeldt den som faktisk
// skriver mest.
// =====================================================================

// =====================================================================
// INGEN AV DE TRE REVALIDERER NOE SOM HELST
// =====================================================================
//
// `useActionState` holder `venter` sann gjennom hele overgangen, og en
// ruteroppdatering inne i den overgangen gjoer kvitteringen til gissel
// for at sida skal tegne seg om - maalt til 45 sekunder paa /stempling
// der serveren svarte paa 190 ms.
//
// ---------------------------------------------------------------------
// DET HOLDT IKKE AA FJERNE REVALIDERINGEN AV EGEN RUTE
// ---------------------------------------------------------------------
//
// #281 fjernet `revalidatePath('/maanedsplan')` og beholdt
// `revalidatePath('/min-plan')`, med begrunnelsen at en ANNEN rute er
// ufarlig. Det var feil, og det ble maalt paa `main` 2026-09-14:
//
//   0,95 s   POST /maanedsplan  (next-action)
//   1,45 s   200, **x-action-revalidated: 1**
//   2,14 s   siste nettverkshendelse i hele sporet
//   20,99 s  timeout - knappen fortsatt «Bygger …», ingen kvittering
//
// Next setter `x-action-revalidated: 1` og sender en fersk
// flight-payload for ruta du STAAR PAA saa snart handlingen revaliderer
// NOE SOM HELST - `revalidatePath`-doksene sier det rett ut: «This will
// purge the Client Cache». Ruteroppdateringen av `/maanedsplan` ble
// dermed en del av handlingens egen overgang igjen, samtidig med
// `router.refresh()` fra klienten. To ruteroppdateringer i én overgang,
// og naar de fletter seg feil committer React aldri.
//
// ---------------------------------------------------------------------
// HVORFOR DET IKKE KOSTER NOE AA FJERNE DEN
// ---------------------------------------------------------------------
//
// `/min-plan` kaller `lagSupabaseServerKlient()`, som awaiter
// `cookies()`. Sida er DYNAMISK - det finnes ingen cachet utgave aa
// invalidere. Og `staleTimes.dynamic` har vaert **0 sekunder siden Next
// 15**, saa klienten henter den ferskt ved hver navigering uansett.
//
// Revalideringen kostet oss feilen og ga oss ingenting.
//
// Sida friskes opp av KLIENTEN: `HandlingKnapp` med `oppfrisk` kaller
// `router.refresh()` i sin EGEN transition naar `tilstand.ok` er satt.
// `oppfriskvakt.test.ts` holder de to fra hverandre.
// =====================================================================

/** Bare eieren slipper planer. Butikksjefen er mottakeren, ikke avsender. */
const KAN_SLIPPE = 'retailer_admin'

export async function slippPlan(_t: Kvittering, fd: FormData): Promise<Kvittering> {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== KAN_SLIPPE) return { feil: 'Bare eier kan slippe planer.' }

  const id = String(fd.get('id') ?? '')
  if (!id) return { feil: 'Mangler plan.' }

  const supabase = await lagSupabaseServerKlient()
  // `{ count: 'exact' }` er ikke pynt: null rader og «det gikk bra» ser
  // like ut for PostgREST. Er raden filtrert bort av RLS - eller
  // allerede sluppet - skal det SIES, ikke se ut som suksess.
  return kvitter(
    supabase
      .from('maanedsplan')
      .update({
        status: 'sluppet',
        sluppet_av: bruker.id,
        sluppet_tid: new Date().toISOString(),
      }, { count: 'exact' })
      .eq('id', id)
      .eq('status', 'utkast'),
    {
      hva: 'slippe planen',
      ok: 'Sluppet. Butikksjefen ser den nå.',
      // INGEN `oppfrisk`. Se blokka oeverst: `/min-plan` er dynamisk og
      // hentes ferskt uansett, og revalideringen trakk ruteroppdateringen
      // inn i handlingens overgang.
    },
  )
}

/**
 * Avvis en plan.
 *
 * En plan eieren ikke vil sende skal ikke bare bli liggende som utkast:
 * da er den umulig å skille fra en hun ikke har sett på ennå, og køen
 * slutter å bety noe.
 */
export async function avvisPlan(_t: Kvittering, fd: FormData): Promise<Kvittering> {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== KAN_SLIPPE) return { feil: 'Bare eier kan avvise planer.' }

  const id = String(fd.get('id') ?? '')
  if (!id) return { feil: 'Mangler plan.' }

  const supabase = await lagSupabaseServerKlient()
  return kvitter(
    supabase
      .from('maanedsplan')
      .update({ status: 'avvist' }, { count: 'exact' })
      .eq('id', id)
      .eq('status', 'utkast'),
    // INGEN `oppfrisk`. En avvist plan har aldri vaert synlig paa
    // `/min-plan` - statusfilteret der slipper bare sluppet og sendt
    // gjennom - saa det finnes ingen annen rute aa friske opp.
    { hva: 'avvise planen', ok: 'Avvist. Den sendes ikke.' },
  )
}


// =====================================================================
// Å BYGGE MÅNEDENS UTKAST PÅ NYTT
// =====================================================================
//
// Den bygger planene av tall som ALLEREDE ligger i basen. Ingen fil
// lastes opp, ingen importjobb kjøres, og ingen av regnskaps- eller
// provenienstabellene skrives. Tabellkartet står i
// `src/lib/kurs/regenerer.ts`, og en vakt leser kildene og feller en
// skriving som sniker seg inn.
//
// ---------------------------------------------------------------------
// MÅNEDEN KOMMER FRA SKJEMAET, MEN AVGJØRES AV SERVEREN
//
// Feltet valideres på form — ISO, første i måneden, ikke framtid — og
// må DESSUTEN være den nyeste måneden kjeden faktisk har en plan for,
// slått opp her. Da kan en gammel fane eller et endret felt ikke styre
// hvilken måned som skrives om; den kan bare gi et nei.
//
// Retailer-ID slås opp på brukeren og kommer aldri fra skjemaet.
// =====================================================================

export async function byggPlanerPaaNytt(_t: Kvittering, fd: FormData): Promise<Kvittering> {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== KAN_SLIPPE || !bruker.retailerId) {
    return { feil: 'Bare eier kan bygge planene på nytt.' }
  }

  const bedtOm = validerMaaned(fd.get('maaned'))
  if (!bedtOm) return { feil: 'Ugyldig måned.' }

  const supabase = await lagSupabaseServerKlient()

  // MÅLMÅNEDEN SLÅS OPP PÅ NYTT, I DATAGRUNNLAGET.
  //
  // Ikke i `maanedsplan`: det er resultattabellen, og en måned som
  // ALDRI fikk en planrad ville da vært utenåelig for reparasjonen.
  // `nyesteKompletteMaaned` leser `v_kurs_maanedstall.linjer_lest` —
  // datadekning, ikke beløp.
  let maal
  try {
    maal = await nyesteKompletteMaaned({ supabase, retailerId: bruker.retailerId })
  } catch (e) {
    return { feil: `Kunne ikke lese datagrunnlaget: ${e instanceof Error ? e.message : String(e)}` }
  }
  if (!maal.maaned) return { feil: maal.grunn ?? 'Fant ingen komplett datamåned.' }

  const maaned = maal.maaned
  if (maaned !== bedtOm) {
    return {
      feil: `Sida viste ${bedtOm.slice(0, 7)}, men nyeste komplette datamåned `
        + `er nå ${maaned.slice(0, 7)}. Last sida på nytt før du bygger.`,
    }
  }

  try {
    const r = await regenererMaaned({ supabase, retailerId: bruker.retailerId, maaned })
    // INGEN revalidering. Se blokka oeverst: den satte
    // `x-action-revalidated: 1` og trakk ruteroppdateringen av
    // `/maanedsplan` inn i handlingens egen overgang.
    return { ok: regenereringsnotat(r) }
  } catch (e) {
    return { feil: `Klarte ikke bygge planene: ${e instanceof Error ? e.message : String(e)}` }
  }
}
