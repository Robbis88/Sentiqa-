import { lagSupabaseAdminKlient } from '@/lib/supabase/admin'
import { beregnAbonnement } from '@/lib/pris'
import { rapporterBruk } from '@/lib/kontrollrom'

/**
 * Daglig (se vercel.json): rapporterer kjeder + månedspris + antall til
 * kontrollrommet. Krever CRON_SECRET kun hvis satt.
 */
export async function GET(request: Request) {
  if (process.env.CRON_SECRET) {
    const auth = request.headers.get('authorization')
    if (auth !== `Bearer ${process.env.CRON_SECRET}`) {
      return new Response('Unauthorized', { status: 401 })
    }
  }

  const admin = lagSupabaseAdminKlient()

  const { data: retailers } = await admin
    .from('retailers')
    .select('id, navn, faktura_epost, premium_avtalevokter')
    .is('slettet_tid', null)

  const { data: stasjoner } = await admin
    .from('stasjoner')
    .select('retailer_id')
    .is('slettet_tid', null)

  const antallPerKjede = new Map<string, number>()
  for (const s of stasjoner ?? []) {
    const id = (s as { retailer_id: string }).retailer_id
    antallPerKjede.set(id, (antallPerKjede.get(id) ?? 0) + 1)
  }

  const abonnement = (retailers ?? []).map((r) => {
    const stns = antallPerKjede.get(r.id) ?? 0
    const { maaned } = beregnAbonnement(stns, r.premium_avtalevokter)
    return {
      ekstern_ref: r.id,
      navn: r.navn,
      epost: r.faktura_epost,
      belop: maaned,
      intervall: 'mnd' as const,
      status: 'active' as const,
    }
  })

  const ok = await rapporterBruk({
    antall_brukere: retailers?.length ?? 0,
    abonnement,
  })

  return Response.json({ ok, antall: abonnement.length })
}
