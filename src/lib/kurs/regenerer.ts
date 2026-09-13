import type { SupabaseClient } from '@supabase/supabase-js'
import { byggPlanerForRetailer } from './hent'
import { lagreUtkast, LAAST_VED_REGENERERING } from './lagre'

// =====================================================================
// Å BYGGE MÅNEDENS UTKAST PÅ NYTT — UTEN Å IMPORTERE NOE
// =====================================================================
//
// `byggPlanerForRetailer` hadde ett kallsted: importkjernen. Skulle en
// plan bygges på nytt, måtte en regnskapsfil kjøres om igjen — og det
// skriver `regnskapslinjer`, `bilagssum`, `bp_linje` og provenienstabellene
// på veien. For å få fem nye juliutkast ville vi rørt hele grunnlaget.
//
// Denne veien gjør ÉN ting: leser tallene som allerede ligger der,
// bygger planene, og skriver utkastene. Ingen fil, ingen jobb, ingen
// parser.
//
// =====================================================================
// TABELLKARTET — hva denne veien rører, og hva den aldri rører
// =====================================================================
//
// LESER (gjennom `byggPlanerForRetailer`):
//
//   stasjoner              id, navn, butikknummer for kjeden
//   v_kurs_maanedstall     månedssummene (0205/0206/0213/0214/0215)
//     └ regnskapslinjer    …og under viewet
//     └ v_svinn_grunnlag
//         └ regnskap_usynlig_svinn
//         └ regnskapslinjer
//         └ v_butikksalg → daglig_salg
//     └ stasjoner
//   bilagssum              leverandørdetalj for måneden (0199)
//   royaltysats            kroneverdiene (0198)
//   kastbudsjett           satsen matkastet måles mot
//   maanedsplan            status og kilde_jobb_id på radene som finnes
//
// SKRIVER:
//
//   maanedsplan            og INGENTING annet
//
// RØRER ALDRI:
//
//   regnskapslinjer, regnskap_usynlig_svinn, bilagssum, bp_aar,
//   bp_linje, kastbudsjett, royaltysats, raa_filer, import_jobber,
//   daglig_salg — ingen av dem står i en insert, update, upsert eller
//   delete noe sted i kallgrafen. Det er lesninger hele veien ned.
//
// Vakten `src/lib/kurs/regenerer.test.ts` leser kildefilene og feller
// en skriving som sniker seg inn. En påstand i en kommentar er ikke en
// grense.
//
// ---------------------------------------------------------------------
// INGEN TJENESTENØKKEL
//
// Kjøres med eierens egen økt. `maanedsplan_ny` (0202) og
// `maanedsplan_slipp` (0200) lar `retailer_admin` skrive i SIN kjede, og
// RLS er dermed den andre låsen bak rollesjekken i handlingen. En
// adminnøkkel ville gjort kodens sjekk til den eneste grensen.
//
// ---------------------------------------------------------------------
// BARE ÉN MÅNED
//
// `byggPlanerForRetailer` bygger én plan per stasjon, og planens `maaned`
// er den SISTE måneden stasjonen har tall for — ikke nødvendigvis den vi
// spurte om. En stasjon som mangler juli ville derfor fått JUNI-raden
// skrevet om, og det er utenfor det som ble bedt om.
//
// Derfor filtreres det her, og stasjonene som faller utenfor NAVNGIS.
// En stille utelatelse ser ut som en stasjon uten avvik.
// =====================================================================

type Klient = SupabaseClient

/** ISO, første i måneden. Ikke en dato, ikke et månedsnummer. */
const MAANEDSFORM = /^\d{4}-(0[1-9]|1[0-2])-01$/

/**
 * Månedene vi i det hele tatt bygger planer for.
 *
 * Nedre grense er året regnskapsmodellen begynte; øvre er «ikke
 * framtida». En måned utenfor er ikke en skrivefeil å rette opp — det er
 * et argument ingen skulle sendt, og da svarer vi nei.
 */
const FRA_AAR = 2024

export function validerMaaned(v: unknown, naa = new Date()): string | null {
  if (typeof v !== 'string') return null
  if (!MAANEDSFORM.test(v)) return null
  const aar = Number(v.slice(0, 4))
  if (aar < FRA_AAR) return null
  // Denne måneden er lov; neste er det ikke.
  const grense = `${naa.getUTCFullYear()}-${String(naa.getUTCMonth() + 1).padStart(2, '0')}-01`
  if (v > grense) return null
  return v
}

export type Regenerering = {
  maaned: string
  /** Antall utkast som faktisk ble skrevet. */
  skrevet: number
  /** Stasjoner som sto låst (sluppet, sendt eller avvist). Navngitt. */
  laast: string[]
  /** Stasjoner som ikke har tall for måneden. Navngitt, med grunn. */
  hoppet: { stasjon: string; grunn: string }[]
};

/**
 * Bygger månedens utkast på nytt fra tall som allerede ligger i basen.
 *
 * `retailerId` skal komme fra den innloggede brukeren, aldri fra input.
 * `maaned` må være validert med `validerMaaned` før den sendes hit.
 */
export async function regenererMaaned(opts: {
  supabase: Klient
  retailerId: string
  maaned: string
}): Promise<Regenerering> {
  const { supabase, retailerId, maaned } = opts
  if (validerMaaned(maaned) === null) {
    throw new Error(`Ugyldig måned: ${maaned}`)
  }

  const planer = await byggPlanerForRetailer({ supabase, retailerId, tilOgMed: maaned })

  const iMaaneden = planer.filter((p) => p.plan.maaned === maaned)
  const hoppet = planer
    .filter((p) => p.plan.maaned !== maaned)
    .map((p) => ({
      stasjon: p.plan.stasjonNavn,
      grunn: `Siste måned med tall er ${p.plan.maaned.slice(0, 7)}, ikke ${maaned.slice(0, 7)}.`,
    }))

  const lagret = await lagreUtkast(
    supabase,
    retailerId,
    // INGEN JOBB. Denne veien har ingen fil å vise til, og `beholdKilde`
    // sørger for at pekeren på radene som finnes fra før står urørt.
    null,
    iMaaneden.map((p) => ({ stasjonId: p.stasjonId, plan: p.plan })),
    { laaste: LAAST_VED_REGENERERING, beholdKilde: true },
  )

  return { maaned, skrevet: lagret.skrevet, laast: lagret.laast, hoppet }
}

/**
 * Kvitteringsteksten. Sier hva som ble skrevet OG hva som ikke ble det.
 *
 * «Skrev 3 utkast» på en kjede med fem stasjoner er en halv beskjed, og
 * den halvdelen som mangler er den som betyr noe.
 */
export function regenereringsnotat(r: Regenerering): string {
  const mnd = r.maaned.slice(0, 7)
  const deler: string[] = [
    r.skrevet === 0
      ? `Ingen utkast ble skrevet for ${mnd}.`
      : `Bygget ${r.skrevet} ${r.skrevet === 1 ? 'utkast' : 'utkast'} for ${mnd}.`,
  ]
  if (r.laast.length > 0) {
    deler.push(
      `${r.laast.join(', ')} sto urørt: planen er allerede avgjort, og en `
      + 'avgjørelse skal ikke gjøres om av et knappetrykk.',
    )
  }
  for (const h of r.hoppet) deler.push(`${h.stasjon}: ${h.grunn}`)
  return deler.join(' ')
}
