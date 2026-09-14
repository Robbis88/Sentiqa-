// =====================================================================
// MÅLKONTRAKTEN
// =====================================================================
//
// Hva en butikksjef kan sette seg som mål, i hvilken enhet, og hva et
// mål er verdt i kroner i året.
//
// **INGEN TABELL OG INGEN FLATE HER.** Kontrakten skrives som kode
// først, med vilje: `0218_maal.sql` fryser enhetene i en
// check-constraint, og en frossen kolonne er dyrere å angre enn en
// type. Robert kvitterte kontrakten 2026-09-14.
//
// ---------------------------------------------------------------------
// TRE ENHETER, IKKE TO
// ---------------------------------------------------------------------
//
// Første utkast hadde `pst_av_oms` og `kr_aar`. Det manglet den
// viktigste: lønn måles verken i kroner eller i prosent av omsetning,
// men som **andel av bruttofortjenesten**.
//
// Grunnen står i `lonnskost/rom.ts`: BP-lønna er fast, men rommet
// beveger seg med brutto. Et mål i kroner mot BP blir meningsløst når
// brutto faller — det er nøyaktig feilen lønnsrommet finnes for å
// hindre.
//
// ---------------------------------------------------------------------
// ÉN KANONISK VERDI, FLERE VISNINGER
// ---------------------------------------------------------------------
//
// `andel_av_brutto` er verdien under panseret. Butikksjefen skal aldri
// måtte skrive «34,5 % av brutto». Hennes språk er de fire radene:
//
//   BP-lønn → lønnsrom nå → forventet lønn → kroner over/under rommet
//
// Prosentpoeng er forklaring, ikke inngang. Og **timer vises ikke** før
// det finnes en dokumentert og testet motor for kostnad per disponibel
// time — feriepenger, AGA og pensjon gjør en løs «400 kr/time» til falsk
// presisjon.
//
// ---------------------------------------------------------------------
// DENNE FILA REGNER GJENNOM `verdiAvGevinst`, ALLTID
// ---------------------------------------------------------------------
//
// Forskjellen mellom en marginforbedring (royaltyfri) og en volumvekst
// (betaler satsen for kanalen) er den som er lett å miste når
// regnestykket ligger spredt. Den bor i `royalty.ts`, og her kalles den
// — den skrives ikke om.
// =====================================================================

import { loftestang, type Klasse, type Loftestang, type LoftestangId } from '@/lib/kurs/loftestenger'
import { verdiAvGevinst, type Kanal, type Satser } from '@/lib/royalty'

/**
 * Enheten et mål lagres i.
 *
 * `pst_av_oms`       prosentpoeng av omsetning. 3,90 → 3,10.
 * `andel_av_brutto`  andel av bruttofortjenesten. 0,364 → 0,345.
 * `kr_aar`           kroner for et helt år.
 */
export type Maalenhet = 'pst_av_oms' | 'andel_av_brutto' | 'kr_aar'

/**
 * Hvor «ambisiøst» kan forankres.
 *
 * ANKERET SKAL VISES. Butikksjefen skal kunne se om nivået er St1s eget
 * tall eller noe vi fant på. `kastbudsjett` er St1s; `egen_historikk` er
 * vårt.
 */
export type Anker = 'kastbudsjett' | 'bp' | 'egen_historikk' | 'beste_stasjon'

export type Maalkontrakt = {
  loftestang: LoftestangId
  enhet: Maalenhet
  /** Hva målverdien kan forankres i, sterkeste først. */
  anker: readonly Anker[]
  /**
   * Kilder som kan gi en PROGNOSE før regnskapet.
   *
   * **Tom liste er en egenskap, ikke et hull.** `usynlig_rest` er per
   * definisjon differansen regnskapet avdekker; å vise et tidlig tall
   * der ville vært å finne på noe fordi det hadde sett pent ut.
   */
  prognosekilder: readonly string[]
  /** Hva som må finnes før en måling kan kalles fasit. */
  fasitkrav: string
}

/**
 * Kontrakten, én post per løftestang.
 *
 * `Record<LoftestangId, …>` med vilje: legger noen til en sjette
 * løftestang uten å ta stilling til enheten, kompilerer ikke koden.
 * Samme grep som `SPALTE` i `redesign/monstre.ts`.
 */
