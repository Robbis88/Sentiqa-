// =====================================================================
// Bemanningsplanlegger — fordeling av timebudsjett.
//
// To trinn, med hver sin kilde:
//
//   1) NIVÅ per måned  — årsrammen fordelt etter BP-ens egen bruttokurve.
//      Modellens premiss er konstant brutto per bemanningstime, så timene
//      skal følge bruttoen. En flat tolvdel bommer med opptil 370 timer i
//      én måned (Dale i juli), og stasjonene svinger i motsatt retning:
//      Dale topper i juli, Varden bunner samme måned.
//
//   2) FORM innad i måneden — historiske innekunder per ukedag × klokketime.
//      Kundene sier når på døgnet timene trengs; budsjettet sier hvor mange.
//
// Fradragene tas før butikksjefen ser tallet: sykefraværsreserve (kjeden
// budsjetterer sykelønn til 0, så den er et garantert overforbruk uten
// avsetning) og en sikkerhetsmargin for overbemanning.
// =====================================================================

export type Fradrag = {
  reservePst: number // sykefravær
  sikkerhetPst: number // overbemanning
}

// --- Trinn 1: årsramme → måned ---------------------------------------

export function disponibleTimerAar(timerAar: number, f: Fradrag): number {
  return timerAar * (1 - f.reservePst / 100) * (1 - f.sikkerhetPst / 100)
}

// bruttoPerMaaned er tolv tall fra BP-en, januar først. Er summen 0 (ingen
// BP lastet ennå) faller vi tilbake på flat fordeling — bedre enn å kaste,
// men kalleren bør si fra i UI-et.
export function fordelPaaMaaneder(
  timerAar: number,
  bruttoPerMaaned: number[],
  f: Fradrag,
): number[] {
  if (bruttoPerMaaned.length !== 12) {
    throw new Error(`fordelPaaMaaneder: forventet 12 månedstall, fikk ${bruttoPerMaaned.length}`)
  }
  const netto = disponibleTimerAar(timerAar, f)
  const sum = bruttoPerMaaned.reduce((a, b) => a + b, 0)
  if (sum <= 0) return new Array(12).fill(netto / 12)
  return bruttoPerMaaned.map((b) => (b / sum) * netto)
}

// Månedsvekter fra stasjonens EGNE kunder, ikke fra BP-kurven.
//
// BP-en er kjedens budsjett, og bruttoen i den er formet av hva stasjonen
// gjorde i fjor — inkludert timene butikksjefen brukte fordi hun hadde dem.
// Fordeler man timene etter den kurven, får man forrige års bemanning tilbake
// med et nytt tall på. Kundene lyver ikke på samme måte: de kom eller de kom
// ikke, og påsken, fellesferien og utfartshelgene ligger allerede inne i
// tallene uten at noen har måttet liste dem opp.
//
// kunderPerMaaned er tolv tall, januar først, fra stasjonens historikk.
// Måneder uten data får vekt fra reserve (BP-bruttoen) — ellers ville en
// måned vi ikke har lastet opp ennå fått null timer. Er ingen av delene
// tilgjengelig, faller det tilbake på flatt.
export function maanedsvekter(
  kunderPerMaaned: (number | null)[],
  reserve: number[],
): number[] {
  if (kunderPerMaaned.length !== 12 || reserve.length !== 12) {
    throw new Error('maanedsvekter: forventet 12 tall i begge')
  }
  const maalte = kunderPerMaaned.filter((k): k is number => k !== null && k > 0)
  if (maalte.length === 0) {
    const sum = reserve.reduce((a, b) => a + b, 0)
    return sum > 0 ? reserve.map((r) => r / sum) : new Array(12).fill(1 / 12)
  }

  // Reserven skaleres til samme nivå som de målte månedene, ellers ville en
  // BP i kroner og en kundetelling i personer blandes som om de var samme
  // enhet — og den ene ville drukne den andre.
  const iBegge = kunderPerMaaned
    .map((k, i) => ({ k, r: reserve[i] }))
    .filter((p): p is { k: number; r: number } => p.k !== null && p.k > 0 && p.r > 0)
  const skala = iBegge.length > 0
    ? iBegge.reduce((a, p) => a + p.k, 0) / iBegge.reduce((a, p) => a + p.r, 0)
    : 0
  const snitt = maalte.reduce((a, b) => a + b, 0) / maalte.length

  const raa = kunderPerMaaned.map((k, i) => {
    if (k !== null && k > 0) return k
    if (skala > 0 && reserve[i] > 0) return reserve[i] * skala
    return snitt
  })
  const sum = raa.reduce((a, b) => a + b, 0)
  return raa.map((r) => r / sum)
}

