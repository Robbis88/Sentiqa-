import { lesArk, arknavn, type Celleverdi } from './xlsx-rader'
import { ParserFeil } from './felles'
import { erDelingsfilArknavn } from './gjenkjenn'

// =====================================================================
// St1s DELINGSFIL — timebudsjettet som ikke står i BP-en
//
// St1 sender to filer per budsjettår: forretningsplanen og delingsfila.
// BP26-malen har et eget ark «Timebudsjett Grunnlagsfil», så der kommer
// timene med. DEN GAMLE MALEN HAR DEM IKKE.
//
// Timene finnes likevel — oppgitt, ikke utledet — i «Timer»-arkets
// kolonne `Timebudsjett`.
//
// ---------------------------------------------------------------------
// HVORFOR IKKE REGNE DEM UT
//
// Arket har byggeklossene også: grunnbemanning, stengte timer per døgn,
// fratrekk per år, fratrekk årsverk, mattillegg, tillegg annen omsetning.
// Første forsøk på å utlede timene traff Bønes eksakt (6 654) og bommet
// på Varden med 390 og Laguneparken med 2 913 — fordi `Tillegg annen oms`
// ikke var med i regnestykket.
//
// En utledet formel som bommer 22 % ser nøyaktig like riktig ut som en
// som treffer. Står tallet i fila, leses det.
//
// ---------------------------------------------------------------------
// BARE «Timer»-ARKET
//
// Fila har elleve ark til — Mat, Vask, Pølser, Bakeri, Pizza … — med
// budsjetterte kast- og bruttotall per varegruppe. De leses ikke her, og
// parseren later ikke som den kjenner dem.
//
// ---------------------------------------------------------------------
// FILA SIER IKKE HVILKET ÅR DEN GJELDER
//
// Ingen kolonne, ingen celle, ingenting i filnavnet. Men den oppgir
// `Budsjettert matomsetning` per stasjon, og det tallet står også i
// BP-en: Laguneparken 4 651 908 er BP 2025s Mat på krona. Året bestemmes
// derfor ved å matche mot budsjettet vi allerede har lagret — se
// `finnAaret` i `src/lib/bp/delingsfil-aar.ts`. Matcher ingen årgang,
// avvises fila. Å gjette ville lagt timene på feil år, og et timebudsjett
// på feil år er verre enn ingen.
// =====================================================================

export type Delingsrad = {
  /** Slik St1 skriver det: «SHELL LAGUNEPARKEN». */
  butikknavn: string
  /** Kolonne `Timebudsjett` — tallet vi er ute etter. */
  timebudsjett: number
  /** Kolonne `Budsjettert matomsetning`. Brukes til å finne året. */
  matomsetning: number
  /** Kolonne `Kost per time`. Til kontroll, ikke til beregning. */
  kostPerTime: number | null
  /** Kolonne `Kronebudsjett timer`. Samme. */
  kronebudsjett: number | null
}

export type Delingsfil = {
  rapporttype: 'st1_delingsfil'
  stasjoner: Delingsrad[]
  /** Kastbudsjett per stasjon og undergruppe. Tom hvis arkene mangler. */
  kastbudsjett: Kastbudsjett[]
}
// =====================================================================
// KASTBUDSJETTET — de andre arkene
//
// St1 setter et kastbudsjett per UNDERGRUPPE, og undergruppene er
// vareområdene under avdeling 120 MAT. Målt mot Kelsars egne filer
// 2026-09-05:
//
//     ark          vareområde i salgsdataene
//     Bakeri       10 BAKERI
//     Pølser       11 PØLSE
//     Hamburger    12 HAMBURGER
//     Pizza        13 PIZZA
//     Oppvarmet    14 OPPVARMET
//     Påsmurt      15 PÅSMURT
//
// Og de summerer: 83 663 + 119 577 + 38 857 + 2 433 + 12 256 + 119 290
// er 376 076 — nøyaktig «Kast budsjett KR» på Mat-arket, på krona.
//
// `21 FRUKT OG GRØNT` har ingen ark. Det forklarer at salget i
// undergruppene er 11 658 kr lavere enn Mat-totalen; kastbudsjettet er
// likevel likt, så St1 budsjetterer ikke kast på frukt.
//
// ---------------------------------------------------------------------
// ARKENE HAR ULIKE KOLONNER, OG DET ER IKKE EN FEIL
//
// `Bakeri` og `Dagligvare` har flere kolonner enn de andre. Derfor leses
// kolonnene på NAVN og aldri på posisjon — en indeks som stemmer på fem
// ark og bommer på det sjette ville gitt et budsjett som ser riktig ut.
//
// ---------------------------------------------------------------------
// «Mat» LESES IKKE SOM EN UNDERGRUPPE
//
// Det arket er totalen, og totalen er summen av de andre. Leste vi det
// også, ville hver krone telt to ganger.
// =====================================================================

