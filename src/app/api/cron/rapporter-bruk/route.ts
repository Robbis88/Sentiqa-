import { lagSupabaseAdminKlient } from '@/lib/supabase/admin'
import { beregnAbonnement } from '@/lib/pris'
import { rapporterBruk } from '@/lib/kontrollrom'
import { hentAlt } from '@/lib/paginer'

/**
 * Daglig (se vercel.json): rapporterer kjeder + månedspris + antall til
 * kontrollrommet. Fail-closed: krever gyldig CRON_SECRET (Vercel Cron) ELLER
 * KONTROLLROM_KEY (manuell trigger). Uten gyldig nøkkel -> 401, så ruten aldri
 * lekker kjeders navn/e-post/pris uautentisert.
 */
export async function GET(request: Request) {
  const auth = request.headers.get('authorization')
  const nokkel = request.headers.get('x-api-key')
  const okCron =
    !!process.env.CRON_SECRET && auth === `Bearer ${process.env.CRON_SECRET}`
  const okKey =
    !!process.env.KONTROLLROM_KEY && nokkel === process.env.KONTROLLROM_KEY
  if (!okCron && !okKey) {
    return new Response('Unauthorized', { status: 401 })
  }

  const admin = lagSupabaseAdminKlient()

  try {
    const [retailerAntall, stasjonAntall] = await Promise.all([
      admin.from('retailers').select('id', { count: 'exact', head: true }).is('slettet_tid', null),
      admin.from('stasjoner').select('id', { count: 'exact', head: true }).is('slettet_tid', null),
    ])
    if (retailerAntall.error || stasjonAntall.error || retailerAntall.count == null || stasjonAntall.count == null) {
      throw new Error('Mangler komplett antall')
    }
    const retailers = await hentAlt((fra, til) => admin
      .from('retailers')
      .select('id, navn, faktura_epost, premium_avtalevokter')
      .is('slettet_tid', null)
      .order('id').range(fra, til))

    const stasjoner = await hentAlt((fra, til) => admin
      .from('stasjoner')
      .select('id, retailer_id')
      .is('slettet_tid', null)
      .order('id').range(fra, til))

    if (retailers.length !== retailerAntall.count || stasjoner.length !== stasjonAntall.count
      || new Set(retailers.map(r => r.id)).size !== retailers.length
      || new Set(stasjoner.map(s => s.id)).size !== stasjoner.length) {
      throw new Error('Ufullstendig abonnementsgrunnlag')
    }

    const antallPerKjede = new Map<string, number>()
    for (const s of stasjoner) {
      const id = (s as { retailer_id: string }).retailer_id
      antallPerKjede.set(id, (antallPerKjede.get(id) ?? 0) + 1)
    }

    const abonnement = retailers.map((r) => {
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
      antall_brukere: retailers.length,
      abonnement,
    })

    return Response.json({ ok, antall: abonnement.length }, { status: ok ? 200 : 502 })
  } catch {
    // En ufullstendig fullsynk kan fjerne kunder i kontrollrommet.
    return Response.json({ ok: false, feil: 'Kunne ikke hente komplett abonnementsgrunnlag.' }, { status: 503 })
  }
}
