'use server'
import { revalidatePath } from 'next/cache'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { hashPin, lesAktivAnsatt, hentStasjonId } from '@/lib/ansatt'
import { nesteRetning, harStaattLenge } from '@/lib/stempling/tilstand'

export type StemplingSvar = {
  ok?: true
  navn?: string
  retning?: 'inn' | 'ut'
  klokkeslett?: string
  advarsel?: string
  feil?: string
}

const klokke = new Intl.DateTimeFormat('nb-NO', {
  timeZone: 'Europe/Oslo', hour: '2-digit', minute: '2-digit', hour12: false,
})

/**
 * Stempler inn eller ut.
 *
 * NUMMER OG PIN, ikke PIN alene. Ansattnummeret staar paa lonnsslippen
 * og vaktlista - det identifiserer, men er ingen hemmelighet. PIN-en
 * beviser. Slaar man opp paa PIN alene, kan hvem som helst som har sett
 * en kollegas firesifrede kode stemple som henne, og det er den
 * klassiske svindelen med stemplingsur.
 *
 * (Den eksisterende vakt-innsjekken i vakt-handlinger.ts gjor nettopp
 * det. Den er ikke endret her - det ville endret hvordan folk logger inn
 * i dag - men den boer folge etter.)
 *
 * FEILER HOYT. Gaar noe galt, sier vi det rett ut og ber henne si fra.
 * Ingen lokal ko: en stille ko som synkroniserer feil er verre enn en
 * synlig feil, fordi ingen oppdager den for lonna er kjort.
 */
export async function stemple(
  _t: StemplingSvar | undefined,
  formData: FormData,
): Promise<StemplingSvar> {
  const bruker = await hentInnloggetBruker()
  if (!bruker.retailerId) return { feil: 'Mangler tilgang.' }

  const nummer = String(formData.get('ansatt_nr') ?? '').trim()
  const pin = String(formData.get('pin') ?? '').trim()
  if (!nummer) return { feil: 'Skriv inn ansattnummeret ditt.' }
  if (!/^\d{4,6}$/.test(pin)) return { feil: 'PIN må være 4–6 siffer.' }

  const supabase = await lagSupabaseServerKlient()

  // Oppslag paa NUMMER. PIN-en sammenlignes etterpaa, saa to ansatte med
  // samme PIN ikke laser hverandre ute - slik de gjor i dagens
  // vakt-innsjekk, der maybeSingle() feiler paa flere treff og begge
  // faar «Ukjent PIN» uten aa skjonne hvorfor.
  const { data: ansatt } = await supabase
    .from('ansatte')
    .select('id, navn, pin_hash, stasjon_id')
    .eq('retailer_id', bruker.retailerId)
    .eq('ansatt_nr', nummer)
    .eq('aktiv', true)
    .is('slettet_tid', null)
    .maybeSingle<{ id: string; navn: string; pin_hash: string; stasjon_id: string }>()

  // Samme melding for ukjent nummer og feil PIN. Ellers kan man prove
  // seg fram til hvilke numre som finnes.
  if (!ansatt || ansatt.pin_hash !== hashPin(bruker.retailerId, pin)) {
    return { feil: 'Fant ingen med det nummeret og den PIN-en.' }
  }

  // Stasjonen er nettbrettets, ikke den ansattes hjemstasjon: folk
  // jobber paa tvers i clusteret, og timene hoerer til der arbeidet skjedde.
  const aktiv = await lesAktivAnsatt()
  const stasjonId = (await hentStasjonId(supabase, aktiv)) ?? ansatt.stasjon_id
  if (!stasjonId) return { feil: 'Nettbrettet vet ikke hvilken stasjon det står på.' }

  const { data: siste } = await supabase
    .from('stempling_hendelse')
    .select('type, tidspunkt')
    .eq('stasjon_id', stasjonId)
    .eq('ansatt_nr', nummer)
    .is('annullert_tid', null)
    .order('tidspunkt', { ascending: false })
    .limit(1)
    .maybeSingle<{ type: 'inn' | 'ut'; tidspunkt: string }>()

  const naa = new Date()
  const retning = nesteRetning(siste ?? null)
  const lenge = harStaattLenge(siste ?? null, naa)

  const { error } = await supabase.from('stempling_hendelse').insert({
    retailer_id: bruker.retailerId,
    stasjon_id: stasjonId,
    ansatt_nr: nummer,
    ansatt_navn: ansatt.navn,
    tidspunkt: naa.toISOString(),
    type: retning,
    kilde: 'tablet',
  })

  if (error) {
    // Hoyt og tydelig. Hun skal vite at det IKKE ble registrert.
    return { feil: 'Dette ble ikke registrert. Si fra til butikksjefen.' }
  }

  revalidatePath('/stempling')
  return {
    ok: true,
    navn: ansatt.navn,
    retning,
    klokkeslett: klokke.format(naa),
    advarsel: lenge
      ? 'Vakten din har stått åpen i over 16 timer. Si fra til butikksjefen om det ikke stemmer.'
      : undefined,
  }
}
