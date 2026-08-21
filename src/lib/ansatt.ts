import 'server-only'
import { createHash } from 'node:crypto'
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

export type AktivAnsatt = { id: string; navn: string }

/**
 * Hvem står på vakt akkurat nå — verifisert, ikke husket.
 *
 * Kapselen sier hvem den PÅSTÅR at det er. Denne funksjonen slår opp
 * påstanden og godtar den bare hvis raden fortsatt finnes, hører til
 * innlogget brukers kjede, er aktiv og ikke slettet.
 *
 * NAVNET KOMMER FRA BASEN, ikke fra kapselen. Ellers kunne en skrevet
 * kapsel sette et navn systemet så viste som om det var kjent — og et
 * navn på skjermen er nettopp det som får folk til å stole på at riktig
 * person er logget på.
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
    const raw = (await cookies()).get(COOKIE)?.value
    if (!raw) return null

    let paastand: { id?: unknown }
    try {
      paastand = JSON.parse(raw) as { id?: unknown }
    } catch {
      return null
    }
    const id = paastand?.id
    if (typeof id !== 'string' || id.length === 0) return null

    const bruker = await hentInnloggetBruker()
    if (!bruker.retailerId) return null

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
 * Lagrer bare ID-en. Navnet sto her før, og det var den delen kapselen
 * ikke hadde noen rett til å bestemme.
 */
export async function settAktivAnsatt(a: { id: string }) {
  ;(await cookies()).set(COOKIE, JSON.stringify({ id: a.id }), {
    httpOnly: true,
    sameSite: 'lax',
    path: '/',
    maxAge: 60 * 60 * 12, // én vakt
  })
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
