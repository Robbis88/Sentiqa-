'use server'
import { revalidatePath } from 'next/cache'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { hashPin, lesAktivAnsatt, hentStasjonId } from '@/lib/ansatt'
import { nesteRetning, harStaattLenge } from '@/lib/stempling/tilstand'
import { skrivAvledteVakter } from '@/lib/stempling/skriv'

/** Raden `verifiser_ansatt_pin` gir. Hashen er ikke med - det er hele poenget. */
type Verifikasjon = { ansatt_id: string | null; status: 'ok' | 'avvist' | 'sperret'; vent_sekunder: number }

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

  // VERIFISERINGEN LIGGER I BASEN (0112). `pin_hash` er ikke lenger
  // lesbar for klientrollen: en nettbrettsesjon kunne ellers hente
  // hashene til alle kolleger paa stasjonen og knekke dem offline.
  //
  // Funksjonen slaar opp paa NUMMER, sammenligner hashen inne i basen,
  // teller forsoek og skriver revisjonssporet. Den returnerer id-en ved
  // treff - aldri hashen.
  //
  // Hashen regnes fortsatt ut her i Node. Da slipper PIN-en aldri inn i
  // en databasesporring, og dermed heller ikke inn i en sporringslogg.
  const { data: svar } = await supabase.rpc('verifiser_ansatt_pin', {
    p_ansatt_nr: nummer,
    p_pin_hash: hashPin(bruker.retailerId, pin),
    p_kilde: 'stempling',
  })
  const rad = (svar as Verifikasjon[] | null)?.[0]

  // PAUSEN ER ET EGET SVAR, og den lekker ingenting: forsoek telles paa
  // nummeret som ble tastet, ogsaa naar ingen har det nummeret. Uten et
  // eget svar ville hun staatt og tastet riktig kode om og om igjen.
  if (rad?.status === 'sperret') {
    const min = Math.max(1, Math.ceil(rad.vent_sekunder / 60))
    return { feil: `For mange forsøk. Prøv igjen om ${min} ${min === 1 ? 'minutt' : 'minutter'}.` }
  }
  // Samme melding for ukjent nummer og feil PIN. Ellers kan man prove
  // seg fram til hvilke numre som finnes.
  if (!rad || rad.status !== 'ok' || !rad.ansatt_id) {
    return { feil: 'Fant ingen med det nummeret og den PIN-en.' }
  }

  // Navnet og hjemstasjonen hentes ETTER at identiteten er bevist. Begge
  // kolonnene er fortsatt lesbare for klientrollen; det var bare `pin_hash`
  // som maatte bak funksjonen.
  const { data: ansatt } = await supabase
    .from('ansatte')
    .select('navn, stasjon_id')
    .eq('id', rad.ansatt_id)
    .maybeSingle<{ navn: string; stasjon_id: string }>()
  if (!ansatt) return { feil: 'Fant ingen med det nummeret og den PIN-en.' }

  // Stasjonen er nettbrettets, ikke den ansattes hjemstasjon: folk
  // jobber paa tvers i clusteret, og timene hoerer til der arbeidet skjedde.
  const aktiv = await lesAktivAnsatt(supabase)
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

  // Vakta er ferdig — regn den om til timer i `stempling`, som lonnsfila
  // og bemanningsplanen leser. Bare ved utstempling: en aapen vakt har
  // ingen sluttid.
  //
  // FEILER STILLE, MED VILJE. Hendelsen ER lagret, og den er fasit;
  // avledningen kan kjores om igjen. Aa si «ble ikke registrert» her
  // ville vaert usant og faatt henne til aa stemple en gang til, som
  // lager et dobbel_inn-avvik butikksjefen maa rydde.
  if (retning === 'ut') {
    await skrivAvledteVakter(supabase, stasjonId, nummer, naa)
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
