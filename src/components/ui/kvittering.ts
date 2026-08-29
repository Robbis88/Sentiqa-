'use client'
import { useActionState, useEffect } from 'react'
import { useRouter } from 'next/navigation'

// =====================================================================
// KVITTERINGEN SKAL IKKE VENTE PÅ AT SIDEN TEGNER SEG OM
//
// `useActionState` holder `venter` sann gjennom HELE overgangen. Kalles
// `revalidatePath` inne i serverhandlingen, blir ruteroppdateringen en
// del av den overgangen — og da vises kvitteringen først når hele siden
// har rendret på nytt.
//
// ---------------------------------------------------------------------
// MÅLT, IKKE ANTATT
//
// Playwright-sporet fra en rød CI-kjøring 2026-08-29, `/stempling`:
//
//   0,7 s   POST /stempling      200 på 190 ms
//   1,2 s   siste aktivitet
//   ...     29 sekunder helt stille
//   30,6 s  GET /stempling?_rsc  200 på 108 ms
//   45 s    knappen står fortsatt «Registrerer …»
//
// Serveren gjorde jobben på 190 millisekunder. Klienten viste det aldri.
//
// De 29 sekundene var ressursmangel på CI-maskinen. Det er ikke fikset
// her, og det er heller ikke poenget: koblingen gjorde treghet om til en
// feil, og den samme koblingen rammer mennesket. Hun ser «Registrerer …»
// på noe som ALT er lagret, og det er da hun trykker igjen.
//
// På /stempling lager dobbelttrykket et `dobbel_inn`-avvik butikksjefen
// må rydde. På de andre sidene lager det en dublett eller ingenting —
// men opplevelsen er den samme: det ser ut som handlingen ikke gikk
// gjennom.
//
// ---------------------------------------------------------------------
// HVORFOR ÉN KROK OG IKKE FØRTI RETTELSER
//
// Seksten sider hadde samme kobling, fordelt på rundt førti skjemaer.
// Rettet hver for seg ville regelen bodd førti steder og forfalt det
// første stedet noen glemte den. Her bor den ett sted, og
// `kvitteringsvakt.test.ts` holder serverhandlingene fri for
// egen-rute-revalidering.
//
// ---------------------------------------------------------------------
// DEN OPPDATERER PÅ HVERT SVAR, OGSÅ FEIL
//
// Ikke bare når svaret har `ok`. Tilstandstypene er ikke like — noen har
// `ok?: true`, andre `ok?: string` — og en krok som må kjenne formen
// ville sluttet å oppdatere den dagen en ny type ikke passet. Stille.
//
// En oppdatering etter en avvist skriving koster en RSC-henting og
// endrer ingenting. Det er en billigere feil enn en liste som henger
// igjen på gamle tall.
// =====================================================================

/**
 * `useActionState`, men kvitteringen kommer først.
 *
 * Bruk denne i stedet for `useActionState` når serverhandlingen endrer
 * noe siden viser. Serverhandlingen skal da IKKE revalidere sin egen
 * rute — `revalidatePath` for ANDRE ruter er fortsatt riktig, siden
 * `router.refresh()` bare treffer siden du står på.
 */
export function useKvittering<Tilstand, Data>(
  handling: (forrige: Awaited<Tilstand>, data: Data) => Tilstand | Promise<Tilstand>,
  start: Awaited<Tilstand>,
  permalenke?: string,
): [Awaited<Tilstand>, (data: Data) => void, boolean] {
  const [svar, send, venter] = useActionState(handling, start, permalenke)
  const router = useRouter()

  // Rekkefølgen er hele poenget: React commiter svaret, kvitteringen
  // står — og FØRST DA hentes siden på nytt.
  useEffect(() => {
    if (svar !== undefined && svar !== null) router.refresh()
  }, [svar, router])

  return [svar, send, venter]
}
