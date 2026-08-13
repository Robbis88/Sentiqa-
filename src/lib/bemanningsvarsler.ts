// =====================================================================
// Varsler etter regnskapsimport — bemanningssiden.
//
// Poenget er ikke å slå alarm, men å lære opp. Et varsel som bare sier
// «du brukte for mange timer» blir ignorert; et som sier hvor mange
// vakter det tilsvarer, hva det kostet, og hvorfor rammen var som den
// var, endrer neste måneds vaktplan.
//
// Derfor bærer hver tekst tre ting: tallet, oversettelsen til vakter og
// kroner, og årsaken. Og de går til stasjonen, ikke til retailer — det
// er butikksjefen som legger vaktplanen.
// =====================================================================

export type BemanningsMaaling = {
  maned: number
  timerBrukt: number
  timerDisponible: number | null
  timesatsFaktisk: number
  timesatsBudsjett: number | null
  bruttoPrTime: number
  bruttoPrTimeCluster: number
  bruttoFaktisk: number
  bruttoBudsjett: number | null
  sykelonnNetto: number
  reserveKr: number | null
  lonnAvBrutto: number // 0–1
}

export type Bemanningsvarsel = {
  type: string
  tittel: string
  tekst: string
}

const MND = ['januar', 'februar', 'mars', 'april', 'mai', 'juni',
  'juli', 'august', 'september', 'oktober', 'november', 'desember']

const kr = (n: number) => `${Math.round(n).toLocaleString('nb-NO')} kr`
const pst = (n: number) => `${(n * 100).toFixed(1).replace('.', ',')} %`

// Terskler. Satt slik at normal månedsstøy ikke utløser noe — det er
// verre å bli oversett enn å si for lite.
const TIMER_OVER = 0.05 // 5 % over disponible timer
const SATS_OVER = 0.03 // 3 % over budsjettert timesats
const BRUTTO_UNDER = 0.85 // under 85 % av clusterets brutto per time

export function lagBemanningsvarsler(m: BemanningsMaaling): Bemanningsvarsel[] {
  const ut: Bemanningsvarsel[] = []
  const mnd = MND[m.maned - 1] ?? `måned ${m.maned}`

  // --- Timeforbruk mot ramme ---
  if (m.timerDisponible && m.timerDisponible > 0) {
    const over = m.timerBrukt - m.timerDisponible
    if (over / m.timerDisponible > TIMER_OVER) {
      const vakter = Math.round(over / 8)
      const kostnad = over * m.timesatsFaktisk
      // Sviktet bruttoen samtidig, skulle rammen vært strammere, ikke løsere.
      const bruttoDel =
        m.bruttoBudsjett && m.bruttoBudsjett > 0 && m.bruttoFaktisk < m.bruttoBudsjett
          ? ` Bruttoen lå ${pst((m.bruttoBudsjett - m.bruttoFaktisk) / m.bruttoBudsjett)} bak budsjett` +
            ' samtidig — da skulle rammen vært strammere, ikke løsere.'
          : ''
      ut.push({
        type: 'bemanning_timer',
        tittel: `${Math.round(over)} timer over rammen i ${mnd}`,
        tekst:
          `Du brukte ${Math.round(m.timerBrukt)} timer mot ${Math.round(m.timerDisponible)} disponible. ` +
          `Det er ${Math.round(over)} timer, omtrent ${vakter} vakter, og ${kr(kostnad)}.${bruttoDel}`,
      })
    }
  }

  // --- Timesats mot budsjett ---
  if (m.timesatsBudsjett && m.timesatsBudsjett > 0) {
    const avvik = (m.timesatsFaktisk - m.timesatsBudsjett) / m.timesatsBudsjett
    if (avvik > SATS_OVER) {
      const ekstra = (m.timesatsFaktisk - m.timesatsBudsjett) * m.timerBrukt
      ut.push({
        type: 'bemanning_timesats',
        tittel: `Timesatsen ligger ${pst(avvik)} over budsjett`,
        tekst:
          `Snittsatsen i ${mnd} var ${Math.round(m.timesatsFaktisk)} kr mot ${Math.round(m.timesatsBudsjett)} kr ` +
          `budsjettert. På ${Math.round(m.timerBrukt)} timer utgjør det ${kr(ekstra)}. ` +
          'Sjekk om vaktene ligger på tillegg — kveld, helg og overtid koster mer enn snittet.',
      })
    }
  }

  // --- Sykefraværsreserven ---
  if (m.reserveKr !== null && m.reserveKr > 0 && m.sykelonnNetto > m.reserveKr) {
    ut.push({
      type: 'bemanning_sykefravaer',
      tittel: 'Sykefraværsreserven er brukt opp',
      tekst:
        `Netto sykelønn i ${mnd} var ${kr(m.sykelonnNetto)} mot ${kr(m.reserveKr)} avsatt. ` +
        'Kjeden budsjetterer sykelønn til null, så det som overstiger avsetningen ' +
        'må tas fra timene resten av året. Planlegg strammere til fraværet er tilbake på normalen.',
    })
  }

  // --- Brutto per bemanningstime ---
  if (m.bruttoPrTimeCluster > 0 && m.bruttoPrTime / m.bruttoPrTimeCluster < BRUTTO_UNDER) {
    ut.push({
      type: 'bemanning_produktivitet',
      tittel: `${Math.round(m.bruttoPrTime)} kr brutto per bemanningstime`,
      tekst:
        `Clusteret ligger på ${Math.round(m.bruttoPrTimeCluster)} kr. Du henter ` +
        `${pst(m.bruttoPrTime / m.bruttoPrTimeCluster - 1)} mindre per time enn snittet. ` +
        'Det betyr som regel at timene ligger feil på døgnet, ikke at det er for mange av dem — ' +
        'se hvilke timer i vaktplanforslaget som har lavest kundetrykk.',
    })
  }

  // --- Og når det går bra, si det ---
  if (
    ut.length === 0 &&
    m.timerDisponible &&
    m.timerBrukt <= m.timerDisponible &&
    m.bruttoPrTime >= m.bruttoPrTimeCluster
  ) {
    ut.push({
      type: 'bemanning_ok',
      tittel: `${mnd} landet innenfor rammen`,
      tekst:
        `${Math.round(m.timerBrukt)} timer mot ${Math.round(m.timerDisponible)} disponible, og ` +
        `${Math.round(m.bruttoPrTime)} kr brutto per bemanningstime mot clusterets ` +
        `${Math.round(m.bruttoPrTimeCluster)}. Lønnsandel ${pst(m.lonnAvBrutto)}.`,
    })
  }

  return ut
}
