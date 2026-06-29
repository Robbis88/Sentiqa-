'use client'
import { useEffect } from 'react'

// Rot-feilgrense (offentlige sider utenfor (beskyttet)). Rapporterer til kontrollrommet.
export default function Feil({ error, reset }: { error: Error & { digest?: string }; reset: () => void }) {
  useEffect(() => {
    console.error('Sentiqa side-feil:', error)
    void fetch('/api/feil', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        alvorlighet: 'warning',
        tittel: `Feil på side: ${error.message}`,
        detaljer: {
          melding: error.message,
          digest: error.digest,
          sti: typeof window !== 'undefined' ? window.location.pathname : null,
        },
      }),
    }).catch(() => {})
  }, [error])

  return (
    <div className="laster-side">
      <h2>Noe gikk galt</h2>
      <p className="undertittel">Vi klarte ikke å laste innholdet. Prøv igjen.</p>
      {error.digest && <p className="undertittel" style={{ fontSize: '0.75rem' }}>Feilkode: {error.digest}</p>}
      <button type="button" onClick={reset}>Prøv igjen</button>
    </div>
  )
}
