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

// --- Trinn 2: måned → ukedag × klokketime ----------------------------

export type Vindu = {
  ukedag: number // isodow: 1 = mandag … 7 = søndag
  fraTime: number // 0–23
  tilTime: number // 1–24
  minBemanning: number
}
export type Krav = { ukedag: number; fraTime: number; tilTime: number; antall: number }
export type FastVakt = { ukedag: number; fraTime: number; tilTime: number }

export type Bemanning = {
  ukedag: number
  time: number
  fast: number // dekket av faste vakter (butikksjef, NK) — går på fastlønn
  gulv: number // bundet variabel bemanning: min/krav minus det faste dekker
  ekstra: number // hele personer tildelt etter kundetrykk
  sum: number // fast + gulv + ekstra
  kunder: number
}

export type Plan = {
  timer: Bemanning[]
  bundneTimer: number // variable timer låst av gulvet
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
      const fast = opts.fasteVakter.some(
        (f) => f.ukedag === v.ukedag && iVindu(t, f.fraTime, f.tilTime),
      ) ? 1 : 0
      sum += Math.max(0, Math.max(v.minBemanning, kravHer) - fast) * antall[v.ukedag]
    }
  }
  return sum
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
}): Plan {
  const { disponibleTimer, ar, maned, vinduer, krav, fasteVakter, profil } = opts
  const maks = opts.maksBemanning ?? Number.POSITIVE_INFINITY
  const minVaktTimer = Math.max(1, opts.minVaktTimer ?? MIN_VAKT_TIMER)
  const antall = dagerPerUkedag(ar, maned)

  // 1) Bundet lag. Faste vakter går på fastlønn og belaster ikke rammen,
  //    men de dekker gulvet — står butikksjefen der, trengs ikke en til.
  const rader: Bemanning[] = []
  let bundneTimer = 0
  for (const v of vinduer) {
    for (let t = v.fraTime; t < v.tilTime; t++) {
      const kravHer = krav
        .filter((k) => k.ukedag === v.ukedag && iVindu(t, k.fraTime, k.tilTime))
        .reduce((m, k) => Math.max(m, k.antall), 0)
      const fast = fasteVakter.some((f) => f.ukedag === v.ukedag && iVindu(t, f.fraTime, f.tilTime))
        ? 1
        : 0
      const gulv = Math.max(0, Math.max(v.minBemanning, kravHer) - fast)
      bundneTimer += gulv * antall[v.ukedag]
      rader.push({
        ukedag: v.ukedag,
        time: t,
        fast,
        gulv,
        ekstra: 0,
        sum: fast + gulv,
        kunder: profil.get(`${v.ukedag}:${t}`) ?? 0,
      })
    }
  }

  const frieTimer = disponibleTimer - bundneTimer
  if (frieTimer <= 0) {
    return {
      timer: rader,
      bundneTimer,
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
            if (r.sum >= maks) { plass = false; break }
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

  return { timer: rader, bundneTimer, frieTimer, brukteTimer, gjennomforbar: true, underskudd: 0 }
}