// --- Trinn 2: måned → ukedag × klokketime ----------------------------

export type Vindu = {
  ukedag: number // isodow: 1 = mandag … 7 = søndag
  fraTime: number // 0–23
  tilTime: number // 1–24
  minBemanning: number
}
export type Krav = { ukedag: number; fraTime: number; tilTime: number; antall: number }
// timelonnet skiller de to slagene binding fra hverandre. Begge står alltid
// og dekker gulvet like godt, men bare den fastlønte er gratis for rammen.
// En NK på timelønn 05-12 er like bundet som butikksjefen, og koster like
// mye som en innkalt — føres den som fastlønn, tror planen at sju timer i
// uka er gratis og deler dem ut en gang til et annet sted.
export type FastVakt = {
  ukedag: number
  fraTime: number
  tilTime: number
  timelonnet?: boolean
}

export type Bemanning = {
  ukedag: number
  time: number
  fast: number // faste vakter som dekker timen, uansett lønnsform
  fastTimelonnet: number // av disse: de som belaster timerammen
  gulv: number // bundet variabel bemanning: min/krav minus det faste dekker
  ekstra: number // hele personer tildelt etter kundetrykk
  sum: number // fast + gulv + ekstra
  kunder: number
}

export type Plan = {
  timer: Bemanning[]
  bundneTimer: number // variable timer låst av gulvet
  fasteTimer: number // timer de faste vaktene bærer — ikke i rammen, men arbeid
  frieTimer: number // igjen til fordeling etter gulvet
  brukteTimer: number // faktisk tildelt av de frie
  gjennomforbar: boolean // false = budsjettet dekker ikke engang gulvet
  underskudd: number // timer som mangler når gjennomforbar er false
}

// Korteste vakt som lar seg sette opp i praksis. Robert oppga 5 timer, med
// forbehold — derfor en navngitt konstant og en parameter, ikke et tall spredt
// i logikken. Endres den, endres den ett sted.
export const MIN_VAKT_TIMER = 5

const iVindu = (t: number, fra: number, til: number) => t >= fra && t < til

// Faste vakter som dekker én time. Telles, ikke bare sjekkes for om det
// finnes én — butikksjef 08-16 og NK 05-12 er to personer mellom 08 og 12,
// og et gulv på to er da allerede dekket.
const dekning = (vakter: FastVakt[], ukedag: number, t: number) =>
  vakter.filter((f) => f.ukedag === ukedag && iVindu(t, f.fraTime, f.tilTime))

// Timelønte faste vakter koster hele sin lengde, også timene som ligger
// utenfor det bemannede vinduet. Starter NK 05 og vinduet 06, er den timen
// like fullt betalt.
const timelonteFasteTimer = (vakter: FastVakt[], antall: number[]) =>
  vakter
    .filter((f) => f.timelonnet)
    .reduce((sum, f) => sum + (f.tilTime - f.fraTime) * antall[f.ukedag], 0)

