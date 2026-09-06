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
  /**
   * Nevneren kan ikke stemme, så tallene skal ikke leses.
   *
   * **KASTEDE KRONER KAN IKKE OVERSTIGE OMSETNINGEN.** Kastet føres til
   * kostpris og salget til utsalgspris; en andel over 100 % beskriver
   * ikke en dyr måned, den beskriver et salgstall som mangler.
   *
   * Vakten kom av at `/svinn` viste **778,6 %** en hel kveld uten at noe
   * sa fra. Telleren var riktig; nevneren var kuttet av PostgREST-taket
   * til under to prosent av seg selv (`0175`). Tallet var galt på en
   * måte som ikke lignet en feil — bare et høyt tall.
   *
   * Er dette sant, skal flatene si at nevneren mangler. **En brøk som
   * ikke kan regnes skal si det, ikke svare likevel.**
   */
  nevnerMistenkelig: boolean
  /** Måneder der tallet er fasit fra regnskapet. */
  avlagteMaaneder: number
  /** Måneder der tallet er den daglige opplastingen — foreløpig. */
  forelopigeMaaneder: number
}

/**
 * Kastet mot salget: over 1 er umulig, ikke bare dårlig.
 *
 * Ingen terskel med skjønn i. Grensen er en identitet i domenet, og en
 * «rimelighetsgrense» på for eksempel 50 % ville vært en mening — den
 * ville felt en ekte katastrofemåned og sluppet gjennom en nevner som
 * var halvert.
 */
export const nevnerHolderIkke = (kastKr: number, salgKr: number): boolean =>
  salgKr <= 0 ? kastKr > 0 : kastKr > salgKr

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
    nevnerMistenkelig: nevnerHolderIkke(kastHittilKr, salgHittilKr),
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
//
// **VAREOMRAADET ALENE ER IKKE ENTYDIG, OG DET ER IKKE EN DETALJ.**
// Elleve av kodene i produksjon ender paa `10`:
//
//     12010 BAKERI    13010 KAFFE      14010 BRUS     16010 SJOKOLADE
//     17010 DAGLIGVARE 18010 SIGARETTER 19010 AVISER  20010 BILPLEIE
//     21010 MASKINVASK 24010 FORBRUK   25010 PANT
//
// Noekles kastet paa `10` alene, faar BAKERI med seg kaffe, brus,
// tobakk, aviser og pant. Tallet blir stoerre og ser ut som et
// bakeriproblem. Derfor maa ALT foerst avgrenses til avdelingen
// budsjettet gjelder - `avdelingAv(kode) === avdeling` - og
// vareomraadet brukes bare innenfor den.
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

// ---------------------------------------------------------------------
// USYNLIG SVINN — DEN ANDRE HALVDELEN
//
// Identiteten St1 regner med:
//
//     teoretisk brutto − faktisk brutto = synlig svinn + usynlig svinn
//
// Målt på Laguneparken: 2 680 962 − 2 102 133 = 578 828 = 426 681 + 152 148.
//
// «Kast» er det som ble slått inn som kastet. «Usynlig» er resten — svinn
// ingen registrerte: manko, feilslag, tyveri, feil pris. **Fortegnet er
// ikke pynt: + er manko, − er overskudd**, og en telling kan finne mer enn
// forventet. Summen kan derfor bli negativ, og det er et gyldig svar.
//
// ---------------------------------------------------------------------
// DEN FINNES BARE I AVLAGTE MÅNEDER, OG DET MÅ STÅ
//
// Kast har to kilder — den daglige opplastingen og regnskapet. Usynlig
// svinn har ÉN: det oppstår per definisjon uten at noen registrerer noe,
// så det kan først regnes ut når måneden er talt opp og avlagt.
//
// **Legges de sammen uten videre, dekker de to halvdelene ulike
// perioder.** Kastet ville hatt med inneværende måned og det usynlige
// ikke, og totalen ville vært for lav på en måte ingen ser. Derfor er
// totalen her avgrenset til de AVLAGTE månedene, for begge — og antallet
// står i svaret.
//
// ---------------------------------------------------------------------
// BUDSJETTET ER ET ÅRSTALL, IKKE EN SATS
//
// Kastbudsjettet er en prosent, så «budsjett hittil» følger salget.
// Usynligbudsjettet er et kronebeløp for hele året; St1 uttrykker det
// ikke som en rate. Å dele det på tolv eller skalere det med salget ville
// vært å finne på en fordeling de ikke har oppgitt.
//
// Det sammenlignes derfor mot ÅRET, og feltet heter deretter.
// ---------------------------------------------------------------------

