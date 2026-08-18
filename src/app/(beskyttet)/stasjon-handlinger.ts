'use server'
import { cookies } from 'next/headers'
import { revalidatePath } from 'next/cache'

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
}
