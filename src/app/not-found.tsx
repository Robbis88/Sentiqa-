import Link from 'next/link'
import { headers } from 'next/headers'
import { loggHendelse } from '@/lib/kontrollrom'

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

  // Logg KUN 404 fra egen side (ekte brutt lenke). Bot-skanning/direkte-treff
  // (ingen/ekstern referer) er støy og ignoreres.
  if (fraEgenSide(referer, h.get('host'))) {
    await loggHendelse({
      type: 'feil',
      alvorlighet: 'warning',
      tittel: '404 – brutt intern lenke',
      detaljer: {
        referer,
        bruker_agent: h.get('user-agent') ?? null,
      },
    })
  }

  return (
    <div className="laster-side">
      <h2>404 – fant ikke siden</h2>
      <p className="undertittel">Siden finnes ikke eller er flyttet.</p>
      <Link href="/">Til forsiden</Link>
    </div>
  )
}
