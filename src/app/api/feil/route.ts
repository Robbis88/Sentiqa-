import { NextResponse, type NextRequest } from 'next/server'
import { loggHendelse } from '@/lib/kontrollrom'

// Klient-feilgrensene (error.tsx / global-error.tsx) POSTer hit. Ruten kjører
// server-side og videresender til kontrollrommet, så KONTROLLROM_KEY aldri
// havner i nettleseren.
type Innkommende = {
  tittel?: string
  alvorlighet?: 'info' | 'warning' | 'critical'
  detaljer?: Record<string, unknown>
}

export async function POST(req: NextRequest) {
  let body: Innkommende
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ feil: 'Ugyldig JSON' }, { status: 400 })
  }

  await loggHendelse({
    type: 'feil',
    alvorlighet: body.alvorlighet ?? 'warning',
    tittel: (body.tittel ?? 'Ukjent klientfeil').slice(0, 200),
    detaljer: body.detaljer ?? {},
  })

  // Svar alltid ok – en feilende feil-logger skal aldri lage ny feil hos brukeren.
  return NextResponse.json({ ok: true })
}
