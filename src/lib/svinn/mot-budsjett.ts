// =====================================================================
// SVINN MOT BUDSJETT — og hvilken kilde som gjelder når
//
// St1 setter et kastbudsjett per stasjon og år. Butikksjefen skal se
// hvor hun ligger. Men de to kildene til «hvor mye har vi kastet» er
// ikke like mye verdt, og det er hele saken her.
//
//   DAGLIG OPPLASTING   Varetransaksjonene. Kommer hver dag, og gir en
//                       løpende peker hun kan justere etter. Men de
//                       ansatte fører på terminalen, og de fører feil:
//                       én linje var 52 % av Lones mai.
//
//   REGNSKAPET          Kommer når måneden er avlagt, og er FASIT. Det
//                       er dette tallet St1 måler mot, og det er dette
//                       som havner i årsoppgjøret.
//
// ---------------------------------------------------------------------
// AVLAGT MÅNED VINNER, ALLTID
//
// Er måneden avlagt, brukes regnskapets tall og den daglige summen
// kastes. Ikke fordi den daglige er verdiløs — den var riktig nok til å
// styre etter — men fordi to tall for samme måned er ett tall for mye,
// og da må det være det som gjelder utad.
//
// **Og det skal SYNES hvilken kilde tallet kommer fra.** En blanding av
// avlagte og foreløpige måneder som ser lik ut, er nøyaktig formen som
// gjør at ingen oppdager at halve året er et anslag.
//
// ---------------------------------------------------------------------
// PROSENTEN ER ST1s, IKKE SENTIQAS
//
// St1 regner kastede kroner (kostpris) delt på SALG. `/svinn` regner
// kost mot kost. De er ulike brøker og vil aldri stemme overens.
//
// Her brukes St1s, fordi budsjettet er uttrykt i den. En oppfyllelses-
// grad må bruke samme brøk som kravet, ellers måler den ingenting.
// =====================================================================

export type Kilde = 'regnskap' | 'daglig'

export type Maanedsvinn = {
  /** «2026-08». */
  maaned: string
  /** Kastede kroner (kostpris). */
  kastKr: number
  kilde: Kilde
  /** Matsalget i måneden. Nevneren i St1s brøk. */
  salgKr: number
}

export type Budsjettlinje = {
  /** `120` for Mat-totalen, ellers vareområdet. */
  kode: string
  navn: string
  /** Andel av omsetning. Ikke av kost. */
  kastPstAvSalg: number
  /** St1s egen utregning for hele året. */
  kastBudsjettKr: number
}

export type Svinnstatus = {
  linje: Budsjettlinje
  /** Kastet så langt, summert over månedene vi har. */
  kastHittilKr: number
  /** Matsalget så langt. Budsjettet følger salget, ikke kalenderen. */
  salgHittilKr: number
  /** `kastPstAvSalg × salgHittil` — kravet så langt, ikke året delt på tolv. */
  budsjettHittilKr: number
  /** Positivt = over budsjett, altså for mye kastet. */
  avvikKr: number
  /** Faktisk kast% så langt, i St1s brøk. */
  faktiskPst: number | null
  /** Måneder der tallet er fasit fra regnskapet. */
  avlagteMaaneder: number
  /** Måneder der tallet er den daglige opplastingen — foreløpig. */
  forelopigeMaaneder: number
}

/**
 * Én kilde per måned: regnskapet der det finnes, ellers den daglige.
 *
 * Tar imot begge og velger. Kallstedet skal ikke gjøre det valget —
 * gjøres det to steder, blir det gjort ulikt.
 */
export function velgKilde(
  fraRegnskap: Map<string, number>,
  fraDaglig: Map<string, number>,
  salgPerMaaned: Map<string, number>,
): Maanedsvinn[] {
  const maaneder = [...new Set([...fraRegnskap.keys(), ...fraDaglig.keys()])].sort()
  return maaneder.map((m) => {
    const avlagt = fraRegnskap.get(m)
    return {
      maaned: m,
      // `?? ` og ikke `||`: 0 kr kastet i en avlagt måned er et svar, og
      // det skal ikke falle tilbake på den daglige summen.
      kastKr: avlagt ?? fraDaglig.get(m) ?? 0,
      kilde: avlagt === undefined ? 'daglig' : 'regnskap',
      salgKr: salgPerMaaned.get(m) ?? 0,
    }
  })
}

/**
 * Hvor ligger stasjonen an mot kravet?
 *
 * BUDSJETTET FØLGER SALGET. Kravet er en prosent, så «budsjett hittil»
 * er `kastPstAvSalg × salget så langt` — ikke året delt på tolv. En flat
 * tolvdel ville sett riktig ut og vært feil hver måned med sesong i.
 */
export function svinnstatus(linje: Budsjettlinje, maaneder: Maanedsvinn[]): Svinnstatus {
  const kastHittilKr = maaneder.reduce((a, m) => a + m.kastKr, 0)
  const salgHittilKr = maaneder.reduce((a, m) => a + m.salgKr, 0)
  const budsjettHittilKr = linje.kastPstAvSalg * salgHittilKr
  return {
    linje,
    kastHittilKr,
    salgHittilKr,
    budsjettHittilKr,
    avvikKr: kastHittilKr - budsjettHittilKr,
    faktiskPst: salgHittilKr > 0 ? kastHittilKr / salgHittilKr : null,
    avlagteMaaneder: maaneder.filter((m) => m.kilde === 'regnskap').length,
    forelopigeMaaneder: maaneder.filter((m) => m.kilde === 'daglig').length,
  }
}

