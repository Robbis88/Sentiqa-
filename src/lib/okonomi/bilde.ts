// =====================================================================
// ØKONOMIBILDET: ÉN SAMMENSTILLER, INGEN NY MOTOR
// =====================================================================
//
// `/regnskap`, `/lonnskost` og `/timeregnskap` leser de samme tabellene
// med hver sin spørring. Skal kildemerking på i tre flater, blir det tre
// regler for hva «prognose» betyr — og da har vi tre sannheter om hvor
// sikkert et tall er.
//
// Denne fila VELGER kilde, kaller motorene, merker feltene og setter
// dekningen. Den regner ingenting.
//
// ---------------------------------------------------------------------
// INGEN ARITMETIKK. BOKSTAVELIG TALT.
// ---------------------------------------------------------------------
//
// `bildevakt.test.ts` leser denne fila og feller enhver `+`, `-`, `*`
// eller `/` utenfor kommentarer og strenger. Regelen er hard med vilje:
// en myk regel om «ingen ØKONOMISK aritmetikk» måtte tolkes hver gang,
// og da flytter beregningene seg hit én linje om gangen til fila er den
// nye økonomimotoren.
//
// Trenger noe å regnes, hører det i en domenemotor med egne tester —
// `rom.ts`, `royalty.ts`, `mot-budsjett.ts`, `kastvurdering.ts`.
//
// ---------------------------------------------------------------------
// TRE LOVER
// ---------------------------------------------------------------------
//
//   1  FASIT OVERSTYRER ALLTID. Finnes tallet i regnskapet, er det det
//      som gjelder. Et anslag ved siden av fasiten er bare støy.
//
//   2  ET FELT KAN IKKE VÆRE TO KILDER. Et avledet tall arver den
//      SVAKESTE av kildene det bygger på. `styringsavvik` av et anslått
//      rom er et anslag, uansett hvor sikkert lønnstallet er.
//
//   3  KILDEN FØLGER MED UT. Flaten skal aldri utlede den selv.
//
// ---------------------------------------------------------------------
// HVA SOM IKKE ER MED, OG HVORFOR
// ---------------------------------------------------------------------
//
//   resultat    Det krever `brutto − royalty − lønn − drift − faste`,
//               altså domenearitmetikk. Den hører i en egen ren
//               funksjon, og den er E10. Å legge feltet inn her nå —
//               alltid `mangler` — ville invitert noen til å fylle det.
//
//   royalty     Med, men FASIT-ONLY. Å anslå den ville krevd
//               `omsetning × sats`, og det er en multiplikasjon.
//               `royalty.ts` eier den regningen.
// =====================================================================

import { styringsavvik, type Lonnsrom, type Styringsavvik } from '@/lib/lonnskost/rom'
import type { Brukerrolle } from '@/lib/auth/typer'

/**
 * Hvor sikkert ett tall er.
 *
 * `plan` er BP-ens eget tall. Det er ikke et anslag på hva som skjer —
 * det er hva noen bestemte at skulle skje, og derfor SVAKERE enn en
 * prognose når spørsmålet er «hva ble det».
 */
export type Kilde = 'mangler' | 'plan' | 'prognose' | 'fasit'

/** Svakest først. Rekkefølgen ER regelen i lov 2. */
const STYRKE: readonly Kilde[] = ['mangler', 'plan', 'prognose', 'fasit'] as const

/**
 * Den svakeste av to kilder.
 *
 * LOV 2. Uten den ville et avledet tall arvet den sterkeste, og et
 * anslag ville stått merket som fasit fordi ett av leddene var det.
 */
export function svakeste(a: Kilde, b: Kilde): Kilde {
  return STYRKE[Math.min(STYRKE.indexOf(a), STYRKE.indexOf(b))]
}

export type Felt = {
  verdi: number | null
  kilde: Kilde
  /** Hvorfor tallet mangler, eller hva anslaget bygger på. */
  grunn?: string
}

export type Avviksfelt = {
  avvik: Styringsavvik
  kilde: Kilde
}

/**
 * Hva som faktisk var kommet inn da bildet ble bygget.
 *
 * `retningPaaFeil` er det viktigste feltet her. En manglende bilvaskuke
 * gjør bruttoanslaget for LAVT og dermed lønnsrommet for stramt — og da
 * er et varsel strengere enn virkeligheten. Det er en helt annen beskjed
 * enn «tallet er usikkert».
 */
