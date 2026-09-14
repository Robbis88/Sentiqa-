'use client'
import { useActionState, useEffect, useRef, useState, useTransition } from 'react'
import { useRouter } from 'next/navigation'
import { Knapp, type Knappevariant } from './knapp'
import type { Kvittering } from '@/lib/kvittering'

// =====================================================================
// En knapp som svarer.
//
// Robert, 2026-08-22: «det er slette-knapper der, det er ikke noe som
// gir beskjed om at de er slettet».
//
// ÉN KOMPONENT, IKKE TJUE VARIANTER. Handlinger som endrer noe finnes
// 25 steder. Skrives kvitteringen på nytt hvert sted, blir den ulik
// hvert sted — og ett av dem blir glemt.
//
// FEILEN BLIR STÅENDE, KVITTERINGEN FORSVINNER IKKE AV SEG SELV. En
// bekreftelse som blinker bort er en bekreftelse man rekker å tvile på.
// Neste navigering fjerner den; det holder.
//
// ---------------------------------------------------------------------
// TRE TILSTANDER, OG DE ER TRE MED VILJE
// ---------------------------------------------------------------------
//
//   sender      handlingen er underveis          -> knappen er låst
//   resultat    serveren har svart               -> kvitteringen står
//   oppfrisker  visningen hentes på nytt         -> egen, stille melding
//
// Den tredje skal ALDRI holde den første åpen eller skjule den andre.
// Derfor kjører oppfriskningen i sin EGEN `useTransition`, ikke i
// handlingens. `venter` fra `useActionState` styrer knappen; `oppfrisker`
// styrer bare sin egen linje.
//
// ---------------------------------------------------------------------
// HVA SOM ER MÅLT, OG HVA SOM ER HYPOTESE
// ---------------------------------------------------------------------
//
// MÅLT, fra Playwright-sporet på `main` 2026-09-14 (PR #281):
//
//   0,95 s   POST /maanedsplan  (next-action)
//   1,45 s   200, x-action-revalidated: 1
//   2,14 s   siste nettverkshendelse i hele sporet
//   20,99 s  timeout — knappen fortsatt «Bygger …», ingen kvittering
//
// Altså: handlingen lyktes, revalideringen kjørte, nettverket var stille
// i 19 sekunder, og React committet aldri.
//
// IKKE MÅLT: at det var nettopp SAMSPILLET mellom den revalideringen og
// `router.refresh()` som holdt overgangen åpen. Sporet viser rekkefølge
// og stillhet, ikke årsak. At React entangler de to er en HYPOTESE — og
// den er sterk, men den er uprøvd til denne endringen har stått en tid
// uten at feilen kommer tilbake.
//
// Derfor gjøres to ting, ikke én:
//
//   1  Revalideringen fjernes, så handlingens overgang ikke lenger kan
//      inneholde en ruteroppdatering (`oppfriskvakt.test.ts`).
//   2  Komponenten gjøres robust UANSETT hva som holder oppfriskningen
//      åpen — den kan ikke lenger ta kvitteringen med seg.
//
// Punkt 2 står på egne ben. Er hypotesen feil, er den fortsatt riktig.
//
// FIRE EGENSKAPER SOM MÅ HOLDE:
//
//   OPT-IN      `oppfrisk` er `false` som standard, så de 25 eksisterende
//               kallstedene er uendret.
//   BARE VED OK En feilet handling skal ikke friske opp sida som om den
//               lyktes. `tilstand.feil` gir ingen refresh.
//   ÉN GANG     `sist`-referansen holder på objektet vi allerede har
//               frisket opp for, så en re-render ikke starter en ny runde.
//   ALDRI FATAL `router.refresh()` står i try/catch. Kastet den før, døde
//               effekten og kvitteringen forsvant med den.
//
// ---------------------------------------------------------------------
// `try/catch` DEKKER ET SYNKRONT KAST — INGENTING MER
// ---------------------------------------------------------------------
//
// `router.refresh()` returnerer `void`. Det finnes ingen promise å
// awaite og ingen feil å fange hvis hentingen feiler eller blir
// stående. `catch` fanger bare at KALLET selv kaster synkront.
//
// Det er to forskjellige tilfeller, og de håndteres av to forskjellige
// mekanismer:
//
//   KASTER SYNKRONT   `catch` → `kastet` med én gang.
//   HENGER / FEILER   usynlig for oss. Fanges av TIDEN i stedet:
//                     `oppfrisker` står i transitionen til den er ferdig,
//                     og blir den stående i 10 sekunder → `froset`.
//
// Den andre hvilte på en antakelse om Next: at `router.refresh()` inne i
// `startTransition` holder `isPending` sann til RSC-hentingen er ferdig.
// Den er nå MÅLT, i CI på `82bdc59`, med RSC-svarene holdt åpne:
//
//   kvittering 159 ms · knapp aktiv 165 ms · 5 av 5 RSC-kall åpne
//   advarsel 10 589 ms · alle RSC ferdige 11 454 ms
//
// Antakelsen holder: advarselen fyrte, og den fyrte mens hentingen
// faktisk hang. Samme måling avdekket at den ble stående etterpå — se
// blokka om de to flaggene lenger ned.
//
// ---------------------------------------------------------------------
// LÅSEN MOT DOBBELTKLIKK ER SYNKRON, IKKE EN RENDER-EGENSKAP
// ---------------------------------------------------------------------
//
// `disabled={venter}` settes ved NESTE render. Et dobbeltklikk rekker
// inn før den. Den gamle e2e-testen het «dobbeltklikk gir én kjøring»,
// men målte bare at knappen på et tidspunkt var `disabled` — den kunne
// ikke se to kjøringer. `sender`-referansen settes i `onSubmit`, i samme
// tikk som klikket, og er derfor den eneste låsen som faktisk holder.
// =====================================================================

