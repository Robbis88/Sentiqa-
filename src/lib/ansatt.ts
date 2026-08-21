import 'server-only'
import { createHash, createHmac, timingSafeEqual } from 'node:crypto'
import { cookies } from 'next/headers'
import { cache } from 'react'
import type { SupabaseClient } from '@supabase/supabase-js'
import { hentInnloggetBruker } from '@/lib/auth/dal'

const COOKIE = 'sentiqa_vakt'

// =====================================================================
// IDENTITETSKONTRAKTEN
//
//   ansatt_nr      utpeker personen
//   PIN            beviser at det er riktig person
//   sentiqa_vakt   husker resultatet — og er ALDRI selv bevis
//
// Den siste linja er den som manglet. Kapselen bar `{id, navn}` som ren
// JSON, og `lesAktivAnsatt()` parset den og stolte på innholdet. Ingen
// signatur, ingen oppslag. `httpOnly` hindrer JavaScript i å lese den —
// den hindrer ikke en forespørsel med et selvskrevet `Cookie:`-hode.
//
// Følgen: den som allerede hadde nettbrettets sesjon kunne sette seg som
// hvilken som helst ansatt-ID, uten PIN i det hele tatt, og få det
// festet til mattilsynsdokumentasjon, rutiner, avvik, puls,
// tilbakemeldinger — og til hvilken stasjon lønnstimene føres på.
//
// Å bytte PIN mot nummer + PIN lukket inngangsdøra. Dette lukker den ved
// siden av.
// =====================================================================

// PIN hashes med retailer-id som salt.
//
// MERK HVA DENNE IKKE ER. Saltet er felles for hele kjeden, så «1234»
// gir samme hash for alle ansatte der. Det var et krav så lenge PIN var
// et databaseoppslag — en per-rad-salt kan ikke slås opp. Etter at
// nummeret overtok som identitet er den bindingen borte, og hashen kan
// bli en ekte passordhash (per-rad-salt, langsom KDF) uten at noe annet
// må endres. Det er ikke gjort her; det krever en migrasjon.
export function hashPin(retailerId: string, pin: string): string {
  return createHash('sha256').update(`${retailerId}:${pin}`).digest('hex')
}

/**
 * Signaturen på vaktkapselen.
 *
 * HVORFOR DATABASEVALIDERING IKKE VAR NOK — og dette er verdt å skrive
 * ned, for det så ut som det holdt:
 *
 * Første forsøk slo opp ID-en fra kapselen og godtok den hvis raden
 * fantes, var aktiv, ikke slettet og hørte til samme kjede. Beviset
 * `skrevet kapsel med en annen gyldig ansatt-ID` felte det med en gang.
 * Bo ER en gyldig, aktiv ansatt i samme kjede. Ingenting i raden hans
 * sier «denne kapselen ble utstedt etter at noen tastet Bos PIN».
 *
 * Et oppslag kan svare på om identiteten FINNES. Det kan aldri svare på
 * om den ble BEVIST. Til det trengs enten en hemmelighet eller
 * serverside-tilstand — det finnes ingen tredje vei.
 *
 * Valget falt på en signatur framfor en øktstabell: den krever ingen
 * migrasjon, ingen ny tabell, og ingen ny runde med RLS-policyer.
 *
 * FEILER LUKKET. Mangler hemmeligheten, kan ingen starte vakt — i
 * stedet for at alle kan starte hvem som helst. En sikkerhetskontroll
 * som slår seg selv av når den mangler oppsett, er ikke en kontroll.
 */
function vaktnokkel(): string | null {
  const n = process.env.VAKT_SIGNATUR_SECRET
  return n && n.length >= 32 ? n : null
}

/** Er vaktinnlogging satt opp på denne installasjonen? */
export function vaktErSattOpp(): boolean {
  return vaktnokkel() !== null
}

function signer(nokkel: string, id: string): string {
  return createHmac('sha256', nokkel).update(id).digest('hex')
}

/**
 * Sammenligning i konstant tid.
 *
 * En vanlig `===` på en hex-streng lekker hvor mange tegn som stemte,
 * gjennom hvor lang tid den brukte. Det er en tynn kanal over nett, men
 * den er gratis å lukke — og en signatur man kan gjette tegn for tegn er
 * ingen signatur.
 */
function likeSignaturer(a: string, b: string): boolean {
  const x = Buffer.from(a, 'utf8')
  const y = Buffer.from(b, 'utf8')
  if (x.length !== y.length) return false
  return timingSafeEqual(x, y)
}

