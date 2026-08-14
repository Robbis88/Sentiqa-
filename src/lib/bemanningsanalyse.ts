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
 * Planen mot virkeligheten.
 *
 * Stemplingene sier hva som faktisk skjedde. Planen sier hva som burde
 * skjedd. Differansen er det eneste som får en butikksjef til å endre
 * noe — «du brukte 140 timer mer enn planen, og de lå på tirsdager»
 * biter, mens «lønnsandelen din er 12,4 %» ikke gjør det.
 *
 * Over- og underforbruk holdes fra hverandre. To timer for mye tirsdag
 * og to for lite mandag er ikke «riktig bemannet» — det er to feil som
 * skjuler hverandre, og netto null er det verste svaret man kan gi.
 */
export type Avvikstime = {
  dato: string
  time: number
  planlagt: number
  faktisk: number
  kunder: number
}

export type Avviksbilde = {
  timer: Avvikstime[]
  planlagteTimer: number
  faktiskeTimer: number
  overforbruk: number
  underforbruk: number
  /** Dagene der planen og virkeligheten er lengst fra hverandre. */
  verstedager: { dato: string; planlagt: number; faktisk: number; avvik: number }[]
  /** Timer på døgnet som systematisk er overbemannet mot planen. */
  verstetimer: { time: number; avvik: number }[]
}

export function planMotFaktisk(
  plan: { dato: string; time: number; sum: number; kunder: number }[],
  faktisk: Map<string, number>, // `${dato}:${time}` → antall personer
): Avviksbilde {
  const timer: Avvikstime[] = plan.map((p) => ({
    dato: p.dato,
    time: p.time,
    planlagt: p.sum,
    faktisk: faktisk.get(`${p.dato}:${p.time}`) ?? 0,
    kunder: p.kunder,
  }))

  let over = 0
  let under = 0
  const perDag = new Map<string, { planlagt: number; faktisk: number }>()
  const perTime = new Map<number, number>()
  for (const t of timer) {
    const d = t.faktisk - t.planlagt
    if (d > 0) over += d
    else under -= d
    const dag = perDag.get(t.dato) ?? { planlagt: 0, faktisk: 0 }
    dag.planlagt += t.planlagt
    dag.faktisk += t.faktisk
    perDag.set(t.dato, dag)
    perTime.set(t.time, (perTime.get(t.time) ?? 0) + d)
  }

  const verstedager = [...perDag]
    .map(([dato, v]) => ({ dato, ...v, avvik: v.faktisk - v.planlagt }))
    .sort((a, b) => Math.abs(b.avvik) - Math.abs(a.avvik))
    .filter((d) => Math.abs(d.avvik) >= 1)
    .slice(0, 5)

  const verstetimer = [...perTime]
    .map(([time, avvik]) => ({ time, avvik }))
    .sort((a, b) => Math.abs(b.avvik) - Math.abs(a.avvik))
    .filter((t) => Math.abs(t.avvik) >= 1)
    .slice(0, 5)

  return {
    timer,
    planlagteTimer: timer.reduce((a, t) => a + t.planlagt, 0),
    faktiskeTimer: timer.reduce((a, t) => a + t.faktisk, 0),
    overforbruk: over,
    underforbruk: under,
    verstedager,
    verstetimer,
  }
}

// =====================================================================
// Taket fra historikken.
//
// Planen foreslo to på jobb i timer stasjonen aldri har hatt to. Et
// globalt tak («maks 2») hjelper ikke: problemet er ikke at to er for
// mange noen gang, det er at to er for mange klokka ni på en tirsdag.
//
// Stemplingene vet dette. Har de aldri vært to tirsdag 09, skal planen
// ikke foreslå det — og hvis den mener det trengs, er det en samtale med
// butikksjefen, ikke et forslag hun kan trykke ja på.
//
// Ikke maks: én julaften med fem på jobb, eller de to timene
// Laguneparken hadde tolv personer inne (personalmøte, etter alt å
// dømme), skal ikke sette taket for hele året. Nivået må ha forekommet
// i minst `andel` av gangene den timen har vært der.
// =====================================================================

export type StemplingTid = { dato: string; fraTid: string; tilTid: string }

const isodow = (iso: string) => {
  const d = new Date(`${iso}T12:00:00Z`).getUTCDay()
  return d === 0 ? 7 : d
}

/**
 * Høyeste bemanning stasjonen faktisk har hatt per ukedag × klokketime.
 *
 * Nøkkelen er `${ukedag}:${time}`, samme som planleggerens rutenett.
 * Timer som aldri har vært bemannet finnes ikke i kartet — kalleren
 * bestemmer selv hva det skal bety (planleggeren lar dem stå åpne, for
 * en ny åpningstid er ikke en feil).
 */