export type Dekning = {
  salgsdager: { har: number; av: number }
  bilvaskUker: { har: number; av: number }
  lonnsfil: boolean
  regnskap: boolean
  /** Klartekst, til flaten. «bilvask uke 39». */
  mangler: readonly string[]
  retningPaaFeil: 'for_lavt' | 'for_hoyt' | 'ukjent'
}

/**
 * Hva regnskapet har for måneden. `null` når den ikke er avlagt.
 *
 * FELTENE ER DE SAMMENSTILLEREN TRENGER, ikke hele regnskapet.
 * `regnskap-tilgang.ts` avgjør hvilke KONTOER som utgjør hver av dem;
 * her kommer de ferdig summert.
 */
export type Regnskapstall = {
  omsetningKr: number | null
  bruttoKr: number | null
  lonnKr: number | null
  royaltyKr: number | null
  paavirkbarDriftKr: number | null
}

export type Bildeinput = {
  stasjonId: string
  maaned: string
  /** Fra `byggLonnsrom`. Bærer selv om bruttoen er anslått. */
  rom: Lonnsrom
  regnskap: Regnskapstall | null
  /** Anslaget fra easy@work, med manuell fastlønn lagt til. */
  easyatworkLonnKr: number | null
  /** Løpende omsetning fra `v_butikksalg`. */
  dagligOmsetningKr: number | null
  dekning: Dekning
}

export type Sikkerhet = 'hoy' | 'middels' | 'lav'

export type Okonomibilde = {
  stasjonId: string
  maaned: string
  omsetning: Felt
  brutto: Felt
  /** BP-ens lønnstall. ALLTID `plan` — det er hele poenget med det. */
  bpLonn: Felt
  lonnsrom: Felt
  lonn: Felt
  styringsavvik: Avviksfelt
  royalty: Felt
  paavirkbarDrift: Felt
  dekning: Dekning
  sikkerhet: Sikkerhet
}

const mangler = (grunn: string): Felt => ({ verdi: null, kilde: 'mangler', grunn })

/** Kilden til bruttoen, som lønnsrommet arver. */
function bruttokilde(rom: Lonnsrom): Kilde {
  if (rom.bruttoKr === null) return 'mangler'
  return rom.anslaatt ? 'prognose' : 'fasit'
}

/**
 * Bildet for én stasjon i én måned.
 *
 * TAR FERDIG HENTEDE DATA. Ingen IO her: da kan hver regel prøves med
 * en fikstur, og flaten bestemmer selv hvordan den henter. Samme form
 * som `byggLonnsrom`.
 */
