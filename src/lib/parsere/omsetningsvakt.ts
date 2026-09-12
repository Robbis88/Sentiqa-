import { ParserFeil } from './felles'
import { SKJUL_OMS_KODER } from '@/lib/avdelinger'

// =====================================================================
// DEN ANDRE KODELISTA — DEN SOM IKKE HAR NOEN EPOKE
// =====================================================================
//
// `kontoregister.ts` tok kostnadslinjene: der er paret (kode, navn)
// nøkkelen, og `0203` flyttet tilgangsgrensen over på begrepet, slik at
// filer fra før februar 2026 endelig kan importeres.
//
// **Men omsetningssiden har sin egen hardkodede kodeliste, og den ble
// aldri sjekket.** `SKJUL_OMS_KODER` i `avdelinger.ts` holder tre linjer
// utenfor butikksjefens tall:
//
//   10   Drivstoff — kommisjon/volum utenfor butikkdriften
//   250  Pant      — gjennomgang
//   40   CR        — St1-totalen, som ellers dobbelteller mot avdelingene
//
// Så lenge importen avviste alt før februar 2026, var lista trygg av
// flaks: den ble bare målt mot ett skjema. Nå slipper vi inn eldre filer,
// og da er spørsmålet reelt — **flyttet St1 omsetningslinjene også?**
//
// Konsekvensen av å ta feil er ikke liten. Drivstoff er ~68 % av
// omsetningen. Faller det ut av filteret, sammenlignes en butikk med
// drivstoff mot en uten, og forsiden viser vekst som ikke finnes. Det har
// skjedd i dette systemet før — «+216 %» i april 2026 — og det er
// grunnen til at `v_butikksalg` finnes.
//
// ---------------------------------------------------------------------
// VAKTEN GÅR BEGGE VEIER, OG DET ER DEN ANDRE SOM BETYR NOE
//
//   kjent kode + feil navn  →  koden betyr noe annet enn vi tror
//   kjent navn + feil kode  →  linja har flyttet seg, og filteret bommer
//
// Den andre er den farlige: da EKSISTERER drivstofflinja fortsatt, men på
// et nummer filteret ikke ser etter — så den blir stille inkludert.
//
// Sammenligningen er på HELE det normaliserte navnet, ikke på en del av
// det. Et delstrengstreff ville felt en varegruppe som tilfeldigvis heter
// noe med «pant», og en vakt som feller riktige filer blir skrudd av.
//
// RESTRISIKO, SKREVET NED: en linje som er BÅDE omdøpt og flyttet går
// forbi begge armene. Da fanges den ikke her, men av at tallene blir
// urimelige — se `import/rimelighet.ts`.
// =====================================================================

/** Navnene St1 bruker på linjene `SKJUL_OMS_KODER` holder utenfor. */
const SKJULTE_NAVN: Record<string, string> = {
  '10': 'drivstoff',
  '250': 'pant',
  '40': 'cr',
}

/** Små bokstaver, kode strippet, skilletegn til mellomrom. Som kontoregisteret. */
function normaliser(s: string): string {
  return s
    .toLowerCase()
    .replace(/^\s*\d+\s+/, '')
    .replace(/[^\wæøå]+/gu, ' ')
    .trim()
}

/**
 * Sjekker at en omsetningslinje står på det nummeret filteret tror.
 *
 * Kaster bare når kode og navn MOTSIER hverandre. En ukjent linje — en
 * vanlig varegruppe — går rett gjennom: det er ikke vår jobb å kjenne
 * hele kontoplanen, bare de tre linjene et filter hviler på.
 */
export function sjekkOmsetningslinje(kode: string | null, navn: string): void {
  if (!kode) return
  const n = normaliser(navn)
  if (!n) return

  const ventet = SKJULTE_NAVN[kode]
  if (ventet && n !== ventet) {
    throw new ParserFeil(
      `Regnskap: omsetningslinje ${kode} heter «${navn.trim()}», men ${kode} skal være ` +
        `«${ventet}». St1 har trolig flyttet omsetningslinjene. Filteret som holder ` +
        `drivstoff og pant utenfor butikksjefens tall bygger på disse numrene ` +
        `(SKJUL_OMS_KODER i src/lib/avdelinger.ts) — sjekk fila og oppdater lista ` +
        `før du importerer.`,
    )
  }

  const somHeterSlik = Object.entries(SKJULTE_NAVN).find(([, v]) => v === n)
  if (somHeterSlik && somHeterSlik[0] !== kode) {
    throw new ParserFeil(
      `Regnskap: «${navn.trim()}» står på kode ${kode}, men filteret leter etter den ` +
        `på ${somHeterSlik[0]}. Da ville den blitt regnet med i butikksjefens omsetning ` +
        `— drivstoff alene er ~68 % av den. Oppdater SKJUL_OMS_KODER i ` +
        `src/lib/avdelinger.ts før du importerer.`,
    )
  }
}

/** Kun for tester: at vakten faktisk dekker lista den er skrevet for. */
export function vokteteKoder(): string[] {
  return Object.keys(SKJULTE_NAVN).sort()
}

/** Kun for tester. */
export { SKJUL_OMS_KODER }
