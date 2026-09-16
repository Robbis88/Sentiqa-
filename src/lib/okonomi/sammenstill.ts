import 'server-only'
import type { SupabaseClient } from '@supabase/supabase-js'
import { maaVaereHele } from '@/lib/supabase/datobolker'
import { hentLonnskost, type Lonnsbilde } from '@/lib/lonnskost/hent'
import { easyatworkNiva } from '@/lib/lonnskost/easyatwork'
import type { Lonnsrom } from '@/lib/lonnskost/rom'
import type { Brukerrolle } from '@/lib/auth/typer'
import { byggOkonomibilde, skjermFor, type Bildeinput, type Okonomibilde } from './bilde'
import { avslutteteUkerIMaaned, byggDekning } from './dekning'
import { hentSalgsdager } from './hent'

// =====================================================================
// ÉN SAMMENSTILLING AV `Bildeinput`, IKKE ÉN PER FLATE
// =====================================================================
//
// Disse åtti linjene sto inne i `/lonnskost/page.tsx`. Det gikk bra så
// lenge den var eneste flate. «Min måned» er den andre, og to
// sammenstillinger ville vært to meninger om hvilken måned bildet
// gjelder, hvilke uker som er ventet, og når en kilde er fasit.
//
// Det er nøyaktig formen `bilde.ts` ble bygget for å unngå, ett nivå
// lenger ut: sammenstilleren løste det for kildemerkingen, men sto selv
// i en sidefil der neste flate måtte kopiere den.
//
// ---------------------------------------------------------------------
// HVA DENNE FILA GJØR, OG HVA DEN IKKE GJØR
// ---------------------------------------------------------------------
//
// Den HENTER og den VELGER MÅNED. Den regner ingen kroner, dømmer ingen
// kilde og setter ingen `Kilde` — alt det eier `byggOkonomibilde`.
//
// IO og valg er skilt med vilje: `hentBildegrunnlag` snakker med basen,
// `byggBildeinput` er ren. Da kan hver regel prøves med en fikstur, og
// `/lonnskost` slipper å hente det samme to ganger.
//
// ---------------------------------------------------------------------
// TRE FELT SOM /lonnskost LOT STÅ TOMME, OG HVORFOR DE FYLLES NÅ
// ---------------------------------------------------------------------
//
// Der sto `omsetningKr`, `royaltyKr` og `paavirkbarDriftKr` som `null`
// med begrunnelsen «de er ikke lønnsblokkens felt — blir de vist, må de
// HENTES, ikke antas». Det var riktig: et felt som står `mangler` fordi
// ingen koblet det, ser ut som et hull i dataene.
//
// «Min måned» viser dem, så de hentes. Lønnsblokken tegner dem fortsatt
// ikke, og den regner sin egen `sikkerhetsgrad` av nøyaktig de feltene
// den rendrer — så den ser ingen forskjell.
//
// ---------------------------------------------------------------------
// BRUTTO HENTES IKKE HER, OG DET ER MED VILJE
// ---------------------------------------------------------------------
//
// `Lonnsrom.bruttoKr` har alt valgt fasit over anslag, og `bilde.ts`
// leser kilden av `rom.anslaatt`. Hentet vi brutto en gang til fra
// `v_kurs_maanedstall` og sendte den inn som `regnskap.bruttoKr`, ville
// to tall svart på samme spørsmål — og det ene ville vunnet uten at noen
// hadde bestemt hvilket.
// =====================================================================

/**
 * Regnskapstallene lønnskjeden ikke henter selv.
 *
 * ALLE TRE ER `null` NÅR DE IKKE FINNES, aldri 0. En måned uten
 * royaltylinje og en måned med null kroner royalty er ikke det samme,
 * og `bilde.ts` skiller dem: `null` blir `mangler`.
 */
export type Fasittall = {
  omsetningKr: number | null
  paavirkbarDriftKr: number | null
  royaltyKr: number | null
}

export type Bildegrunnlag = {
  stasjonId: string
  lonnsbilde: Lonnsbilde
  /** `yyyy-mm` → dager med butikksalg. Fra `v_butikksalg_dag`. */
  salgsdager: Map<string, number>
  /** `yyyy-mm` → regnskapets tall. Bare måneder regnskapet har rader for. */
  fasit: Map<string, Fasittall>
}

/**
 * Taket på månedsradene fra `v_kurs_maanedstall`.
 *
 * Én rad per måned for ÉN stasjon. Tretten måneders vindu gir høyst
 * tretten. 60 er romslig nok til at et lovlig svar aldri treffer det, og
 * langt under `max_rows = 1000` — så `maaVaereHele` kan faktisk kaste.
 */
