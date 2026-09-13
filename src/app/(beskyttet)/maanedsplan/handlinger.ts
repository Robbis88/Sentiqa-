'use server'
import { revalidatePath } from 'next/cache'
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
      oppfrisk: ['/maanedsplan'],
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
    { hva: 'avvise planen', ok: 'Avvist. Den sendes ikke.', oppfrisk: ['/maanedsplan'] },
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
    revalidatePath('/maanedsplan')
    revalidatePath('/min-plan')
    return { ok: regenereringsnotat(r) }
  } catch (e) {
    return { feil: `Klarte ikke bygge planene: ${e instanceof Error ? e.message : String(e)}` }
  }
}
