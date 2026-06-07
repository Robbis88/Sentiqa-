import { NextResponse, type NextRequest } from 'next/server'
import { randomUUID, createHash } from 'node:crypto'
import { env } from '@/lib/env'
import { lagSupabaseAdminKlient } from '@/lib/supabase/admin'

// E-post-inntak (§6). Tar imot videresendte e-poster fra en innboks-tjeneste
// (Postmark/Cloudflare Email Worker/SendGrid Inbound Parse el.l.). Matcher
// tenant på mottakeradresse, sjekker avsender-allowlist, og legger hvert
// vedlegg i kø — akkurat som drop-zone. Kjører som service-role (omgår RLS).
//
// Forventet JSON (Postmark-aktig):
//   { To|OriginalRecipient, From|FromFull.Email, Attachments: [{Name, ContentType, Content(base64)}] }
// Beskyttet med delt hemmelighet i headeren x-inntak-secret.
type Vedlegg = { Name?: string; ContentType?: string; Content?: string }
type Innkommende = {
  To?: string
  OriginalRecipient?: string
  ToFull?: { Email?: string }[]
  From?: string
  FromFull?: { Email?: string }
  Attachments?: Vedlegg[]
}

export async function POST(req: NextRequest) {
  // Hemmelighet i header ELLER ?secret= (tjenester som ikke kan sette egne headere).
  const oppgitt = req.headers.get('x-inntak-secret') ?? req.nextUrl.searchParams.get('secret')
  if (!env.EPOST_INNTAK_SECRET || oppgitt !== env.EPOST_INNTAK_SECRET) {
    return NextResponse.json({ feil: 'uautorisert' }, { status: 401 })
  }

  let body: Innkommende
  try {
    body = (await req.json()) as Innkommende
  } catch {
    return NextResponse.json({ feil: 'ugyldig JSON' }, { status: 400 })
  }

  const mottaker = (body.OriginalRecipient || body.To || body.ToFull?.[0]?.Email || '').toLowerCase().trim()
  const avsender = (body.FromFull?.Email || body.From || '').toLowerCase().trim()
  const vedlegg = body.Attachments ?? []
  if (!mottaker) return NextResponse.json({ feil: 'mangler mottaker' }, { status: 400 })

  const supabase = lagSupabaseAdminKlient()
  const { data: retailer } = await supabase
    .from('retailers')
    .select('id, avsender_allowlist')
    .ilike('inntak_epost', mottaker)
    .is('slettet_tid', null)
    .maybeSingle<{ id: string; avsender_allowlist: string[] }>()
  if (!retailer) return NextResponse.json({ feil: 'ukjent mottakeradresse' }, { status: 404 })

  // Avsender-allowlist (§6): kun forhåndsgodkjente avsendere slipper gjennom.
  const liste = (retailer.avsender_allowlist ?? []).map((x) => x.toLowerCase())
  if (liste.length > 0 && !liste.includes(avsender)) {
    return NextResponse.json({ feil: 'avsender ikke godkjent' }, { status: 403 })
  }

  let antall = 0
  for (const v of vedlegg) {
    if (!v.Content || !v.Name) continue
    const buffer = Buffer.from(v.Content, 'base64')
    const sha256 = createHash('sha256').update(buffer).digest('hex')
    const sti = `${retailer.id}/${randomUUID()}-${v.Name}`

    const opp = await supabase.storage
      .from('raa-filer')
      .upload(sti, buffer, { contentType: v.ContentType || 'application/octet-stream' })
    if (opp.error) continue

    const { data: raaFil, error } = await supabase
      .from('raa_filer')
      .insert({
        retailer_id: retailer.id,
        filnavn: v.Name,
        storage_bucket: 'raa-filer',
        storage_sti: sti,
        mottakskanal: 'epost',
        avsender,
        storrelse_bytes: buffer.length,
        sha256,
      })
      .select('id')
      .single()
    if (error) {
      await supabase.storage.from('raa-filer').remove([sti]) // dedup el. feil → rydd opp
      continue
    }
    await supabase.from('import_jobber').insert({ raa_fil_id: raaFil.id, retailer_id: retailer.id })
    antall++
  }

  return NextResponse.json({ ok: true, mottatt: antall })
}