/**
 * Ark → nivå og kode. Nøkkelen er arknavnet i småbokstaver.
 *
 * `Mat` er TOTALEN, ikke en undergruppe. Den leses fordi 2026-fila bare
 * har den — men den summeres aldri sammen med de seks andre, for den ER
 * summen av dem.
 */
export const KASTARK: Record<string, { nivaa: 'avdeling' | 'vareomrade'; kode: string; navn: string }> = {
  mat: { nivaa: 'avdeling', kode: '120', navn: 'MAT' },
  bakeri: { nivaa: 'vareomrade', kode: '10', navn: 'BAKERI' },
  'pølser': { nivaa: 'vareomrade', kode: '11', navn: 'PØLSE' },
  polser: { nivaa: 'vareomrade', kode: '11', navn: 'PØLSE' },
  hamburger: { nivaa: 'vareomrade', kode: '12', navn: 'HAMBURGER' },
  pizza: { nivaa: 'vareomrade', kode: '13', navn: 'PIZZA' },
  oppvarmet: { nivaa: 'vareomrade', kode: '14', navn: 'OPPVARMET' },
  'påsmurt': { nivaa: 'vareomrade', kode: '15', navn: 'PÅSMURT' },
  pasmurt: { nivaa: 'vareomrade', kode: '15', navn: 'PÅSMURT' },
}

export type Kastbudsjett = {
  butikknavn: string
  /** `avdeling` = Mat-totalen. `vareomrade` = én av de seks delene. */
  nivaa: 'avdeling' | 'vareomrade'
  /** `120` for totalen, ellers vareområdet: `11` for pølse. */
  kode: string
  navn: string
  /** `Budsjettert kast%` — andel av omsetning, ikke av kost. */
  kastPst: number
  /** `Kast budsjett KR` — ferdig utregnet av St1. */
  kastKr: number
  /** `Historisk salg`. Trengs for å se hva prosenten er regnet av. */
  historiskSalg: number | null
  /** `Budsjettert salg`. Brukes til å finne året når «Timer» mangler. */
  budsjettertSalg: number | null
  /** `Usynlig svinn` — bare den nyeste filvarianten oppgir det. */
  usynligKr: number | null
}


const ARK = 'Timer'

const tekst = (v: Celleverdi | undefined): string =>
  v === undefined || v === null ? '' : String(v).trim()
const tall = (v: Celleverdi | undefined): number | null =>
  typeof v === 'number' && Number.isFinite(v) ? v : null

/**
 * Kjenner igjen delingsfila på arknavnene.
 *
 * `Timer` alene er for tynt — ordet kan stå i hvilken som helst
 * arbeidsbok. Delingsfila har `Timer` SAMMEN MED varegruppearkene, og
 * det er kombinasjonen som skiller den.
 */
export function erDelingsfil(data: Uint8Array | ArrayBuffer): boolean {
  return erDelingsfilArknavn(arknavn(data).map((x) => x.toLowerCase()))
}

