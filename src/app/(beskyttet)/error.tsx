'use client'
import { useEffect } from 'react'

// Fanger feil i beskyttede sider så de aldri viser «couldn't load» — menyen
// (layout) blir stående, og brukeren kan prøve igjen eller gå et annet sted.
export default function Feil({ error, reset }: { error: Error & { digest?: string }; reset: () => void }) {
  useEffect(() => {
    console.error('Sentiqa side-feil:', error)
  }, [error])

  return (
    <div className="laster-side">
      <h2>Noe gikk galt på denne siden</h2>
      <p className="undertittel">Vi klarte ikke å laste innholdet. Prøv igjen, eller velg en annen side i menyen.</p>
      {error.digest && <p className="undertittel" style={{ fontSize: '0.75rem' }}>Feilkode: {error.digest}</p>}
      <button type="button" onClick={reset}>Prøv igjen</button>
    </div>
  )
}
