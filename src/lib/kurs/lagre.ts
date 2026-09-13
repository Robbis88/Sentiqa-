import type { SupabaseClient } from '@supabase/supabase-js'
import { lagSnapshot } from './snapshot'
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
  /** Stasjoner der planen sto låst, og derfor urørt. */
  laast: string[]
}

/**
 * Statusene importen aldri skriver om.
 *
 * `avvist` står IKKE her, og det er med vilje: en ny regnskapsfil er ny
 * informasjon, og et nytt utkast på en avvist måned er riktig svar. En
 * MANUELL regenerering er noe annet — se `LAAST_VED_REGENERERING`.
 */
export const LAAST_VED_IMPORT = ['sluppet', 'sendt'] as const

/**
 * Statusene en manuell regenerering aldri skriver om.
 *
 * Her er `avvist` med. Eieren har tatt stilling til den måneden, og et
 * knappetrykk skal ikke gjøre om på den avgjørelsen i stillhet.
 *
 * MERK AT TRIGGEREN IKKE DEKKER `avvist`. `maanedsplan_laas_sluppet`
 * (0200) feller bare `sluppet` og `sendt`. For dem er triggeren
 * autoriteten og denne lista bare en bedre feilmelding; for `avvist` er
 * lista den eneste låsen, og det skal stå skrevet her framfor å bli
 * oppdaget av noen som trodde triggeren tok alt.
 */
export const LAAST_VED_REGENERERING = ['sluppet', 'sendt', 'avvist'] as const

export type Lagreopsjoner = {
  /** Statuser som ikke skrives om. Se de to konstantene over. */
  laaste?: readonly string[]
  /**
   * Behold `kilde_jobb_id` på rader som finnes fra før.
   *
   * Regenereringen har ingen importjobb å vise til, og `null` ville
   * slettet pekeren til filen tallene faktisk kom fra. Verdien leses
   * derfor tilbake fra raden og skrives uåpnet — den GJETTES ikke ut av
   * hva PostgREST gjør med en utelatt kolonne i en upsert.
   */
  beholdKilde?: boolean
}

/**
 * Skriver utkastene. Låste planer står urørt.
 *
 * To kallere, og de låser ulikt:
 *
 *   importen        tjeneste-/eiernøkkel, `LAAST_VED_IMPORT`
 *   regenereringen  eierens egen økt, `LAAST_VED_REGENERERING`
 *
 * ÉN skriver med to innstillinger, ikke to skrivere. To ville drevet fra
 * hverandre, og forskjellen ville vist seg først når noen sammenlignet
 * en regenerert plan med en importert.
 */
export async function lagreUtkast(
  supabase: Klient,
  retailerId: string,
  jobbId: string | null,
  utkast: readonly Utkast[],
  opts: Lagreopsjoner = {},
): Promise<Lagret> {
  if (utkast.length === 0) return { skrevet: 0, laast: [] }
  const laaste: readonly string[] = opts.laaste ?? LAAST_VED_IMPORT

  const stasjoner = [...new Set(utkast.map((u) => u.stasjonId))]
  const maaneder = [...new Set(utkast.map((u) => u.plan.maaned))]

  // Hvilke er allerede sluppet? Ett oppslag, ikke ett per stasjon.
  //
  // GRENSEN ER EKSPLISITT. `unique (stasjon_id, maaned)` gjør at antall
  // treff er nøyaktig stasjoner × måneder — men PostgREST kutter på sitt
  // eget tak UTEN å feile, og et avkortet svar her ville sett ut som «de
  // er ikke sluppet». Da hadde vi skrevet over et brev butikksjefen
  // allerede har lest. Grensen er satt av skranken, ikke gjettet.
  const { data: eksisterende, error: lesefeil } = await supabase
    .from('maanedsplan')
    .select('stasjon_id, maaned, status, kilde_jobb_id')
    .eq('retailer_id', retailerId)
    .in('stasjon_id', stasjoner)
    .in('maaned', maaneder)
    .limit(stasjoner.length * maaneder.length)

  // EN LESEFEIL HER SER UT SOM «INGEN ER SLUPPET».
  //
  // `data ?? []` alene ville gjort en avvist eller feilet spoerring til
  // en tom laaseliste, og da hadde vi skrevet over et brev butikksjefen
  // har lest. Feiler lesingen, skriver vi ingenting.
  if (lesefeil) {
    throw new Error(`Kunne ikke lese eksisterende planer: ${lesefeil.message}`)
  }

  type Rad = {
    stasjon_id: string; maaned: string; status: string; kilde_jobb_id: string | null
  }
  const noekkel = (stasjonId: string, maaned: string) => `${stasjonId}|${maaned.slice(0, 10)}`
  const rader = (eksisterende ?? []) as Rad[]

  const laastNokkel = new Set(
    rader.filter((r) => laaste.includes(r.status))
      .map((r) => noekkel(r.stasjon_id, r.maaned)),
  )
  const kildePer = new Map(rader.map((r) => [noekkel(r.stasjon_id, r.maaned), r.kilde_jobb_id]))

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
        // ANALYSEN FRYSES HER. Regnet vi den paa nytt naar sida eller
        // e-posten aapnes, kunne butikksjefen faatt andre tall enn de
        // eieren godkjente. Se `snapshot.ts`.
        ...lagSnapshot(u.plan),
        rangering: u.plan.rangering,
        status: 'utkast',
        kilde_jobb_id: opts.beholdKilde
          ? (kildePer.get(noekkel(u.stasjonId, u.plan.maaned)) ?? jobbId)
          : jobbId,
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
      `${l.laast.join(', ')} sto urørt: planen er allerede avgjort, og et brev `
      + 'butikksjefen har lest skal ikke endre seg under henne.',
    )
  }
  return deler.join(' ')
}