// Alle timene de faste vaktene bærer, uansett lønnsform. Belaster ikke
// timerammen, men er ikke gratis. Bønes mai 2026: butikksjefen gikk 158 timer
// man–fre 08–16. I juli var han i ferie og gikk null — og stasjonen brukte
// like mange timer likevel, fordi de 158 ble kjøpt tilbake som timelønn.
// Ferie sparer ikke timer, den flytter dem fra fastlønn til rammen.
const alleFasteTimer = (vakter: FastVakt[], antall: number[]) =>
  vakter.reduce((sum, f) => sum + (f.tilTime - f.fraTime) * antall[f.ukedag], 0)

// Antall av hver ukedag i måneden, isodow-indeksert (1–7).
export function dagerPerUkedag(ar: number, maned: number): number[] {
  const ut = new Array(8).fill(0)
  const dager = new Date(Date.UTC(ar, maned, 0)).getUTCDate()
  for (let d = 1; d <= dager; d++) {
    const ukedag = new Date(Date.UTC(ar, maned - 1, d)).getUTCDay() // 0 = søndag
    ut[ukedag === 0 ? 7 : ukedag]++
  }
  return ut
}

// Gulvet for én måned: bemannet vindu × minimumsbemanning, hevet av
// krav-vinduene, minus det de faste vaktene dekker. Regnes uten å planlegge,
// fordi årsfordelingen må kjenne gulvet i alle tolv månedene før den kan
// fordele noe som helst.
export function bundneTimer(opts: {
  ar: number; maned: number; vinduer: Vindu[]; krav: Krav[]; fasteVakter: FastVakt[]
}): number {
  const antall = dagerPerUkedag(opts.ar, opts.maned)
  let sum = 0
  for (const v of opts.vinduer) {
    for (let t = v.fraTime; t < v.tilTime; t++) {
      const kravHer = opts.krav
        .filter((k) => k.ukedag === v.ukedag && iVindu(t, k.fraTime, k.tilTime))
        .reduce((m, k) => Math.max(m, k.antall), 0)
      const fast = dekning(opts.fasteVakter, v.ukedag, t).length
      sum += Math.max(0, Math.max(v.minBemanning, kravHer) - fast) * antall[v.ukedag]
    }
  }
  // De timelonte faste vaktene legges paa hele: gulvet trakk dem fra som
  // dekning, og her betales de tilbake som forbruk.
  return sum + timelonteFasteTimer(opts.fasteVakter, antall)
}

export type Aarsfordeling = {
  maaneder: { maned: number; bundne: number; fri: number; disponible: number }[]
  pool: number // årets ramme
  sumBundne: number
  fri: number
  gjennomforbar: boolean
  underskudd: number
}

/**
 * Fordeler årets ramme på måneder ETTER at gulvet er trukket fra.
 *
 * En døgnåpen stasjon trenger 720 timer bare for å holde én person i luften i
 * juni. Fordeler man året etter bruttokurven først, får juni kanskje 690 og
 * stopper — mens oktober sitter med slakk den ikke kan bruke. Gulvet er ikke
 * forhandlingsbart; det er resten som skal styres dit kundene er.
 *
 * Rekkefølgen blir derfor: gulv i alle tolv månedene, summér, og fordel det
 * som er igjen etter vektene (månedens andel av årets brutto).
 *
 * `rammer` er de tolv radene fra bemanning_maned. Summen er årets ramme, og
 * verdiene brukes som vekter — de er allerede proporsjonale med BP-bruttoen.
 */