export type { Kvittering }

export function HandlingKnapp({
  handling,
  felt,
  merke,
  hva,
  arbeider,
  bekreftelse = 'Utført',
  variant = 'sekundaer',
  sporsmaal,
  oppfrisk = false,
}: {
  /** Serverhandling som tar (tilstand, formData) og svarer med tekst. */
  handling: (t: Kvittering, fd: FormData) => Promise<Kvittering>
  /** Skjulte felter. `{ id }` er det vanlige. */
  felt?: Record<string, string>
  merke: string
  /** Hva handlingen gjelder. Blir aria-label sammen med merket. */
  hva?: string
  /** Hva knappen sier mens den venter. «Sletter …» */
  arbeider?: string
  /** Hva som står etterpå når handlingen ikke svarer med egen tekst. */
  bekreftelse?: string
  variant?: Knappevariant
  /** Spørsmål i en bekreftelsesdialog. Kun for det som ikke kan angres. */
  sporsmaal?: string
  /**
   * Hent serverdataene for DENNE sida på nytt etter en vellykket
   * handling.
   *
   * Av som standard. Slås på der handlingen endrer noe som står på
   * samme side — og da skal serverhandlingen IKKE revalidere sin egen
   * rute. Se blokka øverst.
   */
  oppfrisk?: boolean
}) {
  const [tilstand, kjor, venter] =
    useActionState<Kvittering, FormData>(handling, undefined)

  const router = useRouter()
  // Objektet vi sist frisket opp for. Uten den ville hver re-render
  // etter refreshen utløst en ny refresh, i ring.
  const sist = useRef<Kvittering>(undefined)

  // OPPFRISKNINGEN HAR SIN EGEN OVERGANG. Den deler ikke pending med
  // handlingen, og kan derfor ikke holde knappen låst.
  const [oppfrisker, startOppfrisk] = useTransition()

  // ===================================================================
  // TO FLAGG, FORDI DE TO TILFELLENE HAR ULIK LEVETID
  // ===================================================================
  //
  //   `kastet`  `router.refresh()` kastet synkront. Oppfriskningen ble
  //             ALDRI gjennomført. Det blir den heller ikke av at
  //             `oppfrisker` går av — så advarselen skal bli stående til
  //             et nytt handlingssvar eller en navigering.
  //
  //   `froset`  10-sekunderstimeren løp ut mens hentingen pågikk. Den
  //             sier «dette tar for lang tid», ikke «dette skjedde
  //             aldri» — og fullfører hentingen, er påstanden ikke sann
  //             lenger og skal trekkes tilbake.
  //
  // Ett felles flagg kunne ikke skille dem. Målt i CI på `82bdc59`:
  // advarselen ble stående etter at alle fem RSC-kallene fullførte på
  // 11 454 ms, og sa «last sida på nytt» om en side som var oppdatert.
  // ===================================================================
  const [kastet, settKastet] = useState(false)
  const [froset, settFroset] = useState(false)

  // Har DENNE runden faktisk vært aktiv? Uten den ville effekten under
  // ryddet på førstegangsrenderen — der `oppfrisker` er `false` uten at
  // noen oppfriskning har skjedd — og et synkront kast som aldri rakk å
  // gjøre transitionen pending ville blitt visket bort med det samme.
  const rundeAktiv = useRef(false)

  // Synkron lås. Settes i `onSubmit`, nullstilles når handlingen er
  // ferdig — ikke når kvitteringen er lest.
  const sender = useRef(false)
  useEffect(() => { if (!venter) sender.current = false }, [venter])

  useEffect(() => {
    if (!oppfrisk) return
    if (!tilstand?.ok) return          // en feil skal ikke se ut som suksess
    if (sist.current === tilstand) return
    sist.current = tilstand
    // EN NY RUNDE BEGYNNER PÅ BLANKT ARK. Begge flaggene ryddes før
    // oppfriskningen starter, ikke etter.
    settKastet(false)
    settFroset(false)
    rundeAktiv.current = false
    startOppfrisk(() => {
      // KASTER DEN, ER HANDLINGEN LIKEVEL UTFØRT. Uten denne tok en
      // feilende refresh med seg hele effekten — og kvitteringen med den.
      try { router.refresh() } catch { settKastet(true) }
    })
  }, [oppfrisk, tilstand, router])

  // Blir oppfriskningen stående, sier vi det — i stedet for å la sida
  // vise gamle tall ved siden av en kvittering som sier at noe er endret.
  // Og fullfører den, trekker vi det tilbake.
  useEffect(() => {
    if (oppfrisker) {
      rundeAktiv.current = true
      const t = setTimeout(() => settFroset(true), 10_000)
      return () => clearTimeout(t)
    }
    // AKTIV -> FERDIG. Bare når en runde faktisk har vært aktiv: på
    // førstegangsrenderen er `oppfrisker` også `false`, og der skal
    // ingenting ryddes.
    if (!rundeAktiv.current) return
    rundeAktiv.current = false
    // BARE `froset`. `kastet` betyr at hentingen aldri ble gjennomført,
    // og det blir ikke sant av at transitionen er over.
    settFroset(false)
  }, [oppfrisker])

  return (
    <form
      action={kjor}
      className="sq-slett"
      // INERT. Ingen styling, ingen atferd, ingen semantikk for
      // hjelpemidler — den finnes bare for å gjøre transitionens
      // tilstand målbar utenfra.
      //
      // `aria-busy` ville vært fristende, men den er IKKE inert: den
      // forteller skjermlesere at regionen oppdateres, og da ville et
      // diagnostisk behov endret hva brukere faktisk opplever.
      //
      // Den finnes fordi `oppfrisker` ellers bare kan UTLEDES, og de to
      // tilfellene vi må skille ser like ut utenfra:
      //
      //   transitionen settler aldri   →  `oppfrisker` blir stående true
      //   flagget ryddes ikke          →  `oppfrisker` er false, men
      //                                   advarselen står likevel
      //
      // Målt på `a6df5cc`: advarselen forsvant på 4 ms i ett forsøk og
      // ALDRI innen 5 s i det neste — samme SHA. Uten dette attributtet
      // kan de to ikke skilles.
      data-oppfrisker={oppfrisker ? 'true' : 'false'}
      // BEKREFTELSEN MÅ STOPPE INNSENDINGEN, ikke bare spørre. Uten
      // `preventDefault` kjører handlingen uansett hva man svarer.
      //
      // Rekkefølgen er ikke tilfeldig: låsen sjekkes FØRST, og settes
      // SIST. Et avbrutt spørsmål skal ikke låse knappen for godt.
      onSubmit={(e) => {
        if (sender.current) { e.preventDefault(); return }
        if (sporsmaal && !window.confirm(sporsmaal)) { e.preventDefault(); return }
        sender.current = true
      }}
    >
      {Object.entries(felt ?? {}).map(([navn, verdi]) => (
        <input key={navn} type="hidden" name={navn} value={verdi} />
      ))}
      <Knapp
        type="submit"
        variant={variant}
        liten
        disabled={venter}
        aria-label={hva ? `${merke} ${hva}` : undefined}
      >
        {venter ? (arbeider ?? `${merke} …`) : merke}
      </Knapp>
      {tilstand?.feil && (
        <span className="sq-slett-feil" role="alert">{tilstand.feil}</span>
      )}
      {tilstand?.ok && (
        <span className="sq-slett-ok" role="status">
          {tilstand.ok === 'ok' ? bekreftelse : tilstand.ok}
        </span>
      )}
      {/*
        EGEN LINJE, VED SIDEN AV KVITTERINGEN — aldri i stedet for den.
        Handlingen er utført uansett hva som skjer med visningen.
      */}
      {(kastet || froset) && (
        <span className="sq-oppfrisk-feil" role="status">
          Visningen kunne ikke oppdateres. Handlingen er utført — last
          sida på nytt for å se den.
        </span>
      )}
    </form>
  )
}
