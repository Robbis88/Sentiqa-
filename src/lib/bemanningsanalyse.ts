// =====================================================================
// Sammenligning av stasjoner: hvem bemanner stramt og hvem drar på.
//
// En stasjon alene sier ingenting. 1201 timer i måneden er sløsing eller
// nødvendig avhengig av hvor mange som kom inn døra og hva de kjøpte.
// Målestokken må derfor være de andre stasjonene, ikke et tall noen har
// funnet på.
//
// To drivere, og de trekker hver sin vei:
//
//   KUNDER   flere kunder, flere hender. Åpenbart, men ikke nok — to
//            stasjoner med like mange kunder kan ha helt ulikt arbeid.
//
//   MATANDEL tilberedt mat (avdeling 120) tar lengst tid. En kunde som
//            venter på pølse og kaffe binder en ansatt i minutter; en som
//            tar en cola og går binder henne i sekunder.
//
// Vi tallfester ikke hvor mye en matkrone «koster» i tid — det ville vært
// en gjetning forkledd som modell. I stedet rangeres stasjonene på begge
// aksene, og de som ligger høyt på timer og lavt på mat pekes ut. Det er
// den kombinasjonen Robert beskrev: to på jobb, ingen matomsetning, få
// kunder. Da er timene bedre brukt et annet sted.
// =====================================================================

export type StasjonsForbruk = {
  stasjonId: string
  navn: string
  timer: number // faktisk stemplede timer i perioden
  kunder: number // innekunder i samme periode
  omsetning: number // butikksalg eks. drivstoff
  matOmsetning: number // avdeling 120
}

export type Vurdering = 'stramt' | 'normalt' | 'romslig' | 'for lite data'

export type StasjonsVurdering = StasjonsForbruk & {
  timerPer100Kunder: number
  matandel: number // 0–1
  vurdering: Vurdering
  /** Setningen butikksjefen skal lese. Aldri en score uten forklaring. */
  begrunnelse: string
}

const median = (tall: number[]): number => {
  if (tall.length === 0) return 0
  const s = [...tall].sort((a, b) => a - b)
  const m = Math.floor(s.length / 2)
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2
}

const pst = (v: number) => `${Math.round(v * 100)} %`

/**
 * Vurderer hver stasjon mot medianen av de andre.
 *
 * Terskelen er 15 % over eller under medianen. Under det er forskjellen
 * mindre enn støyen fra en enkelt sykemelding, og en plan som roper på
 * hver sjette prosent blir ignorert etter tredje gang.
 *
 * Færre enn tre stasjoner gir ingen målestokk — da sier vi det, framfor
 * å kalle den ene av to for «romslig».
 */
export function sammenlignStasjoner(
  forbruk: StasjonsForbruk[],
  opts: { terskel?: number } = {},
): StasjonsVurdering[] {
  const terskel = opts.terskel ?? 0.15
  const gyldige = forbruk.filter((f) => f.kunder > 0 && f.timer > 0)

  const beregnet = forbruk.map((f) => ({
    ...f,
    timerPer100Kunder: f.kunder > 0 ? (f.timer / f.kunder) * 100 : 0,
    matandel: f.omsetning > 0 ? f.matOmsetning / f.omsetning : 0,
  }))

  if (gyldige.length < 3) {
    return beregnet.map((b) => ({
      ...b,
      vurdering: 'for lite data' as const,
      begrunnelse: 'Trenger minst tre stasjoner med data for å ha noe å måle mot.',
    }))
  }

  const medTimer = median(beregnet.filter((b) => b.timerPer100Kunder > 0).map((b) => b.timerPer100Kunder))
  const medMat = median(beregnet.map((b) => b.matandel))

  return beregnet.map((b) => {
    if (b.kunder <= 0 || b.timer <= 0) {
      return {
        ...b,
        vurdering: 'for lite data' as const,
        begrunnelse: 'Mangler timer eller kundetall for perioden.',
      }
    }

    const avvik = (b.timerPer100Kunder - medTimer) / medTimer
    const mySnittMat = b.matandel >= medMat

    if (avvik > terskel) {
      // Høyt timeforbruk. Om det er berettiget avhenger av maten.
      return {
        ...b,
        vurdering: 'romslig' as const,
        begrunnelse: mySnittMat
          ? `Bruker ${pst(avvik)} flere timer per kunde enn de andre, men har også mest `
            + `mat (${pst(b.matandel)} av salget). Tilberedt mat tar tid — se på om timene `
            + 'ligger i matens travleste klokkeslett før du kutter.'
          : `Bruker ${pst(avvik)} flere timer per kunde enn de andre, og har lite mat `
            + `(${pst(b.matandel)} av salget mot ${pst(medMat)} normalt). Her er det timer å hente.`,
      }
    }
    if (avvik < -terskel) {
      return {
        ...b,
        vurdering: 'stramt' as const,
        begrunnelse: `Bruker ${pst(-avvik)} færre timer per kunde enn de andre. `
          + (mySnittMat
            ? 'Med mye mat på toppen er dette stramt — sjekk at det ikke går på bekostning av folk.'
            : 'Ser effektivt ut. Verdt å se hvordan de har lagt opp vaktene.'),
      }
    }
    return {
      ...b,
      vurdering: 'normalt' as const,
      begrunnelse: `Ligger på linje med de andre (${b.timerPer100Kunder.toFixed(1)} timer per 100 kunder).`,
    }
  })
}

/**
 * Timer per klokketime, målt mot planen.
 *
 * Stemplingene sier hva som faktisk skjedde. Planen sier hva som burde
 * skjedd. Differansen er det eneste som får en butikksjef til å endre
 * noe — «du brukte 140 timer mer enn planen, og de lå på tirsdager»
 * biter, mens «lønnsandelen din er 12,4 %» ikke gjør det.
 */
export type Avvikstime = {
  ukedag: number
  time: number
  planlagt: number
  faktisk: number
  kunder: number
}

export function planMotFaktisk(
  plan: { ukedag: number; time: number; sum: number; kunder: number }[],
  faktisk: Map<string, number>, // `${ukedag}:${time}` → snitt antall personer
): { timer: Avvikstime[]; overforbruk: number; underforbruk: number } {
  const timer = plan.map((p) => ({
    ukedag: p.ukedag,
    time: p.time,
    planlagt: p.sum,
    faktisk: faktisk.get(`${p.ukedag}:${p.time}`) ?? 0,
    kunder: p.kunder,
  }))
  let over = 0
  let under = 0
  for (const t of timer) {
    const d = t.faktisk - t.planlagt
    if (d > 0) over += d
    else under -= d
  }
  return { timer, overforbruk: over, underforbruk: under }
}
