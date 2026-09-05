// =====================================================================
// LØNNSKOST PER MÅNED — FAKTISK MOT BUDSJETT
//
// Ingen flate viste lønn over tid. `/regnskap` viser én måned om gangen,
// `/lonn` handler om enkeltansatte — timesatser, skiftordning, lukking
// av vakter. Spørsmålet «koster stasjonen mer i lønn enn den skal, og
// har den gjort det lenge» hadde ingen side.
//
// ---------------------------------------------------------------------
// SUMMEN ER VERIFISERT MOT PRODUKSJON, IKKE UTLEDET
//
// Bønes, juli 2026 — de ni kontiene under gir 242 963 kr. Den samme
// måneden regnet ut av easy@work-eksporten med Energiavtalens satser,
// feriepenger og AGA gir 242 963. Null kroners avvik.
//
// Det er derfor `LONNSKONTI` er en LISTE og ikke et prefiksfilter:
// `kode like '5%'` ville tatt med 590 Andre personalkostnader, og
// summen ville ikke lenger vært den som stemmer.
//
// ---------------------------------------------------------------------
// 590 ER PERSONALKOST, IKKE LØNN
//
// Andre personalkostnader er kurs, verneutstyr, bedriftshelsetjeneste.
// Det er en kostnad lederen styrer, men den er ikke lønn, og den følger
// ingen tariff. Blandes den inn, kan ikke tallet sammenlignes med noe
// lønnsgrunnlag — og «lønn per time» blir en brøk med feil teller.
//
// Den vises derfor ved siden av, aldri i.
//
// ---------------------------------------------------------------------
// 506 REFUNDERT SYKELØNN LIGGER INNE SOM NEGATIVT TALL
//
// Refusjonen fra NAV er lagret som en negativ kostnad, slik den står i
// regnskapet. Den skal derfor LEGGES TIL som alle de andre — trekkes
// den fra, teller refusjonen dobbelt og lønnskosten blir for lav.
// =====================================================================

/**
 * Kontiene som utgjør lønnskost. Rekkefølgen er visningsrekkefølgen.
 *
 * St1s kontoplan er tresifret her; BP-en bruker fire siffer for de samme
 * postene. Se `bp.ts` — de to settene møtes aldri i samme måned.
 */
export const LONNSKONTI = [
  '501', // Faste lønninger
  '502', // Lønnstillegg
  '503', // Timelønn
  '505', // Sykelønn
  '506', // Refundert sykelønn — negativ
  '508', // Påløpte feriepenger
  '509', // Bonus
  '540', // Arb.avg av lønn
  '541', // Arb.avg av feriepenger
] as const

/** Personalkost som IKKE er lønn. Vises ved siden av, aldri i summen. */
export const ANDRE_PERSONALKONTI = ['590'] as const

/** Kontantlønn — grunnlaget feriepenger og AGA regnes av. */
const KONTANTKONTI = new Set(['501', '502', '503', '505', '506', '509'])
const FERIEPENGEKONTI = new Set(['508'])
const AGAKONTI = new Set(['540', '541'])

/** Nøkkeltallet St1 selv oppgir. Eneste sted faktiske timer finnes. */
export const TIMEPOST = 'Timelønn - antall timer'

export type Kontolinje = {
  periode: string
  seksjon: string
  kode: string | null
  post: string
  regnskap: number | null
  budsjett: number | null
}

/**
 * Hvor budsjettallet kom fra.
 *
 * DE TO FINNES ALDRI I SAMME MÅNED, og det er ikke tilfeldig:
 * BP-importen hopper over måneder som er avlagt (`if (erLaast) continue`
 * i `import/kjerne.ts`), fordi regnskapet da bærer budsjettet selv — på
 * samme rad som tallet det skal sammenlignes med.
 *
 * En avlagt måned har altså St1s månedsbudsjett; en åpen måned har
 * BP-ens. Derfor sier hver rad hvilket budsjett den ble målt mot.
 * Uten det ville en serie som skifter kilde midt i se ut som et brudd i
 * tallene.
 */
export type Budsjettkilde = 'st1_maaned' | 'bp'

export type Maanedslonn = {
  maaned: string
  /** `regnskap` = avlagt måned. `bp` = budsjett, ingen fasit ennå. */
  avlagt: boolean
  kontantKr: number
  feriepengerKr: number
  agaKr: number
  /** Summen av de ni kontiene. Verifisert mot Bønes juli 2026. */
  lonnskostKr: number
  /** 590. Utenfor lønnskosten med vilje. */
  andrePersonalKr: number
  budsjettKr: number | null
  budsjettKilde: Budsjettkilde | null
  /** Fra St1s eget nøkkeltall. Null når måneden ikke er avlagt. */
  timer: number | null
  /** Lønnskost per time. Null uten timer — aldri en brøk på gjetning. */
  perTime: number | null
  linjer: { kode: string; post: string; regnskap: number; budsjett: number | null }[]
}