export function historiskTak(
  stemplinger: StemplingTid[],
  opts: { andel?: number } = {},
): Map<string, number> {
  const andel = opts.andel ?? 0.1

  // Per dato og klokketime: hvor mange var inne samtidig.
  const perDagTime = new Map<string, number>()
  for (const s of stemplinger) {
    const fra = Number(s.fraTid.slice(0, 2))
    let til = Number(s.tilTid.slice(0, 2))
    if (s.tilTid === '00:00' || s.tilTid === '24:00') til = 24
    if (til <= fra) til += 24 // vakt over midnatt
    for (let t = fra; t < til; t++) {
      // Timer etter midnatt hører til dagen etter — det er da de jobbes.
      const dato = t < 24
        ? s.dato
        : new Date(Date.parse(`${s.dato}T12:00:00Z`) + 86400000).toISOString().slice(0, 10)
      const n = `${dato}:${t % 24}`
      perDagTime.set(n, (perDagTime.get(n) ?? 0) + 1)
    }
  }

  // Samle observasjonene per ukedag × time.
  const obs = new Map<string, number[]>()
  for (const [noekkel, antall] of perDagTime) {
    const skille = noekkel.lastIndexOf(':')
    const dato = noekkel.slice(0, skille)
    const time = Number(noekkel.slice(skille + 1))
    const k = `${isodow(dato)}:${time}`
    const liste = obs.get(k) ?? []
    liste.push(antall)
    obs.set(k, liste)
  }

  const tak = new Map<string, number>()
  for (const [k, liste] of obs) {
    const hoyeste = Math.max(...liste)
    let niva = 1
    for (let n = hoyeste; n >= 1; n--) {
      const ganger = liste.filter((x) => x >= n).length
      // Både andel OG minst to ganger. Andelen alene er for slapp når
      // utvalget er lite: med fire mandager i historikken ville ett
      // personalmøte utgjort 25 % og satt taket til tolv. Et nivå som har
      // forekommet én eneste gang er ikke et mønster, uansett utvalg.
      if (ganger >= 2 && ganger / liste.length >= andel) { niva = n; break }
    }
    tak.set(k, niva)
  }
  return tak
}

// =====================================================================
// Har formen flyttet seg?
//
// Planen for september bygger på september i fjor. Det bærer så lenge
// stasjonen er den samme — men stasjonene endrer seg hele tiden. Ny
// konkurrent over gata, endret åpningstid, matkonseptet som slo an. Da
// er fjorårets døgnkurve feil, og planen arver feilen uten at noen ser
// det.
//
// Vi har januar–juli i både fjor og år. Den overlappen sier hvordan
// formen har flyttet seg, og den justeringen gjelder alle månedene —
// ikke bare de vi har målt.
//
// VIKTIG: begge periodene normaliseres først. Vi er ute etter FORMEN,
// ikke nivået. Vokser stasjonen 8 % jevnt, har formen ikke endret seg,
// og veksten ligger allerede i BP-rammen — legger vi den på her også,
// telles den to ganger.
// =====================================================================

export type Formendring = {
  /** `${ukedag}:${time}` → hvor mye den timens ANDEL har endret seg. */
  faktorer: Map<string, number>
  /** Største bevegelser, sortert. Til å vise butikksjefen. */
  storsteUtslag: { ukedag: number; time: number; faktor: number }[]
  /** Hvor mye formen har flyttet seg totalt, 0 = ikke i det hele tatt. */
  drift: number
  /** Har vi nok data til å tro på dette? */
  paalitelig: boolean
}

// Under dette er endringen mindre enn støyen fra en enkelt uke med
// dårlig vær, og en justering ville gjort planen dårligere, ikke bedre.
const DRIFT_TERSKEL = 0.08
const MIN_KUNDER = 200 // per periode, summert

/**
 * Sammenligner to døgnkurver og finner hvordan formen har flyttet seg.
 *
 * `basis` og `ny` er `${ukedag}:${time}` → snitt innekunder, fra samme
 * kalenderperiode i to år (jan–jul i fjor mot jan–jul i år). Samme
 * periode er poenget: ellers måler man sesong og kaller det endring.
 */
