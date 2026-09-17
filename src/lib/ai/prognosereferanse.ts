import { createHmac, timingSafeEqual } from 'node:crypto'
import { gyldigDato } from './periode'

export type Prognosereferanse = { vare: string; stasjoner: string[]; fra: string; til: string }

/** Bærer identitet og periode, aldri tall eller tilgang. Alle tall hentes på nytt. */
export function signerPrognose(ref: Prognosereferanse, brukerId: string, noekkel: string): string {
  const body = Buffer.from(JSON.stringify({ ref, brukerId })).toString('base64url')
  return `${body}.${createHmac('sha256', noekkel).update(`prognosereferanse:${body}`).digest('base64url')}`
}

export function lesPrognose(token: unknown, brukerId: string, noekkel: string): Prognosereferanse | null {
  if (typeof token !== 'string' || token.length > 8000) return null
  const [body, sig, ekstra] = token.split('.')
  if (!body || !sig || ekstra) return null
  const fasit = createHmac('sha256', noekkel).update(`prognosereferanse:${body}`).digest()
  const gitt = Buffer.from(sig, 'base64url')
  if (gitt.length !== fasit.length || !timingSafeEqual(gitt, fasit)) return null
  try {
    const data = JSON.parse(Buffer.from(body, 'base64url').toString('utf8'))
    const ref = data.ref
    if (data.brukerId !== brukerId || !ref || typeof ref.vare !== 'string'
      || !/^\d{1,14}$/.test(ref.vare) || !Array.isArray(ref.stasjoner) || !ref.stasjoner.length
      || ref.stasjoner.some((s: unknown) => typeof s !== 'string' || !s.trim())
      || typeof ref.fra !== 'string' || typeof ref.til !== 'string'
      || !gyldigDato(ref.fra) || !gyldigDato(ref.til) || ref.fra > ref.til) return null
    return ref
  } catch { return null }
}

export function erTreffoppfolging(tekst: string): boolean {
  return /(?:hvor (?:sikker|sikkert)|treffsikker|stole på (?:tallet|prognosen)|hvor godt.*treff)/i.test(tekst)
}
