// =====================================================================
// Signalmotor — det som avgjør hva butikksjefen ser først.
//
// Problemet er ikke å finne avvik. Systemet vet allerede om forsinkede
// oppgaver, uleste tilbakemeldinger, åpne avvik og kategorier som faller.
// Problemet er at alt vises med lik vekt, i hver sin modul, så sjefen må
// lete for å finne ut om noe haster.
//
// Her rangeres de mot hverandre. Tre ting avgjør, i denne rekkefølgen:
//
//   1. ALVOR      — en krenkelse slår alltid en kategori som faller.
//   2. KONSEKVENS — kroner, men kvadratrot-skalert. 100 000 kr er verre
//                   enn 10 000, men ikke ti ganger verre; uten demping
//                   ville ett stort tall skjult alt annet for alltid.
//   3. VARIGHET   — fire dager på rad er et mønster, én dag er en dag.
//
// Og for kategorisignalene: det som teller er ikke at noe faller, men at
// det faller MOTSATT av resten av butikken. Faller alt, er det sesong
// eller vær — ingenting butikksjefen kan gjøre noe med i morgen.
// =====================================================================

export type Nivaa = 'kritisk' | 'folg' | 'info'

export type RaaSignal = {
  id: string
  merke: string // hvor det kommer fra: «Salg», «Oppgaver» …
  tittel: string
  endring?: string // kort nøkkeltall til høyre for tittelen
  detalj: string
  niva: Nivaa
  lenke: string
  konsekvensKr?: number | null
  dager?: number | null
}

export type Signal = RaaSignal & { poeng: number }

const GRUNNPOENG: Record<Nivaa, number> = { kritisk: 1000, folg: 300, info: 50 }

export function poengFor(s: RaaSignal): number {
  let p = GRUNNPOENG[s.niva]
  if (s.konsekvensKr) p += Math.min(400, Math.sqrt(Math.abs(s.konsekvensKr)) * 1.2)
  if (s.dager) p += Math.min(200, s.dager * 25)
  return Math.round(p)
}

export function rangerSignaler(raa: RaaSignal[]): Signal[] {
  return raa
    .map((s) => ({ ...s, poeng: poengFor(s) }))
    .sort((a, b) => b.poeng - a.poeng || a.tittel.localeCompare(b.tittel, 'nb'))
}

// Overskriften i pulsen. Skrevet ut fra tallet, ikke av en modell — den
// skal si det samme hver gang for samme tall, og aldri koste et API-kall.
export function pulsOverskrift(navn: string, vekstPst: number): string {
  if (vekstPst >= 25) return `${navn} har en sterk uke`
  if (vekstPst >= 5) return `${navn} ligger foran fjoråret`
  if (vekstPst > -5) return `${navn} ligger på fjorårsnivå`
  if (vekstPst > -20) return `${navn} ligger bak fjoråret`
  return `${navn} har en svak uke`
}

// --- Kategorier som beveger seg motsatt av butikken ------------------

export type Avdeling = { kode: string; navn: string; omsetning: number; ifjor: number; vekstPst: number }

// Under dette er beløpet for lite til å bruke sjefens oppmerksomhet på,
// uansett hvor stort utslaget er i prosent.
const MIN_KRONER = 2000
// Under dette er kategorien for liten i fjor til at prosenten betyr noe.
const MIN_IFJOR = 5000
// Hvor mange prosentpoeng den må avvike fra butikken for å være et signal.
const MIN_AVVIK_PP = 25

/**
 * Finner kategorier som drar i motsatt retning av butikken samlet.
 *
 * En kategori som faller 20 % i en butikk som faller 20 % er ikke en sak —
 * den følger med. En kategori som faller 63 % i en butikk som stiger 216 %
 * avviker med 279 prosentpoeng, og det er noe helt annet.
 */
export function avdelingsSignaler(opts: {
  avdelinger: Avdeling[]
  omsetning: number
  omsetningIfjor: number
}): RaaSignal[] {
  const butikkPst = opts.omsetningIfjor > 0
    ? ((opts.omsetning - opts.omsetningIfjor) / opts.omsetningIfjor) * 100
    : 0

  const ut: RaaSignal[] = []
  for (const a of opts.avdelinger) {
    if (a.ifjor < MIN_IFJOR) continue
    const kroner = a.omsetning - a.ifjor
    if (kroner >= 0) continue // vi varsler ikke om vekst
    if (Math.abs(kroner) < MIN_KRONER) continue

    const avvikPp = butikkPst - a.vekstPst
    if (avvikPp < MIN_AVVIK_PP) continue

    // Kritisk når den både er stor i kroner og tydelig alene om retningen.
    const niva: Nivaa = Math.abs(kroner) >= 10000 && avvikPp >= 50 ? 'kritisk' : 'folg'
    ut.push({
      id: `avd-${a.kode}`,
      merke: 'Salg',
      tittel: a.navn,
      endring: `${a.vekstPst < 0 ? '↓' : '↑'} ${Math.abs(a.vekstPst).toFixed(0)} %`,
      detalj:
        `${Math.abs(Math.round(kroner)).toLocaleString('nb-NO')} kr lavere enn i fjor. ` +
        `Butikken samlet ${butikkPst >= 0 ? 'steg' : 'falt'} ${Math.abs(butikkPst).toFixed(0)} % — ` +
        'denne kategorien går motsatt vei.',
      niva,
      lenke: '/salg',
      konsekvensKr: kroner,
    })
  }
  return ut
}
