// =====================================================================
// UKEBRIEFEN
//
// Formen er `Ukebrief` i lib/ukebrief/type.ts: overskrift, ingress,
// `bra`, `oppmerksomhet`, `handlinger` og `viIkkeVet`. Reglene som står
// i teksten er modulens egne, ikke markedsføring:
//
//   «Samme uke gir samme brev hver gang — et brev som endrer seg mellom
//    to kjøringer kan ikke etterprøves av den som fikk det forrige
//    mandag.»
//
//   «Fem er ikke et designvalg, det er et lesevalg. Over dette slutter
//    en liste å være en prioritering og blir en oversikt.»
//
// «HVA VI IKKE VET» ER MED I BREVET, og derfor er den med her. Den er
// det som skiller brevet fra en rapport: et signal uten data foreslår
// ingenting, det havner der i stedet. Å vise brevet uten den bolken
// ville solgt et produkt som er lettere å stole på enn det er.
//
// Serverkomponent: ingenting her er interaktivt.
// =====================================================================

export function Ukebrief() {
  return (
    <section className="lp-seksjon lp-seksjon-tont" id="brev">
      <div className="lp-ramme">
        <p className="lp-eyebrow">Uten å logge inn</p>
        <h2 className="lp-h2">Mandag 07:00.</h2>
        <p className="lp-ingress">
          Ukebriefen skrives av tallene, ikke av en modell. Samme uke gir samme brev hver
          gang — et brev som endrer seg mellom to kjøringer kan ikke etterprøves av den
          som fikk det forrige mandag.
        </p>

        <div className="lp-brev">
          <div className="lp-brev-hode">
            <p className="lp-brev-tid">Mandag 07:00 · uke 36</p>
            <h3>Nordbyen holdt stand, men bakeriet kostet.</h3>
            <p>
              Omsetningen er opp 7,2 % mot samme uke i fjor. Det meste av gevinsten
              forsvant i kast.
            </p>
          </div>

          <div className="lp-brev-bolk">
            <h4>Dette gikk bra</h4>
            <ul>
              <li>Omsetning mot i fjor <span className="lp-v lp-v-gronn">+7,2 %</span></li>
              <li>Varm drikke <span className="lp-v lp-v-gronn">+13 %</span></li>
              <li>Produksjonstreff bakeri <span className="lp-v lp-v-gronn">84 %</span></li>
            </ul>
          </div>

          <div className="lp-brev-bolk">
            <h4>Krever oppmerksomhet</h4>
            <ul>
              <li>Kast bakeri <span className="lp-v lp-v-rod">+18 %</span></li>
              <li>Timer over plan <span className="lp-v lp-v-rod">27 t</span></li>
              <li>IK-mat ikke ført <span className="lp-v lp-v-rod">2 dager</span></li>
            </ul>
          </div>

          <div className="lp-brev-bolk lp-brev-bred">
            <h4>Sentiqa foreslår</h4>
            <ul>
              <li>1 · Reduser siste steking etter 17:00</li>
              <li>2 · Følg opp mersalg på kveldsvakt</li>
              <li>3 · Se på torsdagsbemanningen før neste uke</li>
            </ul>
          </div>

          <p className="lp-brev-vet">
            <strong>Hva vi ikke vet:</strong>{' '}
            stemplinger mangler for onsdag og torsdag, så timene over er planlagte,
            ikke faktiske.
          </p>
        </div>

        <p className="lp-brev-note">
          Maks fem forslag. Et brev med tolv gjøremål blir ingen gjøremål — og et signal
          uten data foreslår ingenting, det havner under «hva vi ikke vet».
        </p>
      </div>
    </section>
  )
}
