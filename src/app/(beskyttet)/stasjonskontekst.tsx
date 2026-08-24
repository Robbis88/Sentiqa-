'use client'
import { useRef, useState } from 'react'
import { useSearchParams } from 'next/navigation'
import { useFormStatus } from 'react-dom'
import { settStasjon } from './stasjon-handlinger'
import { stasjonsnavn, type Stasjon } from '@/lib/stasjonsvalg'

// =====================================================================
// Stasjonsvelgeren, ett sted.
//
// Ti sider spurte om dette hver for seg. Butikksjefen med én stasjon
// svarte ti ganger og fikk aldri et annet svar — og eieren måtte velge
// på nytt for hver side han gikk til.
//
// Vises ikke i det hele tatt når det bare finnes ett alternativ. En
// nedtrekksliste med ett valg ber om en beslutning som ikke finnes.
//
// BYTTET MÅ SES, IKKE BARE SKJE. Robert, 2026-08-22: «klarer ikke å
// velge mellom stasjonene … må være noe som indikerer at du har byttet
// stasjon.»
//
// Den byttet faktisk — men flere sider navngir ikke stasjonen sin, så
// et vellykket bytte så ut som ingenting. Et valg som ikke kvitterer er
// et valg brukeren prøver på nytt, og til slutt slutter å stole på.
//
// Derfor en tilstand mens det står på, i et `aria-live`-område, så en
// skjermleser hører det samme som øyet ser.
//
// NAVNET STO OGSÅ DER PERMANENT, OG DET VAR EN FEIL — ikke fordi det var
// stygt, men fordi det kunne si noe annet enn velgeren.
//
// `<select>` hadde `defaultValue`, altså ukontrollert: verdien settes
// ÉN gang, ved montering. Ved myk navigering blir komponenten stående
// montert, og React rører aldri en ukontrollert select. Gikk brukeren
// via en lenke med `?stasjon=` — de finnes i /salg, /rutiner og
// nettbrettets IK-mat — vant URL-en i `velgStasjon`, siden hentet den
// nye stasjonens data, kvitteringen fulgte etter, og velgeren ble
// stående på det gamle valget.
//
// Skjermen viste Lone. Systemet mente Dale. Og velgeren, den som ser ut
// som fasiten, var den som løy.
//
// Hard omlasting remonterte og skjulte avviket — derfor var hver
// eksisterende e2e-test grønn gjennom hele feilen. De bruker `goto`.
//
// Nå er velgeren KONTROLLERT. Da kan DOM-en ikke bli stående på egen
// hånd, og kvitteringen kan bli det den var ment som: en forbigående
// beskjed, ikke en andre stasjonsvisning.
//
// MEN DET VAR IKKE NOK, og CI sa det (kjøring 32727545063, S6 fortsatt
// rød). Feilen stikker dypere enn DOM-verdien:
//
//   LAYOUTS RE-RENDERES IKKE VED MYK NAVIGERING. Next.js gir ikke
//   `searchParams` til en layout, og bytter man bare søkestrengen,
//   beholdes hele layouten. `kontekst.valgt` — som skallet får fra
//   serveren — er altså UTDATERT etter et klikk på `?stasjon=`.
//   Siden under re-renderes med den nye stasjonen; skallet gjør ikke.
//
// Prop-en alene kan derfor aldri være riktig. Velgeren må lese URL-en
// selv, på klienten, med NØYAKTIG samme forrang som `velgStasjon`
// bruker på serveren: URL, så hukommelse. Gjør den noe annet, har vi
// byttet én dobbel sannhet mot en ny.
// =====================================================================

/**
 * «Bytter …» mens handlingen står på.
 *
 * Egen komponent fordi `useFormStatus` bare leser status fra skjemaet
 * OVER seg. Ligger den i samme komponent som `<form>`, er den alltid
 * `false` — en felle som gir en indikator som ser riktig ut og aldri
 * lyser.
 */
function Kvittering({ navn }: { navn: string }) {
  const { pending } = useFormStatus()
  return (
    <span
      // Synlig KUN mens byttet står på. Er velgeren og konteksten
      // synkronisert, sier velgeren allerede alt — og en tekst som
      // gjentar den er i beste fall støy, i verste fall en andre
      // sannhet. Navnet blir liggende for skjermlesere, som ikke ser
      // at nedtrekkslisten endret seg.
      className={pending ? 'sq-stasjonssvar' : 'sq-skjult'}
      aria-live="polite"
    >
      {pending ? 'Bytter …' : navn}
    </span>
  )
}