export function fordelAaret(opts: {
  ar: number
  rammer: { maned: number; timer: number }[]
  vinduer: Vindu[]
  krav: Krav[]
  fasteVakter: FastVakt[]
}): Aarsfordeling {
  const pool = opts.rammer.reduce((a, r) => a + r.timer, 0)
  const vektSum = pool

  const bundne = opts.rammer.map((r) => ({
    maned: r.maned,
    vekt: r.timer,
    bundne: bundneTimer({
      ar: opts.ar, maned: r.maned,
      vinduer: opts.vinduer, krav: opts.krav, fasteVakter: opts.fasteVakter,
    }),
  }))
  const sumBundne = bundne.reduce((a, b) => a + b.bundne, 0)
  const fri = pool - sumBundne

  if (fri <= 0) {
    // Gulvet alene sprenger året. Da er det ikke en fordelingsjobb lenger —
    // enten må åpningstiden ned, eller så er rammen for stram.
    return {
      maaneder: bundne.map((b) => ({ maned: b.maned, bundne: b.bundne, fri: 0, disponible: b.bundne })),
      pool, sumBundne, fri: 0,
      gjennomforbar: false,
      underskudd: -fri,
    }
  }

  return {
    maaneder: bundne.map((b) => {
      const andel = vektSum > 0 ? b.vekt / vektSum : 1 / 12
      const friHer = fri * andel
      return { maned: b.maned, bundne: b.bundne, fri: friHer, disponible: b.bundne + friHer }
    }),
    pool, sumBundne, fri,
    gjennomforbar: true,
    underskudd: 0,
  }
}

/**
 * Fordeler månedens disponible timer på ukedag × klokketime.
 *
 * Ekstrabemanning tildeles som HELE personer etter D'Hondts metode: neste
 * person går alltid til timen med høyest `kunder / (bemanning + 1)`. Det gir
 * to egenskaper vi er avhengige av:
 *
 *   — En rolig time får aldri person nummer to før hver eneste travlere time
 *     har fått sin. Der én holder, blir det aldri foreslått to.
 *   — En time med kraftig trykk får tre, fire og fem hvis budsjettet rekker,
 *     uten at noen terskel må stilles inn.
 *
 * Kostnaden ved å bemanne en time er antall ganger den ukedagen forekommer i
 * måneden, så fem tirsdager koster mer enn fire fredager.
 */
