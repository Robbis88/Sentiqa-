'use server'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { kvitter, type Kvittering } from '@/lib/kvittering'

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
