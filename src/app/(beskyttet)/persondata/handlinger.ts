'use server'
import { revalidatePath } from 'next/cache'
import * as z from 'zod'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { loggOppslag } from '@/lib/personvern/logg'

export type Tilstand = { ok?: string; feil?: string } | undefined

const Frist = z.object({
  // 12 måneder er gulvet fordi lønnsgrunnlag uansett må ligge lenger;
  // 240 er taket fordi «for alltid» ikke er en oppbevaringstid.
  maaneder: z.coerce.number<string>().int().min(12).max(240),
})

export async function lagreFrist(_t: Tilstand, fd: FormData): Promise<Tilstand> {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin' || !bruker.retailerId) {
    return { feil: 'Bare eier kan endre oppbevaringstiden.' }
  }
  const felt = Frist.safeParse({ maaneder: fd.get('maaneder') })
  if (!felt.success) return { feil: 'Oppbevaringstiden må være mellom 12 og 240 måneder.' }

  const supabase = await lagSupabaseServerKlient()
  const { error } = await supabase.from('retailers')
    .update({ oppbevaring_maaneder: felt.data.maaneder }).eq('id', bruker.retailerId)
  if (error) return { feil: error.message }
  revalidatePath('/persondata')
  return { ok: `Oppbevaringstid satt til ${felt.data.maaneder} måneder` }
}

const Slett = z.object({
  stasjon_id: z.string().uuid(),
  ansatt_nr: z.string().min(1),
  // Navnet må skrives inn på nytt. Sletting er endelig, og et
  // bekreftelsesfelt som bare sier «ja» er ikke en bekreftelse.
  bekreft: z.string().min(1),
})

/**
 * Sletter alt om én person som har passert oppbevaringsfristen.
 *
 * Rekkefølgen er med vilje: Storage FØRST, deretter radene.
 *
 * Feiler noe underveis, er det bedre å sitte igjen med en kontraktsrad
 * uten dokument enn med et dokument ingen vet finnes. Det første er
 * synlig og kan ryddes; det andre er personopplysninger vi har sagt at
 * vi slettet.
 */
export async function slettPerson(_t: Tilstand, fd: FormData): Promise<Tilstand> {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin') return { feil: 'Bare eier kan slette persondata.' }

  const felt = Slett.safeParse({
    stasjon_id: fd.get('stasjon_id'),
    ansatt_nr: fd.get('ansatt_nr'),
    bekreft: fd.get('bekreft'),
  })
  if (!felt.success) return { feil: 'Skriv navnet for å bekrefte.' }

  const supabase = await lagSupabaseServerKlient()
  const { data: person } = await supabase
    .from('v_persondata_alder').select('navn')
    .eq('stasjon_id', felt.data.stasjon_id).eq('ansatt_nr', felt.data.ansatt_nr)
    .maybeSingle<{ navn: string }>()
  if (!person) return { feil: 'Fant ingen data for denne ansatte.' }
  if (felt.data.bekreft.trim().toLowerCase() !== person.navn.trim().toLowerCase()) {
    return { feil: `Skriv «${person.navn}» nøyaktig for å bekrefte.` }
  }

  const { data: filer } = await supabase
    .from('ansatt_kontrakt').select('storage_sti')
    .eq('stasjon_id', felt.data.stasjon_id).eq('ansatt_nr', felt.data.ansatt_nr)
    .not('storage_sti', 'is', null)
  const stier = ((filer ?? []) as { storage_sti: string }[]).map((f) => f.storage_sti)
  if (stier.length > 0) {
    const { error } = await supabase.storage.from('raa-filer').remove(stier)
    if (error) return { feil: `Fikk ikke slettet signerte dokumenter: ${error.message}` }
  }

  const { data, error } = await supabase.rpc('slett_person', {
    p_stasjon: felt.data.stasjon_id,
    p_ansatt_nr: felt.data.ansatt_nr,
  })
  if (error) return { feil: error.message }

  const r = data as { stemplinger: number; kontrakter: number; ansattkort: number } | null

  // Loggen overlever slettingen med vilje: den skal kunne vise HVEM som
  // slettet, ogsaa etter at dataene er borte. Den beholder navn og
  // ansattnummer, ikke opplysningene.
  await loggOppslag(supabase, {
    retailerId: bruker.retailerId ?? '',
    stasjonId: felt.data.stasjon_id,
    ansattNr: felt.data.ansatt_nr,
    ansattNavn: person.navn,
    handling: 'persondata_slettet',
    brukerId: bruker.id,
    brukerNavn: bruker.fulltNavn,
    detaljer: { ...(r ?? {}), dokumenter: stier.length },
  })
  revalidatePath('/persondata')
  return {
    ok: `${person.navn} slettet — ${r?.stemplinger ?? 0} stemplinger, `
      + `${r?.kontrakter ?? 0} kontrakter, ${r?.ansattkort ?? 0} ansattkort`
      + `${stier.length > 0 ? `, ${stier.length} dokumenter` : ''}`,
  }
}
