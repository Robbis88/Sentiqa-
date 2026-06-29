'use client'
import { useEffect } from 'react'

// Fanger krasj i ROT-layouten (hele appen feiler). Må selv rendre <html>/<body>,
// så vi bruker inline-stiler (globals.css er ikke garantert lastet her).
export default function GlobalError({ error, reset }: { error: Error & { digest?: string }; reset: () => void }) {
  useEffect(() => {
    void fetch('/api/feil', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        alvorlighet: 'critical',
        tittel: `Krasj: ${error.message}`,
        detaljer: {
          melding: error.message,
          digest: error.digest,
          sti: typeof window !== 'undefined' ? window.location.pathname : null,
        },
      }),
    }).catch(() => {})
  }, [error])

  return (
    <html lang="no">
      <body style={{ fontFamily: 'system-ui, sans-serif', padding: '4rem 1.5rem', textAlign: 'center', color: '#1a1a1a' }}>
        <h1 style={{ fontSize: '1.5rem', marginBottom: '0.5rem' }}>Noe gikk galt</h1>
        <p style={{ color: '#666', marginBottom: '1.5rem' }}>Feilen er logget, og vi ser på den. Prøv igjen.</p>
        <button
          onClick={() => reset()}
          style={{ padding: '0.6rem 1.4rem', borderRadius: 10, border: '1px solid #ccc', background: '#fff', cursor: 'pointer' }}
        >
          Prøv igjen
        </button>
      </body>
    </html>
  )
}
