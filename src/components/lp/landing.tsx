import Link from 'next/link'
import { Hero } from './hero'
import { Kilder } from './kilder'
import { Onboarding } from './onboarding'
import { Utforsker } from './utforsker'
import { Assistent } from './assistent'
import { Driftssentral } from './sentral'
import { Ukebrief } from './ukebrief'
import { Signaler } from './signaler'

// =====================================================================
// DEN OFFENTLIGE SIDA
//
// Rekkefølgen er et spørsmål av gangen:
//
//   hva er dette          hero
//   hvor får den dataene  kilder
//   må jeg bygge om alt   onboarding
//   hva forstår den       utforsker
//   kan jeg spørre den    assistent
//   hva ser jeg som eier  driftssentral
//   må jeg logge inn      ukebrief
//   hvorfor skal jeg tro  signaler
//   hvordan starter jeg   slutt
//
// ÉN CTA HELE VEIEN. «Kom i gang» går til `/registrer`, som finnes og
// er selvbetjent. Sekundæren peker innover i sida, ikke ut av den.
//
// Denne fila komponerer bare. Seksjonene ligger hver for seg, og bare
// de som trenger interaksjon er klientkomponenter — kildene og
// ukebriefen rendres på serveren og koster ingenting i bundle.
// =====================================================================

export function Landing() {
  return (
    <div className="lp">
      <header className="lp-nav">
        <div className="lp-ramme lp-nav-inn">
          <span className="lp-merke"><span className="lp-merke-prikk" />Sentiqa</span>
          <nav className="lp-nav-lenker" aria-label="Hovedmeny">
            <a href="#produkt">Produkt</a>
            <a href="#onboarding">Onboarding</a>
            <a href="#ledelse">For ledere</a>
            <a href="#brev">Ukebriefen</a>
          </nav>
          <div className="lp-nav-hoyre">
            <Link className="lp-logginn" href="/logg-inn">Logg inn</Link>
            <Link className="lp-knapp" href="/registrer">Kom i gang</Link>
          </div>
        </div>
      </header>

      <main>
        <Hero />
        <Kilder />
        <Onboarding />
        <Utforsker />
        <Assistent />
        <Driftssentral />
        <Ukebrief />
        <Signaler />

        <section className="lp-seksjon lp-slutt" id="kom-i-gang">
          <div className="lp-ramme">
            <h2>
              Du har allerede dataene.<br />
              <span className="lp-dim">Sentiqa gjør noe med dem.</span>
            </h2>
            <div className="lp-cta lp-cta-midt">
              <Link className="lp-knapp lp-knapp-stor" href="/registrer">Kom i gang</Link>
              <a className="lp-knapp lp-knapp-stor lp-knapp-stille" href="#produkt">
                Se hvordan det virker
              </a>
            </div>
            <p className="lp-fot">
              Opprett kjeden, legg til stasjonene, last opp første rapport. Faktura på EHF.
            </p>
          </div>
        </section>
      </main>

      <footer>
        <div className="lp-ramme lp-bunn">
          <span className="lp-merke"><span className="lp-merke-prikk" />Sentiqa</span>
          <span>R-G Invest AS · Org.nr 937 861 621</span>
          <Link className="lp-bunn-hoyre" href="/personvern">Personvern</Link>
          <Link href="/databehandleravtale">Databehandleravtale</Link>
          <Link href="/sikkerhet">Sikkerhet</Link>
        </div>
      </footer>
    </div>
  )
}