export type Usynligstatus = {
  /** Sum `usynlig_kr` over de avlagte månedene. Kan være negativ. */
  usynligKr: number
  /** Kastet i de SAMME månedene — så totalen dekker én periode. */
  kastAvlagtKr: number
  /** `usynligKr + kastAvlagtKr`. Hele svinnet, avlagte måneder. */
  totaltKr: number
  /** St1s årsbudsjett for usynlig. Null når fila ikke oppgir det. */
  arsbudsjettKr: number | null
  /** Hvor mange måneder tallene dekker. Står i teksten, ikke bare her. */
  maaneder: number
}

export type Svinnbilde = {
  linjer: Svinnstatus[]
  /** Summen av linjene. Aldri regnet av en egen totalrad - se `nivaa`. */
  total: Svinnstatus | null
  /** Usynlig svinn og hele svinnet. Null når ingen måned er avlagt. */
  usynlig: Usynligstatus | null
  notat: string
}

/**
 * Usynlig svinn og totalen, over de månedene som ER avlagt.
 *
 * `usynligPerMaaned` og `kastPerMaaned` skal begge komme fra regnskapet.
 * Den daglige opplastingen hører ikke hjemme her: den finnes bare for
 * kast, og en total der den ene halvdelen dekker én måned mer enn den
 * andre er ikke en total.
 */
export function usynligstatus(
  usynligPerMaaned: Map<string, number>,
  kastPerMaaned: Map<string, number>,
  arsbudsjettKr: number | null,
): Usynligstatus | null {
  // SNITTET, ikke unionen. En måned med usynlig men uten kast — eller
  // omvendt — er en måned der den ene kilden mangler, og da er totalen
  // for den måneden ikke hele svinnet.
  const maaneder = [...usynligPerMaaned.keys()].filter((m) => kastPerMaaned.has(m))
  if (maaneder.length === 0) return null

  const usynligKr = maaneder.reduce((a, m) => a + (usynligPerMaaned.get(m) ?? 0), 0)
  const kastAvlagtKr = maaneder.reduce((a, m) => a + (kastPerMaaned.get(m) ?? 0), 0)
  return {
    usynligKr,
    kastAvlagtKr,
    totaltKr: usynligKr + kastAvlagtKr,
    arsbudsjettKr,
    maaneder: maaneder.length,
  }
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
  /** `maaned -> kroner`, fra regnskapet. + er manko, − er overskudd. */
  usynligPerMaaned?: Map<string, number>
  /** St1s årsbudsjett for usynlig. Bare den nyeste filvarianten har det. */
  usynligArsbudsjettKr?: number | null
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
    // TOTALEN ER MISTENKELIG OM ÉN LINJE ER DET. En enkelt linje med en
    // manglende nevner drar hele prosenten med seg, og en total som ser
    // rolig ut over en ødelagt linje er verre enn ingen total.
    total.nevnerMistenkelig = nevnerHolderIkke(total.kastHittilKr, total.salgHittilKr)
      || linjer.some((l) => l.nevnerMistenkelig)
  }

  // KASTET PER MÅNED, FRA REGNSKAPET ALENE. Summert på tvers av linjene,
  // slik at usynlig og kast dekker nøyaktig de samme månedene.
  const kastAvlagtPerMaaned = new Map<string, number>()
  for (const per of opts.kastRegnskap.values()) {
    for (const [m, kr] of per) kastAvlagtPerMaaned.set(m, (kastAvlagtPerMaaned.get(m) ?? 0) + kr)
  }

  return {
    linjer: [...linjer].sort((a, b) => b.avvikKr - a.avvikKr),
    total,
    usynlig: opts.usynligPerMaaned
      ? usynligstatus(
        opts.usynligPerMaaned, kastAvlagtPerMaaned, opts.usynligArsbudsjettKr ?? null,
      )
      : null,
    notat: total ? kildenotat(total) : 'Ingen kastbudsjett for dette året.',
  }
}
