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

export function parseDelingsfil(data: Uint8Array | ArrayBuffer): Delingsfil {
  let kol: Map<string, number> | null = null
  let iNavn = 0, iTimer = 0, iMat = 0, iKost = 0, iKrone = 0
  const stasjoner: Delingsrad[] = []

  lesArk(data, (n) => n.toLowerCase() === ARK.toLowerCase(), (rad) => {
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

  if (stasjoner.length === 0) {
    throw new ParserFeil('Delingsfil: fant ingen stasjoner med timebudsjett i «Timer»-arket.')
  }
  return { rapporttype: 'st1_delingsfil', stasjoner }
}
