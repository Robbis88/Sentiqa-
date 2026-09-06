'use client'
import Link from 'next/link'
import { useSynlig, useTeller } from './bevegelse'

// =====================================================================
// HERO — PRODUKTET ER BILDET
//
// Flata under overskriften er `/oversikt` sin faktiske form: hilsen,
// «krever oppmerksomhet», og nøkkeltallsraden. Ikke en tegning av et
// dashbord, men den samme oppbygningen en eier møter om morgenen.
//
// LYS FLATE PÅ MØRK GRUNN. Appen er lys. Å vise den mørk for at den
// skal passe til sida ville vært å vise fram noe som ikke finnes.
//
// TALLENE STÅR FERDIG VED LAST og teller opp når flata er sett. Et
// nøkkeltall parkert på null til noen scroller, er et tall som mangler
// i thumbnailen og for den som leser raskt — se `useTeller`.
// =====================================================================

function Nokkeltall(
  { merke, til, des = 0, pre = '', suff = '', under, opp, start }:
  {
    merke: string; til: number; des?: number; pre?: string; suff?: string
    under: string; opp?: boolean; start: boolean
  },
) {
  const v = useTeller(til, start, des)
  return (
    <div className="lp-nokkel">
      <p className="lp-nokkel-merke">{merke}</p>
      <p className="lp-nokkel-verdi">{pre}{v}{suff}</p>
      <p className={opp ? 'lp-nokkel-under lp-nokkel-under-opp' : 'lp-nokkel-under'}>{under}</p>
    </div>
  )
}

export function Hero() {
  const { ref, synlig } = useSynlig<HTMLDivElement>(0.15)
  const svinn = useTeller(20105, synlig)
  const timer = useTeller(27, synlig)

  return (
    <section className="lp-seksjon lp-hero">
      <div className="lp-ramme">
        <h1>
          Hele driften.<br />
          <span className="lp-dim">Ett system.</span>
        </h1>
        <p className="lp-hero-ingress">
          Salg, bemanning, svinn, produksjon, regnskap og folk ligger allerede i rapportene
          dine. Sentiqa leser dem sammen og sier hva som krever oppmerksomhet i dag.
        </p>
        <div className="lp-cta">
          <Link className="lp-knapp lp-knapp-stor" href="/registrer">Kom i gang</Link>
          <a className="lp-knapp lp-knapp-stor lp-knapp-stille" href="#produkt">
            Se hvordan det virker
          </a>
        </div>
        <p className="lp-fot">
          Selvbetjent oppstart · ingen systemer må byttes ut · faktura på EHF
        </p>

        <div className="lp-flate-ramme" ref={ref}>
          <div className="lp-flate">
            <div className="lp-flate-topp">
              <span className="lp-merke"><span className="lp-merke-prikk" />Sentiqa</span>
              <span className="lp-stasjonsvelger">5 stasjoner</span>
              <span className="lp-avatar" aria-hidden="true">RL</span>
            </div>

            <div className="lp-flate-kropp">
              <div className="lp-flate-hode">
                <div>
                  <p className="lp-hilsen">God morgen, Robert.</p>
                  <p className="lp-hilsen-under">Her er det du trenger å vite.</p>
                </div>
                <span className="lp-demo">Demodata</span>
              </div>

              <div className="lp-signalliste">
                <h3>Krever oppmerksomhet</h3>

                <div className="lp-signal">
                  <span className="lp-pip lp-pip-rod" />
                  <span className="lp-signal-tekst">
                    <span className="lp-signal-tittel">Nordbyen kaster mer enn kravet</span>
                    <span className="lp-signal-under">15,2 % av omsetning · kravet er 13,6 %</span>
                  </span>
                  <span className="lp-signal-verdi lp-v-rod">{svinn} kr</span>
                </div>

                <div className="lp-signal">
                  <span className="lp-pip lp-pip-gul" />
                  <span className="lp-signal-tekst">
                    <span className="lp-signal-tittel">Storhaug over bemanningsplanen</span>
                    <span className="lp-signal-under">Uke 36 · flest timer torsdag og fredag</span>
                  </span>
                  <span className="lp-signal-verdi">{timer} t</span>
                </div>

                <div className="lp-signal">
                  <span className="lp-pip lp-pip-gul" />
                  <span className="lp-signal-tekst">
                    <span className="lp-signal-tittel">Regnskapet for august mangler på Vestre</span>
                    <span className="lp-signal-under">
                      Lønn kan ikke måles mot ramme før det er inne
                    </span>
                  </span>
                  <span className="lp-signal-verdi">—</span>
                </div>

                <div className="lp-signal">
                  <span className="lp-pip lp-pip-gronn" />
                  <span className="lp-signal-tekst">
                    <span className="lp-signal-tittel">
                      Åsheim traff produksjonsplanen fem dager på rad
                    </span>
                    <span className="lp-signal-under">Bakeri innenfor på alle fem</span>
                  </span>
                  <span className="lp-signal-verdi lp-v-gronn">+5</span>
                </div>
              </div>

              <div className="lp-nokkelrad">
                <Nokkeltall
                  merke="Salg i går" til={184302} suff=" kr" start={synlig}
                  under="+6,4 % mot samme dag i fjor" opp
                />
                <Nokkeltall
                  merke="Mot forretningsplan" til={2.1} des={1} pre="+" suff=" %"
                  start={synlig} under="hittil i september"
                />
                <Nokkeltall
                  merke="Timer denne uken" til={612} suff=" av 640" start={synlig}
                  under="28 timer igjen av rammen"
                />
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}
