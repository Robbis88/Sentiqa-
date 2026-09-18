import { Merke } from '@/components/ui/merke'
import Link from 'next/link'
import type { Metadata } from 'next'
import { RegistrerSkjema } from './skjema'

export const metadata: Metadata = { title: 'Kom i gang – Sentiqa' }

export default function RegistrerSide() {
  return (
    <main className="logg-inn">
      <div className="kort">
        <Merke />
        <h1>Kom i gang</h1>
        <p className="undertittel">
          Send inn kjeden din og kontaktpersonen. Vi godkjenner oppstarten før du får tilgang.
          Faktura sendes på EHF.
        </p>
        <div className="oppstart-info">
          <strong>Ha dette klart til oppstart</strong>
          <ul>
            <li>Navn og organisasjonsnummer for kjeden</li>
            <li>Stasjonene som skal inn i Sentiqa</li>
            <li>Salgsstatistikk, timesalg og årets forretningsplan</li>
          </ul>
          <p>Flere rapporter kan legges til etterpå. Systemet viser hva som mangler per stasjon.</p>
        </div>
        <RegistrerSkjema />
        <p className="undertittel" style={{ marginTop: '1rem' }}>
          Har du allerede konto? <Link href="/logg-inn">Logg inn</Link>
        </p>
      </div>
      <footer className="auth-bunn">R-G Invest AS · Org.nr 937 861 621 · <Link href="/personvern">Personvern</Link></footer>
    </main>
  )
}