/**
 * Leser ett undergruppeark.
 *
 * Kolonnene finnes paa NAVN. Arkene har ulikt antall kolonner, og en
 * indeks som stemmer paa fem av dem ville gitt et budsjett som ser
 * riktig ut paa det sjette.
 */
function lesKastark(
  data: Uint8Array | ArrayBuffer,
  arkNavn: string,
  omrade: { nivaa: 'avdeling' | 'vareomrade'; kode: string; navn: string },
  ut: Kastbudsjett[],
): void {
  let kol: Map<string, number> | null = null
  let iNavn = 0, iPst = 0, iKr = 0, iSalg = 0, iBud = 0, iUsyn = 0

  lesArk(data, (n) => n.toLowerCase() === arkNavn, (rad) => {
    if (!kol) {
      const k = new Map<string, number>()
      for (const [nr, v] of rad.celler) {
        const navn = tekst(v).toLowerCase()
        if (navn && !k.has(navn)) k.set(navn, nr)
      }
      // Overskriftsraden er den som baerer «kast budsjett kr». Ligger det
      // en tittelrad over, hoppes den over av seg selv.
      if (!k.has('kast budsjett kr')) return
      kol = k
      // NAVNEKOLONNEN ER DEN LENGST TIL VENSTRE. «Butikknavn» er
      // bekreftelsen, ikke mekanismen.
      //
      // 2026-fila har `#REF!` i den cella - en broetet formelreferanse
      // St1 aldri ryddet. Navnene STAAR der (C8 = SHELL DALE); det er
      // bare overskriften som er borte. Med et rent navneoppslag ble
      // `iNavn` 0, hver rad falt paa `if (!butikknavn) return`, og hele
      // arket ble lest som tomt. Fila meldte da «fant verken timebudsjett
      // eller kastbudsjett» - sant om det parseren saa, usant om fila.
      //
      // Venstrest stemmer i begge variantene: 2025 har Butikknavn i A,
      // 2026 har navnene i C og bruksomraadet starter i C.
      iNavn = k.get('butikknavn') ?? Math.min(...rad.celler.keys())
      iPst = k.get('budsjettert kast%') ?? 0
      iKr = k.get('kast budsjett kr') ?? 0
      iSalg = k.get('historisk salg') ?? 0
      // 2026-fila kaller den «Budsjettert salg (inkl. volumvekst)»; navnet
      // varierer, saa den finnes paa prefiks. Tallet er det samme som
      // «Budsjettert matomsetning» paa Timer-arket - maalt paa Kelsars
      // filer: Laguneparken 4 651 908 i begge.
      for (const [navn, nr] of k) {
        if (!iBud && navn.startsWith('budsjettert salg')) iBud = nr
        if (!iUsyn && navn === 'usynlig svinn') iUsyn = nr
      }
      return
    }
    const butikknavn = tekst(rad.celler.get(iNavn))
    const kastKr = tall(rad.celler.get(iKr))
    const kastPst = iPst ? tall(rad.celler.get(iPst)) : null
    if (!butikknavn || kastKr === null || kastPst === null) return
    // Et kastbudsjett paa null er ikke et budsjett - det er en tom rad
    // eller en sumrad. Null ville betydd «ingenting maa kastes», som er
    // et krav ingen stasjon kan innfri.
    if (kastKr <= 0) return
    ut.push({
      butikknavn,
      nivaa: omrade.nivaa,
      kode: omrade.kode,
      navn: omrade.navn,
      kastPst,
      kastKr,
      historiskSalg: iSalg ? tall(rad.celler.get(iSalg)) : null,
      budsjettertSalg: iBud ? tall(rad.celler.get(iBud)) : null,
      usynligKr: iUsyn ? tall(rad.celler.get(iUsyn)) : null,
    })
  })
}

