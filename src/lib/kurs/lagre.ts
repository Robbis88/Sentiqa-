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
  /** Stasjoner der planen sto laast, og derfor uroert. */
  laast: string[]
  /** Stasjoner som ikke hoerer til kjeden. Skal normalt vaere tom. */
  fremmede: string[]
}

/**
 * Statusene som ALDRI skrives om. Én liste, for begge kallerne.
 *
 * =====================================================================
 * DEN STO EN STUND SOM TO
 * =====================================================================
 *
 * Importen hadde en saerregel: et nytt utkast paa en AVVIST maaned var
 * riktig svar, fordi en ny regnskapsfil er ny informasjon. Regelen er
 * forlatt — eieren har tatt stilling, og hverken en import, en
 * regenerering, en PATCH over PostgREST eller annen kode skal kunne
 * gjoere om paa det i stillhet. Gjenaapning blir en egen, eksplisitt
 * handling med eget revisjonsspor.
 *
 * Lista staar her som dokumentasjon og for feilmeldingens skyld. DEN
 * ER IKKE LAASEN. Laasen ligger to steder i basen, og begge er
 * autoriteter:
 *
 *   `skriv_maanedsplan_utkast` — `on conflict ... do update ... where`,
 *      evaluert etter radlaasen, saa en plan som avgjoeres MELLOM
 *      lesing og skriving staar uroert
 *   `maanedsplan_laas_sluppet` — triggeren, som bakstopper for alt som
 *      skriver forbi funksjonen
 */
export const LAAST = ['sluppet', 'sendt', 'avvist'] as const

/** Én rad slik skriveren i basen tar imot den. */
type Skriverad = {
  stasjon_id: string
  maaned: string
  dom: string
  ingress: string
  punkter: unknown
  merknad: string | null
  matkast: unknown
  usynlig: unknown
  rangering: unknown
}

type Svarrad = {
  stasjon_id: string
  maaned: string
  skrevet: boolean
  status_ved_start: string | null
  tilhorer_kjeden: boolean
}

/** Radene, bygget ÉN gang. Begge kallerne sender nøyaktig det samme. */
export function byggRader(utkast: readonly Utkast[]): Skriverad[] {
  return utkast.map((u) => ({
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
  }))
}

/**
 * Skriver utkastene gjennom den atomiske skriveren i basen.
 *
 * =====================================================================
 * INGEN FORHAANDSSJEKK — DEN VAR IKKE EN LAAS
 * =====================================================================
 *
 * Her sto SELECT status -> filtrer i TypeScript -> UPSERT. Tre steg og
 * to vinduer: avviste eieren planen ETTER lesingen men FOER skrivingen,
 * ble avvisningen skrevet tilbake til utkast, og triggeren fanget det
 * ikke fordi den bare voktet `sluppet` og `sendt`.
 *
 * Naa er lesing og skriving ÉN setning i basen, og svaret sier per
 * stasjon om raden ble skrevet. `skrevet` kommer fra `RETURNING` og er
 * autoriteten; `status_ved_start` er en forklaring til kvitteringen og
 * kan vaere ett commit gammel.
 *
 * `jobbId` er `null` ved regenerering. Da beholder en rad som finnes
 * fra foer sin egen `kilde_jobb_id`, og en ny rad faar `null`. Er den
 * satt, VALIDERES den i basen mot `import_jobber` — kjede,
 * rapporttype og maaned — og hele kallet feiler lukket hvis den ikke
 * holder.
 */
export async function lagreUtkast(
  supabase: Klient,
  retailerId: string,
  jobbId: string | null,
  utkast: readonly Utkast[],
): Promise<Lagret> {
  if (utkast.length === 0) return { skrevet: 0, laast: [], fremmede: [] }

  const { data, error } = await supabase.rpc('skriv_maanedsplan_utkast', {
    p_rader: byggRader(utkast),
    p_retailer_id: retailerId,
    p_kilde_jobb_id: jobbId,
  })
  if (error) throw new Error(`Klarte ikke lagre månedsplanene: ${error.message}`)

  const svar = (data ?? []) as Svarrad[]
  const navn = new Map(utkast.map((u) => [
    `${u.stasjonId}|${u.plan.maaned}`, u.plan.stasjonNavn,
  ]))
  const navnFor = (r: Svarrad) =>
    navn.get(`${r.stasjon_id}|${String(r.maaned).slice(0, 10)}`) ?? r.stasjon_id

  // EN TOM SVARLISTE ER IKKE «INGENTING AA SKRIVE».
  //
  // Funksjonen returnerer ÉN rad per rad den fikk inn, ogsaa for dem
  // den hoppet over. Kommer det ingenting tilbake, har vi ikke
  // grunnlag for aa si at noe ble skrevet — og «0 skrevet, 0 laast»
  // ville sett ut som en vellykket, tom kjoering.
  if (svar.length !== utkast.length) {
    throw new Error(
      `Skriveren svarte for ${svar.length} av ${utkast.length} planer. `
      + 'Resultatet kan ikke tolkes, og ingenting regnes som skrevet.',
    )
  }

  return {
    skrevet: svar.filter((r) => r.skrevet).length,
    laast: svar.filter((r) => !r.skrevet && r.tilhorer_kjeden).map(navnFor),
    fremmede: svar.filter((r) => !r.tilhorer_kjeden).map(navnFor),
  }
}

/**
 * Merknaden importen viser.
 *
 * EN STILLE UTELATELSE ER VERRE ENN EN SYNLIG MERKNAD — samme regel som
 * `utenEan` og stasjonsdekningen. Sto det ingenting, ville en eier som
 * hadde sluppet planen tidligere lurt på hvorfor den ikke oppdaterte seg.
 */
export function lagringsnotat(l: Lagret): string | null {
  if (l.skrevet === 0 && l.laast.length === 0 && l.fremmede.length === 0) return null
  const deler: string[] = []
  if (l.skrevet > 0) {
    deler.push(`Skrev ${l.skrevet} ${l.skrevet === 1 ? 'månedsplan' : 'månedsplaner'} som utkast.`)
  }
  if (l.laast.length > 0) {
    deler.push(
      `${l.laast.join(', ')} sto urørt: planen er allerede avgjort, og en `
      + 'avgjørelse skal ikke gjøres om i stillhet.',
    )
  }
  if (l.fremmede.length > 0) {
    deler.push(
      `${l.fremmede.join(', ')} hører ikke til kjeden og ble ikke skrevet.`,
    )
  }
  return deler.join(' ')
}
