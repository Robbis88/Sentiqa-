'use client'
import { useActionState, useEffect, useRef } from 'react'
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
// `oppfrisk` — OPT-IN, OG DET ER HELE POENGET
// ---------------------------------------------------------------------
//
// En serverhandling må IKKE revalidere sin egen rute:
// `useActionState` holder `venter` sann gjennom hele overgangen, og en
// revalidering av egen rute gjør ruteroppdateringen til en del av den.
// Kvitteringen blir gissel for at sida skal tegne seg om — målt til 45
// sekunder på /stempling der serveren svarte på 190 ms. Regelen står i
// `kvitteringsvakt.test.ts`.
//
// Men å bare fjerne revalideringen etterlater sida med gamle
// serverdata til noen laster den manuelt. Derfor gjør KLIENTEN det, ETTER
// at svaret er kommet: `router.refresh()` henter serverkomponentene på
// nytt uten å nullstille klienttilstand — så kvitteringen blir stående.
//
// TRE EGENSKAPER SOM MÅ HOLDE:
//
//   OPT-IN     `oppfrisk` er `false` som standard, så de 25 eksisterende
//              kallstedene er uendret. Bare den som trenger det, slår
//              det på.
//   BARE VED OK En feilet handling skal ikke friske opp sida som om den
//              lyktes. `tilstand.feil` gir ingen refresh.
//   ÉN GANG    `useEffect` på `tilstand` ville kjørt på nytt ved hver
//              re-render. `sist`-referansen holder på objektet vi
//              allerede har frisket opp for.
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

  useEffect(() => {
    if (!oppfrisk) return
    if (!tilstand?.ok) return          // en feil skal ikke se ut som suksess
    if (sist.current === tilstand) return
    sist.current = tilstand
    router.refresh()
  }, [oppfrisk, tilstand, router])

  return (
    <form
      action={kjor}
      className="sq-slett"
      // BEKREFTELSEN MÅ STOPPE INNSENDINGEN, ikke bare spørre. Uten
      // `preventDefault` kjører handlingen uansett hva man svarer.
      onSubmit={(e) => {
        if (sporsmaal && !window.confirm(sporsmaal)) e.preventDefault()
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
    </form>
  )
}
