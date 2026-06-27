import type { Metadata } from 'next'
import { TotpSkjema } from './totp-skjema'

export const metadata: Metadata = { title: 'Bekreft innlogging – Sentiqa' }

export default async function TotpSide({
  searchParams,
}: {
  searchParams: Promise<{ retur?: string }>
}) {
  const { retur } = await searchParams

  return (
    <main className="logg-inn">
      <div className="kort">
        <div className="merke">Sentiqa</div>
        <h1>Bekreft innlogging</h1>
        <p className="undertittel">Skriv inn engangskoden fra autentiseringsappen din.</p>
        <TotpSkjema retur={retur} />
      </div>
      <footer className="auth-bunn">R-G Invest AS · Org.nr 937 861 621</footer>
    </main>
  )
}
