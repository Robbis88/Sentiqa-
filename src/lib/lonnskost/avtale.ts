import 'server-only'
import type { SupabaseClient } from '@supabase/supabase-js'
import { hentAlle } from '@/lib/supabase/sider'
import type { Avtaleoppslag, Avtalerad } from './prisbarhet'

// =====================================================================
// `ansatt_avtale`: hva et MENNESKE har sagt om ansettelsesforholdet.
//
// Ikke en kildeobservasjon fra easy@work. Noen har huket av, og det er
// nettopp derfor den kan overstyre Easy for én ting: fastlønn.
//
// ---------------------------------------------------------------------
// NØKKELEN ER (stasjon_id, ansatt_nr). ALLTID.
//
// Leseren returnerer et `Avtaleoppslag` — funksjonen `prisbarhet.ts`
// allerede tar — og ikke et kart. Da finnes det ingen
// `Map<ansatt_nr, …>` å bygge, og et globalt oppslag lar seg ikke skrive
// uten å endre typen.
//
// Hvorfor det betyr noe, med ekte tall: `(Lone, 118)` er `fastlonn`.
// Lekket den på nummer alene, ville en hvilken som helst annen stasjons
// 118 sluttet å bli timepriset — for lite lønn, altså for stort grønt
// lønnsrom.
//
// ---------------------------------------------------------------------
// INGEN HISTORIKK OPPFINNES
//
// Tabellen har ingen «gyldig fra». `oppdatert_tid` er sist gang raden
// ble SKREVET, ikke datoen klassifiseringen begynte å gjelde. Vi
// rapporterer den som `sistSatt` og later ikke som den er noe mer;
// `anvendtBakover` i `prisbarhet.ts` sier bare det den kan vite.
//
// ---------------------------------------------------------------------
// INGEN RAD ER IKKE FASTLØNN
//
// Målt i produksjon 2026-09-16: 13 rader, på to av fem stasjoner, 9 av
// dem med `lonnsform = null`. Uavklart er et spørsmål, ikke en verdi —
// telte `null` som fastlønn, ville lønnskosten falt for ni personer i
// stillhet. Semantikken er låst i `prisbarhet.ts`; denne fila leverer
// bare raden slik den står.
// =====================================================================

type Klient = SupabaseClient

const LONNSFORM = new Set(['timelonn', 'fastlonn', 'tilkalling'])

/** `${stasjonId}|${ansattNr}`. Aldri nummeret alene. */
const noekkel = (stasjonId: string, ansattNr: string) => `${stasjonId}|${ansattNr}`

/**
 * Avtalene for stasjonene kalleren ber om, som et stasjonsbundet oppslag.
 *
 * Tom liste betyr «alle stasjoner RLS viser meg». RLS avgjør uansett
 * hva som kommer tilbake; lista kan bare snevre inn.
 */
export async function hentAvtaler(
  supabase: Klient,
  stasjonIder: readonly string[] = [],
): Promise<Avtaleoppslag> {
  // SIDER, IKKE ETT KALL. Tretten rader i dag. Det er nettopp når det
  // slutter å være sant at dette betyr noe — og en avkortet avtaleliste
  // ville gjort en fastlønnet til en timelønnet uten at noe pekte på
  // hvorfor.
  type Raa = {
    stasjon_id: string; ansatt_nr: string
    lonnsform: string | null; oppdatert_tid: string | null
  }
  const data = await hentAlle<Raa>(() => {
    const q = supabase
      .from('ansatt_avtale')
      .select('stasjon_id, ansatt_nr, lonnsform, oppdatert_tid')
    return stasjonIder.length > 0 ? q.in('stasjon_id', stasjonIder) : q
  })

  const kart = new Map<string, Avtalerad>()
  for (const r of data ?? []) {
    const raa = r.lonnsform
    kart.set(noekkel(r.stasjon_id, r.ansatt_nr), {
      // En verdi vi ikke kjenner igjen er UKJENT, ikke en klassifisering.
      // Samme innsats som `betalingsfrekvens` i `0220`.
      lonnsform: typeof raa === 'string' && LONNSFORM.has(raa)
        ? (raa as Avtalerad['lonnsform'])
        : null,
      sistSatt: String(r.oppdatert_tid ?? '').slice(0, 10),
    })
  }

  return (stasjonId: string, ansattNr: string) =>
    kart.get(noekkel(stasjonId, ansattNr)) ?? null
}
