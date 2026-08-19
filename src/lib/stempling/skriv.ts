import type { SupabaseClient } from '@supabase/supabase-js'
import { avledVakter, type Hendelse, type Vakt } from './avled'
import { tellbareMinutter, type Pauseregel } from './pause'

// =====================================================================
// Hendelser inn, vakter ut, skrevet tilbake til `stempling`.
//
// Dette er leddet som gjør stemplingen verdt noe: uten det er en vakt på
// nettbrettet bare en rad ingen leser. Lønnsfila, bemanningsplanen,
// stillingsanslaget og innsynsutskriften leser alle `stempling`, og de
// skal fortsette å gjøre det uten å merke hvor timene kom fra.
//
// SKRIVER ALLTID, TELLER IKKE ALLTID. Radene får `kilde = 'tablet'` og
// legger seg ved siden av easy@work-importens rader. Hva som TELLES
// avgjøres av `stasjoner.stempling_kilde` gjennom `v_stempling_aktiv`
// (0111). Derfor kan en stasjon kjøre begge kilder en hel måned og
// avstemmes mot seg selv før flagget snus — det var slik de 27 prosentene
// på Bønes ble funnet.
//
// RE-AVLEDER ET VINDU, ikke én vakt. En korreksjon lagt inn i etterkant
// endrer hvilke vakter som finnes, ikke bare tidene i én av dem: en
// annullert innstempling kan slå to vakter sammen til én. Da må hele
// dagen regnes på nytt, og de gamle radene må vekk.
// =====================================================================

type Rad = {
  id: string; ansatt_nr: string; ansatt_navn: string
  stasjon_id: string; tidspunkt: string; type: 'inn' | 'ut'
}

export type Skriveresultat = {
  skrevet: number
  fjernet: number
  /** Vakter som ikke kunne skrives. Tom liste er det normale. */
  feil: string[]
}

/** Oslo-dato ut av et ISO-tidspunkt, som i avled.ts. */
const osloDato = new Intl.DateTimeFormat('sv-SE', {
  timeZone: 'Europe/Oslo', year: 'numeric', month: '2-digit', day: '2-digit',
})

/**
 * Hvor stort vindu som re-avledes rundt et tidspunkt.
 *
 * Ett døgn i hver ende, av samme grunn som i aapne.ts: en vakt som
 * krysser midnatt hører til datoen den STARTET. Regnet vi bare på selve
 * dagen, ville nattevakten falle utenfor og bli borte.
 */
const VINDU_DOGN = 1
const DAG = 86_400_000

export function vindu(rundt: Date): { fra: string; til: string } {
  return {
    fra: new Date(rundt.getTime() - VINDU_DOGN * DAG).toISOString(),
    til: new Date(rundt.getTime() + (VINDU_DOGN + 1) * DAG).toISOString(),
  }
}

/**
 * `Vakt` → rad i `stempling`.
 *
 * `fra_tid` og `til_tid` står som de ble stemplet — de er hva som
 * faktisk skjedde. Det er `minutter` som er lønnstallet, og det er der
 * pausen trekkes. Å barbere sluttiden i stedet ville skrevet et
 * klokkeslett som aldri fant sted, i noe som er
 * regnskapsdokumentasjon.
 */
export function tilStemplingsrad(v: Vakt, pause: Pauseregel) {
  return {
    stasjon_id: v.stasjonId,
    ansatt_nr: v.ansattNr,
    ansatt_navn: v.ansattNavn,
    dato: v.dato,
    fra_tid: v.fraTid,
    til_tid: v.tilTid,
    minutter: tellbareMinutter(v.minutter, pause),
    kilde: 'tablet',
    betalt: true,
  }
}

/**
 * Regner om vaktene rundt et tidspunkt og skriver dem til `stempling`.
 *
 * Kalles etter hver utstempling og etter hver korreksjon. Er det ingen
 * ferdige vakter i vinduet, gjør den ingenting — en åpen vakt har ingen
 * sluttid, og å skrive den ville betydd å gjette hva noen skal ha betalt.
 */
