'use client'
import { useState } from 'react'
import { useSynlig } from './bevegelse'

// =====================================================================
// PRODUKTUTFORSKEREN
//
// Sju faner, én per område i appen. Hver av dem svarer på det samme
// tredelte spørsmålet modulene selv svarer på:
//
//   hva skjedde · hvorfor det betyr noe · hva som bør gjøres
//
// GRAFENE ER SVG, IKKE ET BIBLIOTEK. En chartpakke ville lagt 40–90 kB
// på en side som viser fire strektegninger. Aksene og fargene kommer
// fra de samme tokenene som resten.
//
// Ingen `<table>` her, selv om økonomifanen kunne brukt en: `design.test.ts`
// skraller på rå tabeller, og en radliste sier det samme uten å legge
// til i tallet.
// =====================================================================

type Fane = 'salg' | 'produksjon' | 'bemanning' | 'svinn' | 'okonomi' | 'ansatte' | 'ledelse'

const FANER: { id: Fane; navn: string }[] = [
  { id: 'salg', navn: 'Salg' },
  { id: 'produksjon', navn: 'Produksjon' },
  { id: 'bemanning', navn: 'Bemanning' },
  { id: 'svinn', navn: 'Svinn' },
  { id: 'okonomi', navn: 'Økonomi' },
  { id: 'ansatte', navn: 'Ansatte' },
  { id: 'ledelse', navn: 'Ledelse' },
]

function Punkt({ navn, verdi, retning }: { navn: string; verdi: string; retning?: 'opp' | 'ned' }) {
  const k = retning === 'opp' ? 'lp-v lp-v-opp' : retning === 'ned' ? 'lp-v lp-v-ned' : 'lp-v'
  return <li>{navn}<span className={k}>{verdi}</span></li>
}

function Anbefaling({ merke = 'Sentiqa foreslår', children }: { merke?: string; children: React.ReactNode }) {
  return (
    <div className="lp-anbef">
      <p className="lp-anbef-merke">{merke}</p>
      <p>{children}</p>
    </div>
  )
}

function Bar({ navn, pst, farge, paa }: { navn: string; pst: number; farge?: 'gul' | 'rod'; paa: boolean }) {
  const k = farge === 'gul' ? 'lp-bar-fyll lp-bar-fyll-gul'
    : farge === 'rod' ? 'lp-bar-fyll lp-bar-fyll-rod' : 'lp-bar-fyll'
  return (
    <div className="lp-bar-rad">
      <span className="lp-bar-navn">{navn}</span>
      <span className="lp-bar-spor">
        <i className={k} data-fyll={paa ? pst : 0} />
      </span>
      <span className="lp-bar-tall">{pst} %</span>
    </div>
  )
}

