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
  'Hvorfor falt salget av pølser 12 % i Bergen i går?',
  'Hvordan påvirker varslet regnvær neste uke salget vårt?',
  'Hvor mye baguetter bør vi produsere på fredag?',
]

const FUNKSJONER = [
  { tittel: 'Datainntak uten styr', tekst: 'Send rapportene fra St1, Salesgrid og regnskapskontoret på e-post eller dra dem inn. Sentiqa tolker dem automatisk.' },
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
          <h1 className="lp-h1">Drift, analyse og AI-assistanse for servicehandelen</h1>
          <p className="lp-sub">
            Ta inn rapportene du allerede eksporterer. Få <strong>svar</strong> — ikke dashboards å lete i.
          </p>
          <div className="lp-cta">
            <Link href="/registrer" className="lp-knapp primar">Kom i gang</Link>
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

      <section className="lp-seksjon" id="priser">
        <h2 className="lp-h2">Enkel pris — per stasjon, ikke per hode</h2>
        <div className="lp-priser">
          <div className="lp-pris">
            <span className="lp-pris-tall">499 kr<small>/mnd</small></span>
            <span className="lp-pris-merke">per cluster (retailer)</span>
            <p>Konto, onboarding, support og AI-grunnkvote for hele kjeden.</p>
          </div>
          <div className="lp-pris fremhevet">
            <span className="lp-pris-tall">249 kr<small>/mnd</small></span>
            <span className="lp-pris-merke">per stasjon</span>
            <p>Butikksjef-tilgang, tablet og AI-kvote. Dekker kjernen: import, svinn, salg, regnskap og AI.</p>
          </div>
          <div className="lp-pris">
            <span className="lp-pris-tall">Tillegg</span>
            <span className="lp-pris-merke">premium-moduler</span>
            <p>Avtalevokter (faktura-AI), gamification m.m. — legg til det dere trenger.</p>
          </div>
        </div>
        <p className="lp-eksempel">
          Eksempel: en kjede med 5 stasjoner = 499 + 5 × 249 = <strong>1 744 kr/mnd</strong>. Rabatt ved årlig forskudd.
        </p>
        <div className="lp-cta midt">
          <Link href="/registrer" className="lp-knapp primar stor">Kom i gang</Link>
        </div>
      </section>

      <footer className="lp-footer">
        <span className="merke">Sentiqa</span>
        <span>Fornemmer. Forstår. Forutser.</span>
        <span className="lp-footer-svak">© Sentiqa · Data i EU/EØS</span>
      </footer>
    </div>
  )
}
