import type { InputHTMLAttributes, SelectHTMLAttributes, ReactNode } from 'react'
import { useId } from 'react'

// =====================================================================
// Felt og velger.
//
// ETIKETTEN ER PÅKREVD, ikke valgfri. Et felt uten etikett er den
// vanligste tilgjengelighetsfeilen i dette repoet, og den er alltid
// utilsiktet — man skriver en placeholder og tror det holder. Det gjør
// det ikke: placeholderen forsvinner idet man begynner å skrive, og da
// står feltet uten navn for både skjermleser og den som ble avbrutt
// midtveis.
//
// Skal etiketten ikke SES, sier man det (`skjultEtikett`). Da er det et
// valg, ikke en forglemmelse.
//
// FEIL KNYTTES TIL FELTET med aria-describedby og aria-invalid. En rød
// setning under et felt er usynlig for den som ikke ser den røde
// setningen.
//
// Høyden er felles med resten av systemet (`.felt`-reglene), så et
// skjema ikke blir en trapp.
// =====================================================================

type Delt = {
  etikett: string
  /** Skjuler etiketten visuelt, men ikke for skjermlesere. */
  skjultEtikett?: boolean
  /** Rolig hjelpetekst. Vises alltid — ikke bare når noe går galt. */
  hjelp?: string
  /** Feilmelding. Overstyrer hjelpeteksten når den finnes. */
  feil?: string
}

export function Felt({
  etikett, skjultEtikett, hjelp, feil, ...rest
}: Delt & InputHTMLAttributes<HTMLInputElement>) {
  const id = useId()
  const beskrivelse = feil ?? hjelp
  return (
    <label className="felt" htmlFor={id}>
      <span className={skjultEtikett ? 'sq-skjult' : undefined}>{etikett}</span>
      <input
        id={id}
        aria-describedby={beskrivelse ? `${id}-hjelp` : undefined}
        aria-invalid={feil ? true : undefined}
        {...rest}
      />
      {beskrivelse && (
        <span id={`${id}-hjelp`} className={feil ? 'feil' : 'undertittel sq-felthjelp'}>
          {beskrivelse}
        </span>
      )}
    </label>
  )
}

export function Velg({
  etikett, skjultEtikett, hjelp, feil, children, ...rest
}: Delt & SelectHTMLAttributes<HTMLSelectElement> & { children: ReactNode }) {
  const id = useId()
  const beskrivelse = feil ?? hjelp
  return (
    <label className="felt" htmlFor={id}>
      <span className={skjultEtikett ? 'sq-skjult' : undefined}>{etikett}</span>
      <select
        id={id}
        aria-describedby={beskrivelse ? `${id}-hjelp` : undefined}
        aria-invalid={feil ? true : undefined}
        {...rest}
      >
        {children}
      </select>
      {beskrivelse && (
        <span id={`${id}-hjelp`} className={feil ? 'feil' : 'undertittel sq-felthjelp'}>
          {beskrivelse}
        </span>
      )}
    </label>
  )
}
