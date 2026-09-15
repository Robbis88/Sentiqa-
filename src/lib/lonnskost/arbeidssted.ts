// Konto 503 per FAKTISK arbeidsstasjon.
//
// =====================================================================
// HVA DENNE LØSER
//
// Daglig lønnskost kan ikke se hvor arbeidet skjedde. Basis Export kan.
// Her møtes de: Basis Export bestemmer hvem som jobbet hvor og hvor
// mange betalte timer det ble, lønnsgrunnlaget gir timesatsen, og
// `tilleggsfordeling` + `tilleggssats` gjør timene om til kroner.
//
// MÅLT mot Lønnsoversikt (kronefila) over fem stasjonsmåneder:
//
//     Bønes juli 2026     -0,058 %
//     Bønes aug  2026     -0,830 %
//     Dale  mai  2026     -0,195 %
//     Dale  juli 2026     +1,045 %   (2 737 kr av det er én utdatert sats)
//     Dale  aug  2026     -2,284 %   (7 023 kr av det er overtid)
//     -----------------------------
//     SUM                 -0,402 %
//
// Dagens modell — bare stasjonens eget lønnsgrunnlag — bommet med
// -10,9 % på Bønes juli. `arbeidssted.test.ts` holder den feilen borte.
//
// ---------------------------------------------------------------------
// TRE TING SOM IKKE ER MED, OG SOM IKKE SKAL FYLLES MED NULL
//
//   OVERTID (96, 97)  Basis Export sier ikke hvilke timer som er
//                     overtid. Art 96 ser ut til å være «timer over 10
//                     på en dag» — 6 av 8 observasjoner — men 6 av 8 er
//                     ikke en regel. Art 97 avhenger av PLANLAGT vakt,
//                     som Basis Export ikke har i det hele tatt.
//   FASTLØNN (501)    finnes i ingen easy@work-eksport.
//   502/506/509       finnes heller ikke.
//
// De står i `ikkeMed` så de følger tallet ut i stedet for å bo i en
// fotnote. En ukjent kostnad er ikke null.
// =====================================================================

import type { Basisstempling, Lengdeavvik } from '@/lib/parsere/basiseksport'
import type { Ansattregister } from '@/lib/parsere/lonnsgrunnlag'
import { belopFor } from '@/lib/lonn/tilleggssats'
import { fordelVakt, TIMEART } from '@/lib/lonn/tilleggsfordeling'
import { koble } from '@/lib/lonn/identitet'

/**
 * Den delen av et register motoren faktisk leser.
 *
 * `Ansattregister` bærer også `utenSats` og `konflikter` — kjente
 * personer uten pris, og numre kilden sa to ting om. Motoren ser dem
 * IKKE, og det er et valg, ikke en forglemmelse: å koble dem inn endrer
 * hvilke timer som blir priset, og det er en egen beslutning med egne
 * målinger. Feltene er utelatt her så den dagen noen kobler dem på, må
 * de endre denne typen — og da står de foran valget i stedet for å gli
 * forbi det.
 */
export type Prisregister = Pick<Ansattregister, 'fraDato' | 'tilDato' | 'ansatte'>

/**
 * Er hver time vi KAN se, priset?
 *
 * `minimum` betyr at noe vi vet om ikke lot seg prise — en ukoblet
 * timelønnet, en tvetydig bro, eller en vakt parseren avviste. Da er
 * kostnaden høyere enn tallet, og lønnsrommet skal ikke regnes: et
 * ufullstendig grunnlag som vises som komplett er nettopp det som gir
 * butikksjefen et stort grønt rom han ikke har.
 *
 * ---------------------------------------------------------------------
 * `komplett` ER IKKE DET SAMME SOM «HELE LØNNSKOSTEN»
 *
 * Det som står i `ikkeMed` — overtid, fastlønn, 502/506/509 — mangler
 * ALLTID, for alle, og finnes ikke i noen easy@work-eksport. Lot vi det
 * gjøre grunnlaget til `minimum`, ville ingen måned noen gang vært
 * komplett, og skillet ville sluttet å bety noe. Da hadde vi hatt et
 * varsel som alltid lyser, altså ikke noe varsel.
 *
 * Skillet er derfor: `komplett` = «hver time denne kilden ser, er
 * priset». Hva kilden ikke ser, står i `ikkeMed` og følger tallet ut.
 * Flaten må vise begge — det ene svarer ikke på det andre.
 */