const tall = (v: number | null | undefined) => (typeof v === 'number' && Number.isFinite(v) ? v : 0)

/**
 * Bygger én rad per måned av de rå regnskapslinjene.
 *
 * `linjer` skal være ALLE linjene for én stasjon — både `driftskostnader`
 * (avlagte måneder), `bp_kostnad` (åpne) og `nokkeltall` (timene).
 * Filtrering på stasjon hører hjemme i spørringen, ikke her: en funksjon
 * som både henter og velger kan ikke testes uten en base.
 */
export function byggLonnskost(
  linjer: Kontolinje[],
  bpLonnskonti: ReadonlySet<string>,
): Maanedslonn[] {
  const perMaaned = new Map<string, Kontolinje[]>()
  for (const l of linjer) {
    const m = l.periode.slice(0, 7)
    const liste = perMaaned.get(m) ?? []
    liste.push(l)
    perMaaned.set(m, liste)
  }

  const ut: Maanedslonn[] = []
  for (const [maaned, ls] of perMaaned) {
    const drift = ls.filter((l) => l.seksjon === 'driftskostnader' && l.kode != null)
    const bp = ls.filter((l) => l.seksjon === 'bp_kostnad' && l.kode != null)

    // AVLAGT ER EN EGENSKAP VED DATAENE, IKKE VED DATOEN.
    //
    // En måned er avlagt når regnskapet har lønnslinjer for den — ikke
    // når kalenderen har passert den. Regnskapet kommer midt i neste
    // måned, og en kalenderbasert regel ville meldt inneværende måned
    // som avlagt i to uker med tomme tall.
    const lonnsdrift = drift.filter((l) => LONNSKONTI.includes(l.kode as never))
    const avlagt = lonnsdrift.length > 0

    const kilde = avlagt ? lonnsdrift : bp.filter((l) => bpLonnskonti.has(l.kode!))
    if (kilde.length === 0) continue

    let kontantKr = 0, feriepengerKr = 0, agaKr = 0, budsjett = 0, harBudsjett = false
    const rader: Maanedslonn['linjer'] = []
    for (const l of kilde) {
      const kr = tall(l.regnskap)
      // BP-radene bærer budsjettet i BEGGE kolonnene — importen setter
      // `regnskap: 0`. For en åpen måned er budsjettet derfor det eneste
      // tallet som finnes, og det er hva raden viser.
      const belop = avlagt ? kr : tall(l.budsjett)
      const kode = l.kode!
      if (avlagt) {
        if (KONTANTKONTI.has(kode)) kontantKr += belop
        else if (FERIEPENGEKONTI.has(kode)) feriepengerKr += belop
        else if (AGAKONTI.has(kode)) agaKr += belop
      }
      if (l.budsjett != null) { budsjett += l.budsjett; harBudsjett = true }
      rader.push({ kode, post: l.post, regnskap: belop, budsjett: l.budsjett })
    }

    const lonnskostKr = avlagt
      ? kontantKr + feriepengerKr + agaKr
      : rader.reduce((a, r) => a + r.regnskap, 0)

    const andrePersonalKr = (avlagt ? drift : bp)
      .filter((l) => ANDRE_PERSONALKONTI.includes(l.kode as never))
      .reduce((a, l) => a + (avlagt ? tall(l.regnskap) : tall(l.budsjett)), 0)

    const timerLinje = ls.find((l) => l.seksjon === 'nokkeltall' && l.post === TIMEPOST)
    const timer = timerLinje && tall(timerLinje.regnskap) > 0 ? tall(timerLinje.regnskap) : null

    ut.push({
      maaned,
      avlagt,
      kontantKr,
      feriepengerKr,
      agaKr,
      lonnskostKr,
      andrePersonalKr,
      budsjettKr: harBudsjett ? budsjett : null,
      budsjettKilde: harBudsjett ? (avlagt ? 'st1_maaned' : 'bp') : null,
      timer,
      perTime: timer ? lonnskostKr / timer : null,
      linjer: rader.sort((a, b) => a.kode.localeCompare(b.kode)),
    })
  }

  return ut.sort((a, b) => b.maaned.localeCompare(a.maaned))
}