const TAK_MAANEDER = 60

/**
 * Taket på royaltylinjene.
 *
 * Én linje per måned i normaltilfellet. En reimport skriver ikke en rad
 * til (`slettet_tid` settes på den gamle), men taket står romslig
 * likevel: det skal oppdage avkorting, ikke begrense et gyldig svar.
 */
const TAK_ROYALTY = 120

/**
 * Alt bildet trenger, for én stasjon, tretten måneder bakover.
 *
 * STASJONEN FILTRERES I SPØRRINGEN, ikke etterpå. RLS gir butikksjefen
 * sine egne stasjoner og eieren kjeden; et valg her er en innsnevring av
 * det, aldri en utvidelse. Samme regel som `hentLonnskost`.
 */
export async function hentBildegrunnlag(
  supabase: SupabaseClient,
  stasjonId: string,
  fraOgMed: string,
): Promise<Bildegrunnlag> {
  const [lonnsbilde, salgsdager, maanedstall, royalty] = await Promise.all([
    hentLonnskost(supabase, stasjonId, fraOgMed),
    hentSalgsdager(supabase, stasjonId, fraOgMed),
    // OMSETNING OG PÅVIRKBAR DRIFT FRA `v_kurs_maanedstall` (0205).
    //
    // Viewet er stedet de to summeringene bor: omsetningen uten
    // drivstoff, pant og «40 CR», og driftskostnadene filtrert på
    // `begrep` og ikke på kode — St1 renummererte i februar 2026, og en
    // grense i tall viser leasing som renovasjon på hver eldre rad.
    //
    // Å summere dem her ville vært en tredje kopi av de samme listene.
    // `security_invoker = true`, så RLS gjelder som for en rå spørring.
    //
    // `linjer_lest` VELGES IKKE. Kolonnen kom i `0206`, forsvant i
    // `0213`–`0215` og kom tilbake i `0217`. De tre kolonnene under har
    // stått i hver eneste utgave siden `0205`.
    supabase
      .from('v_kurs_maanedstall')
      .select('maaned, omsetning_kr, paavirkbar_drift_kr')
      .eq('stasjon_id', stasjonId)
      .gte('maaned', fraOgMed)
      .limit(TAK_MAANEDER)
      .overrideTypes<{
        maaned: string; omsetning_kr: number | null; paavirkbar_drift_kr: number | null
      }[]>(),
    // ROYALTY: SMALT, OG PÅ BEGREP.
    //
    // Den ligger i `driftskostnader` som konto `622`, men koden er en
    // adresse og begrepet er identiteten (0203). `royalty` står IKKE i
    // `BUTIKKSJEF_DRIFT_BEGREP`, så policyen fra `0192` gir butikksjefen
    // null rader her — og `skjermFor` merker feltet `skjult` uansett.
    // De to er enige, og RLS er den som håndhever det.
    supabase
      .from('regnskapslinjer')
      .select('periode, regnskap')
      .eq('stasjon_id', stasjonId)
      .eq('seksjon', 'driftskostnader')
      .eq('begrep', 'royalty')
      .gte('periode', fraOgMed)
      .is('slettet_tid', null)
      .limit(TAK_ROYALTY)
      .overrideTypes<{ periode: string; regnskap: number | null }[]>(),
  ])

  // ET AVKORTET SVAR SER UT SOM EN LITEN STASJON (0090, 0166, 0175).
  // `maaVaereHele` kaster på feil OG på et svar som treffer taket — en
  // svelget feil ville gitt en tom map, og da ville hver måned stått
  // uten omsetning og uten royalty, som «mangler» på en stasjon der alt
  // er i orden.
  const maanedsrad = maaVaereHele(maanedstall, 'regnskapsmånedene', TAK_MAANEDER)
  const royaltyrad = maaVaereHele(royalty, 'royaltylinjene', TAK_ROYALTY)

  const fasit = new Map<string, Fasittall>()
  for (const r of maanedsrad) {
    fasit.set(r.maaned.slice(0, 7), {
      omsetningKr: tall(r.omsetning_kr),
      paavirkbarDriftKr: tall(r.paavirkbar_drift_kr),
      royaltyKr: null,
    })
  }
  for (const r of royaltyrad) {
    const n = r.periode.slice(0, 7)
    const f = fasit.get(n) ?? { omsetningKr: null, paavirkbarDriftKr: null, royaltyKr: null }
    // SUM, IKKE «SISTE VINNER». En måned skal ha én royaltylinje; får vi
    // to, er summen det ærlige svaret, og en stille overskriving ville
    // valgt en av dem uten å si hvilken.
    f.royaltyKr = (f.royaltyKr ?? 0) + (tall(r.regnskap) ?? 0)
    fasit.set(n, f)
  }

  return { stasjonId, lonnsbilde, salgsdager, fasit }
}

