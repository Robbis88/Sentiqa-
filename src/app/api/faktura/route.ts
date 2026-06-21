import { NextResponse, type NextRequest } from 'next/server'
import { env } from '@/lib/env'
import { lagSupabaseAdminKlient } from '@/lib/supabase/admin'
import { PRIS } from '@/lib/pris'
import { opprettKunde, opprettFaktura, sendFaktura, fikenKonfigurert, type Fakturalinje } from '@/lib/fiken'
import { loggHendelse } from '@/lib/kontrollrom'

// Operatør-endepunkt: generer + send EHF-faktura for én tenant via Fiken.
// Beskyttet med FAKTURA_SECRET (header x-faktura-secret eller ?secret=).
// POST body: { retailerId: "uuid" }
function isoDato(d: Date): string {
  return d.toISOString().slice(0, 10)
}

export async function POST(req: NextRequest) {
  const oppgitt = req.headers.get('x-faktura-secret') ?? req.nextUrl.searchParams.get('secret')
  if (!env.FAKTURA_SECRET || oppgitt !== env.FAKTURA_SECRET) {
    return NextResponse.json({ feil: 'uautorisert' }, { status: 401 })
  }
  if (!fikenKonfigurert()) {
    return NextResponse.json({ feil: 'Fiken er ikke konfigurert (mangler token/selskap/bankkonto).' }, { status: 400 })
  }

  let retailerId: string
  try {
    retailerId = (await req.json()).retailerId
  } catch {
    return NextResponse.json({ feil: 'mangler retailerId' }, { status: 400 })
  }
  if (!retailerId) return NextResponse.json({ feil: 'mangler retailerId' }, { status: 400 })

  const token = env.FIKEN_API_TOKEN!
  const slug = env.FIKEN_COMPANY_SLUG!
  const konto = env.FIKEN_INCOME_ACCOUNT || '3000'
  const moms = env.FIKEN_VAT_TYPE || 'HIGH'

  const supabase = lagSupabaseAdminKlient()
  const { data: retailer } = await supabase
    .from('retailers')
    .select('id, navn, org_nr, faktura_epost, aarlig_forskudd, premium_avtalevokter, fiken_kontakt_id')
    .eq('id', retailerId)
    .is('slettet_tid', null)
    .maybeSingle<{
      id: string; navn: string; org_nr: string | null; faktura_epost: string | null
      aarlig_forskudd: boolean; premium_avtalevokter: boolean; fiken_kontakt_id: number | null
    }>()
  if (!retailer) return NextResponse.json({ feil: 'ukjent tenant' }, { status: 404 })
  if (!retailer.org_nr) return NextResponse.json({ feil: 'tenant mangler org.nr' }, { status: 400 })

  const { count } = await supabase
    .from('stasjoner')
    .select('*', { count: 'exact', head: true })
    .eq('retailer_id', retailerId)
    .is('slettet_tid', null)
  const antallStasjoner = count ?? 0

  // Linjer i øre (netto, eks. mva). Årlig forskudd = 10 mnd (2 gratis).
  const m = retailer.aarlig_forskudd ? 10 : 1
  const periode = retailer.aarlig_forskudd ? 'år' : 'mnd'
  const lines: Fakturalinje[] = [
    { productName: `Sentiqa grunnpris (${periode})`, unitPrice: PRIS.cluster * 100, quantity: m, vatType: moms, incomeAccount: konto },
  ]
  if (antallStasjoner > 0) {
    lines.push({ productName: `Sentiqa stasjon (${periode})`, unitPrice: PRIS.stasjon * 100, quantity: antallStasjoner * m, vatType: moms, incomeAccount: konto })
  }
  if (retailer.premium_avtalevokter) {
    lines.push({ productName: `Avtalevokter premium (${periode})`, unitPrice: PRIS.avtalevokter * 100, quantity: m, vatType: moms, incomeAccount: konto })
  }

  try {
    // Sikre Fiken-kunde (gjenbruk lagret kontakt-ID).
    let kundeId = retailer.fiken_kontakt_id
    if (!kundeId) {
      kundeId = await opprettKunde(token, slug, { navn: retailer.navn, orgnr: retailer.org_nr, epost: retailer.faktura_epost })
      await supabase.from('retailers').update({ fiken_kontakt_id: kundeId }).eq('id', retailerId)
    }

    const naa = new Date()
    const forfall = new Date(naa)
    forfall.setDate(forfall.getDate() + 14)

    const invoiceId = await opprettFaktura(token, slug, {
      customerId: kundeId,
      lines,
      bankAccountCode: env.FIKEN_BANK_ACCOUNT_CODE!,
      issueDate: isoDato(naa),
      dueDate: isoDato(forfall),
      ourReference: 'Sentiqa abonnement',
    })
    await sendFaktura(token, slug, invoiceId, ['auto']) // EHF først

    await loggHendelse({
      type: 'system',
      alvorlighet: 'info',
      tittel: `Faktura sendt: ${retailer.navn}`,
      detaljer: { invoiceId, antallStasjoner, retailer_id: retailerId },
    })

    return NextResponse.json({ ok: true, invoiceId, antallStasjoner })
  } catch (e) {
    await loggHendelse({
      type: 'feil',
      alvorlighet: 'warning',
      tittel: `Faktura feilet: ${retailer.navn}`,
      detaljer: { retailer_id: retailerId, feil: String(e) },
    })
    return NextResponse.json({ feil: String(e) }, { status: 502 })
  }
}
