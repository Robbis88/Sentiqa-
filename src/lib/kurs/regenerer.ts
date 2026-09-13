import type { SupabaseClient } from '@supabase/supabase-js'
import { byggPlanerForRetailer } from './hent'
import { maaVaereHele } from '@/lib/supabase/datobolker'
import { lagreUtkast } from './lagre'

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

/**
 * Hvor langt tilbake dekningen leses.
 *
 * Taket er et sted å oppdage avkorting, ikke et ønske om færre
 * rader: `maaVaereHele` kaster når svaret TREFFER det.
 */
const MAANEDER_TILBAKE = 24

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
    // INGEN JOBB. Denne veien har ingen fil å vise til. `0217` tolker
    // `null` som «behold pekeren som står der», og dikter ingen opp.
    null,
    iMaaneden.map((p) => ({ stasjonId: p.stasjonId, plan: p.plan })),
  )

  return {
    maaned,
    skrevet: lagret.skrevet,
    laast: [...lagret.laast, ...lagret.fremmede],
    hoppet,
  }
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


// =====================================================================
// MÅLMÅNEDEN KOMMER FRA DATAGRUNNLAGET, IKKE FRA `maanedsplan`
// =====================================================================
//
// Foerste utgave leste nyeste maaned i `maanedsplan`. Det er
// RESULTATTABELLEN: feilet byggingen av augustplanene foer ÉN eneste
// planrad ble opprettet, ville knappen fortsatt funnet juli — og da kan
// den ikke reparere maaneden som mangler. En reparasjonsfunksjon som
// ikke når tilstanden den skal reparere, er ikke en reparasjon.
//
// ---------------------------------------------------------------------
// «KOMPLETT» MÅLES PÅ DATADEKNING, ALDRI PÅ ET BELØP
//
// `omsetning_kr > 0` sto her i skissen. Den blander to ting som ser like
// ut og betyr motsatt: en ekte nullmaaned og en maaned ingen har
// importert. `linjer_lest` (0217) er antall regnskapslinjer bak raden,
// og er DATADEKNINGEN.
//
// En maaned er komplett naar HVER aktive stasjon har regnskapsrader for
// den. Svinn og budsjett kan fortsatt mangle — det blokkeres per
// analyse av nipunktsporten, og er ikke denne funksjonens sak.
// =====================================================================

export type Maalmaaned = {
  /** Nyeste komplette datamaaned, eller `null`. */
  maaned: string | null
  /** Hvor mange stasjoner grunnlaget forventer. */
  aktiveStasjoner: number
  /** Hvorfor det ikke ble noen maaned. `null` naar det ble en. */
  grunn: string | null
}

type Dekningsrad = { maaned: string; stasjon_id: string; linjer_lest: number | null }

export async function nyesteKompletteMaaned(opts: {
  supabase: Klient
  retailerId: string
  naa?: Date
}): Promise<Maalmaaned> {
  const { supabase, retailerId } = opts
  const naa = opts.naa ?? new Date()

  const { data: stasjonsrader, error: stasjonsfeil } = await supabase
    .from('stasjoner')
    .select('id')
    .eq('retailer_id', retailerId)
    .is('slettet_tid', null)
    .limit(200)
  if (stasjonsfeil) throw new Error(`Kunne ikke lese stasjonene: ${stasjonsfeil.message}`)

  const aktive = new Set((stasjonsrader ?? []).map((r) => (r as { id: string }).id))
  if (aktive.size === 0) {
    return { maaned: null, aktiveStasjoner: 0, grunn: 'Kjeden har ingen aktive stasjoner.' }
  }

  // ALDRI FRAMTID. Innevärende maaned er lov — den kan vaere komplett
  // hvis regnskapet er kjoert.
  const grense = `${naa.getUTCFullYear()}-${String(naa.getUTCMonth() + 1).padStart(2, '0')}-01`

  const tak = aktive.size * (MAANEDER_TILBAKE + 1)
  const svar = await supabase
    .from('v_kurs_maanedstall')
    .select('maaned, stasjon_id, linjer_lest')
    .eq('retailer_id', retailerId)
    .lte('maaned', grense)
    .order('maaned', { ascending: false })
    .limit(tak)
  const rader = maaVaereHele(svar, 'datadekningen', tak) as unknown as Dekningsrad[]

  const perMaaned = new Map<string, Set<string>>()
  for (const r of rader) {
    // DEKNING, IKKE BELØP. `linjer_lest` er antall regnskapslinjer bak
    // raden; er den 0 eller null, er maaneden ikke lest for stasjonen.
    if (!((r.linjer_lest ?? 0) > 0)) continue
    if (!aktive.has(r.stasjon_id)) continue
    const m = String(r.maaned).slice(0, 10)
    const f = perMaaned.get(m)
    if (f) f.add(r.stasjon_id)
    else perMaaned.set(m, new Set([r.stasjon_id]))
  }

  const komplette = [...perMaaned.entries()]
    .filter(([, st]) => st.size === aktive.size)
    .map(([m]) => m)
    .sort()

  if (komplette.length === 0) {
    const beste = [...perMaaned.entries()].sort((a, b) => b[0].localeCompare(a[0]))[0]
    return {
      maaned: null,
      aktiveStasjoner: aktive.size,
      grunn: beste
        ? `Ingen måned har regnskapsdata for alle ${aktive.size} aktive stasjoner. `
          + `Nyeste er ${beste[0].slice(0, 7)} med ${beste[1].size} av ${aktive.size}.`
        : 'Ingen måned har regnskapsdata for kjeden.',
    }
  }

  return {
    maaned: komplette[komplette.length - 1],
    aktiveStasjoner: aktive.size,
    grunn: null,
  }
}