/**
 * Én setning om hvor mye tallet er verdt.
 *
 * Den står aldri tom. Et tall uten kildeangivelse leses som fasit, og
 * halve året kan være et anslag.
 */
export function kildenotat(s: Svinnstatus): string {
  const { avlagteMaaneder: a, forelopigeMaaneder: f } = s
  if (a === 0 && f === 0) return 'Ingen måneder med data ennå.'
  if (f === 0) return `Alle ${a} månedene er avlagt i regnskapet. Tallet er fasit.`
  if (a === 0) {
    return `${f} ${f === 1 ? 'måned' : 'måneder'} fra den daglige opplastingen. `
      + 'Ingen er avlagt ennå, så tallet kan flytte seg når regnskapet kommer.'
  }
  return `${a} ${a === 1 ? 'måned' : 'måneder'} er avlagt i regnskapet, `
    + `${f} ${f === 1 ? 'er' : 'er'} fortsatt den daglige opplastingen. `
    + 'De siste kan flytte seg.'
}

// ---------------------------------------------------------------------
// HELE BILDET: FLERE VAREOMRAADER, FLERE MAANEDER
//
// Regnskapets kode er AVDELING + VAREOMRAADE, satt sammen: `12010` er
// 120 MAT >> 10 BAKERI, `13010` er 130 VARM DRIKKE >> 10 KAFFE. Det er
// samme nummerering som salgsdataene, bare skrevet i ett - og det er
// derfor de to kildene kan legges ved siden av hverandre.
//
// Budsjettet bruker det korte: `10` for BAKERI. Sammenstillingen skjer
// her, én gang, saa ingen kallsteder gjoer den hver sin vei.
// ---------------------------------------------------------------------

/** `12010` -> `10`. Avdelingen er alltid tre siffer. */
export function vareomradeAv(regnskapskode: string | null): string | null {
  if (!regnskapskode) return null
  const k = regnskapskode.trim()
  return k.length === 5 && /^\d{5}$/.test(k) ? k.slice(3) : null
}

/** Avdelingen i regnskapskoden: `12010` -> `120`. */
export function avdelingAv(regnskapskode: string | null): string | null {
  if (!regnskapskode) return null
  const k = regnskapskode.trim()
  return k.length === 5 && /^\d{5}$/.test(k) ? k.slice(0, 3) : null
}

export type Svinnbilde = {
  linjer: Svinnstatus[]
  /** Summen av linjene. Aldri regnet av en egen totalrad - se `nivaa`. */
  total: Svinnstatus | null
  notat: string
}

/**
 * Setter budsjettet mot det som faktisk ble kastet.
 *
 * `kast*` og `salg` er `kode -> maaned -> kroner`, der `kode` er den
 * korte formen budsjettet bruker.
 *
 * TOTALEN ER SUMMEN AV LINJENE, aldri en egen rad. Finnes bare
 * Mat-totalen i budsjettet (2026-fila), er den ene linja totalen; finnes
 * undergruppene, summeres de. Aa lagre begge og vise begge ville telt
 * hver krone to ganger.
 */
export function svinnbilde(opts: {
  budsjett: Budsjettlinje[]
  kastRegnskap: Map<string, Map<string, number>>
  kastDaglig: Map<string, Map<string, number>>
  salg: Map<string, Map<string, number>>
}): Svinnbilde {
  const tom = new Map<string, number>()
  const linjer = opts.budsjett.map((b) => svinnstatus(
    b,
    velgKilde(
      opts.kastRegnskap.get(b.kode) ?? tom,
      opts.kastDaglig.get(b.kode) ?? tom,
      opts.salg.get(b.kode) ?? tom,
    ),
  ))

  const total = linjer.length === 0 ? null : svinnstatus(
    {
      kode: 'sum',
      navn: linjer.length === 1 ? linjer[0].linje.navn : 'Til sammen',
      // Den samlede prosenten er den VEIDE, ikke gjennomsnittet av
      // linjenes prosenter. Bakeri kaster 12 % av en liten omsetning og
      // poelse 6 % av en stor; et snitt av de to tallene beskriver ingen.
      kastPstAvSalg: linjer.reduce((a, l) => a + l.budsjettHittilKr, 0)
        / (linjer.reduce((a, l) => a + l.salgHittilKr, 0) || 1),
      kastBudsjettKr: linjer.reduce((a, l) => a + l.linje.kastBudsjettKr, 0),
    },
    // Én syntetisk «maaned» per kilde, saa telleverket under stemmer.
    linjer.flatMap((l) => [
      ...Array.from({ length: l.avlagteMaaneder }, () => ({ maaned: '', kastKr: 0, salgKr: 0, kilde: 'regnskap' as const })),
      ...Array.from({ length: l.forelopigeMaaneder }, () => ({ maaned: '', kastKr: 0, salgKr: 0, kilde: 'daglig' as const })),
    ]),
  )
  if (total) {
    total.kastHittilKr = linjer.reduce((a, l) => a + l.kastHittilKr, 0)
    total.salgHittilKr = linjer.reduce((a, l) => a + l.salgHittilKr, 0)
    total.budsjettHittilKr = linjer.reduce((a, l) => a + l.budsjettHittilKr, 0)
    total.avvikKr = total.kastHittilKr - total.budsjettHittilKr
    total.faktiskPst = total.salgHittilKr > 0 ? total.kastHittilKr / total.salgHittilKr : null
  }

  return {
    linjer: [...linjer].sort((a, b) => b.avvikKr - a.avvikKr),
    total,
    notat: total ? kildenotat(total) : 'Ingen kastbudsjett for dette året.',
  }
}
