import Link from 'next/link'
import { headers } from 'next/headers'
import Meld404 from './meld-404'

/** True bare når 404-en kom fra en lenke på vårt eget domene. */
function fraEgenSide(referer: string | null, host: string | null): boolean {
  if (!referer || !host) return false
  try {
    return new URL(referer).host === host
  } catch {
    return false
  }
}

export default async function IkkeFunnet() {
  const h = await headers()
  const referer = h.get('referer')

  return (
    <div className="laster-side">
      <Meld404 meld={fraEgenSide(referer, h.get('host'))} referer={referer} />
      <h2>404 – fant ikke siden</h2>
      <p className="undertittel">Siden finnes ikke eller er flyttet.</p>
      <Link href="/">Til forsiden</Link>
    </div>
  )
}
