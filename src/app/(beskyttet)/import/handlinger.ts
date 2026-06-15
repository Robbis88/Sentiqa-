'use server'
import { randomUUID, createHash } from 'node:crypto'
import { revalidatePath } from 'next/cache'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'

const BUCKET = 'raa-filer'

export type OpplastingTilstand =
  | { ok: true; antall: number; hoppet: number; feilet: string[] }
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
  let hoppet = 0
  const feilet: string[] = []

  // Per-fil-isolasjon: en duplikat eller én rar fil HOPPER VI OVER og fortsetter
  // — aldri stopp hele bunken på grunn av én. Last opp 5, har 1 → 4 inn, 1 hoppet.
  for (const fil of filer) {
    try {
      const bytes = Buffer.from(await fil.arrayBuffer())
      const sha256 = createHash('sha256').update(bytes).digest('hex')
      const sti = `${bruker.retailerId}/${randomUUID()}-${fil.name}`

      const opplasting = await supabase.storage
        .from(BUCKET)
        .upload(sti, bytes, { contentType: fil.type || 'application/octet-stream' })
      if (opplasting.error) { feilet.push(`${fil.name}: ${opplasting.error.message}`); continue }

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
        await supabase.storage.from(BUCKET).remove([sti]) // rydd opp ved DB-feil
        if (filFeil.code === '23505') { hoppet++; continue } // allerede lastet opp → hopp over
        feilet.push(`${fil.name}: ${filFeil.message}`); continue
      }

      const { error: jobbFeil } = await supabase.from('import_jobber').insert({
        raa_fil_id: raaFil.id,
        retailer_id: bruker.retailerId,
      })
      if (jobbFeil) { feilet.push(`${fil.name}: ${jobbFeil.message}`); continue }

      antall++
    } catch (e) {
      feilet.push(`${fil.name}: ${e instanceof Error ? e.message : String(e)}`)
    }
  }

  revalidatePath('/import')
  return { ok: true, antall, hoppet, feilet }
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
