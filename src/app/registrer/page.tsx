import Link from 'next/link'
import type { Metadata } from 'next'
import { RegistrerSkjema } from './skjema'

export const metadata: Metadata = { title: 'Kom i gang – Sentiqa' }

export default function RegistrerSide() {
  return (
    <main className="logg-inn">
      <div className="kort">
        <div className="merke">Sentiqa</div>
        <h1>Kom i gang</h1>
        <p className="undertittel">Opprett kjeden din og legg til stasjonene. Faktura sendes på EHF.</p>
        <RegistrerSkjema />
        <p className="undertittel" style={{ marginTop: '1rem' }}>
          Har du allerede konto? <Link href="/logg-inn">Logg inn</Link>
        </p>
        <p className="undertittel" style={{ marginTop: '0.75rem', fontSize: '0.78rem' }}>
          Ved å opprette konto godtar du at R-G Invest AS behandler opplysningene som beskrevet i{' '}
          <Link href="/personvern">personvernerklæringen</Link>.
        </p>
      </div>
      <footer className="auth-bunn">R-G Invest AS · Org.nr 937 861 621 · <Link href="/personvern">Personvern</Link></footer>
    </main>
  )
}