/** `null` blir `null`, ikke 0. Alt annet blir et tall. */
function tall(v: number | null | undefined): number | null {
  return typeof v === 'number' && Number.isFinite(v) ? v : null
}

/**
 * Månedene det faktisk finnes et bilde for, nyest først.
 *
 * =====================================================================
 * EN VELGER SKAL IKKE TILBY EN MÅNED SOM IKKE KAN VISES
 * =====================================================================
 *
 * Her sto `maanedsrader(maaneder, easyatwork, rom)` — unionen av
 * regnskapets måneder, easy@work sine og rommets. Målt mot produksjon
 * 2026-09-16 ga den seksten måneder per stasjon, til og med
 * **2026-12**: BP-en dekker hele året, så `byggLonnskost` skriver en rad
 * for hver budsjettmåned, også de som ikke har vært ennå.
 *
 * Velgeren tilbød altså oktober, november og desember, og hver av dem
 * endte i «Ingen ramme for desember 2026». Det er ikke farlig, men det
 * er en liste som lover noe den ikke har — og en liste man lærer å ikke
 * stole på, slutter man å bruke.
 *
 * ---------------------------------------------------------------------
 * SAMME PREDIKAT SOM `standardmaaned`, IKKE ET PARALLELT
 * ---------------------------------------------------------------------
 *
 * Lista og standardvalget leser nå nøyaktig samme regel. Sto de med hver
 * sin, kunne standardmåneden falt utenfor sin egen velger — og da ville
 * velgeren vist én måned mens siden viste en annen.
 *
 * ---------------------------------------------------------------------
 * UNIONEN ER IKKE GLEMT, DEN ER FLYTTET
 * ---------------------------------------------------------------------
 *
 * `maanedsrader` finnes fordi en måned med BARE en lønnsfil ikke skal bli
 * usynlig — Bønes august traff nettopp det. Den regelen lever videre på
 * /lonnskost, som er flaten der en slik måned skal ses.
 *
 * Her kan den ikke gjelde: `byggMaanedsbilde` gir `null` uten et rom, så
 * en måned uten rom har ikke noe bilde å vise uansett hva lista sier.
 * `vakt.test.ts` krever at HVER måned lista tilbyr faktisk rendrer.
 */
export function maanederMedBilde(grunnlag: Bildegrunnlag): string[] {
  return grunnlag.lonnsbilde.rom
    .filter(harRamme)
    .map((r) => r.maaned)
    .sort((a, b) => b.localeCompare(a))
}

/**
 * Har måneden en ramme å tegne et bilde av?
 *
 * Uten brutto OG uten rom finnes det verken et tall å vise eller en
 * grense å måle det mot. `standardmaaned` og `maanederMedBilde` deler
 * denne ene linja med vilje.
 */
const harRamme = (r: Lonnsrom): boolean => r.bruttoKr !== null || r.romKr !== null

/**
 * Måneden bildet står på når ingen har valgt en.
 *
 * NYESTE MÅNED MED ET ROM ELLER EN BRUTTO — ikke nyeste måned med en
 * lønnsfil. Det er nettopp måneden UTEN lønnsfil som har mest å
 * fortelle: «lønnsfila er ikke kommet», «tre salgsdager mangler». Bandt
 * vi bildet til lønnsfila, ville blokken forsvunnet i den tilstanden den
 * er bygget for.
 *
 * `rom` er sortert nyest først.
 */
export function standardmaaned(grunnlag: Bildegrunnlag): string | null {
  return maanederMedBilde(grunnlag)[0] ?? null
}

export type Maanedsbilde = {
  maaned: string
  rom: Lonnsrom
  /** Sant når regnskapet har lønnslinjer for måneden. */
  avlagt: boolean
  bilde: Okonomibilde
}

/**
 * Bildet for én måned, ferdig skjermet for rollen.
 *
 * REN. Ingen IO, ingen klokke som leses inne i funksjonen — `naa` er et
 * argument, slik `muligeSalgsdager` krever, fordi en regel som leser
 * klokka selv ikke kan prøves.
 *
 * `null` når måneden ikke har et rom. Uten brutto og uten BP finnes det
 * ikke noe bilde å tegne, og en tom `Okonomibilde` med `mangler` i hvert
 * felt ville sett ut som en stasjon der alt er borte.
 */