export function formendring(
  basis: Map<string, number>,
  ny: Map<string, number>,
): Formendring {
  const sumBasis = [...basis.values()].reduce((a, b) => a + b, 0)
  const sumNy = [...ny.values()].reduce((a, b) => a + b, 0)
  const tomt: Formendring = {
    faktorer: new Map(), storsteUtslag: [], drift: 0, paalitelig: false,
  }
  if (sumBasis < MIN_KUNDER || sumNy < MIN_KUNDER) return tomt

  const faktorer = new Map<string, number>()
  const utslag: { ukedag: number; time: number; faktor: number }[] = []
  let drift = 0
  let vekt = 0

  for (const [noekkel, verdi] of ny) {
    const for_ = basis.get(noekkel)
    if (for_ === undefined || for_ <= 0 || verdi <= 0) continue
    // Andeler, ikke absolutte tall: nivået hører til rammen, ikke formen.
    const andelFor = for_ / sumBasis
    const andelNa = verdi / sumNy
    const faktor = andelNa / andelFor
    faktorer.set(noekkel, faktor)

    const [u, t] = noekkel.split(':').map(Number)
    utslag.push({ ukedag: u, time: t, faktor })
    // Vektet med hvor mange kunder timen faktisk har — at en død
    // nattetime doblet seg fra to til fire kunder er ikke en formendring.
    drift += Math.abs(faktor - 1) * andelNa
    vekt += andelNa
  }

  const samletDrift = vekt > 0 ? drift / vekt : 0
  utslag.sort((a, b) => Math.abs(b.faktor - 1) - Math.abs(a.faktor - 1))
  return {
    faktorer,
    storsteUtslag: utslag.slice(0, 8),
    drift: samletDrift,
    paalitelig: samletDrift >= DRIFT_TERSKEL,
  }
}

// Justeringen kappes. En time som «tredoblet seg» er som regel en time
// som gikk fra tre til ni kunder, og den skal ikke velte en månedsplan.
const MIN_JUSTERING = 0.6
const MAKS_JUSTERING = 1.7

/**
 * Legger den målte formendringen på fjorårets kurve.
 *
 * Gjøres bare når driften er stor nok til å tro på — ellers returneres
 * profilen uendret. En justering på tre prosent er ikke en forbedring,
 * det er å flytte støy fra ett sted til et annet.
 */
export function justerProfil(
  profil: Map<string, number>,
  endring: Formendring,
): Map<string, number> {
  if (!endring.paalitelig) return profil
  const ut = new Map(profil)
  for (const [noekkel, verdi] of profil) {
    const f = endring.faktorer.get(noekkel)
    if (f === undefined) continue
    ut.set(noekkel, verdi * Math.min(MAKS_JUSTERING, Math.max(MIN_JUSTERING, f)))
  }
  return ut
}

/** Én setning om hva som har flyttet seg. Null hvis ingenting har det. */
export function formendringTekst(e: Formendring, ukedager: string[]): string | null {
  if (!e.paalitelig || e.storsteUtslag.length === 0) return null
  const opp = e.storsteUtslag.filter((u) => u.faktor > 1).slice(0, 2)
  const ned = e.storsteUtslag.filter((u) => u.faktor < 1).slice(0, 2)
  const beskriv = (u: { ukedag: number; time: number; faktor: number }) =>
    `${ukedager[u.ukedag]} kl. ${String(u.time).padStart(2, '0')}`
  const deler: string[] = []
  if (opp.length > 0) deler.push(`opp på ${opp.map(beskriv).join(' og ')}`)
  if (ned.length > 0) deler.push(`ned på ${ned.map(beskriv).join(' og ')}`)
  if (deler.length === 0) return null
  return `Kundeformen har flyttet seg siden i fjor — ${deler.join(', ')}. `
    + 'Planen er justert etter det, ikke bare arvet fra fjoråret.'
}

// =====================================================================
// Hvor mye går folk i?
//
// «Alle skal få timene sine» krever at systemet vet hva folk har krav
// på. Det tallet finnes ikke i noen fil vi får. Men å be butikksjefen
// taste inn stillingsprosent for femten personer er å be om noe hun
// ikke kommer til å gjøre — hun planlegger på hukommelse nettopp fordi
// det å hente tall er arbeid.
//
// Så vi gjetter først, og lar henne rette. 19 måneder med stemplinger
// sier omtrent hva folk går i.
//
// MEDIANMÅNEDEN, ikke snittet. Snittet drukner i ferie, sykdom og den
// ene måneden noen tok ekstravakter for hele huset. Medianen er «en
// vanlig måned for denne personen», og det er det stillingsprosenten
// skal beskrive.
// =====================================================================

/** 100 % = 37,5 t/uke ≈ 162,5 t/mnd. Norsk standard. */
export const TIMER_PER_MND_100 = 162.5

export type AnsattForbruk = { ansattNr: string; navn: string; dato: string; timer: number }

export type Stillingsanslag = {
  ansattNr: string
  navn: string
  /** Median av de hele månedene personen har jobbet. */
  medianMnd: number
  anslagProsent: number
  /** Hele måneder anslaget bygger på. Under 3 er det en gjetning. */
  maaneder: number
  sisteMnd: string | null
  /** Har personen sluttet? Ingen timer på tre måneder. */
  aktiv: boolean
  /** Én setning når tallet ikke skal leses som en stillingsprosent. */
  merknad: string | null
}