export type Datagrunnlag = 'komplett' | 'minimum'

export type UkobletAnsatt = {
  ansattNr: string
  ansattNavn: string
  /** Betalte timer vi VET om, men ikke kan prise. */
  timer: number
}

export type Artsum = { timer: number; belopKr: number }

export type Arbeidsstedskost = {
  /** Lokasjonen slik Basis Export skriver den, f.eks. «St1 - Bønes». */
  lokasjon: string
  maaned: string
  /** Konto 503: timelønn pluss alle tillegg vi kan utlede. */
  konto503Kr: number
  /** Betalte timer som faktisk ble priset. */
  timer: number
  perArt: Record<string, Artsum>
  /** Kroner for ansatte med en annen hovedlokasjon enn denne. */
  innlaantKr: number
  innlaanteNr: string[]
  /** Timer som med vilje ikke ble priset fordi noen har sagt «fastlønn». */
  fastlonnTimer: number
  /** Timelønnede vi ikke kunne koble. Tom liste er hele poenget. */
  ukoblede: UkobletAnsatt[]
  /**
   * Ansatte der BAADE nummeret og broas maal finnes i loennsgrunnlaget.
   * Da er broa gal, og vi kan ikke velge for noen.
   */
  tvetydige: UkobletAnsatt[]
  /**
   * Stemplinger som kom inn flere ganger og ble talt EN gang.
   *
   * Noekkelen er den samme som `stempling`-tabellens: stasjon, ansatt,
   * dato og starttid. Lastes samme fil to ganger, eller to filer med
   * overlappende perioder, ville loennskosten ellers doblet seg - og et
   * doblet tall ser ut som en dyr maaned, ikke som en feil.
   */
  dubletter: number
  /**
   * Vakter parseren ikke kunne lese - typisk en glemt utstempling.
   * De er ikke priset, og de gjor grunnlaget til et minimum.
   */
  uavklarteVakter: Lengdeavvik[]
  datagrunnlag: Datagrunnlag
  /** Hva som strukturelt ikke er med. Følger tallet ut. */
  ikkeMed: string[]
}

const IKKE_MED = [
  'overtid (lønnsart 96 og 97)',
  'fastlønn (konto 501)',
  'lønnstillegg, refundert sykelønn og bonus (502, 506, 509)',
] as const

const rund = (n: number): number => Math.round(n * 100) / 100

export type Inndata = {
  /** Maaneden som regnes, `yyyy-mm`. Alt utenfor den ses bort fra. */
  maaned: string
  stemplinger: readonly Basisstempling[]
  /**
   * Ett register per stasjon, hvert med sin egen periode.
   *
   * KASTER om et av dem ikke dekker `maaned`. Det er ikke pirk: satsen
   * hoerer til en person I EN MAANED, og et register fra feil maaned gir
   * feil kroner og et resultat som ser komplett ut.
   */
  registre: readonly Prisregister[]
  /** Numre et menneske har klassifisert som fastlønn. Aldri utledet. */
  fastlonnede?: ReadonlySet<string>
  /**
   * `avvik` fra `lesBasiseksport`. PAAKREVD.
   *
   * Var den valgfri, ville en kaller som glemte den faatt et tall som sa
   * `komplett` mens en uleselig vakt laa igjen i parseren. Tom liste maa
   * skrives, saa fravaeret er et valg og ikke en forglemmelse.
   */
  avvik: readonly Lengdeavvik[]
}

const MAANED = /^\d{4}-\d{2}$/

/**
 * Regner konto 503 per lokasjon og måned.
 *
 * MÅNEDEN ER FORRETNINGSDATOENS. En vakt som starter 1. august men
 * føres på 31. juli hører til juli — det er slik kronefila grupperer,
 * og de to må være enige for at målingen skal bety noe. Tillegget
 * regnes likevel av `fraDato`, så vakten får mandagens satser.
 */
