'use server'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { kvitter, type Kvittering } from '@/lib/kvittering'

// =====================================================================
// TALLENE INGEN FIL LEVERER
//
// To ting kommer ikke inn av seg selv, og begge gjør bruttofortjenesten
// og lønnskosten feil så lenge de mangler:
//
//   bilvask    abonnementene betales rett til konto, så kassa ser dem
//              ikke. Rapporten kommer på e-post, én gang i uka.
//   fastlønn   BP-en fører kjedesnittet, og regnskapets konto 501
//              finnes først når måneden er avlagt.
//
// Begge skrives med `upsert` på sin naturlige nøkkel. Det gjør at samme
// uke kan rettes uten at noen må slette først — og at to personer som
// legger inn samme uke ender med ett tall, ikke to.
// =====================================================================

const tall = (fd: FormData, felt: string): number | null => {
  // Norsk tastatur gir komma. Et beløp som blir NaN og lagres som 0 er
  // verre enn et som avvises: null kroner ser ut som en rolig uke.
  const raa = String(fd.get(felt) ?? '').trim().replace(/\s/g, '').replace(',', '.')
  if (raa === '') return null
  const n = Number(raa)
  return Number.isFinite(n) ? n : null
}

const heltall = (fd: FormData, felt: string): number | null => {
  const n = tall(fd, felt)
  return n !== null && Number.isInteger(n) ? n : null
}

/**
 * Ukas abonnementsinntekt på bilvask.
 *
 * BÅDE EIER OG BUTIKKSJEF. Rapporten kommer ukentlig, og den som er på
 * jobb skal kunne legge den inn. Policyen i `0184` slipper begge til.
 */
export async function lagreBilvask(_forrige: unknown, fd: FormData): Promise<Kvittering> {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin' && bruker.rolle !== 'butikksjef') {
    return { feil: 'Bare eier og butikksjef kan legge inn bilvask.' }
  }

  const stasjonId = String(fd.get('stasjon') ?? '').trim()
  const ar = heltall(fd, 'ar')
  const uke = heltall(fd, 'uke')
  const belop = tall(fd, 'belop')

  if (!stasjonId) return { feil: 'Velg en stasjon.' }
  if (ar === null || ar < 2000 || ar > 2100) return { feil: 'Året må være et tall.' }
  if (uke === null || uke < 1 || uke > 53) return { feil: 'Uka må være mellom 1 og 53.' }
  if (belop === null || belop < 0) return { feil: 'Beløpet må være et tall.' }

  const supabase = await lagSupabaseServerKlient()
  return kvitter(
    supabase.from('bilvask_abonnement').upsert({
      retailer_id: bruker.retailerId,
      stasjon_id: stasjonId,
      ar,
      uke,
      belop_kr: belop,
      registrert_av: bruker.id,
      oppdatert_tid: new Date().toISOString(),
      slettet_tid: null,
    }, { onConflict: 'stasjon_id,ar,uke', count: 'exact' }),
    {
      hva: 'lagre bilvasken',
      ok: `Uke ${uke} er lagret. 75 % av beløpet regnes som bruttofortjeneste.`,
      oppfrisk: ['/lonnskost'],
    },
  )
}

/**
 * Butikksjefens grunnlønn for en måned.
 *
 * EIERENS ALENE. Raden peker på én navngitt person — stasjonen har én
 * butikksjef — og butikksjefen ble stengt ute fra konto 501 nettopp
 * fordi den raden var én persons lønn. Sjekken her speiler policyen i
 * `0185`, som er den som faktisk håndhever det.
 */
export async function lagreFastlonn(_forrige: unknown, fd: FormData): Promise<Kvittering> {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin') {
    return { feil: 'Bare eier kan legge inn grunnlønn.' }
  }

  const stasjonId = String(fd.get('stasjon') ?? '').trim()
  const ar = heltall(fd, 'ar')
  const maned = heltall(fd, 'maned')
  const grunnlonn = tall(fd, 'grunnlonn')

  if (!stasjonId) return { feil: 'Velg en stasjon.' }
  if (ar === null || ar < 2000 || ar > 2100) return { feil: 'Året må være et tall.' }
  if (maned === null || maned < 1 || maned > 12) return { feil: 'Måneden må være 1–12.' }
  if (grunnlonn === null || grunnlonn < 0) return { feil: 'Grunnlønna må være et tall.' }

  const supabase = await lagSupabaseServerKlient()
  return kvitter(
    supabase.from('butikksjef_fastlonn').upsert({
      retailer_id: bruker.retailerId,
      stasjon_id: stasjonId,
      ar,
      maned,
      grunnlonn_kr: grunnlonn,
      registrert_av: bruker.id,
      oppdatert_tid: new Date().toISOString(),
      slettet_tid: null,
    }, { onConflict: 'stasjon_id,ar,maned', count: 'exact' }),
    {
      hva: 'lagre grunnlønna',
      ok: 'Grunnlønna er lagret. Feriepenger, avgift og pensjon regnes av den.',
      oppfrisk: ['/lonnskost'],
    },
  )
}
