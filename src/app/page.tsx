import Image from 'next/image'
import Link from 'next/link'
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Sentiqa — Fornemmer. Forstår. Forutser.',
  description:
    'AI-drevet drift, analyse og assistanse for servicehandelen. Ta inn rapportene du allerede eksporterer — få svar, ikke dashboards å lete i.',
}

const MARQUEE = [
  'Live AI-assistent', 'Rutineskjema', 'Produksjonsplan', 'Svinnkontroll',
  'Regnskap mot budsjett', 'Værbasert salg', 'AI-konkurranser', 'Auto-fokus',
  'Sjekkpunkt-tablet', 'IK-mat', 'E-post-import', 'Timesalg-heatmap',
  'Lederstøtte', 'Multi-tenant & sikkert',
]

const SPORSMAL = [
  'Hvorfor falt salget av ferskvarer 12 % i Bergen i går?',
  'Hvordan påvirker varslet regnvær neste uke salget vårt?',
  'Hvor mye bør vi produsere til fredag?',
]

const FUNKSJONER = [
  { tittel: 'Datainntak uten styr', tekst: 'Send rapportene du allerede eksporterer på e-post eller dra dem inn. Sentiqa tolker dem automatisk.' },
  { tittel: 'AI som svarer', tekst: 'Spør på vanlig norsk og få svar med tall fra dine egne data — den finner aldri på noe, og viser kildene.' },
  { tittel: 'Analyse & dashboards', tekst: 'Salg, timesalg, svinn mot terskel, kasserer, regnskap mot budsjett og værbasert produksjonsplan.' },
  { tittel: 'Drift på tablet', tekst: 'Rutiner, sjekkpunkter og oppgaver med store knapper — enkelt for de ansatte, oversikt for sjefen.' },
  { tittel: 'Engasjement', tekst: 'AI-styrte konkurranser mellom stasjonene, auto-fokus og coaching-rapporter som driver atferd.' },
  { tittel: 'Trygt og adskilt', tekst: 'Multi-tenant med vanntett dataadskillelse. Ingen ser på tvers — heller ikke vi. Data i EU/EØS.' },
]

export default function Landing() {
  return (
    <div className="lp">
      <header className="lp-hero">
        <div className="lp-hero-inner">
          <Image src="/logo.png" alt="Sentiqa" width={460} height={307} priority className="lp-logo" />
          <p className="lp-avsender">Bygget av en som har stått på gulvet i 24 år — ikke av et programvareselskap.</p>
          <h1 className="lp-h1">Mindre tid på kontoret. Mer tid i butikken.</h1>
          <p className="lp-sub">
            For deg som ikke har tid til å lese hele regnskapet — Sentiqa fanger svinnet, treffer
            produksjonen på vær og trend, og forteller deg hva som faktisk skjer.
          </p>
          <div className="lp-cta">
            <a href="mailto:post@sentiqa.ai" className="lp-knapp primar">Be om demo</a>
            <Link href="/logg-inn" className="lp-knapp">Logg inn</Link>
          </div>
        </div>

        <div className="lp-marquee" aria-hidden>
          <div className="lp-marquee-track">
            {[...MARQUEE, ...MARQUEE].map((m, i) => (
              <span className="lp-pille" key={i}>● {m}</span>
            ))}
          </div>
        </div>
      </header>

      <section className="lp-seksjon">
        <h2 className="lp-h2">Verdien ligger ikke i modulene — den ligger i svarene</h2>
        <div className="lp-sporsmal">
          {SPORSMAL.map((s) => (
            <div className="lp-sporsmal-kort" key={s}>
              <span className="lp-q">«</span>
              <p>{s}</p>
            </div>
          ))}
        </div>
        <p className="lp-sub midt">Sentiqa forklarer fortid, forutser fremtid og foreslår hva du bør gjøre.</p>
      </section>

      <section className="lp-seksjon grå">
        <h2 className="lp-h2">Alt du trenger for å drive smartere</h2>
        <div className="lp-grid">
          {FUNKSJONER.map((f) => (
            <div className="lp-funk" key={f.tittel}>
              <h3>{f.tittel}</h3>
              <p>{f.tekst}</p>
            </div>
          ))}
        </div>
      </section>

      <section className="lp-seksjon" id="kontakt">
        <h2 className="lp-h2">Pris og demo</h2>
        <p className="lp-sub midt">
          Prisen tilpasses kjeden din. Ta kontakt for et uforpliktende tilbud og en demo der vi viser
          Sentiqa på deres egne tall.
        </p>
        <div className="lp-cta midt">
          <a href="mailto:post@sentiqa.ai?subject=Demo%20av%20Sentiqa" className="lp-knapp primar stor">Ta kontakt</a>
        </div>
        <p className="lp-eksempel"><a href="mailto:post@sentiqa.ai">post@sentiqa.ai</a></p>
      </section>

      <footer className="lp-footer">
        <span className="merke">Sentiqa</span>
        <span>Fornemmer. Forstår. Forutser.</span>
        <span className="lp-footer-svak">Eid og driftet av R-G Invest AS · Org.nr 937 861 621</span>
        <span className="lp-footer-svak">© Sentiqa · Data i EU/EØS</span>
      </footer>
    </div>
  )
}
