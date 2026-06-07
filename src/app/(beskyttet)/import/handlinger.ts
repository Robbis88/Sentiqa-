'use server'
import { randomUUID, createHash } from 'node:crypto'
import { revalidatePath } from 'next/cache'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'

const BUCKET = 'raa-filer'

export type OpplastingTilstand =
  | { ok: true; antall: number }
  | { ok: false; feil: string }
  | undefined

// Drop-zone (§6 reserve-inntak). Kun retailer_admin. Lagrer rå fil i Storage
// og oppretter en import-jobb med status 'mottatt'. Parsing skjer i eget lag.
export async function lastOppFiler(
  _tilstand: OpplastingTilstand,
  formData: FormData,
): Promise<OpplastingTilstand> {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin' || !bruker.retailerId) {
    return { ok: false, feil: 'Bare eier kan laste opp filer.' }
  }

  const filer = formData.getAll('filer').filter((f): f is File => f instanceof File && f.size > 0)
  if (filer.length === 0) return { ok: false, feil: 'Velg minst én fil.' }

  const supabase = await lagSupabaseServerKlient()
  let antall = 0

  for (const fil of filer) {
    const bytes = Buffer.from(await fil.arrayBuffer())
    const sha256 = createHash('sha256').update(bytes).digest('hex')
    const sti = `${bruker.retailerId}/${randomUUID()}-${fil.name}`

    const opplasting = await supabase.storage
      .from(BUCKET)
      .upload(sti, bytes, { contentType: fil.type || 'application/octet-stream' })
    if (opplasting.error) {
      return { ok: false, feil: `Opplasting feilet: ${opplasting.error.message}` }
    }

    const { data: raaFil, error: filFeil } = await supabase
      .from('raa_filer')
      .insert({
        retailer_id: bruker.retailerId,
        filnavn: fil.name,
        storage_bucket: BUCKET,
        storage_sti: sti,
        mottakskanal: 'drop_zone',
        storrelse_bytes: bytes.length,
        sha256,
      })
      .select('id')
      .single()

    if (filFeil) {
      // Rydd opp den opplastede filen ved DB-feil (f.eks. duplikat-sha)
      await supabase.storage.from(BUCKET).remove([sti])
      if (filFeil.code === '23505') {
        return { ok: false, feil: `"${fil.name}" er allerede lastet opp tidligere.` }
      }
      return { ok: false, feil: filFeil.message }
    }

    const { error: jobbFeil } = await supabase.from('import_jobber').insert({
      raa_fil_id: raaFil.id,
      retailer_id: bruker.retailerId,
    })
    if (jobbFeil) return { ok: false, feil: jobbFeil.message }

    antall++
  }

  revalidatePath('/import')
  return { ok: true, antall }
}

// Avsender-allowlist for e-post-inntak (§6).
export async function settAllowlist(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin' || !bruker.retailerId) return
  const raw = String(formData.get('allowlist') ?? '')
  const liste = [...new Set(raw.split(/[\n,;]+/).map((s) => s.trim().toLowerCase()).filter(Boolean))]
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('retailers').update({ avsender_allowlist: liste }).eq('id', bruker.retailerId)
  revalidatePath('/import')
}
