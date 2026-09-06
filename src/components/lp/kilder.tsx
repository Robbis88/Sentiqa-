import { KILDER } from '@/lib/onboarding'

// =====================================================================
// KILDENE — RENDRET FRA PRODUKTETS EGEN LISTE
//
// `KILDER` er den samme konstanten `onboardingsteg()` måler mot inne i
// appen. Den bærer navnet, hvor fila hentes fra, hva den låser opp, og
// om den er kritisk — alt sammen skrevet én gang, av den som bygde
// modulen.
//
// **ÉN SANNHET, IKKE TO.** Alternativet var å skrive lista av her.
// Da hadde markedssida og produktet skilt lag første gang noen la til
// en kilde, og det er nøyaktig formen på feilen dette repoet har lært
// å kjenne igjen: en liste som ser komplett ut dagen den blir feil.
//
// Legger noen til en tiende kilde i `onboarding.ts`, står den her
// samme kveld.
//
// Serverkomponent med vilje: ingenting her er interaktivt, så det
// koster null i bundle.
// =====================================================================

export function Kilder() {
  return (
    <section className="lp-seksjon" id="data">
      <div className="lp-ramme">
        <p className="lp-eyebrow">Hvordan Sentiqa får dataene</p>
        <h2 className="lp-h2">{KILDER.length} filer du allerede får tilsendt.</h2>
        <p className="lp-ingress">
          Ingenting skal legges inn på nytt. Sentiqa leser rapportene kjeden, regnskapsføreren
          og stemplingssystemet sender fra seg — og hver av dem låser opp noe bestemt.
        </p>

        <div className="lp-kilder">
          {KILDER.map((k) => (
            <article className="lp-kilde" key={k.noekkel}>
              <h3 className="lp-kilde-navn">{k.navn}</h3>
              <p className="lp-kilde-fra">{k.hentesFra}</p>
              <p className="lp-kilde-laser">{k.laserOpp}</p>
              {k.kritisk && <span className="lp-kilde-krit">Kritisk</span>}
            </article>
          ))}
        </div>

        <div className="lp-inntak">
          <div className="lp-inntak-tekst">
            <strong>Eller la det gå av seg selv.</strong>
            <p>
              Hver kjede får sin egen inntaksadresse. Videresend rapportene dit, så havner
              vedleggene rett i importkøen.
            </p>
          </div>
          <span className="lp-inntak-adr">kjedenavn@inntak.sentiqa.ai</span>
        </div>
      </div>
    </section>
  )
}