export type AktivAnsatt = { id: string; navn: string }

/**
 * Hvem står på vakt akkurat nå — bevist, ikke husket.
 *
 * TO LÅS, OG BEGGE MÅ ÅPNE:
 *
 *   1. SIGNATUREN  beviser at kapselen ble utstedt av `checkInn`, altså
 *                  at noen faktisk tastet nummer og PIN. Uten den kan
 *                  hvem som helst med nettbrettets sesjon skrive seg
 *                  inn som hvem som helst.
 *
 *   2. OPPSLAGET   beviser at identiteten fortsatt gjelder: samme kjede,
 *                  aktiv, ikke slettet. Uten det ville en kapsel fra før
 *                  noen sluttet virke i tolv timer til.
 *
 * NAVNET KOMMER FRA BASEN, ikke fra kapselen — og det er nettopp derfor
 * kapselen ikke bærer noe navn lenger. Et navn på skjermen er det som
 * får folk til å stole på at riktig person er pålogget.
 *
 * `cache()` gjør oppslaget én gang per forespørsel. Uten den ville
 * layouten og siden under spurt hver for seg, og noen sider kaller den
 * to ganger.
 *
 * TAR IMOT KLIENTEN SOM ARGUMENT MED VILJE. Da må hvert kallsted ha en
 * server-klient i hånda, og en fremtidig snarvei som «les bare
 * kapselen» kompilerer ikke.
 */
export const lesAktivAnsatt = cache(
  async (supabase: SupabaseClient): Promise<AktivAnsatt | null> => {
    const nokkel = vaktnokkel()
    if (!nokkel) return null // feiler lukket: ingen nøkkel, ingen vakt

    const raw = (await cookies()).get(COOKIE)?.value
    if (!raw) return null

    let paastand: { id?: unknown; sig?: unknown }
    try {
      paastand = JSON.parse(raw) as { id?: unknown; sig?: unknown }
    } catch {
      return null
    }
    const id = paastand?.id
    const sig = paastand?.sig
    if (typeof id !== 'string' || !id) return null
    if (typeof sig !== 'string' || !sig) return null

    // LÅS 1: ble denne kapselen utstedt av oss?
    if (!likeSignaturer(sig, signer(nokkel, id))) return null

    const bruker = await hentInnloggetBruker()
    if (!bruker.retailerId) return null

    // LÅS 2: gjelder identiteten fortsatt?
    //
    // RLS (`ansatte_les`, 0078) begrenser allerede til `mine_stasjoner()`.
    // Kjedefilteret står likevel eksplisitt: to lag som må svikte
    // samtidig, og en policy som endres i morgen tar ikke med seg dette.
    const { data } = await supabase
      .from('ansatte')
      .select('id, navn')
      .eq('id', id)
      .eq('retailer_id', bruker.retailerId)
      .eq('aktiv', true)
      .is('slettet_tid', null)
      .maybeSingle<{ id: string; navn: string }>()

    if (!data) return null
    return { id: data.id, navn: data.navn }
  },
)

/**
 * Settes KUN etter at nummer og PIN er kontrollert.
 *
 * Lagrer ID-en og en signatur over den. Navnet sto her før, og det var
 * den delen kapselen ikke hadde noen rett til å bestemme.
 */
export async function settAktivAnsatt(a: { id: string }) {
  const nokkel = vaktnokkel()
  if (!nokkel) return
  ;(await cookies()).set(
    COOKIE,
    JSON.stringify({ id: a.id, sig: signer(nokkel, a.id) }),
    {
      httpOnly: true,
      sameSite: 'lax',
      path: '/',
      maxAge: 60 * 60 * 12, // én vakt
    },
  )
}

export async function fjernAktivAnsatt() {
  ;(await cookies()).delete(COOKIE)
}

// Stasjon for innlogget tablet/ansatt: aktiv ansatts stasjon, ellers første
// tilgjengelige (RLS scoper uansett). Tidligere duplisert i flere handlinger.
export async function hentStasjonId(supabase: SupabaseClient, ansatt: AktivAnsatt | null): Promise<string | null> {
  if (ansatt) {
    const { data } = await supabase.from('ansatte').select('stasjon_id').eq('id', ansatt.id).maybeSingle<{ stasjon_id: string }>()
    if (data?.stasjon_id) return data.stasjon_id
  }
  const { data } = await supabase.from('stasjoner').select('id').is('slettet_tid', null).limit(1).maybeSingle<{ id: string }>()
  return data?.id ?? null
}