export function beregnArbeidssted(inn: Inndata): Arbeidsstedskost[] {
  if (!MAANED.test(inn.maaned)) {
    throw new Error(`Ugyldig måned «${inn.maaned}». Forventet yyyy-mm.`)
  }
  if (!inn.registre.length) {
    throw new Error('Ingen lønnsgrunnlag. Uten sats kan ingen timer prises.')
  }
  for (const r of inn.registre) {
    // Perioden maa OMSLUTTE maaneden. En fil for april kan ikke prise
    // juli, og en fil for januar-juli kan.
    if (r.fraDato.slice(0, 7) > inn.maaned || r.tilDato.slice(0, 7) < inn.maaned) {
      throw new Error(
        `Lønnsgrunnlaget dekker ${r.fraDato} til ${r.tilDato} og kan ikke `
        + `prise ${inn.maaned}. Satsen hører til en måned, ikke til en person.`,
      )
    }
  }

  const register = new Map<string, (typeof inn.registre)[number]['ansatte'][number]>()
  for (const r of inn.registre) for (const a of r.ansatte) if (!register.has(a.ansattNr)) register.set(a.ansattNr, a)
  const finnes = (nr: string) => register.has(nr)
  const fastlonnede = inn.fastlonnede ?? new Set<string>()

  const grupper = new Map<string, Arbeidsstedskost>()
  // Ukoblede samles per gruppe, per ansatt — ikke per stempling. Ellers
  // ville én person med 20 vakter sett ut som 20 problemer.
  const ukobletPer = new Map<string, Map<string, UkobletAnsatt>>()
  const tvetydigPer = new Map<string, Map<string, UkobletAnsatt>>()
  // Samme noekkel som `stempling`-tabellens unike indeks (0088).
  const sett = new Set<string>()

  for (const s of inn.stemplinger) {
    if (s.dato.slice(0, 7) !== inn.maaned) continue
    // UBETALT TID OG PAUSE PRISES IKKE. De er ikke kostnad, og
    // `Lengde` på en pause ville lagt seg oppå timelønna som om den var
    // arbeid.
    if (!s.betalt) continue

    const maaned = s.dato.slice(0, 7)
    const noekkel = `${s.lokasjon}|${maaned}`
    let g = grupper.get(noekkel)
    if (!g) {
      g = {
        lokasjon: s.lokasjon,
        maaned,
        konto503Kr: 0,
        timer: 0,
        perArt: {},
        innlaantKr: 0,
        innlaanteNr: [],
        fastlonnTimer: 0,
        ukoblede: [],
        tvetydige: [],
        dubletter: 0,
        uavklarteVakter: [],
        datagrunnlag: 'komplett',
        ikkeMed: [...IKKE_MED],
      }
      grupper.set(noekkel, g)
      ukobletPer.set(noekkel, new Map())
      tvetydigPer.set(noekkel, new Map())
    }

    // DUBLETTVERN. Telles samme vakt to ganger, dobles kostnaden - og et
    // for hoeyt tall ser ut som en dyr maaned, ikke som en feil.
    //
    // NOEKKELEN ER STARTOEYEBLIKKET, IKKE FORRETNINGSDATOEN. Foerste
    // utgave brukte `dato` og aat ekte timer: 31. juli 2026 har to rader
    // for samme ansatt som BEGGE starter 00:00 - den ene er halen av
    // vakten fra 30. juli, den andre halen av vakten fra 31. juli, med
    // «1 august 2026 00:00» i `Fra`. De er to forskjellige arbeidsoekter.
    // Med forretningsdatoen som noekkel forsvant 0,93 timer, og avviket
    // for Dale juli gikk fra 1,045 % til 0,980 % - et tall som saa
    // BEDRE ut fordi data ble slettet.
    //
    // Merk at `stempling`-tabellens unike indeks (0088) har samme form
    // som den gale noekkelen. Den lagrer nettbrettdata, som ikke har
    // denne fasongen - men det er verdt aa vite naar Basis Export en
    // gang skal lagres der.
    const unik = `${s.lokasjon}|${s.ansattNr}|${s.fraDato}|${s.fraTid}`
    if (sett.has(unik)) { g.dubletter++; continue }
    sett.add(unik)

    const kobling = koble(s.ansattNr, finnes, fastlonnede)

    if (kobling.status === 'fastlonn') {
      // BEVISST IKKE PRISET. En fastlønnet som jobber på en annen
      // stasjon koster ikke den stasjonen noe på 503 — timene er
      // allerede betalt gjennom månedslønna et annet sted. Timene
      // telles likevel, for de er ekte arbeid og noen skal kunne se dem.
      g.fastlonnTimer = rund(g.fastlonnTimer + s.minutter / 60)
      continue
    }

    if (kobling.status === 'tvetydig') {
      // BROA ER GAL. Baade nummeret og maalet finnes; velger vi det ene,
      // kan timene bli priset med en annen persons sats.
      const kart = tvetydigPer.get(noekkel)!
      const f = kart.get(s.ansattNr)
      if (f) f.timer = rund(f.timer + s.minutter / 60)
      else kart.set(s.ansattNr, {
        ansattNr: s.ansattNr,
        ansattNavn: s.ansattNavn,
        timer: rund(s.minutter / 60),
      })
      g.datagrunnlag = 'minimum'
      continue
    }

    if (kobling.status === 'ukoblet') {
      // ALDRI STILLE BORTFALL. Uten broa ville 160 timer på Varden
      // blitt borte i et tall som så ferdig ut — nærmere 38 000 kroner.
      const kart = ukobletPer.get(noekkel)!
      const f = kart.get(s.ansattNr)
      if (f) f.timer = rund(f.timer + s.minutter / 60)
      else kart.set(s.ansattNr, {
        ansattNr: s.ansattNr,
        ansattNavn: s.ansattNavn,
        timer: rund(s.minutter / 60),
      })
      g.datagrunnlag = 'minimum'
      continue
    }

    const ansatt = register.get(kobling.lonnsnr)!
    // Tillegget regnes av datoen arbeidet BEGYNTE, ikke av
    // forretningsdatoen. Se `fordelVakt`.
    for (const [art, timer] of fordelVakt(s.fraDato, s.fraTid, s.minutter)) {
      const kr = belopFor(art, timer, ansatt.timesats)
      g.konto503Kr = rund(g.konto503Kr + kr)
      const sum = g.perArt[art] ?? { timer: 0, belopKr: 0 }
      sum.timer = rund(sum.timer + timer)
      sum.belopKr = rund(sum.belopKr + kr)
      g.perArt[art] = sum
      if (art === TIMEART) g.timer = rund(g.timer + timer)
      if (ansatt.hovedlokasjon && ansatt.hovedlokasjon !== s.lokasjon) {
        g.innlaantKr = rund(g.innlaantKr + kr)
        if (!g.innlaanteNr.includes(ansatt.ansattNr)) g.innlaanteNr.push(ansatt.ansattNr)
      }
    }
  }

  for (const [noekkel, g] of grupper) {
    g.ukoblede = [...ukobletPer.get(noekkel)!.values()]
      .sort((a, b) => b.timer - a.timer)
    g.tvetydige = [...tvetydigPer.get(noekkel)!.values()]
      .sort((a, b) => b.timer - a.timer)
    g.innlaanteNr.sort()
  }

  // EN ULESELIG VAKT ER OGSAA EN UKJENT KOSTNAD. Den skal slaa gjennom i
  // datagrunnlaget paa samme maate som en ukoblet ansatt - ellers ville
  // en glemt utstempling gjort tallet ufullstendig i stillhet.
  for (const a of inn.avvik) {
    if (a.dato.slice(0, 7) !== inn.maaned) continue
    const g = grupper.get(`${a.lokasjon}|${inn.maaned}`)
    // EN AVVIST RAD UTEN LOKASJON HOERER INGEN STEDER, og nettopp derfor
    // maa den ikke forsvinne. Finnes det ingen gruppe aa henge den paa,
    // henges den paa ALLE maanedens grupper - da kan ingen stasjon vise
    // et komplett tall mens timer ligger uplassert.
    if (!g) {
      for (const [, annen] of grupper) {
        if (annen.maaned !== inn.maaned) continue
        annen.uavklarteVakter.push(a)
        annen.datagrunnlag = 'minimum'
      }
      continue
    }
    g.uavklarteVakter.push(a)
    g.datagrunnlag = 'minimum'
  }

  return [...grupper.values()]
    .sort((a, b) => b.maaned.localeCompare(a.maaned) || a.lokasjon.localeCompare(b.lokasjon))
}
