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
  /** Hvilken stasjon funnet gjelder. Butikksjefen har som regel én, så den
      utledes ved skriving; eierens stasjonssignaler peker på en bestemt. */
  stasjonId?: string
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

// --- Eierens akse: er det stasjonen eller er det markedet? -----------

export type Stasjonsrapport = {
  stasjonId: string
  navn: string
  omsetning: number
  omsetningIfjor: number
}

export type Klyngebilde = {
  omsetning: number
  omsetningIfjor: number
  vekstPst: number
  /** Stasjoner sortert etter hvor mye de avviker fra klyngen, verst først. */
  rader: {
    stasjonId: string
    navn: string
    vekstPst: number
    /** Prosentpoeng over/under klyngen. Negativt = henger etter. */
    avvikPp: number
    /** Kroner stasjonen ligger unna der den ville vært med klyngens vekst. */
    residualKr: number
  }[]
  signaler: RaaSignal[]
}

// Hvor mange prosentpoeng en stasjon må avvike fra klyngen for å bli en sak.
const STASJON_AVVIK_PP = 12
// Og hvor mange kroner residualen minst må utgjøre.
const STASJON_MIN_KR = 15000

/**
 * Skiller stasjonsspesifikke problemer fra markedet.
 *
 * Faller alle stasjonene, er det vær, sesong eller pris — ingenting en
 * butikksjef kan gjøre noe med i morgen, og fem varsler om det samme er
 * bare støy. Faller én mens de andre ligger flatt, er det den stasjonen,
 * og da skal saken havne hos én person med et navn.
 *
 * Residualen er det ærlige tallet: hvor mange kroner stasjonen ligger unna
 * der den ville vært om den hadde beveget seg som klyngen.
 */
export function klyngebilde(rapporter: Stasjonsrapport[]): Klyngebilde {
  const omsetning = rapporter.reduce((a, r) => a + r.omsetning, 0)
  const omsetningIfjor = rapporter.reduce((a, r) => a + r.omsetningIfjor, 0)
  const vekstPst = omsetningIfjor > 0 ? ((omsetning - omsetningIfjor) / omsetningIfjor) * 100 : 0

  // Målestokken for én stasjon er DE ANDRE stasjonene, ikke klyngen den selv
  // inngår i. Dale er størst; lar vi Dale telle med i sin egen målestokk,
  // trekker den snittet ned mot seg selv og under-oppdager sitt eget avvik.
  const rader = rapporter
    .filter((r) => r.omsetningIfjor > 0)
    .map((r) => {
      const egen = ((r.omsetning - r.omsetningIfjor) / r.omsetningIfjor) * 100
      const andre = rapporter.filter((x) => x.stasjonId !== r.stasjonId)
      const andreIfjor = andre.reduce((a, x) => a + x.omsetningIfjor, 0)
      const andreVekst = andreIfjor > 0
        ? ((andre.reduce((a, x) => a + x.omsetning, 0) - andreIfjor) / andreIfjor) * 100
        : null
      // Én stasjon alene har ingen målestokk — da kan vi ikke skille
      // stasjonen fra markedet, og skal ikke late som.
      const maalestokk = andreVekst ?? egen
      return {
        stasjonId: r.stasjonId,
        navn: r.navn,
        vekstPst: egen,
        avvikPp: egen - maalestokk,
        residualKr: r.omsetning - r.omsetningIfjor * (1 + maalestokk / 100),
      }
    })
    .sort((a, b) => a.avvikPp - b.avvikPp)

  const signaler: RaaSignal[] = []

  // Faller hele klyngen, er det ÉN sak — ikke én per stasjon.
  if (vekstPst <= -5 && rader.length > 1 && rader.every((r) => r.vekstPst < 0)) {
    signaler.push({
      id: 'klynge-ned',
      merke: 'Marked',
      tittel: 'Alle stasjonene faller',
      endring: `↓ ${Math.abs(vekstPst).toFixed(0)} %`,
      detalj:
        'Nedgangen er felles for hele klyngen. Da er det sesong, vær eller pris — ' +
        'ikke noe den enkelte butikksjefen kan rette opp i neste uke.',
      niva: 'folg',
      lenke: '/salg',
      konsekvensKr: omsetning - omsetningIfjor,
    })
  }

  for (const r of rader) {
    if (r.avvikPp > -STASJON_AVVIK_PP) continue
    if (Math.abs(r.residualKr) < STASJON_MIN_KR) continue
    signaler.push({
      id: `stasjon-${r.stasjonId}`,
      stasjonId: r.stasjonId,
      merke: 'Stasjon',
      tittel: r.navn,
      endring: `${r.avvikPp.toFixed(0)} pp mot klyngen`,
      detalj:
        `${Math.abs(Math.round(r.residualKr)).toLocaleString('nb-NO')} kr under der stasjonen ` +
        `ville vært med klyngens utvikling. De øvrige stasjonene forklarer ikke dette.`,
      niva: Math.abs(r.residualKr) >= 60000 ? 'kritisk' : 'folg',
      lenke: '/regnskap',
      konsekvensKr: r.residualKr,
    })
  }

  return { omsetning, omsetningIfjor, vekstPst, rader, signaler }
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

// --- Ferskhet på salgsdata -------------------------------------------

export type Ferskhet = { nivaa: 'fersk' | 'sen' | 'gammel'; dager: number; tekst: string }

/**
 * Hvor gamle er salgstallene, og skal det uroe noen?
 *
 * Salgsdata kommer alltid dagen etter — én dag gammelt er normaltilstanden,
 * ikke et avvik. Men fra og med natten filene lastes opp automatisk, er
 * dette det ENESTE stedet som røper at rørledningen har stoppet. En prikk
 * som alltid er grønn ville løyet i nøyaktig den situasjonen den finnes for.
 */
export function ferskhet(sisteSalgsdag: string, idag: string): Ferskhet {
  const dager = Math.round(
    (Date.parse(`${idag}T12:00:00Z`) - Date.parse(`${sisteSalgsdag}T12:00:00Z`)) / 86400000,
  )
  if (dager <= 1) return { nivaa: 'fersk', dager, tekst: '' }
  if (dager <= 3) return { nivaa: 'sen', dager, tekst: `${dager} dager gamle` }
  return { nivaa: 'gammel', dager, tekst: `${dager} dager gamle — importen har trolig stoppet` }
}