export function Stasjonskontekst({
  stasjoner,
  valgt,
  tillatAlle,
}: {
  stasjoner: Stasjon[]
  /** null = alle stasjoner samlet. */
  valgt: string | null
  tillatAlle: boolean
}) {
  const ref = useRef<HTMLFormElement>(null)
  const sok = useSearchParams()

  // URL-en, lest paa klienten. Speiler `velgStasjon` og `stasjonFraUrl`:
  // begge parameternavnene godtas, ukjent verdi gir null (og da vinner
  // hukommelsen), og «alle» teller bare der sida taaler aggregat.
  const fraUrl = (() => {
    const eksplisitt = sok.get('stasjon')
    if (eksplisitt === 'alle') return tillatAlle ? 'alle' : null
    if (eksplisitt && stasjoner.some((x) => x.id === eksplisitt)) return eksplisitt
    const nr = sok.get('butikknummer')
    return (nr ? stasjoner.find((x) => x.butikknummer === nr)?.id : null) ?? null
  })()
  // Navnet vises fra det øyeblikket brukeren velger, ikke først når
  // serveren svarer. Ellers står det gamle navnet mens siden laster,
  // og det er nettopp da man lurer på om klikket gikk gjennom.
  const [nettoppValgt, settValgt] = useState<string | null>(null)
  // Nullstilles naar konteksten har endret seg utenfra - enten fordi
  // serveren leverte et nytt valg, ELLER fordi URL-en byttet stasjon.
  // Bare `valgt` her ville betydd at et klikk paa en `?stasjon=`-lenke
  // ikke naadde velgeren, siden layouten ikke re-renderes da.
  const utenfra = `${valgt ?? ''}|${fraUrl ?? ''}`
  const [sist, settSist] = useState(utenfra)
  if (sist !== utenfra) {
    settSist(utenfra)
    settValgt(null)
  }

  const navnFor = (id: string | null) => {
    if (id === null || id === 'alle') return 'Alle stasjoner'
    const s = stasjoner.find((x) => x.id === id)
    return s ? stasjonsnavn(s) : ''
  }

  const vist = nettoppValgt ?? fraUrl ?? valgt ?? (tillatAlle ? 'alle' : (stasjoner[0]?.id ?? ''))

  return (
    // KEY PAA FORMEN, IKKE PAA SELECTEN.
    //
    // CI leste ut at komponenten hadde riktig stasjon i baade prop og
    // URL - `kilde=url prop=5101 url=5101` - mens DOM-verdien sto paa
    // «alle» gjennom 34 pollinger. Verken `value` eller en `key` paa
    // `<select>` endret det.
    //
    // Selecten ligger i et `<form action={settStasjon}>`. React bevarer
    // skjematilstand gjennom en serverhandling - det er meningen, saa et
    // felt ikke nullstilles mens handlingen staar paa - og den
    // bevaringen gjelder skjemaet, ikke det enkelte feltet. En `key` paa
    // selecten roerer den derfor ikke.
    //
    // Naar konteksten endres utenfra, er det ikke lenger samme skjema.
    <form
      key={vist}
      action={settStasjon}
      ref={ref}
      className="sq-stasjonskontekst"
    >
      <label>
        {/* Etiketten er skjult visuelt, men ikke for skjermlesere: uten
            den er dette bare «kombinasjonsboks» i toppen av hver side. */}
        <span className="sq-skjult">Stasjon</span>
        {/* KONTROLLERT, ikke `defaultValue`. Se toppen av fila: en
            ukontrollert select kan bli staaende paa gammel verdi naar
            konteksten endres uten omlasting, og da viser skjermen én
            stasjon mens siden regner paa en annen. */}
        {/* KEY, IKKE BARE `value`.
            CI leste ut at komponenten hadde riktig stasjon i BAADE
            prop og URL - `kilde=url prop=5101 url=5101` - mens
            DOM-verdien sto paa «alle» gjennom 34 pollinger. Verdien
            naadde altsaa React, men ikke elementet.
            En `key` som foelger konteksten bygger `<select>` paa nytt
            naar stasjonen endres, og da finnes det ingen gammel
            DOM-tilstand aa bli staaende i. */}
        <select
          name="stasjon"
          // HVEM AVGJORDE. Uten dette er en roed S6 bare «velgeren sto
          // stille», og det kan bety at URL-en ikke naadde klienten,
          // at prop-en var utdatert, eller at et optimistisk valg
          // hang igjen. Attributtet blir staaende: det er tre linjer,
          // og det er forskjellen paa en test som peker og en som
          // gjetter.
          data-kilde={nettoppValgt ? 'valg' : fraUrl ? 'url' : valgt ? 'kapsel' : 'ingen'}
          data-prop={valgt ?? ''}
          data-url={fraUrl ?? ''}
          value={vist}
          onChange={(e) => {
            settValgt(e.target.value)
            ref.current?.requestSubmit()
          }}
        >
          {tillatAlle && <option value="alle">Alle stasjoner</option>}
          {stasjoner.map((s) => (
            <option key={s.id} value={s.id}>{stasjonsnavn(s)}</option>
          ))}
        </select>
      </label>
      <Kvittering navn={navnFor(nettoppValgt ?? fraUrl ?? valgt)} />
      {/* Uten JavaScript blir dette en vanlig knapp. Med, er den unødvendig. */}
      <noscript><button type="submit" className="liten">Bytt</button></noscript>
    </form>
  )
}