export function parseDelingsfil(data: Uint8Array | ArrayBuffer): Delingsfil {
  let kol: Map<string, number> | null = null
  let iNavn = 0, iTimer = 0, iMat = 0, iKost = 0, iKrone = 0
  const stasjoner: Delingsrad[] = []

  // ARKNAVNENE FOERST, OG BEGGE LESNINGENE SPOER DEM.
  //
  // `lesArk` KASTER naar arket ikke finnes - med vilje: et tomt resultat
  // og et fravaerende ark maa ikke se like ut. Men da maa den som vet at
  // arket er VALGFRITT, spoerre foerst.
  //
  // Kastarkene gjorde det. Timer-lesningen gjorde det ikke, og det var
  // hele feilen: 2026-fila har bare Mat og Vask, saa lesningen kastet
  // «Fant ikke arket. Arkene i fila er: Mat, Vask.» foer kastbudsjettet
  // under i det hele tatt ble forsoekt. Gjenkjenningen slapp fila inn
  // 2026-09-05; parseren fikk aldri den samme endringen.
  const finnes = new Set(arknavn(data).map((n) => n.toLowerCase()))

  if (finnes.has(ARK.toLowerCase())) lesArk(data, (n) => n.toLowerCase() === ARK.toLowerCase(), (rad) => {
    if (!kol) {
      const k = new Map<string, number>()
      for (const [nr, v] of rad.celler) {
        const navn = tekst(v).toLowerCase()
        if (navn && !k.has(navn)) k.set(navn, nr)
      }
      // Overskriftsraden er den som har `timebudsjett`. Skulle St1 legge
      // en tittelrad over, hoppes den over av seg selv.
      if (!k.has('timebudsjett')) return
      kol = k
      iNavn = k.get('butikknavn') ?? 0
      iTimer = k.get('timebudsjett') ?? 0
      iMat = k.get('budsjettert matomsetning') ?? 0
      iKost = k.get('kost per time') ?? 0
      iKrone = k.get('kronebudsjett timer') ?? 0
      if (!iNavn || !iTimer || !iMat) {
        throw new ParserFeil(
          'Delingsfil: «Timer»-arket mangler Butikknavn, Timebudsjett eller '
          + 'Budsjettert matomsetning.',
        )
      }
      return
    }

    const butikknavn = tekst(rad.celler.get(iNavn))
    const timebudsjett = tall(rad.celler.get(iTimer))
    const matomsetning = tall(rad.celler.get(iMat))
    if (!butikknavn || timebudsjett === null || matomsetning === null) return
    // 0 timer er ikke et budsjett — det er en rad uten innhold, eller en
    // sumrad. Et timebudsjett på null ville stengt en stasjon.
    if (timebudsjett <= 0) return

    stasjoner.push({
      butikknavn,
      timebudsjett,
      matomsetning,
      kostPerTime: iKost ? tall(rad.celler.get(iKost)) : null,
      kronebudsjett: iKrone ? tall(rad.celler.get(iKrone)) : null,
    })
  })

  // Kastbudsjettet er FRIVILLIG. Fila finnes i to varianter, og bare den
  // ene har undergruppearkene. Aa kaste her ville avvist et timebudsjett
  // som er helt i orden.
  const kastbudsjett: Kastbudsjett[] = []
  for (const [ark, omrade] of Object.entries(KASTARK)) {
    if (!finnes.has(ark)) continue
    lesKastark(data, ark, omrade, kastbudsjett)
  }

  // BEGGE ARKENE KAN MANGLE, MEN IKKE SAMTIDIG.
  //
  // 2026-fila har ingen «Timer», bare Mat og Vask - og den er fila for
  // aaret vi driver i. Et krav om timebudsjett ville avvist den.
  // Motsatt: 2025-fila har Timer og undergruppene.
  //
  // Er begge tomme, er det ikke en delingsfil vi kjenner igjen, og da
  // skal den si det - ikke lagre ingenting og melde «parset».
  if (stasjoner.length === 0 && kastbudsjett.length === 0) {
    throw new ParserFeil(
      'Delingsfil: fant verken timebudsjett i «Timer»-arket eller '
      + 'kastbudsjett i vareomraadearkene.',
    )
  }

  return { rapporttype: 'st1_delingsfil', stasjoner, kastbudsjett }
}
