import Link from 'next/link'
import { headers } from 'next/headers'
import { loggHendelse } from '@/lib/kontrollrom'

export default async function IkkeFunnet() {
  const h = await headers()
  await loggHendelse({
    type: 'feil',
    alvorlighet: 'info',
    tittel: '404 – side ikke funnet',
    detaljer: {
      referer: h.get('referer') ?? null,
      bruker_agent: h.get('user-agent') ?? null,
    },
  })

  return (
    <div className="laster-side">
      <h2>404 – fant ikke siden</h2>
      <p className="undertittel">Siden finnes ikke eller er flyttet.</p>
      <Link href="/">Til forsiden</Link>
    </div>
  )
}