export const MAALKONTRAKT: Record<LoftestangId, Maalkontrakt> = {
  matkast: {
    loftestang: 'matkast',
    // KRONER ER FEIL MÅLESTOKK, og det er målt: over Kelsars
    // januar–juli 2026 ga kroner og prosent MOTSATT svar på tre av fem
    // stasjoner. Se `kurs/kastvurdering.ts`.
    enhet: 'pst_av_oms',
    anker: ['kastbudsjett', 'egen_historikk'],
    // Den daglige varetransaksjonsfila. Verdt å styre etter, men de
    // ansatte fører på terminalen og de fører feil — én linje var 52 %
    // av Lones mai. Derfor merkes den, den erstatter ikke fasit.
    prognosekilder: ['synlig_svinn (daglig, upålitelig)'],
    fasitkrav: 'regnskap_usynlig_svinn for måneden',
  },

  usynlig_rest: {
    loftestang: 'usynlig_rest',
    enhet: 'pst_av_oms',
    // INTET BUDSJETT FINNES. St1 setter kastbudsjett, men ingen norm for
    // usynlig svinn. Eneste ærlige anker er stasjonens egen historikk.
    anker: ['egen_historikk'],
    // TOM MED VILJE. Se `Maalkontrakt.prognosekilder`.
    prognosekilder: [],
    fasitkrav: 'regnskapet — ingen tidlig kilde finnes',
  },

  personal: {
    loftestang: 'personal',
    // Se blokka øverst. Dette er den ene enheten som ikke er opplagt,
    // og den er hele grunnen til at kontrakten ble skrevet før tabellen.
    enhet: 'andel_av_brutto',
    anker: ['bp', 'egen_historikk'],
    prognosekilder: [
      'easy@work + manuell fastlønn (mangler sykerefusjon og bonus)',
      'stempling (timer, ikke kroner)',
    ],
    fasitkrav: 'de ni lønnskontiene i regnskapet — se lonnskost/maaned.ts',
  },

  paavirkbar_drift: {
    loftestang: 'paavirkbar_drift',
    // KRONER, IKKE NORMALISERT PER OMSETNING. `rommet/spare.ts`
    // normaliserer når den SAMMENLIGNER STASJONER — der er det riktig,
    // for Laguneparken er dobbelt så stor som Bønes. Men et mål er én
    // stasjon over tid, og normalisering ville latt et omsetningsfall
    // «oppnå» kostnadsmålet uten at noen hadde spart en krone.
    enhet: 'kr_aar',
    anker: ['egen_historikk', 'beste_stasjon'],
    // Ingen faktura leses før regnskapet. En datagrense, ikke en
    // byggefeil — og den skal stå skrevet.
    prognosekilder: [],
    fasitkrav: 'regnskapet, og bilagssum for leverandørdetaljen',
  },

  omsetning: {
    loftestang: 'omsetning',
    enhet: 'kr_aar',
    anker: ['bp', 'egen_historikk'],
    // Den beste tidlige kilden i hele systemet: den kommer hver dag.
    prognosekilder: ['v_butikksalg (daglig)'],
    fasitkrav: 'regnskapets omsetningsseksjon',
  },
}

/**
 * Kan denne løftestangen bli et mål?
 *
 * BARE SPAKER. En `folge` faller ut av noe annet — pensjon følger lønna
 * — og en `fast` er en avtale. Et mål på en av dem ville bedt
 * butikksjefen om noe hun ikke rår over, og det er nøyaktig det
 * `loftestenger.ts` finnes for å hindre.
 *
 * Tar klassen og ikke en id, så regelen kan prøves mot en `folge` selv
 * når alle fem løftestengene tilfeldigvis er spaker.
 */
export function kanSettesSomMaal(l: Pick<Loftestang, 'klasse'>): boolean {
  return l.klasse === 'spak'
}

/** Klassene som aldri kan bli mål. Står her for at testen skal kunne liste dem. */
export const IKKE_MAALBARE: readonly Klasse[] = ['folge', 'fast'] as const

/**
 * Grunnlaget en kroneverdi regnes av.
 *
 * ÅRSTALL, IKKE MÅNEDSTALL. Det er ikke en detalj — se `aarseffekt`.
 */
export type Maalgrunnlag = {
  /** Butikkomsetning for et år, uten drivstoff (`v_butikksalg`). */
  omsetningKr: number
  /** Bruttofortjeneste for det samme året, i kroner. */
  bruttoKr: number
  /** Royaltysatsene som gjaldt da målet ble satt. */
  satser: Satser
  /** Bare for omsetningsmål. Vask over kassa betaler 60 %, app 0 %. */
  kanal?: Kanal
}