export function planleggMaaned(opts: {
  disponibleTimer: number
  ar: number
  maned: number
  vinduer: Vindu[]
  krav: Krav[]
  fasteVakter: FastVakt[]
  profil: Map<string, number> // `${ukedag}:${time}` → snitt innekunder
  maksBemanning?: number // fysisk tak, f.eks. antall kasser
  /** Korteste vakt som lar seg sette opp. Under dette blir forslaget
      teoretisk — ingen kalles inn for to timer. */
  minVaktTimer?: number
  /** Tak per `${ukedag}:${time}`, målt fra stemplingene. Gjelder BARE det
      frie laget: gulvet er butikksjefens beslutning, ikke et forslag, og
      har hun sagt at det skal være to ved varemottak, skal historikken
      ikke overprøve henne. */
  tak?: Map<string, number>
}): Plan {
  const { disponibleTimer, ar, maned, vinduer, krav, fasteVakter, profil } = opts
  const maks = opts.maksBemanning ?? Number.POSITIVE_INFINITY
  // Har stasjonen aldri hatt to tirsdag 09, skal planen ikke foreslå det.
  // Mangler timen i historikken (ny åpningstid), står den åpen — et hull i
  // dataene er ikke det samme som et forbud.
  const takFor = (ukedag: number, time: number) =>
    Math.min(maks, opts.tak?.get(`${ukedag}:${time}`) ?? Number.POSITIVE_INFINITY)
  const minVaktTimer = Math.max(1, opts.minVaktTimer ?? MIN_VAKT_TIMER)
  const antall = dagerPerUkedag(ar, maned)

  // 1) Bundet lag. Faste vakter dekker gulvet — står butikksjefen der, trengs
  //    ikke en til. Om de belaster rammen, avhenger av lønnsformen: en
  //    fastlønt butikksjef er gratis for timerammen, en timelønt NK er det
  //    ikke, selv om vakten er like fast.
  const rader: Bemanning[] = []
  let bundneTimer = 0
  for (const v of vinduer) {
    for (let t = v.fraTime; t < v.tilTime; t++) {
      const kravHer = krav
        .filter((k) => k.ukedag === v.ukedag && iVindu(t, k.fraTime, k.tilTime))
        .reduce((m, k) => Math.max(m, k.antall), 0)
      const dekker = dekning(fasteVakter, v.ukedag, t)
      const fast = dekker.length
      const gulv = Math.max(0, Math.max(v.minBemanning, kravHer) - fast)
      bundneTimer += gulv * antall[v.ukedag]
      rader.push({
        ukedag: v.ukedag,
        time: t,
        fast,
        fastTimelonnet: dekker.filter((f) => f.timelonnet).length,
        gulv,
        ekstra: 0,
        sum: fast + gulv,
        kunder: profil.get(`${v.ukedag}:${t}`) ?? 0,
      })
    }
  }
  bundneTimer += timelonteFasteTimer(fasteVakter, antall)

  const frieTimer = disponibleTimer - bundneTimer
  if (frieTimer <= 0) {
    return {
      timer: rader,
      bundneTimer,
      fasteTimer: alleFasteTimer(fasteVakter, antall),
      frieTimer: 0,
      brukteTimer: 0,
      gjennomforbar: frieTimer >= 0,
      underskudd: Math.max(0, -frieTimer),
    }
  }

  // 2) Fritt lag — hele VAKTER, ikke løse timer.
  //
  // Den forrige versjonen delte ut én person til én time om gangen. Det ga
  // riktig form på kurven, men foreslo vakter på én og to timer — som ingen
  // kan settes opp. En plan som ikke lar seg bemanne er ikke en plan.
  //
  // Nå deles det ut sammenhengende blokker på minst minVaktTimer. Vi prøver
  // hver mulige start og lengde, og tar den blokken som gir mest kundedekning
  // per krone. D'Hondt-tanken er den samme — kunder delt på bemanning etter
  // at personen er lagt til — bare regnet over blokken i stedet for timen.
  const indeks = new Map<string, number>()
  rader.forEach((r, i) => indeks.set(`${r.ukedag}:${r.time}`, i))

  // Sammenhengende timer per ukedag, så en blokk aldri spenner over et hull
  // i det bemannede vinduet.
  const kjeder = new Map<number, number[]>()
  for (const r of rader) {
    const liste = kjeder.get(r.ukedag) ?? []
    liste.push(r.time)
    kjeder.set(r.ukedag, liste)
  }
  for (const liste of kjeder.values()) liste.sort((a, b) => a - b)

  let igjen = frieTimer
  let brukteTimer = 0

  for (;;) {
    let beste: { rader: number[]; kost: number } | null = null
    let besteVerdi = 0

    for (const [ukedag, timer] of kjeder) {
      const dager = antall[ukedag]
      if (dager <= 0) continue

      for (let start = 0; start < timer.length; start++) {
        for (let lengde = minVaktTimer; start + lengde <= timer.length; lengde++) {
          // Sammenhengende? Ellers hopper blokken over en stengt time.
          if (timer[start + lengde - 1] - timer[start] !== lengde - 1) break

          const idxer: number[] = []
          let kunder = 0
          let bemanningEtter = 0
          let plass = true
          for (let k = 0; k < lengde; k++) {
            const i = indeks.get(`${ukedag}:${timer[start + k]}`)
            if (i === undefined) { plass = false; break }
            const r = rader[i]
            if (r.sum >= takFor(ukedag, timer[start + k])) { plass = false; break }
            idxer.push(i)
            kunder += r.kunder
            bemanningEtter += r.sum + 1
          }
          if (!plass || kunder <= 0) continue

          const kost = lengde * dager
          if (kost > igjen) continue

          // Kunder per bemanning over blokken. Timer uten kunder trekker ned,
          // så en blokk som strekker seg inn i den døde kvelden taper mot en
          // kortere som ligger midt i rushet.
          const verdi = kunder / bemanningEtter
          if (verdi > besteVerdi) {
            besteVerdi = verdi
            beste = { rader: idxer, kost }
          }
        }
      }
    }

    if (!beste) break
    for (const i of beste.rader) { rader[i].ekstra++; rader[i].sum++ }
    igjen -= beste.kost
    brukteTimer += beste.kost
  }

  return {
    timer: rader, bundneTimer, fasteTimer: alleFasteTimer(fasteVakter, antall),
    frieTimer, brukteTimer, gjennomforbar: true, underskudd: 0,
  }
}