export function byggOkonomibilde(inn: Bildeinput): Okonomibilde {
  const { rom, regnskap } = inn

  // --- OMSETNING. Fasit slår daglig, lov 1. --------------------------
  const omsetning: Felt =
    regnskap?.omsetningKr != null
      ? { verdi: regnskap.omsetningKr, kilde: 'fasit' }
      : inn.dagligOmsetningKr != null
        ? { verdi: inn.dagligOmsetningKr, kilde: 'prognose', grunn: 'Daglige salgsfiler, ikke avstemt.' }
        : mangler('Ingen salgsdata for måneden.')

  // --- BRUTTO. `byggLonnsrom` har alt valgt fasit over anslag. -------
  const bk = bruttokilde(rom)
  const brutto: Felt =
    rom.bruttoKr === null
      ? mangler('Verken regnskap eller nok grunnlag til et anslag.')
      : {
        verdi: rom.bruttoKr,
        kilde: bk,
        grunn: rom.anslaatt ? 'BP-brutto skalert med faktisk omsetning og kalibrering.' : undefined,
      }

  // --- BP-LØNNA. Alltid plan. Den skrives aldri om. ------------------
  const bpLonn: Felt =
    rom.bpLonnKr === null
      ? mangler('BP mangler for måneden.')
      : { verdi: rom.bpLonnKr, kilde: 'plan' }

  // --- ROMMET. Arver bruttoens kilde, for det er brutto det er. ------
  const lonnsrom: Felt =
    rom.romKr === null
      ? mangler('Uten BP finnes det ikke noe rom.')
      : { verdi: rom.romKr, kilde: bk, grunn: 'Lønnsandel fra BP, ganget med faktisk brutto.' }

  // --- LØNNA. Fasit slår easy@work. ---------------------------------
  const lonn: Felt =
    regnskap?.lonnKr != null
      ? { verdi: regnskap.lonnKr, kilde: 'fasit' }
      : inn.easyatworkLonnKr != null
        ? {
          verdi: inn.easyatworkLonnKr,
          kilde: 'prognose',
          grunn: 'easy@work med manuell fastlønn. Mangler refundert sykelønn og bonus.',
        }
        : mangler('Lønnsfila er ikke kommet.')

  // --- AVVIKET. LOV 2: svakeste kilde vinner. ------------------------
  //
  // `styringsavvik` er E2 sin, og den kalles — den gjentas ikke. At
  // rommet er anslått gjør avviket til et anslag, uansett hvor sikkert
  // lønnstallet er.
  const styringsfelt: Avviksfelt = {
    avvik: styringsavvik(rom, lonn.verdi),
    kilde: svakeste(lonnsrom.kilde, lonn.kilde),
  }

  // --- ROYALTY. FASIT-ONLY, og det er en datagrense. -----------------
  //
  // Å anslå den ville krevd `omsetning × sats`. Den regningen bor i
  // `royalty.ts`; her leses bare det regnskapet har ført.
  const royalty: Felt =
    regnskap?.royaltyKr != null
      ? { verdi: regnskap.royaltyKr, kilde: 'fasit' }
      : mangler('Royalty leses av regnskapet. Ingen tidlig kilde.')

  // --- PÅVIRKBAR DRIFT. Ingen faktura før regnskapet. ----------------
  const paavirkbarDrift: Felt =
    regnskap?.paavirkbarDriftKr != null
      ? { verdi: regnskap.paavirkbarDriftKr, kilde: 'fasit' }
      : mangler('Ingen leverandørfaktura leses før regnskapet.')

  return {
    stasjonId: inn.stasjonId,
    maaned: inn.maaned,
    omsetning,
    brutto,
    bpLonn,
    lonnsrom,
    lonn,
    styringsavvik: styringsfelt,
    royalty,
    paavirkbarDrift,
    dekning: inn.dekning,
    sikkerhet: sikkerhetsgrad([omsetning, brutto, lonn, royalty, paavirkbarDrift]),
  }
}

/**
 * Hvor sikkert bildet er, som ett ord.
 *
 * Tre trinn og ingen terskel: alt fasit er `hoy`, ingenting fasit er
 * `lav`, blandet er `middels`. En prosentgrense her ville vært et tall
 * ingen kunne begrunnet — og bildet skal si hvor sikkert det er, ikke
 * hvor sikkert det er på en skala noen fant på.
 */
export function sikkerhetsgrad(felter: readonly Felt[]): Sikkerhet {
  if (felter.every((f) => f.kilde === 'fasit')) return 'hoy'
  if (felter.some((f) => f.kilde === 'fasit')) return 'middels'
  return 'lav'
}

/**
 * Bildet slik rollen skal se det.
 *
 * ERGONOMI, IKKE SIKKERHET. RLS avgjør hva som i det hele tatt kommer ut
 * av basen — `0192` gjorde `regnskap-tilgang.ts` sine lister til en
 * RLS-grense. Denne funksjonen sørger for at et tall butikksjefen ikke
 * skal forholde seg til heller ikke STÅR der, selv om det skulle ha
 * fulgt med. Samme skille som `ai/assistent.ts` skriver ut:
 * tilgangsregelen er ikke en sikkerhetsgrense.
 *
 * Royalty er eierens. Det er en kjedeavtale butikksjefen verken
 * forhandler eller påvirker — et tall uten en handling.
 */
export function skjermFor(rolle: Brukerrolle, bilde: Okonomibilde): Okonomibilde {
  if (rolle !== 'butikksjef') return bilde
  const skjermet: Felt = { verdi: null, kilde: 'mangler', grunn: 'Royalty er eierens linje.' }
  return {
    ...bilde,
    royalty: skjermet,
    sikkerhet: sikkerhetsgrad([
      bilde.omsetning, bilde.brutto, bilde.lonn, skjermet, bilde.paavirkbarDrift,
    ]),
  }
}