export function Utforsker() {
  const [aktiv, setAktiv] = useState<Fane>('salg')
  const { ref, synlig } = useSynlig<HTMLDivElement>(0.2)

  return (
    <section className="lp-seksjon" id="produkt">
      <div className="lp-ramme" ref={ref}>
        <p className="lp-eyebrow">Hva Sentiqa forstår</p>
        <h2 className="lp-h2">Hver del av driften, med et svar.</h2>
        <p className="lp-ingress">
          Hva som skjedde, hvorfor det betyr noe, og hva som bør gjøres.
        </p>

        <div className="lp-faner" role="tablist" aria-label="Områder i Sentiqa">
          {FANER.map((f) => (
            <button
              key={f.id}
              className="lp-fane"
              role="tab"
              type="button"
              id={`fane-${f.id}`}
              aria-selected={aktiv === f.id}
              aria-controls={`panel-${f.id}`}
              onClick={() => setAktiv(f.id)}
            >
              {f.navn}
            </button>
          ))}
        </div>

        {/* SALG */}
        <div
          className={aktiv === 'salg' ? 'lp-panel lp-panel-aktiv' : 'lp-panel'}
          role="tabpanel" id="panel-salg" aria-labelledby="fane-salg"
        >
          <div>
            <h3>Nordbyen ligger 6,4 % bak forventet salg.</h3>
            <p className="lp-panel-p">
              Prognosen bygger på egen historikk, ukedag, helligdager og vær — og måles mot
              treffet i etterkant.
            </p>
            <ul className="lp-punkter">
              <Punkt navn="Bakeri" verdi="−11,8 %" retning="ned" />
              <Punkt navn="Varmmat" verdi="−8,3 %" retning="ned" />
              <Punkt navn="Kald drikke" verdi="+4,1 %" retning="opp" />
            </ul>
            <Anbefaling>
              Kontroller tilgjengelighet mellom 14 og 17. Timesalget viser kunder, men
              bakeriet er tomt fra 14:30 tre av fem dager.
            </Anbefaling>
          </div>
          <div className="lp-flate-ramme lp-flate-ramme-tett">
            <div className="lp-flate"><div className="lp-flate-kropp">
              <p className="lp-vis-merke">Salg per dag · siste 14 dager</p>
              <svg
                className="lp-graf" viewBox="0 0 320 120" role="img"
                aria-label="Salg per dag siste fjorten dager, mot prognose. Faktisk salg faller under prognosen fra dag åtte."
              >
                <line x1="0" y1="100" x2="320" y2="100" stroke="var(--kant-sterk)" strokeWidth="1" />
                <line x1="0" y1="60" x2="320" y2="60" stroke="var(--kant)" strokeWidth="1" />
                <line x1="0" y1="20" x2="320" y2="20" stroke="var(--kant)" strokeWidth="1" />
                <path
                  d="M4,44 L28,40 L52,50 L76,38 L100,46 L124,34 L148,42 L172,48 L196,44 L220,52 L244,46 L268,56 L292,50 L316,58"
                  fill="none" stroke="var(--tekst-svak)" strokeWidth="1.5" strokeDasharray="3 3"
                />
                <path
                  d="M4,48 L28,42 L52,54 L76,40 L100,52 L124,38 L148,50 L172,62 L196,58 L220,70 L244,64 L268,76 L292,70 L316,78"
                  fill="none" stroke="var(--gronn)" strokeWidth="2.2"
                />
                <circle cx="316" cy="78" r="3.5" fill="var(--gronn)" />
                <text x="4" y="114" fontSize="9" fill="var(--tekst-svak)">24. aug</text>
                <text x="270" y="114" fontSize="9" fill="var(--tekst-svak)">6. sep</text>
              </svg>
              <p className="lp-tegnforklaring">
                <span><span className="lp-strek" /> Faktisk</span>
                <span><span className="lp-strek lp-strek-stiplet" /> Prognose</span>
              </p>
            </div></div>
          </div>
        </div>

        {/* PRODUKSJON */}
        <div
          className={aktiv === 'produksjon' ? 'lp-panel lp-panel-aktiv' : 'lp-panel'}
          role="tabpanel" id="panel-produksjon" aria-labelledby="fane-produksjon"
        >
          <div>
            <h3>Produksjonsplanen måles mot salget dagen etter.</h3>
            <p className="lp-panel-p">
              Systemet foreslår antall per vare og time. Gulvet skriver inn hva som faktisk
              ble laget, og treffsikkerheten regnes ut i etterkant — så forslaget lærer.
            </p>
            <ul className="lp-punkter">
              <Punkt navn="Foreslått i går" verdi="142" />
              <Punkt navn="Faktisk lagd" verdi="168" />
              <Punkt navn="Solgt" verdi="139" />
              <Punkt navn="Kastet" verdi="29" retning="ned" />
            </ul>
            <Anbefaling>
              Reduser siste steking etter 17:00 med 20 stk. Overproduksjonen forsvinner ikke
              i kassa — den kommer tilbake som usynlig svinn i regnskapet.
            </Anbefaling>
          </div>
          <div className="lp-flate-ramme lp-flate-ramme-tett">
            <div className="lp-flate"><div className="lp-flate-kropp">
              <p className="lp-vis-merke">Traff vi? · siste 8 dager</p>
              <div className="lp-barer">
                <Bar navn="Bakeri" pst={84} paa={synlig} />
                <Bar navn="Varmmat" pst={71} farge="gul" paa={synlig} />
                <Bar navn="Påsmurt" pst={91} paa={synlig} />
                <Bar navn="Pizza" pst={62} farge="rod" paa={synlig} />
              </div>
              <p className="lp-vis-note">
                Andel dager innenfor planen. Nettbrettet på gulvet fører inn det som faktisk
                ble lagd.
              </p>
            </div></div>
          </div>
        </div>

        {/* BEMANNING */}
        <div
          className={aktiv === 'bemanning' ? 'lp-panel lp-panel-aktiv' : 'lp-panel'}
          role="tabpanel" id="panel-bemanning" aria-labelledby="fane-bemanning"
        >
          <div>
            <h3>Timerammen kommer fra forretningsplanen.</h3>
            <p className="lp-panel-p">
              Bemanningsplanleggeren fordeler årets timer på måneder og døgn ut fra når
              kundene faktisk er der — ikke ut fra åpningstiden.
            </p>
            <ul className="lp-punkter">
              <Punkt navn="Ramme september" verdi="640 t" />
              <Punkt navn="Planlagt" verdi="612 t" />
              <Punkt navn="Stemplet hittil" verdi="421 t" />
              <Punkt navn="Røde dager i måneden" verdi="1" />
            </ul>
            <Anbefaling>
              Torsdag har 2,3 timer mer enn kundegrunnlaget tilsier, fredag 1,8 for lite.
              Flytt én vakt, så treffer uka rammen uten å kutte.
            </Anbefaling>
          </div>
          <div className="lp-flate-ramme lp-flate-ramme-tett">
            <div className="lp-flate"><div className="lp-flate-kropp">
              <p className="lp-vis-merke">Kunder per time · torsdag</p>
              <svg
                className="lp-graf" viewBox="0 0 320 112" role="img"
                aria-label="Kunder per time på torsdag, med planlagt bemanning lagt over. Toppene er klokken 11 og 16."
              >
                <g fill="var(--kant-sterk)">
                  <rect x="6" y="76" width="18" height="20" rx="2" />
                  <rect x="30" y="66" width="18" height="30" rx="2" />
                  <rect x="54" y="52" width="18" height="44" rx="2" />
                  <rect x="78" y="40" width="18" height="56" rx="2" />
                  <rect x="102" y="30" width="18" height="66" rx="2" />
                  <rect x="126" y="26" width="18" height="70" rx="2" />
                  <rect x="150" y="38" width="18" height="58" rx="2" />
                  <rect x="174" y="46" width="18" height="50" rx="2" />
                  <rect x="198" y="34" width="18" height="62" rx="2" />
                  <rect x="222" y="28" width="18" height="68" rx="2" />
                  <rect x="246" y="44" width="18" height="52" rx="2" />
                  <rect x="270" y="62" width="18" height="34" rx="2" />
                  <rect x="294" y="80" width="18" height="16" rx="2" />
                </g>
                <path
                  d="M6,80 L48,64 L96,44 L144,30 L192,42 L240,32 L288,64 L312,84"
                  fill="none" stroke="var(--gronn)" strokeWidth="2"
                />
                <text x="6" y="109" fontSize="9" fill="var(--tekst-svak)">07</text>
                <text x="150" y="109" fontSize="9" fill="var(--tekst-svak)">14</text>
                <text x="292" y="109" fontSize="9" fill="var(--tekst-svak)">21</text>
              </svg>
              <p className="lp-tegnforklaring">
                <span><span className="lp-rute" /> Kunder</span>
                <span><span className="lp-strek" /> Planlagt bemanning</span>
              </p>
            </div></div>
          </div>
        </div>

        {/* SVINN */}
        <div
          className={aktiv === 'svinn' ? 'lp-panel lp-panel-aktiv' : 'lp-panel'}
          role="tabpanel" id="panel-svinn" aria-labelledby="fane-svinn"
        >
          <div>
            <h3>Kastet er én halvdel. Resten så ingen.</h3>
            <p className="lp-panel-p">
              Det som føres som kast er registrert svinn. Differansen mellom teoretisk og
              faktisk bruttofortjeneste er resten — for mat er det som regel overproduksjon.
            </p>
            <ul className="lp-punkter">
              <Punkt navn="Registrert kast" verdi="164 735" />
              <Punkt navn="Usynlig svinn" verdi="−8 241" retning="opp" />
              <Punkt navn="Totalt svinn" verdi="156 493" />
              <Punkt navn="Forretningsplanen tåler" verdi="144 234" />
            </ul>
            <Anbefaling>
              Rommet er stramt fordi salget ligger under budsjett tre av sju måneder — ikke
              fordi det er kastet mer. Bruttokravet står i kroner.
            </Anbefaling>
          </div>
          <div className="lp-flate-ramme lp-flate-ramme-tett">
            <div className="lp-flate"><div className="lp-flate-kropp">
              <p className="lp-vis-merke">Kastbudsjett · hittil i år</p>
              <p className="lp-nokkel-verdi">15,2 %</p>
              <p className="lp-nokkel-under">kravet er 13,6 % av omsetning</p>
              <div className="lp-skille" />
              <div className="lp-liste-linjer">
                <span className="lp-linje">Bakeri<span className="lp-v lp-v-rod">+8 412</span></span>
                <span className="lp-linje">Påsmurt<span className="lp-v lp-v-rod">+6 220</span></span>
                <span className="lp-linje">Pølse<span className="lp-v lp-v-gronn">−1 908</span></span>
              </div>
              <p className="lp-vis-note">
                Avlagt måned tar regnskapet. Åpen måned tar den daglige opplastingen — og
                kortet sier hvilken.
              </p>
            </div></div>
          </div>
        </div>

        {/* ØKONOMI */}
        <div
          className={aktiv === 'okonomi' ? 'lp-panel lp-panel-aktiv' : 'lp-panel'}
          role="tabpanel" id="panel-okonomi" aria-labelledby="fane-okonomi"
        >
          <div>
            <h3>Lønn og resultat mot det som faktisk er budsjettert.</h3>
            <p className="lp-panel-p">
              Regnskapet er fasit. Sentiqa leser lønnskontiene, holder dem mot budsjettet i
              forretningsplanen, og sier hvilken måned som drar.
            </p>
            <ul className="lp-punkter">
              <Punkt navn="Lønnskost juli" verdi="242 963" />
              <Punkt navn="Budsjett" verdi="261 018" />
              <Punkt navn="Avvik" verdi="−18 055" retning="opp" />
              <Punkt navn="Snittsats timelønn" verdi="216 kr" />
            </ul>
            <Anbefaling>
              Juni ligger 65 000 under de andre månedene. Det er ferietrekket, ikke en
              billig måned — se den i sammenheng med juli før du konkluderer.
            </Anbefaling>
          </div>
          <div className="lp-flate-ramme lp-flate-ramme-tett">
            <div className="lp-flate"><div className="lp-flate-kropp">
              <p className="lp-vis-merke">Lønnskost mot budsjett</p>
              <div className="lp-liste-linjer">
                <span className="lp-linje">juli<span className="lp-v">242 963</span>
                  <span className="lp-v lp-v-gronn">−18 055</span></span>
                <span className="lp-linje">juni<span className="lp-v">175 384</span>
                  <span className="lp-v lp-v-gronn">−37 803</span></span>
                <span className="lp-linje">mai<span className="lp-v">262 838</span>
                  <span className="lp-v lp-v-gronn">−15 178</span></span>
                <span className="lp-linje">april<span className="lp-v">242 571</span>
                  <span className="lp-v lp-v-gronn">−25 814</span></span>
              </div>
              <p className="lp-vis-note">
                Ni lønnskonti, verifisert mot stemplingene: samme måned, samme tall, to veier.
              </p>
            </div></div>
          </div>
        </div>

        {/* ANSATTE */}
        <div
          className={aktiv === 'ansatte' ? 'lp-panel lp-panel-aktiv' : 'lp-panel'}
          role="tabpanel" id="panel-ansatte" aria-labelledby="fane-ansatte"
        >
          <div>
            <h3>Folkene, ikke bare timene.</h3>
            <p className="lp-panel-p">
              Arbeidsavtaler, stillingsprosent, timesats mot tariff, opplæring, skills-score,
              merker og konkurranser. Nettbrettet på gulvet er de ansattes flate — de
              stempler, krysser av rutiner og ser sine egne merker.
            </p>
            <ul className="lp-punkter">
              <Punkt navn="Timesats mot tariff" verdi="10 av 10 innenfor" retning="opp" />
              <Punkt navn="Arbeidsavtaler" verdi="8 av 10 signert" />
              <Punkt navn="Opplæring fullført" verdi="6 av 10" />
            </ul>
            <Anbefaling>
              To ansatte har sats mellom to tarifftrinn. Sett arbeidstid manuelt på dem —
              knappen som utleder ordningen fra satsen tier når satsen er tvetydig.
            </Anbefaling>
          </div>
          <div className="lp-flate-ramme lp-flate-ramme-tett">
            <div className="lp-flate"><div className="lp-flate-kropp">
              <p className="lp-vis-merke">Mot Energiavtalen</p>
              <div className="lp-liste-linjer">
                <span className="lp-linje">II Butikkpersonell · 6 år, to skift
                  <span className="lp-v lp-lapp lp-lapp-gronn">Tariff</span></span>
                <span className="lp-linje">II Butikkpersonell · 3 år, to skift
                  <span className="lp-v lp-lapp lp-lapp-gronn">Tariff</span></span>
                <span className="lp-linje">Mellom to trinn
                  <span className="lp-v lp-lapp lp-lapp-gul">Sjekk</span></span>
                <span className="lp-linje">II Butikkpersonell · 0–1 år
                  <span className="lp-v lp-lapp lp-lapp-gronn">Tariff</span></span>
              </div>
              <p className="lp-vis-note">
                Satstabellen er transkribert fra tariffarket, ikke utledet.
              </p>
            </div></div>
          </div>
        </div>

        {/* LEDELSE */}
        <div
          className={aktiv === 'ledelse' ? 'lp-panel lp-panel-aktiv' : 'lp-panel'}
          role="tabpanel" id="panel-ledelse" aria-labelledby="fane-ledelse"
        >
          <div>
            <h3>Fire roller, fire flater.</h3>
            <p className="lp-panel-p">
              Eieren ser kjeden. Butikksjefen ser sine stasjoner. Nettbrettet på gulvet ser
              dagen sin. Hver rolle ser bare det den skal — det er håndhevet i databasen,
              ikke i menyen.
            </p>
            <ul className="lp-punkter">
              <Punkt navn="Eier" verdi="hele kjeden" />
              <Punkt navn="Butikksjef" verdi="egne stasjoner" />
              <Punkt navn="Nettbrett" verdi="dagens vakt" />
            </ul>
            <Anbefaling merke="Slik er det bygget">
              Tilgangen ligger i radnivåsikring i databasen. En side kan ikke vise noe
              brukeren ikke har lov til, selv om noen skulle lenke direkte til den.
            </Anbefaling>
          </div>
          <div className="lp-flate-ramme lp-flate-ramme-tett">
            <div className="lp-flate"><div className="lp-flate-kropp">
              <p className="lp-vis-merke">Nettbrettet · på vakt</p>
              <div className="lp-liste-linjer">
                <span className="lp-linje"><span className="lp-pip lp-pip-gronn" />Stemplet inn 06:58</span>
                <span className="lp-linje"><span className="lp-pip lp-pip-gronn" />Morgenrutine · 7 av 7</span>
                <span className="lp-linje"><span className="lp-pip lp-pip-gul" />IK-mat temperatur · mangler</span>
                <span className="lp-linje"><span className="lp-pip lp-pip-gronn" />Produksjon ført · 168 stk</span>
              </div>
              <p className="lp-vis-note">
                Ansatte identifiseres med ansattnummer og PIN. Vakten huskes i en signert
                kapsel, ikke i et navn skjermen viser fram.
              </p>
            </div></div>
          </div>
        </div>
      </div>
    </section>
  )
}
