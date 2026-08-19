import { Merke } from '@/components/ui/merke'
import type { Metadata } from 'next'
import Link from 'next/link'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { mfaPaakrevd } from '@/lib/auth/mfa'
import { MfaOppsett } from './mfa-oppsett'

export const metadata: Metadata = { title: 'Sikkerhet – Sentiqa' }

export default async function SikkerhetSide({
  searchParams,
}: {
  searchParams: Promise<{ paakrevd?: string }>
}) {
  const bruker = await hentInnloggetBruker()
  const { paakrevd } = await searchParams
  const tvunget = paakrevd === '1'
  const rollenKrever = mfaPaakrevd(bruker.rolle)

  return (
    <main className="logg-inn">
      <div className="kort" style={{ maxWidth: 460 }}>
        <Merke />
        <h1>To-faktor-autentisering</h1>
        {tvunget ? (
          <p className="undertittel" style={{ color: '#7c2d12' }}>
            Rollen din krever to-faktor. Fullfør oppsettet for å fortsette.
          </p>
        ) : (
          <p className="undertittel">
            Beskytt kontoen din med en engangskode fra en autentiseringsapp
            (Google Authenticator, Microsoft Authenticator, Authy m.fl.).
          </p>
        )}

        <MfaOppsett tvunget={tvunget} rollenKrever={rollenKrever} />

        {!tvunget && (
          <p className="undertittel" style={{ marginTop: '1.25rem' }}>
            <Link href="/oversikt">← Tilbake</Link>
          </p>
        )}
      </div>
      <footer className="auth-bunn">R-G Invest AS · Org.nr 937 861 621</footer>
    </main>
  )
}