export async function skrivAvledteVakter(
  supabase: SupabaseClient,
  stasjonId: string,
  ansattNr: string,
  rundt: Date,
): Promise<Skriveresultat> {
  const { fra, til } = vindu(rundt)
  const feil: string[] = []

  // Pauseregelen ligger på kjeden (0110). Standard er at pausen er
  // betalt: med én til to på jobb kan folk sjelden forlate stasjonen, og
  // da er den arbeidstid etter aml. § 10-9.
  //
  // Feiler oppslaget, regner vi pausen som BETALT. Det er den trygge
  // veien å ta feil på — den gir henne timene, og et for høyt tall
  // oppdages i avstemmingen mot easy@work. Et for lavt tall oppdages på
  // lønnsslippen hennes, av henne, en måned senere.
  const { data: kjede } = await supabase
    .from('retailers').select('stempling_pause_betalt')
    .maybeSingle<{ stempling_pause_betalt: boolean }>()
  const pause: Pauseregel = { betalt: kjede?.stempling_pause_betalt ?? true }

  const { data, error } = await supabase
    .from('stempling_hendelse')
    .select('id, ansatt_nr, ansatt_navn, stasjon_id, tidspunkt, type')
    .eq('stasjon_id', stasjonId)
    .eq('ansatt_nr', ansattNr)
    .is('annullert_tid', null)
    .gte('tidspunkt', fra)
    .lt('tidspunkt', til)
    .order('tidspunkt')

  if (error) return { skrevet: 0, fjernet: 0, feil: [error.message] }

  const hendelser: Hendelse[] = ((data ?? []) as Rad[]).map((r) => ({
    id: r.id,
    ansattNr: r.ansatt_nr,
    ansattNavn: r.ansatt_navn,
    stasjonId: r.stasjon_id,
    tidspunkt: r.tidspunkt,
    type: r.type,
  }))

  const { vakter } = avledVakter(hendelser)

  // Datoene vi faktisk rører. Bare disse ryddes — et bredere slett ville
  // tatt rader utenfor vinduet vi nettopp regnet på, og de ville ikke
  // blitt skrevet tilbake.
  const datoer = [...new Set([
    ...vakter.map((v) => v.dato),
    // Er alle vakter borte etter en korreksjon, står det likevel rader
    // igjen som må vekk. Derfor tas dagene i vinduet med, ikke bare de
    // som ga vakter.
    ...hendelser.map((h) => osloDato.format(new Date(h.tidspunkt))),
  ])].sort()

  if (datoer.length === 0) return { skrevet: 0, fjernet: 0, feil }

  // RYDD FØRST, SKRIV ETTERPÅ. En korreksjon kan flytte starttidspunktet,
  // og da får vakta en ny (dato, fra_tid) — den gamle raden ville blitt
  // stående og telt en gang til. Bare våre egne rader røres: `kilde`
  // skiller dem fra easy@work-importens, som er fasit fram til stasjonen
  // er snudd.
  const { error: slettfeil, count } = await supabase
    .from('stempling')
    .delete({ count: 'exact' })
    .eq('stasjon_id', stasjonId)
    .eq('ansatt_nr', ansattNr)
    .eq('kilde', 'tablet')
    .in('dato', datoer)
  if (slettfeil) return { skrevet: 0, fjernet: 0, feil: [slettfeil.message] }

  if (vakter.length === 0) return { skrevet: 0, fjernet: count ?? 0, feil }

  const { error: skrivfeil } = await supabase
    .from('stempling')
    .insert(vakter.map((v) => tilStemplingsrad(v, pause)))
  if (skrivfeil) feil.push(skrivfeil.message)

  return {
    skrevet: skrivfeil ? 0 : vakter.length,
    fjernet: count ?? 0,
    feil,
  }
}
