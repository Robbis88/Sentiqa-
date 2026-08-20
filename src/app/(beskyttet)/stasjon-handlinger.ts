'use server'
import { cookies, headers } from 'next/headers'
import { revalidatePath } from 'next/cache'
import { redirect } from 'next/navigation'
import { URL_HODE } from '@/lib/supabase/proxy'

// Navnet ligger i lib/stasjonskontekst.ts. En 'use server'-fil kan BARE
// eksportere async funksjoner — en konstant her brekker bygget, fordi
// alt som eksporteres blir et handlingsendepunkt.
import { STASJONSKAPSEL } from '@/lib/stasjonskontekst'

/**
 * Husker hvilken stasjon brukeren ser på.
 *
 * En informasjonskapsel, ikke databasen: valget er en visningstilstand,
 * ikke en opplysning om personen. Bytter hun maskin, starter hun på
 * standardvalget — det er riktig oppførsel, ikke en mangel.
 *
 * `revalidatePath('/', 'layout')` framfor den enkelte siden: valget
 * gjelder overalt, og uten dette ville brukeren byttet stasjon i
 * toppstripen mens innholdet under sto på den gamle.
 */
export async function settStasjon(formData: FormData) {
  const id = String(formData.get('stasjon') ?? '').trim()
  if (!id) return
  const k = await cookies()
  k.set(STASJONSKAPSEL, id, {
    path: '/',
    sameSite: 'lax',
    httpOnly: true,
    maxAge: 60 * 60 * 24 * 365,
  })
  revalidatePath('/', 'layout')

  // ET KLIKK NÅ SLÅR EN URL FRA I GÅR.
  //
  // URL-en vinner over hukommelsen — riktig for en delt lenke, og feil i
  // det sekundet brukeren selv velger noe annet i toppstripen. Sto det
  // `?butikknummer=4177` i adressefeltet, ville parameteren overstyrt
  // valget hennes og klikket sett dødt ut.
  //
  // Derfor fjernes stasjonsparameteren når hun velger selv. Det skjer
  // her, på serveren, og ikke med en `router.replace` i nettleseren:
  // klientveien var et kappløp mot navigeringen, og den tapte av og til.
  const url = (await headers()).get(URL_HODE) ?? ''
  const [sti, spor = ''] = url.split('?')
  const igjen = new URLSearchParams(spor)
  if (igjen.has('stasjon') || igjen.has('butikknummer')) {
    igjen.delete('stasjon')
    igjen.delete('butikknummer')
    const rest = igjen.toString()
    redirect(rest ? `${sti}?${rest}` : sti)
  }
}