export type Maalspenn = {
  loftestang: LoftestangId
  /** Der stasjonen står i dag, i kontraktens enhet. */
  startverdi: number
  /** Der butikksjefen vil, i samme enhet. */
  maalverdi: number
}

export type Spenndom =
  | { gyldig: true }
  | { gyldig: false; grunn: string }

/**
 * Er dette et mål i det hele tatt?
 *
 * =====================================================================
 * RETNINGEN LESES AV LØFTESTANGEN, OG DEN GJELDER OGSÅ FOR VERDIEN
 * =====================================================================
 *
 * Her sto ingenting, og `aarseffekt` gjorde `Math.abs` på spennet. Da
 * fikk et mål som går FEIL vei en positiv årsgevinst:
 *
 *   matkast 3,90 → 3,10 %   forbedring    +113 600
 *   matkast 3,10 → 3,90 %   forverring    +113 600     <- samme tall
 *
 * Det er ikke en visningsfeil. `aarseffekt` fryses som `aarseffekt_kr`
 * når målet settes (E8), og et lagret gevinstpotensial for et mål som
 * går bakover er en løgn ingen senere kan se at var det.
 *
 * `fremdrift` leste `loftestang().god` riktig hele tiden. To syn på
 * samme sannhet i samme fil er ett for mye.
 *
 * ---------------------------------------------------------------------
 * ET MÅL UTEN SPENN ER IKKE ET MÅL
 *
 * `start === mål` er teknisk håndterbart — `fremdrift` gir 0 og ikke en
 * divisjon på null. Men det er ingen forpliktelse, og det skal ikke
 * kunne lagres. Grensen hører hjemme her, ved skrivingen, ikke i E8 der
 * den måtte gjettes.
 *
 * ---------------------------------------------------------------------
 * IKKE-ENDELIGE TALL ER HVERKEN LIKE ELLER ULIKE
 *
 * `NaN !== NaN`, og hver sammenligning mot NaN er usann. Uten denne
 * ville et skjemafelt som ikke lot seg lese passert som gyldig og gitt
 * `NaN` kroner i året.
 */
export function gyldigSpenn(spenn: Maalspenn): Spenndom {
  const l = loftestang(spenn.loftestang)
  const { startverdi: fra, maalverdi: til } = spenn

  if (!Number.isFinite(fra) || !Number.isFinite(til)) {
    return { gyldig: false, grunn: 'Start eller mål er ikke et tall.' }
  }
  if (fra === til) {
    return { gyldig: false, grunn: 'Start og mål er like — et mål uten spenn er ikke et mål.' }
  }
  if (l.god === 'ned' && til > fra) {
    return {
      gyldig: false,
      grunn: `${l.navn} skal ned. Målet ${til} ligger over dagens ${fra}.`,
    }
  }
  if (l.god === 'opp' && til < fra) {
    return {
      gyldig: false,
      grunn: `${l.navn} skal opp. Målet ${til} ligger under dagens ${fra}.`,
    }
  }
  return { gyldig: true }
}

/**
 * Hva målet er verdt i kroner i året, om det nås og holdes.
 *
 * =====================================================================
 * INGEN GANGING MED TOLV HER, OG DET ER POENGET
 * =====================================================================
 *
 * `kronerIAret()` i `kurs/plan.ts` ganger med 12, og har rett i det:
 * inputen der er en MÅNEDSBEVEGELSE, målt mellom to måneder.
 *
 * Et mål er noe annet. Det uttrykkes mot et ÅRSGRUNNLAG — årsomsetning,
 * årsbrutto, kroner per år — og er derfor allerede årlig. Ganger man med
 * tolv her, blir svaret tolv ganger for stort, og det ser ut som et
 * stort funn i stedet for en feil.
 *
 * `aarseffekt.test.ts` binder de to sammen: samme underliggende
 * forbedring, uttrykt månedlig og årlig, skal gi samme kroneverdi.
 *
 * ---------------------------------------------------------------------
 * KASTER PÅ ET UGYLDIG SPENN
 * ---------------------------------------------------------------------
 *
 * Her sto `Math.abs`, og da fikk et mål i feil retning samme positive
 * årsgevinst som det riktige. Se `gyldigSpenn`.
 *
 * **Kaster, og gir ikke null.** Et `null` ville latt en kallssti lagre
 * ingenting i stillhet; et kast blir en kvittering brukeren ser. Samme
 * valg som `loftestang()` gjør på en ukjent id.
 *
 * Den som skriver skal kalle `gyldigSpenn` FØRST og gi grunnen videre —
 * kastet er bakstopperen, ikke porten.
 */
