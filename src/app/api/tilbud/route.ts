import { NextResponse } from 'next/server'
import { Resend } from 'resend'
import * as z from 'zod'
import { lagSupabaseAdminKlient } from '@/lib/supabase/admin'
import { env } from '@/lib/env'

const Skjema = z.object({
  virksomhet: z.string().trim().min(2).max(160),
  org_nr: z.string().trim().regex(/^\d{9}$/).or(z.literal('')).optional(),
  kontaktperson: z.string().trim().min(2).max(160),
  epost: z.email(),
  telefon: z.string().trim().min(6).max(40),
  antall_stasjoner: z.coerce.number().int().min(1).max(1000),
  retailer_limit: z.coerce.number().int().min(0).max(1000),
  butikksjef_limit: z.coerce.number().int().min(0).max(1000),
  tablet_station_limit: z.coerce.number().int().min(0).max(1000),
  onsket_oppstart: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).or(z.literal('')).optional(),
  kommentar: z.string().trim().max(4000).optional(),
  samtykke: z.literal('on'),
  website: z.string().max(0).optional(),
})

const forsok = new Map<string, number>()

export async function POST(req: Request) {
  const ip = req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ?? 'ukjent'
  const naa = Date.now()
  const sist = forsok.get(ip) ?? 0
  if (naa - sist < 30_000) return NextResponse.json({ feil: 'Vent litt før du sender en ny forespørsel.' }, { status: 429 })
  forsok.set(ip, naa)
  let input: unknown
  try { input = await req.json() } catch { return NextResponse.json({ feil: 'Ugyldig forespørsel.' }, { status: 400 }) }
  const felt = Skjema.safeParse(input)
  if (!felt.success) return NextResponse.json({ feil: 'Kontroller feltene og samtykket før du sender.' }, { status: 400 })
  if (felt.data.website) return NextResponse.json({ ok: true })
  const admin = lagSupabaseAdminKlient()
  const { data, error } = await admin.from('tilbudsforesporsler').insert({
    virksomhet: felt.data.virksomhet, org_nr: felt.data.org_nr || null,
    kontaktperson: felt.data.kontaktperson, epost: felt.data.epost,
    telefon: felt.data.telefon, antall_stasjoner: felt.data.antall_stasjoner,
    retailer_limit: felt.data.retailer_limit, butikksjef_limit: felt.data.butikksjef_limit,
    tablet_station_limit: felt.data.tablet_station_limit,
    onsket_oppstart: felt.data.onsket_oppstart || null, kommentar: felt.data.kommentar || null,
    samtykke: true, spam_nokkel: ip,
  }).select('id').single()
  if (error || !data) return NextResponse.json({ feil: 'Forespørselen kunne ikke lagres. Prøv igjen.' }, { status: 500 })

  let epostStatus = 'ikke_konfigurert'
  if (env.RESEND_API_KEY && env.SENTIQA_QUOTE_NOTIFICATION_EMAIL) {
    try {
      const resend = new Resend(env.RESEND_API_KEY)
      const sendt = await resend.emails.send({
        from: env.UKEBRIEF_AVSENDER,
        to: env.SENTIQA_QUOTE_NOTIFICATION_EMAIL,
        subject: `Ny tilbudsforespørsel: ${felt.data.virksomhet}`,
        text: `Virksomhet: ${felt.data.virksomhet}\nKontakt: ${felt.data.kontaktperson}\nE-post: ${felt.data.epost}\nTelefon: ${felt.data.telefon}\nStasjoner: ${felt.data.antall_stasjoner}\nRetailerbrukere: ${felt.data.retailer_limit}\nButikksjefer: ${felt.data.butikksjef_limit}\nTabletstasjoner: ${felt.data.tablet_station_limit}\nOppstart: ${felt.data.onsket_oppstart || 'Ikke oppgitt'}\nKommentar: ${felt.data.kommentar || '—'}\nID: ${data.id}`,
      })
      epostStatus = sendt.error ? 'feilet' : 'sendt'
    } catch { epostStatus = 'feilet' }
  }
  await admin.from('tilbudsforesporsler').update({ epost_status: epostStatus, oppdatert_tid: new Date().toISOString() }).eq('id', data.id)
  return NextResponse.json({ ok: true })
}
