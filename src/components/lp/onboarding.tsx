'use client'
import { OPPSTART } from './demo'
import { useSynlig } from './bevegelse'

// =====================================================================
// ONBOARDING — UTEN PROSENTBAR, MED VILJE
//
// Den vanlige måten å tegne dette på er «78 % ferdig» med en bar.
// Produktet nekter, og begrunnelsen står i `lib/onboarding.ts`:
//
//   «Ingen prosentbar. En prosentbar sier «du er 60 % ferdig» og skjuler
//    at de siste 40 er den ene fila som gjør at bemanningsplanen virker.»
//
// Sida viser derfor det samme som appen: status per kilde, per stasjon,
// med hva som mangler og for hvem. Sitatet er selve poenget i seksjonen
// — det sier til en skeptisk kjøper at systemet ikke pynter på hvor
// langt han er kommet, og det er et sterkere salgsargument enn et tall
// som alltid ser oppmuntrende ut.
//
// Statusordene er modulens egne: `mangler`, `tynt`, `ufullstendig`, `ok`.
// =====================================================================

const KLASSE = { ok: 'lp-ob-ok', tynt: 'lp-ob-tynt', mangler: 'lp-ob-mangler' } as const

export function Onboarding() {
  const { ref, synlig } = useSynlig<HTMLDivElement>(0.25)

  return (
    <section className="lp-seksjon lp-seksjon-tont" id="onboarding">
      <div className="lp-ramme">
        <p className="lp-eyebrow">Fra tom konto til drift</p>
        <h2 className="lp-h2">Du bygger ikke om selskapet ditt.</h2>
        <p className="lp-ingress">
          Sentiqa måler hva som faktisk ligger inne — per stasjon, per kilde — og sier hva
          som mangler, for hvem, og hva du får når det er på plass. Modulene åpner seg
          etter hvert som grunnlaget kommer.
        </p>

        <div className="lp-ob">
          <div className="lp-ob-liste" ref={ref}>
            <div className="lp-ob-hode">
              <h3>Oppstart</h3>
              <span className="lp-demo">Demodata</span>
            </div>
            {OPPSTART.map((s) => (
              <div
                className={`lp-ob-rad ${synlig ? KLASSE[s.status] : 'lp-ob-mangler'}`}
                key={s.navn}
              >
                <span className="lp-ob-ikon" aria-hidden="true">&#10003;</span>
                <span>
                  <span className="lp-ob-navn">{s.navn}</span>
                  <span className="lp-ob-beskjed">{s.beskjed}</span>
                </span>
                <span className="lp-ob-status">{s.merke}</span>
              </div>
            ))}
          </div>

          <div>
            <h3>Ingen prosentbar.</h3>
            <blockquote className="lp-sitat">
              «En prosentbar sier <em>du er 60 % ferdig</em> og skjuler at de siste 40 er
              den ene fila som gjør at bemanningsplanen virker.»
              <cite>onboarding.ts · fra kildekoden</cite>
            </blockquote>
            <p className="lp-ob-tekst">
              Derfor er beskjeden alltid konkret: hvilken kilde, hvilke stasjoner, hvor
              mange dager — og hva den låser opp. Et steg som står som{' '}
              <span className="lp-flamme">Tynt</span> betyr at analysen finnes, men ikke er
              til å stole på ennå. Sentiqa sier det heller enn å gjette.
            </p>
          </div>
        </div>
      </div>
    </section>
  )
}
