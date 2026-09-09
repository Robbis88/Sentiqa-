import { NextResponse, type NextRequest } from 'next/server'
import { randomUUID, createHash } from 'node:crypto'
import PostalMime from 'postal-mime'
import { env } from '@/lib/env'
import { lagSupabaseAdminKlient } from '@/lib/supabase/admin'
import { behandleJobbKjerne } from '@/lib/import/kjerne'
import { trygtFilnavn } from '@/lib/storage-noekkel'

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
type Normalisert = { mottaker: string; avsender: string; vedlegg: Vedlegg[] }

// Forstår to formater: JSON (Postmark-aktig, brukt i tester) og rå MIME
// (message/rfc822 fra vår Cloudflare Email Worker — der parser vi her).
async function hentInnkommende(req: NextRequest): Promise<Normalisert> {
  const ct = req.headers.get('content-type') || ''
  if (ct.includes('application/json')) {
    const body = (await req.json()) as Innkommende
    return {
      mottaker: (body.OriginalRecipient || body.To || body.ToFull?.[0]?.Email || '').toLowerCase().trim(),
      avsender: (body.FromFull?.Email || body.From || '').toLowerCase().trim(),
      vedlegg: body.Attachments ?? [],
    }
  }
  const raw = Buffer.from(await req.arrayBuffer())
  const epost = await new PostalMime().parse(raw)
  return {
    mottaker: (req.headers.get('x-mail-to') || epost.to?.[0]?.address || '').toLowerCase().trim(),
    avsender: (req.headers.get('x-mail-from') || epost.from?.address || '').toLowerCase().trim(),
    vedlegg: (epost.attachments ?? []).map((a) => ({
      Name: a.filename || 'vedlegg',
      ContentType: a.mimeType || 'application/octet-stream',
      Content: Buffer.from(a.content as ArrayBuffer).toString('base64'),
    })),
  }
}

export async function POST(req: NextRequest) {
  // =================================================================
  // «IKKE SATT OPP» OG «FEIL NØKKEL» SÅ HELT LIKE UT
  //
  // Her sto ett svar for begge: 401 «uautorisert». Er
  // `EPOST_INNTAK_SECRET` ikke satt i Vercel, får Cloudflare-workeren
  // nøyaktig samme svar som om nøkkelen var feil — og den som kobler
  // opp inntaket for første gang har ingen måte å vite hvilken av dem
  // det er.
  //
  // Det er samme form som resten av dette systemet nekter: to
  // tilstander som betyr helt ulike ting, tegnet likt. Her kostet den
  // ikke penger, men den kostet en feilsøking ingen kunne fullføre.
  //
  // 503 lekker ingenting. At funksjonen er avslått er ikke en
  // hemmelighet — hemmeligheten er nøkkelen, og den sies ikke.
  if (!env.EPOST_INNTAK_SECRET) {
    return NextResponse.json({
      feil: 'e-post-inntaket er ikke satt opp',
      hint: 'EPOST_INNTAK_SECRET mangler i miljøet',
    }, { status: 503 })
  }
  // Hemmelighet i header ELLER ?secret= (tjenester som ikke kan sette egne headere).
  const oppgitt = req.headers.get('x-inntak-secret') ?? req.nextUrl.searchParams.get('secret')
  if (oppgitt !== env.EPOST_INNTAK_SECRET) {
    return NextResponse.json({ feil: 'uautorisert' }, { status: 401 })
  }

  let mottaker: string, avsender: string, vedlegg: Vedlegg[]
  try {
    ;({ mottaker, avsender, vedlegg } = await hentInnkommende(req))
  } catch {
    return NextResponse.json({ feil: 'kunne ikke lese e-posten' }, { status: 400 })
  }
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

  // ET VEDLEGG SOM FALLER UT SKAL SES.
  //
  // De tre `continue`-ene under svelget hver sin feil: en opplasting som
  // feilet, en innsetting som feilet, et vedlegg uten innhold. Svaret ble
  // `{ ok: true, mottatt: 2 }` av tre vedlegg, og workeren kaster bare på
  // ikke-2xx — så en halvveis mottatt e-post så ut som en vellykket.
  //
  // Fila kommer aldri igjen: St1 sender én gang. «Rapporten kom ikke»
  // ville blitt lett etter i importkøen, der den aldri var.
  const hoppet: string[] = []
  let antall = 0
  for (const v of vedlegg) {
    if (!v.Content || !v.Name) { hoppet.push(v.Name || '(uten navn)'); continue }
    const buffer = Buffer.from(v.Content, 'base64')
    const sha256 = createHash('sha256').update(buffer).digest('hex')
    const sti = `${retailer.id}/${randomUUID()}-${trygtFilnavn(v.Name)}`

    const opp = await supabase.storage
      .from('raa-filer')
      .upload(sti, buffer, { contentType: v.ContentType || 'application/octet-stream' })
    if (opp.error) { hoppet.push(`${v.Name}: ${opp.error.message}`); continue }

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
      // Dedup er en LEGITIM grunn til aa hoppe over - samme fil sendt to
      // ganger skal ikke bli to jobber. Den staar likevel i svaret, for
      // «vi har den fra foer» og «vi mistet den» skal ikke se like ut.
      hoppet.push(`${v.Name}: ${error.message}`)
      continue
    }
    const { data: jobb } = await supabase
      .from('import_jobber')
      .insert({ raa_fil_id: raaFil.id, retailer_id: retailer.id })
      .select('id')
      .single<{ id: string }>()
    antall++
    // Auto-behandling (§6): parse med en gang, så natt-flyten er ferdig uten klikk.
    if (jobb) {
      try {
        await behandleJobbKjerne(supabase, retailer.id, jobb.id)
      } catch {
        // jobben er allerede markert feilet inne i kjernen; ikke velt webhooken
      }
    }
  }

  // `hoppet` er med i svaret, ikke bare i loggen: workeren ser det, og
  // det gjoer den som feilsoeker med curl.
  return NextResponse.json(
    hoppet.length > 0 ? { ok: true, mottatt: antall, hoppet } : { ok: true, mottatt: antall },
  )
}