/** Hvor langt tilbake anslaget ser. Sissel på Dale gikk fra ~200 t/mnd i
    2025 til ~170 i 2026: medianen over alt beskriver hvem hun VAR, ikke
    hvem hun er nå. Tolv måneder fanger et helt sesongår og lar likevel
    en endring slå gjennom innen året er omme. */
const MAANEDER_TILBAKE = 12

/**
 * Anslår stillingsprosent per ansatt fra faktiske timer.
 *
 * `tilDato` er dagen anslaget regnes fra — inneværende måned utelates,
 * for den er ikke ferdig og ville dratt alle ned.
 */
export function stillingsanslag(
  forbruk: AnsattForbruk[],
  tilDato: string,
  opts: { maanederTilbake?: number } = {},
): Stillingsanslag[] {
  const vindu = opts.maanederTilbake ?? MAANEDER_TILBAKE
  const inneVaerende = tilDato.slice(0, 7)
  const fraMnd = (() => {
    const d = new Date(`${inneVaerende}-01T12:00:00Z`)
    d.setUTCMonth(d.getUTCMonth() - vindu)
    return d.toISOString().slice(0, 7)
  })()
  const perPerson = new Map<string, { navn: string; mnd: Map<string, number> }>()

  for (const f of forbruk) {
    const mnd = f.dato.slice(0, 7)
    if (mnd >= inneVaerende || mnd < fraMnd) continue
    const p = perPerson.get(f.ansattNr) ?? { navn: f.navn, mnd: new Map() }
    p.navn = f.navn // nyeste navn vinner — folk gifter seg
    p.mnd.set(mnd, (p.mnd.get(mnd) ?? 0) + f.timer)
    perPerson.set(f.ansattNr, p)
  }

  // Tre måneder tilbake fra siste hele måned: har man ikke stemplet på
  // så lenge, er man sluttet eller i permisjon, og skal ikke telle med
  // når timene skal fordeles.
  const grense = (() => {
    const d = new Date(`${inneVaerende}-01T12:00:00Z`)
    d.setUTCMonth(d.getUTCMonth() - 3)
    return d.toISOString().slice(0, 7)
  })()

  return [...perPerson]
    .map(([ansattNr, p]) => {
      const maaneder = [...p.mnd.values()]
      const m = median(maaneder)
      const siste = [...p.mnd.keys()].sort().pop() ?? null
      const prosent = Math.round((m / TIMER_PER_MND_100) * 100 / 5) * 5
      // Over full stilling finnes ikke som kontrakt. Anslaget maaler
      // ARBEIDEDE timer, og de inkluderer ekstravakter og vikartimer -
      // en 80 %-stilling som daekker for en sykemeldt ser ut som 130 %.
      // Tallet er riktig, tolkningen er det ikke, og da skal det staa.
      //
      // Motsatt vei: en 100 %-stilling jobber MINDRE enn 162,5 t i en
      // maaned med rode dager, for de betales uten aa jobbes. Anslaget
      // ligger derfor systematisk litt lavt for de fast ansatte.
      const merknad = prosent > 100
        ? 'Over full stilling — dette er arbeidede timer, så det inkluderer '
          + 'ekstravakter og vikartimer. Skriv inn den faktiske kontrakten.'
        : maaneder.length < 3
          ? 'For få måneder til å si noe sikkert.'
          : null
      return {
        ansattNr,
        navn: p.navn,
        medianMnd: m,
        merknad,
        // Rundes til nærmeste 5 %. Et anslag på 37,4 % later som om det
        // er målt; 35 % ser ut som det det er.
        anslagProsent: prosent,
        maaneder: maaneder.length,
        sisteMnd: siste,
        aktiv: siste !== null && siste >= grense,
      }
    })
    .sort((a, b) => b.medianMnd - a.medianMnd)
}

/**
 * Har stasjonen folk nok til å fylle planen?
 *
 * Summen av stillingene mot timene planen krever. Ligger stillingene
 * under, må noen ta ekstravakter uansett hvor god planen er — og det er
 * en bemanningssak, ikke en planleggingssak.
 */
export function kapasitet(
  stillinger: { anslagProsent: number; aktiv: boolean }[],
  planlagteTimer: number,
): { tilgjengelig: number; planlagt: number; dekning: number } {
  const tilgjengelig = stillinger
    .filter((s) => s.aktiv)
    .reduce((a, s) => a + (s.anslagProsent / 100) * TIMER_PER_MND_100, 0)
  return {
    tilgjengelig,
    planlagt: planlagteTimer,
    dekning: planlagteTimer > 0 ? tilgjengelig / planlagteTimer : 0,
  }
}
