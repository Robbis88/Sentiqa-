import type { SupabaseClient } from '@supabase/supabase-js'
import type { Maanedsplan } from './plan'

// =====================================================================
// Utkastene, og slippet.
//
// Robert godkjenner før planen går. Det gir én grense som ikke kan ligge
// i en visning: **butikksjefen skal aldri se et utkast.** Den står i RLS
// (0200) — her ligger bare skrivingen.
//
// ---------------------------------------------------------------------
// ET SLUPPET BREV SKRIVES IKKE OM
//
// Regnskapet kan lastes opp på nytt: en korrigert fil, eller samme fil to
// ganger. Da skal utkastet skrives om. Men er planen sluppet, har
// butikksjefen lest den — og da ville en ny versjon betydd at hun har en
// annen plan enn den hun husker, uten at noe sa fra.
//
// Regelen håndheves av en TRIGGER i 0200, ikke her og ikke i policyen.
// Policyen gjelder `authenticated`; importen kjører med tjenestenøkkelen,
// og en regel som bare finnes i policyen gjelder ikke den som faktisk
// skriver.
//
// `lagreUtkast` filtrerer derfor på `status = 'utkast'` i tillegg — ikke
// fordi triggeren ikke holder, men fordi en import som stopper med
// «check_violation» midt i en batch er en dårligere beskjed enn en import
// som hopper over det som er låst og sier hvor mange.
// =====================================================================

type Klient = SupabaseClient

export type Utkast = {
  stasjonId: string
  plan: Maanedsplan
}

export type Lagret = {
  skrevet: number
  /** Stasjoner der planen allerede var sluppet, og derfor sto urørt. */
  laast: string[]
}

/**
 * Skriver utkastene. Planer som allerede er sluppet står urørt.
 *
 * Kjøres med tjenestenøkkelen fra importen — det finnes ingen
 * insert-policy for `authenticated`.
 */
export async function lagreUtkast(
  supabase: Klient,
  retailerId: string,
  jobbId: string | null,
  utkast: readonly Utkast[],
): Promise<Lagret> {
  if (utkast.length === 0) return { skrevet: 0, laast: [] }

  const stasjoner = [...new Set(utkast.map((u) => u.stasjonId))]
  const maaneder = [...new Set(utkast.map((u) => u.plan.maaned))]

  // Hvilke er allerede sluppet? Ett oppslag, ikke ett per stasjon.
  //
  // GRENSEN ER EKSPLISITT. `unique (stasjon_id, maaned)` gjør at antall
  // treff er nøyaktig stasjoner × måneder — men PostgREST kutter på sitt
  // eget tak UTEN å feile, og et avkortet svar her ville sett ut som «de
  // er ikke sluppet». Da hadde vi skrevet over et brev butikksjefen
  // allerede har lest. Grensen er satt av skranken, ikke gjettet.
  const { data: eksisterende } = await supabase
    .from('maanedsplan')
    .select('stasjon_id, maaned, status')
    .eq('retailer_id', retailerId)
    .in('stasjon_id', stasjoner)
    .in('maaned', maaneder)
    .limit(stasjoner.length * maaneder.length)

  const laastNokkel = new Set(
    ((eksisterende ?? []) as { stasjon_id: string; maaned: string; status: string }[])
      .filter((r) => r.status === 'sluppet' || r.status === 'sendt')
      .map((r) => `${r.stasjon_id}|${r.maaned.slice(0, 10)}`),
  )

  const aaSkrive = utkast.filter(
    (u) => !laastNokkel.has(`${u.stasjonId}|${u.plan.maaned}`),
  )
  const laast = utkast
    .filter((u) => laastNokkel.has(`${u.stasjonId}|${u.plan.maaned}`))
    .map((u) => u.plan.stasjonNavn)

  if (aaSkrive.length > 0) {
    const { error } = await supabase.from('maanedsplan').upsert(
      aaSkrive.map((u) => ({
        retailer_id: retailerId,
        stasjon_id: u.stasjonId,
        maaned: u.plan.maaned,
        dom: u.plan.dom,
        ingress: u.plan.ingress,
        punkter: u.plan.punkter,
        merknad: u.plan.merknad,
        status: 'utkast',
        kilde_jobb_id: jobbId,
        oppdatert_tid: new Date().toISOString(),
      })),
      { onConflict: 'stasjon_id,maaned' },
    )
    if (error) throw new Error(`Klarte ikke lagre månedsplanene: ${error.message}`)
  }

  return { skrevet: aaSkrive.length, laast }
}

/**
 * Merknaden importen viser.
 *
 * EN STILLE UTELATELSE ER VERRE ENN EN SYNLIG MERKNAD — samme regel som
 * `utenEan` og stasjonsdekningen. Sto det ingenting, ville en eier som
 * hadde sluppet planen tidligere lurt på hvorfor den ikke oppdaterte seg.
 */
export function lagringsnotat(l: Lagret): string | null {
  if (l.skrevet === 0 && l.laast.length === 0) return null
  const deler: string[] = []
  if (l.skrevet > 0) {
    deler.push(`Skrev ${l.skrevet} ${l.skrevet === 1 ? 'månedsplan' : 'månedsplaner'} som utkast.`)
  }
  if (l.laast.length > 0) {
    deler.push(
      `${l.laast.join(', ')} sto urørt: planen er allerede sluppet, og et brev `
      + 'butikksjefen har lest skal ikke endre seg under henne.',
    )
  }
  return deler.join(' ')
}