// =====================================================================
// Trinn 2b: måned → DATO × klokketime
//
// planleggMaaned gir «en vanlig uke». Det holder til å se formen, men
// skjærtorsdag er ikke en torsdag — den er en dato, med sitt eget
// kundetrykk og dobbelt lønn. Så lenge planen bare kjenner ukedager
// finnes det ikke noe sted å si «to på jobb 2. april».
//
// Her legges tre ting på:
//
//   DAGFAKTOR   målt per stasjon fra dens egen historikk (dagtyper.ts).
//               Utfartsdager og røde dager kommer inn av seg selv.
//
//   KOSTNAD     en rød time trekker to fra rammen, fordi den koster
//               100 % tillegg. Uten dette ser 1. mai ut som en fredag.
//
//   FERIE       en fast vakt som ikke er der, dekker ikke gulvet. Da må
//               timene kjøpes, og de skal belaste rammen den måneden.
// =====================================================================

export type Dagsvekt = {
  dato: string
  ukedag: number
  faktor: number // kundetrykk mot en vanlig samme ukedag
  /** Fra hvilken klokketime timene koster dobbelt. null = ingen.
      0 = hele dagen (rød dag), 15 = aften. Kostnaden er en egenskap ved
      TIMEN, ikke ved dagen: julaften 10:00 er en vanlig time. */
  rodFraTime: number | null
}

const kostnadFor = (d: Dagsvekt, time: number) =>
  (d.rodFraTime !== null && time >= d.rodFraTime ? 2 : 1)

export type Dagsbemanning = {
  dato: string
  ukedag: number
  time: number
  fast: number
  gulv: number
  ekstra: number
  sum: number
  kunder: number // etter dagfaktor
  kostnad: number // per person-time denne dagen
}

export type Kalenderplan = {
  timer: Dagsbemanning[]
  bundneTimer: number // rammetimer bundet av gulvet, rødt talt dobbelt
  fasteTimer: number
  frieTimer: number
  brukteTimer: number
  rodtPaaslag: number // hvor mye av bundneTimer som ER påslaget
  gjennomforbar: boolean
  underskudd: number
}

/** Er den faste vakten borte denne datoen? */
export type Fravaer = { navn: string; fraDato: string; tilDato: string }

