import 'server-only'
import { createHash } from 'node:crypto'
import { cookies } from 'next/headers'

const COOKIE = 'sentiqa_vakt'

// PIN hashes med retailer-id som salt. Identifikasjon (kasserer-nr-nivå),
// ikke datasikkerhet — RLS styrer all faktisk tilgang.
export function hashPin(retailerId: string, pin: string): string {
  return createHash('sha256').update(`${retailerId}:${pin}`).digest('hex')
}

export type AktivAnsatt = { id: string; navn: string }

// Leses i server-komponenter (read-only).
export async function lesAktivAnsatt(): Promise<AktivAnsatt | null> {
  const raw = (await cookies()).get(COOKIE)?.value
  if (!raw) return null
  try {
    const o = JSON.parse(raw) as AktivAnsatt
    return o?.id && o?.navn ? o : null
  } catch {
    return null
  }
}

// Settes/fjernes kun i server actions / route handlers.
export async function settAktivAnsatt(a: AktivAnsatt) {
  ;(await cookies()).set(COOKIE, JSON.stringify(a), {
    httpOnly: true,
    sameSite: 'lax',
    path: '/',
    maxAge: 60 * 60 * 12, // én vakt
  })
}

export async function fjernAktivAnsatt() {
  ;(await cookies()).delete(COOKIE)
}