export function byggMaanedsbilde(
  grunnlag: Bildegrunnlag,
  opts: { maaned: string; rolle: Brukerrolle; naa: Date },
): Maanedsbilde | null {
  const { maaneder, easyatwork, rom, bilvaskUker } = grunnlag.lonnsbilde
  const valgtRom = rom.find((r) => r.maaned === opts.maaned)
  if (!valgtRom) return null

  const maanedslonn = maaneder.find((m) => m.maaned === opts.maaned)
  const avlagt = maanedslonn?.avlagt ?? false
  const ea = easyatwork.find((e) => e.maaned === opts.maaned)
  // SAMME SETT SOM TELLES, IKKE ET PARALLELT. Kallstedet må kunne avgjøre
  // hvilke REGISTRERTE uker som hører til måneden; en egen regel her
  // ville latt en måned få flere uker enn den ventet.
  const forventedeUker = avslutteteUkerIMaaned(opts.maaned, opts.naa)
  // FASITEN BRUKES BARE PÅ EN AVLAGT MÅNED, OG GATEN STÅR ÉTT STED.
  //
  // `v_kurs_maanedstall` har `coalesce(..., 0)` på hvert kronefelt, så en
  // rad som finnes av en annen grunn ville meldt null kroner omsetning og
  // null kroner påvirkbar drift som om det var målt. Raden finnes bare
  // når måneden har regnskapslinjer — men «har rader» og «er avlagt» er
  // to påstander, og det er den andre som gjør tallet til en fasit.
  //
  // Her sto `avlagt ? grunnlag.fasit.get(...) : undefined`. Den var en
  // ANDRE gate foran `regnskap:`-ternæren under, og derfor inert: en
  // injeksjon som fjernet den kom grønn tilbake, fordi den gate under
  // fortsatt holdt. To gater som ikke kan feile hver for seg ser ut som
  // to gater. Det er én, og den står ved `regnskap:`.
  const fasit = grunnlag.fasit.get(opts.maaned)

  const inn: Bildeinput = {
    stasjonId: grunnlag.stasjonId,
    maaned: opts.maaned,
    rom: valgtRom,
    regnskap: avlagt && maanedslonn
      ? {
        omsetningKr: fasit?.omsetningKr ?? null,
        // BRUTTO EIES AV `rom`. Se toppkommentaren.
        bruttoKr: null,
        lonnKr: maanedslonn.lonnskostKr,
        // ROMMET MÅLES MOT DENNE, IKKE MOT `lonnKr`. Se
        // `lonnskost/kostnadsniva.ts`.
        styringskostKr: maanedslonn.niva?.styringskostKr ?? null,
        royaltyKr: fasit?.royaltyKr ?? null,
        paavirkbarDriftKr: fasit?.paavirkbarDriftKr ?? null,
      }
      : null,
    easyatworkLonnKr: ea?.lonnskostKr ?? null,
    easyatworkStyringskostKr: ea ? easyatworkNiva(ea).styringskostKr : null,
    dagligOmsetningKr: valgtRom.omsetningKr,
    dekning: byggDekning({
      maaned: opts.maaned,
      salgsdagerHar: grunnlag.salgsdager.get(opts.maaned) ?? 0,
      bilvaskUkerHar: bilvaskUker
        .filter((u) => forventedeUker.has(`${u.ar}-${u.uke}`)).length,
      // ===============================================================
      // EN STASJON UTEN BILVASK VENTER INGEN BILVASKUKER
      // ===============================================================
      //
      // Uten dette leddet ville hver stasjon uten vaskehall stått med
      // «4 bilvaskuker mangler» hver eneste måned, for alltid — et
      // varsel ingen kan lukke, om en fil som aldri kommer.
      //
      // UTLEDET, IKKE KONFIGURERT. Har stasjonen noen gang registrert en
      // uke, har den bilvask. Det krever ingen ny innstilling i
      // onboarding. Prisen: en ny stasjon MED bilvask varsler ikke før
      // første uke er lagt inn — heller tie én gang enn å rope hver
      // måned.
      bilvaskUkerAv: bilvaskUker.length > 0 ? forventedeUker.size : null,
      lonnsfil: ea !== undefined,
      regnskap: avlagt,
      naa: opts.naa,
    }),
  }

  return {
    maaned: opts.maaned,
    rom: valgtRom,
    avlagt,
    // SKJERMINGEN ER ERGONOMI, IKKE SIKKERHET. RLS avgjør hva som kommer
    // ut av basen; denne sørger for at et tall butikksjefen ikke skal
    // forholde seg til heller ikke STÅR der. Royalty er eierens linje.
    bilde: skjermFor(opts.rolle, byggOkonomibilde(inn)),
  }
}