export function planleggKalender(opts: {
  disponibleTimer: number
  dager: Dagsvekt[]
  vinduer: Vindu[]
  krav: Krav[]
  fasteVakter: (FastVakt & { navn?: string })[]
  fravaer?: Fravaer[]
  profil: Map<string, number> // `${ukedag}:${time}` → snitt innekunder
  maksBemanning?: number
  minVaktTimer?: number
  tak?: Map<string, number>
}): Kalenderplan {
  const { disponibleTimer, dager, vinduer, krav, fasteVakter, profil } = opts
  const maks = opts.maksBemanning ?? Number.POSITIVE_INFINITY
  const minVaktTimer = Math.max(1, opts.minVaktTimer ?? MIN_VAKT_TIMER)
  const fravaer = opts.fravaer ?? []
  const takFor = (ukedag: number, time: number) =>
    Math.min(maks, opts.tak?.get(`${ukedag}:${time}`) ?? Number.POSITIVE_INFINITY)

  // En fast vakt som er i ferie står ikke der. Da faller den ut av
  // dekningen, gulvet stiger, og timene må kjøpes av rammen. Det er
  // dette som gjør at fem ukers ferie HENTER timer i stedet for å spare.
  const erBorte = (navn: string | undefined, dato: string) =>
    navn !== undefined
    && fravaer.some((f) => f.navn === navn && dato >= f.fraDato && dato <= f.tilDato)

  const rader: Dagsbemanning[] = []
  let bundneTimer = 0
  let fasteTimer = 0
  let rodtPaaslag = 0

  for (const d of dager) {
    for (const v of vinduer.filter((x) => x.ukedag === d.ukedag)) {
      for (let t = v.fraTime; t < v.tilTime; t++) {
        const kravHer = krav
          .filter((k) => k.ukedag === d.ukedag && iVindu(t, k.fraTime, k.tilTime))
          .reduce((m, k) => Math.max(m, k.antall), 0)
        const dekker = fasteVakter.filter(
          (f) => f.ukedag === d.ukedag && iVindu(t, f.fraTime, f.tilTime) && !erBorte(f.navn, d.dato),
        )
        const fast = dekker.length
        const gulv = Math.max(0, Math.max(v.minBemanning, kravHer) - fast)
        const kostnad = kostnadFor(d, t)
        bundneTimer += gulv * kostnad
        rodtPaaslag += gulv * (kostnad - 1)
        fasteTimer += fast
        // Timelønte faste vakter belaster rammen på lik linje.
        const timelonte = dekker.filter((f) => f.timelonnet).length
        bundneTimer += timelonte * kostnad
        rodtPaaslag += timelonte * (kostnad - 1)

        rader.push({
          dato: d.dato,
          ukedag: d.ukedag,
          time: t,
          fast,
          gulv,
          ekstra: 0,
          sum: fast + gulv,
          kunder: (profil.get(`${d.ukedag}:${t}`) ?? 0) * d.faktor,
          kostnad,
        })
      }
    }
  }

  const frieTimer = disponibleTimer - bundneTimer
  if (frieTimer <= 0) {
    return {
      timer: rader, bundneTimer, fasteTimer, frieTimer: 0, brukteTimer: 0,
      rodtPaaslag, gjennomforbar: frieTimer >= 0, underskudd: Math.max(0, -frieTimer),
    }
  }

  // Fritt lag: sammenhengende vakter innenfor ÉN dato.
  const indeks = new Map<string, number>()
  rader.forEach((r, i) => indeks.set(`${r.dato}:${r.time}`, i))
  const kjeder = new Map<string, number[]>()
  for (const r of rader) {
    const liste = kjeder.get(r.dato) ?? []
    liste.push(r.time)
    kjeder.set(r.dato, liste)
  }
  for (const liste of kjeder.values()) liste.sort((a, b) => a - b)

  let igjen = frieTimer
  let brukteTimer = 0

  for (;;) {
    let beste: { rader: number[]; kost: number } | null = null
    let besteVerdi = 0

    for (const [dato, timer] of kjeder) {
      for (let start = 0; start < timer.length; start++) {
        for (let lengde = minVaktTimer; start + lengde <= timer.length; lengde++) {
          if (timer[start + lengde - 1] - timer[start] !== lengde - 1) break
          const idxer: number[] = []
          let kunder = 0
          let bemanningEtter = 0
          let kost = 0
          let plass = true
          for (let k = 0; k < lengde; k++) {
            const i = indeks.get(`${dato}:${timer[start + k]}`)
            if (i === undefined) { plass = false; break }
            const r = rader[i]
            if (r.sum >= takFor(r.ukedag, r.time)) { plass = false; break }
            idxer.push(i)
            kunder += r.kunder
            bemanningEtter += r.sum + 1
            // Kostnaden summeres per time: en vakt 12–18 på julaften er
            // tre vanlige timer og tre doble, ikke seks av det ene.
            kost += r.kostnad
          }
          if (!plass || kunder <= 0) continue
          if (kost > igjen) continue

          // Kundedekning per krone, ikke per time. En rød time må gi
          // dobbelt igjen for å være verdt like mye som en vanlig.
          const verdi = kunder / bemanningEtter / (kost / lengde)
          if (verdi > besteVerdi) { besteVerdi = verdi; beste = { rader: idxer, kost } }
        }
      }
    }

    if (!beste) break
    for (const i of beste.rader) { rader[i].ekstra++; rader[i].sum++ }
    igjen -= beste.kost
    brukteTimer += beste.kost
  }

  return {
    timer: rader, bundneTimer, fasteTimer, frieTimer, brukteTimer,
    rodtPaaslag, gjennomforbar: true, underskudd: 0,
  }
}

