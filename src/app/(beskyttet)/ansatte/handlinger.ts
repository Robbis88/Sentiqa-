'use server'
import { revalidatePath } from 'next/cache'
import * as z from 'zod'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { hashPin } from '@/lib/ansatt'

// Ansattnummeret kommer fra AZETS, ikke herfra og ikke fra easy@work.
// Derfor er det valgfritt ved opprettelse: en ny ansatt finnes hos oss
// før hun finnes i lønnssystemet, og et felt som krever et nummer ingen
// har ennå, blir fylt med et påfunn som senere må ryddes.
//
// Uten nummer kan hun ikke stemple og kommer ikke i lønnsfila. Det står
// på lista som noe som mangler, ikke som en feil.
const Ny = z.object({
  navn: z.string().min(1, { error: 'Skriv inn navn.' }),
  stasjon_id: z.string().uuid({ error: 'Velg stasjon.' }),
  pin: z.string().regex(/^\d{4,6}$/, { error: 'PIN må være 4–6 siffer.' }),
  ansatt_nr: z.string().regex(/^\d{1,10}$/, { error: 'Ansattnummer må være siffer.' })
    .optional(),
})

export type AnsattTilstand = { ok?: true; feil?: string } | undefined

export async function leggTilAnsatt(_t: AnsattTilstand, formData: FormData): Promise<AnsattTilstand> {
  const bruker = await hentInnloggetBruker()
  if ((!erLeder(bruker.rolle)) || !bruker.retailerId) {
    return { feil: 'Ikke tilgang.' }
  }
  const raaNr = String(formData.get('ansatt_nr') ?? '').trim()
  const felt = Ny.safeParse({
    navn: formData.get('navn'),
    stasjon_id: formData.get('stasjon_id'),
    pin: formData.get('pin'),
    ansatt_nr: raaNr === '' ? undefined : raaNr,
  })
  if (!felt.success) return { feil: z.prettifyError(felt.error) }

  const supabase = await lagSupabaseServerKlient()
  const { error } = await supabase.from('ansatte').insert({
    retailer_id: bruker.retailerId,
    stasjon_id: felt.data.stasjon_id,
    navn: felt.data.navn,
    ansatt_nr: felt.data.ansatt_nr ?? null,
    pin_hash: hashPin(bruker.retailerId, felt.data.pin),
    opprettet_av: bruker.id,
  })
  if (error) return { feil: forklarFeil(error.message) }
  revalidatePath('/ansatte')
  return { ok: true }
}

/**
 * Én melding for begge indeksene — med vilje, og med et tap.
 *
 * FØR: «PIN er allerede i bruk — velg en annen.» Den var vennlig, og
 * den bekreftet en hemmelighet. En butikksjef kunne prøve seg fram og
 * kartlegge hvilke PIN-er som er i bruk i hele kjeden, fire siffer om
 * gangen. Så lenge PIN var identiteten på nettbrettet, var det nok til
 * å logge på som noen.
 *
 * TAPET, SOM SKAL STÅ SKREVET: den forrige utgaven het at hun ellers
 * måtte gjette hvilket felt som var galt, og at det vanlige gjettet er
 * PIN. Det argumentet er fortsatt riktig. Meldingen nevner derfor BEGGE
 * årsakene i stedet for å velge én — hun kan fortsatt rette feilen, men
 * svaret sier ikke hvilken av dem det var.
 *
 * Grunnen til at PIN-en må være unik i det hele tatt, er at den var et
 * databaseoppslag. Etter dette trinnet er den bare en hemmelighet, og
 * `ansatte_pin_unik` kan droppes. Det er en migrasjon, og hører til et
 * eget trinn.
 */
function forklarFeil(melding: string): string {
  if (/duplicate|unique/i.test(melding)) {
    return 'Kunne ikke lagre. Ansattnummeret eller PIN-en er allerede '
      + 'i bruk på en annen ansatt — velg en ny PIN, og sjekk nummeret '
      + 'mot Azets.'
  }
  return melding
}

const Nummer = z.object({
  id: z.string().uuid({ error: 'Ukjent ansatt.' }),
  ansatt_nr: z.string().regex(/^\d{1,10}$/, { error: 'Ansattnummer må være siffer.' }),
})

/**
 * Setter ansattnummeret på en som allerede finnes.
 *
 * Nummeret kommer fra Azets etter at den ansatte er opprettet, så dette
 * er den vanlige veien inn — ikke unntaket. Derfor står feltet i lista
 * og ikke bak en redigeringsside ingen finner.
 *
 * Nummeret kan ENDRES, ikke bare settes. Azets har rettet numre før, og
 * et felt som låser seg etter første lagring tvinger fram en ny ansatt
 * med samme navn — som er nøyaktig den tredje identiteten vi allerede
 * sliter med.
 */
export async function settAnsattnummer(
  _t: AnsattTilstand, formData: FormData,
): Promise<AnsattTilstand> {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return { feil: 'Ikke tilgang.' }

  const felt = Nummer.safeParse({
    id: formData.get('id'),
    ansatt_nr: String(formData.get('ansatt_nr') ?? '').trim(),
  })
  if (!felt.success) return { feil: z.prettifyError(felt.error) }

  const supabase = await lagSupabaseServerKlient()
  const { error } = await supabase
    .from('ansatte')
    .update({ ansatt_nr: felt.data.ansatt_nr })
    .eq('id', felt.data.id)
  if (error) return { feil: forklarFeil(error.message) }

  revalidatePath('/ansatte')
  return { ok: true }
}

export async function deaktiverAnsatt(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return
  const id = String(formData.get('id') ?? '')
  if (!id) return
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('ansatte').update({ aktiv: false, slettet_tid: new Date().toISOString() }).eq('id', id)
  revalidatePath('/ansatte')
}