export function aarseffekt(spenn: Maalspenn, g: Maalgrunnlag): number {
  const dom = gyldigSpenn(spenn)
  if (!dom.gyldig) throw new Error(`Ugyldig maalspenn: ${dom.grunn}`)

  const k = MAALKONTRAKT[spenn.loftestang]
  const l = loftestang(spenn.loftestang)
  // RETNINGEN, IKKE AVSTANDEN. `gyldigSpenn` har alt slaatt fast at
  // maalet ligger riktig vei, saa dette er garantert positivt - men det
  // er `god` som gjoer det, ikke `Math.abs`.
  const delta = l.god === 'ned'
    ? spenn.startverdi - spenn.maalverdi
    : spenn.maalverdi - spenn.startverdi

  // VOLUM BETALER ROYALTY, MARGIN GJØR DET IKKE. Skillet er `royalty.ts`
  // sitt, og det kalles — det gjentas ikke.
  if (l.gevinst === 'volum') {
    const bruttomargin = g.omsetningKr > 0 ? g.bruttoKr / g.omsetningKr : 0
    return verdiAvGevinst(
      { type: 'volum', omsetningKr: kronerAv(k.enhet, delta, g), bruttomargin, kanal: g.kanal ?? 'ordinaer' },
      g.satser,
    )
  }
  return verdiAvGevinst({ type: 'margin', kroner: kronerAv(k.enhet, delta, g) }, g.satser)
}

/** Enheten gjort om til kroner for et år. Ingen multiplikator. */
function kronerAv(enhet: Maalenhet, delta: number, g: Maalgrunnlag): number {
  switch (enhet) {
    // Prosentpoeng av omsetning: 0,80 pp av 14,2 mill = 113 600.
    case 'pst_av_oms': return (delta / 100) * g.omsetningKr
    // Andel av brutto: 0,019 av 5,35 mill = 101 650.
    case 'andel_av_brutto': return delta * g.bruttoKr
    // Allerede kroner, allerede for et år.
    case 'kr_aar': return delta
  }
}

export type Fremdrift = {
  /** Andelen av veien fra start til mål som er gått. Kan overstige 1. */
  andel: number
  /** Avviket mot målet, i kontraktens enhet. Negativt = forbi målet. */
  avvik: number
  naadd: boolean
}

/**
 * Hvor langt målet er kommet, målt i sin egen enhet.
 *
 * RETNINGEN LESES AV LØFTESTANGEN, ikke av fortegnet på spennet. `god`
 * i `loftestenger.ts` vet at omsetning skal opp og matkast ned; å utlede
 * det av tallene ville gitt en andre sannhet om hva som er bedre.
 *
 * ---------------------------------------------------------------------
 * DENNE KASTER IKKE, OG DET ER MED VILJE
 * ---------------------------------------------------------------------
 *
 * `aarseffekt` kaster på et ugyldig spenn fordi den kalles når målet
 * SETTES. `fremdrift` kalles når et lagret mål LESES, og en rad som
 * likevel skulle være rar må ikke kunne ta ned sida.
 *
 * Porten står ved skrivingen (`gyldigSpenn`), som `maanedsplan`-
 * triggeren: basen vokter det som skrives, flaten tegner det som står.
 *
 * ANDELEN KLEMMES IKKE TIL NULL. Går et mål bakover, skal det SES — en
 * stasjon som blir verre må ikke se ut som en som står stille.
 */
export function fremdrift(spenn: Maalspenn, naa: number): Fremdrift {
  const l = loftestang(spenn.loftestang)
  const bredde = Math.abs(spenn.maalverdi - spenn.startverdi)
  const gaatt = l.god === 'ned' ? spenn.startverdi - naa : naa - spenn.startverdi
  const avvik = l.god === 'ned' ? naa - spenn.maalverdi : spenn.maalverdi - naa
  return {
    andel: bredde === 0 ? 0 : gaatt / bredde,
    avvik,
    naadd: bredde > 0 && gaatt >= bredde,
  }
}
