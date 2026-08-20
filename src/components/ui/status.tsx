// =====================================================================
// Status og Signal.
//
// ROLIG SOM STANDARD. Det viktigste designvalget i hele biblioteket
// ligger her: en liste der alt er i orden skal være nesten fargeløs.
//
// Farge er et budsjett. Fyller man normale rader med grønne merker,
// er det ingenting igjen å bruke den dagen noe faktisk er galt — og da
// leser folk forbi det røde også, fordi skjermen alltid har vært
// broket.
//
//   normal    Ingen farge. Bare tekst og en nøytral prikk.
//   endring   Svak farge. Noe har beveget seg.
//   handling  Tydelig. Noen må gjøre noe.
//   kritisk   Umulig å overse.
//
// «Aktiv» på en ansattliste er NORMAL, ikke suksess. Det er ingen god
// nyhet at en ansatt er aktiv — det er utgangspunktet.
// =====================================================================

export type Statusnivaa = 'normal' | 'endring' | 'handling' | 'kritisk'

/**
 * Status på en rad eller et objekt.
 *
 * Fargelegger IKKE raden. Prikken og teksten bærer det, og resten av
 * raden blir stående rolig — ellers kan ikke to statuser stå ved siden
 * av hverandre uten at siden blir et fargekart.
 */
export function Status({
  nivaa = 'normal',
  children,
}: {
  nivaa?: Statusnivaa
  children: React.ReactNode
}) {
  return (
    <span className={`sq-status sq-status-${nivaa}`}>
      <span className="sq-status-prikk" aria-hidden />
      {children}
    </span>
  )
}

export type Signalnivaa = 'informasjon' | 'mulighet' | 'oppmerksomhet' | 'kritisk'

/**
 * Noe systemet har å fortelle.
 *
 * REN VISNING. Komponenten henter ingenting, tolker ingenting og
 * genererer ingenting. Den vet ikke hva et signal er — den tegner det
 * den får. Legger man datalogikk her, blir det umulig å svare på
 * hvorfor et signal dukket opp, fordi svaret ligger spredt mellom
 * spørringen og malen.
 *
 * FINNES DET INGENTING Å SI, SKAL DEN IKKE RENDRES. Ikke et tomt
 * signalkort, ikke «ingen funn» — bare ingenting. Et varselfelt som
 * står der uten innhold lærer folk å slutte å se på det.
 */
export function Signal({
  nivaa = 'informasjon',
  tittel,
  children,
  handling,
}: {
  nivaa?: Signalnivaa
  tittel: string
  /** Én setning på norsk. Ikke en rapport. */
  children?: React.ReactNode
  /** Veien videre, når det finnes en. */
  handling?: React.ReactNode
}) {
  return (
    <div className={`sq-signal sq-signal-${nivaa}`} role={nivaa === 'kritisk' ? 'alert' : undefined}>
      <span className="sq-signal-prikk" aria-hidden />
      <div className="sq-signal-tekst">
        <strong>{tittel}</strong>
        {children && <p>{children}</p>}
      </div>
      {handling && <div className="sq-signal-handling">{handling}</div>}
    </div>
  )
}
