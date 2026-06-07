'use server'
import { randomUUID } from 'node:crypto'
import { revalidatePath } from 'next/cache'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { parseFaktura, lagForhandlingsutkast } from '@/lib/ai/faktura'

const BUCKET = 'fakturaer'
const GYLDIG = ['application/pdf', 'image/png', 'image/jpeg']

export type FakturaTilstand = { ok?: true; leverandor?: string; feil?: string } | undefined

export async function lastOppFaktura(
  _t: FakturaTilstand,
  formData: FormData,
): Promise<FakturaTilstand> {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin' || !bruker.retailerId) {
    return { feil: 'Bare eier kan bruke Avtalevokter.' }
  }
  const fil = formData.get('faktura')
  if (!(fil instanceof File) || fil.size === 0) return { feil: 'Velg en faktura (PDF eller bilde).' }
  if (!GYLDIG.includes(fil.type)) return { feil: 'Kun PDF, PNG eller JPG.' }
  const stasjonId = String(formData.get('stasjon_id') ?? '') || null

  const buffer = Buffer.from(await fil.arrayBuffer())
  const sti = `${bruker.retailerId}/${randomUUID()}-${fil.name}`
  const supabase = await lagSupabaseServerKlient()

  const opp = await supabase.storage.from(BUCKET).upload(sti, buffer, { contentType: fil.type })
  if (opp.error) return { feil: `Opplasting feilet: ${opp.error.message}` }

  const parsed = await parseFaktura(buffer, fil.type)
  if (!parsed) {
    await supabase.storage.from(BUCKET).remove([sti])
    return { feil: 'Kunne ikke lese fakturaen (mangler AI-nøkkel, eller uleselig fil).' }
  }

  const { error } = await supabase.from('fakturaer').insert({
    retailer_id: bruker.retailerId,
    stasjon_id: stasjonId,
    leverandor: parsed.leverandor,
    kategori: parsed.kategori,
    faktura_dato: parsed.faktura_dato || null,
    belop_kr: parsed.belop_kr,
    beskrivelse: parsed.beskrivelse,
    storage_sti: sti,
    parsedata: parsed,
    opprettet_av: bruker.id,
  })
  if (error) return { feil: error.message }

  revalidatePath('/avtalevokter')
  return { ok: true, leverandor: parsed.leverandor }
}

export async function forhandling(formData: FormData): Promise<{ ok: boolean; utkast?: string; feil?: string }> {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin') return { ok: false, feil: 'Ikke tilgang.' }
  const leverandor = String(formData.get('leverandor') ?? '')
  if (!leverandor) return { ok: false, feil: 'Mangler leverandør.' }

  const supabase = await lagSupabaseServerKlient()
  const { data } = await supabase
    .from('fakturaer')
    .select('kategori, belop_kr, faktura_dato, stasjon_id, beskrivelse, stasjoner(navn, butikknummer)')
    .eq('leverandor', leverandor)
    .is('slettet_tid', null)
    .overrideTypes<{ kategori: string | null; belop_kr: number | null; faktura_dato: string | null; stasjon_id: string | null; beskrivelse: string | null; stasjoner: { navn: string; butikknummer: string } | null }[]>()

  const fakturaer = data ?? []
  if (fakturaer.length === 0) return { ok: false, feil: 'Ingen fakturaer for leverandøren.' }

  // Antar fakturaene er periodiske; grovt årlig estimat = sum (kan justeres senere).
  const total = fakturaer.reduce((a, f) => a + (f.belop_kr ?? 0), 0)
  const stasjoner = new Set(fakturaer.map((f) => f.stasjon_id).filter(Boolean))
  const detaljer = fakturaer
    .map((f) => `- ${f.stasjoner ? `${f.stasjoner.butikknummer} ${f.stasjoner.navn}` : 'ukjent stasjon'}: ${Math.round(f.belop_kr ?? 0)} kr (${f.faktura_dato ?? '?'})`)
    .join('\n')

  const utkast = await lagForhandlingsutkast(
    leverandor,
    fakturaer[0].kategori ?? 'leverandør',
    total,
    stasjoner.size || 1,
    detaljer,
  )
  return { ok: true, utkast }
}