// =====================================================================
// Fra rutenett til vaktliste.
//
// «3 personer klokka 12» er ikke noe en butikksjef kan sette opp. Tre
// tall i en kolonne skjuler at det er to vakter som overlapper: 10–15
// og 11–16 gir tre i overlappet, og det er et vaktbytte, ikke en umulig
// time. Robert leste rutenettet og spurte hvordan man skulle klare det.
// Han hadde rett i at det ikke gikk an å lese.
//
// Dekomponeringen er den samme som når man skriver en timeplan: legg
// første person gjennom hele det bemannede vinduet, andre person der det
// trengs to, og så videre. Hvert sammenhengende strekk på hvert nivå er
// én vakt.
// =====================================================================

export type Vakt = {
  dato: string
  fraTime: number
  tilTime: number
  timer: number
  kilde: 'gulv' | 'ekstra'
}

const strekk = (
  dato: string,
  timer: { time: number; niva: number }[],
  kilde: 'gulv' | 'ekstra',
): Vakt[] => {
  const ut: Vakt[] = []
  const maks = Math.max(0, ...timer.map((t) => t.niva))
  for (let n = 1; n <= maks; n++) {
    let start: number | null = null
    let forrige: number | null = null
    for (const t of timer) {
      const med = t.niva >= n
      if (med && start === null) start = t.time
      // Hull i vinduet bryter vakten — man går ikke hjem og kommer tilbake.
      if (med && forrige !== null && t.time !== forrige + 1 && start !== null) {
        ut.push({ dato, fraTime: start, tilTime: forrige + 1, timer: forrige + 1 - start, kilde })
        start = t.time
      }
      if (!med && start !== null && forrige !== null) {
        ut.push({ dato, fraTime: start, tilTime: forrige + 1, timer: forrige + 1 - start, kilde })
        start = null
      }
      forrige = med ? t.time : forrige
      if (!med) forrige = null
    }
    if (start !== null && forrige !== null) {
      ut.push({ dato, fraTime: start, tilTime: forrige + 1, timer: forrige + 1 - start, kilde })
    }
  }
  return ut
}

/**
 * Vaktene planen egentlig foreslår.
 *
 * Gulvet (fast + minimumsbemanning) og det frie laget dekomponeres hver
 * for seg, så en ekstravakt ikke smelter sammen med grunnbemanningen.
 */
export function vaktliste(timer: Dagsbemanning[]): Vakt[] {
  const perDag = new Map<string, Dagsbemanning[]>()
  for (const t of timer) {
    const liste = perDag.get(t.dato) ?? []
    liste.push(t)
    perDag.set(t.dato, liste)
  }
  const ut: Vakt[] = []
  for (const [dato, rader] of perDag) {
    const sortert = [...rader].sort((a, b) => a.time - b.time)
    ut.push(...strekk(dato, sortert.map((r) => ({ time: r.time, niva: r.fast + r.gulv })), 'gulv'))
    ut.push(...strekk(dato, sortert.map((r) => ({ time: r.time, niva: r.ekstra })), 'ekstra'))
  }
  return ut.sort((a, b) => a.dato.localeCompare(b.dato) || a.fraTime - b.fraTime)
}
