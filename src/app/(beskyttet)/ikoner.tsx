// =====================================================================
// Ikonene i fellesflaten.
//
// INGEN NY PAKKE. Prosjektet har allerede et strekspråk — kommandopaletten,
// sidemenyens pil og oppmerksomhetslista tegner alle med `currentColor`,
// 1,5–1,6 i strek og runde ender. Å dra inn et bibliotek for tre ikoner
// ville lagt til en avhengighet, en bundle og et andre formspråk ved
// siden av det som finnes.
//
// `currentColor` er poenget: ikonet arver fargen fra flaten det står i,
// så det virker både på den lyse toppstripen og på nettbrettets mørke
// skall uten en eneste ekstra regel. En emoji kan ikke det — den har
// sine egne farger, og de er ikke våre.
//
// aria-hidden på alle: teksten eller aria-label på knappen rundt sier
// hva den gjør. Et ikon som også annonserer seg selv leses to ganger.
// =====================================================================

type Props = { className?: string }

const felles = {
  width: 16,
  height: 16,
  viewBox: '0 0 16 16',
  fill: 'none',
  stroke: 'currentColor',
  strokeWidth: 1.5,
  strokeLinecap: 'round' as const,
  strokeLinejoin: 'round' as const,
  'aria-hidden': true,
}

/** Varsler. */
export function Bjelle({ className }: Props) {
  return (
    <svg {...felles} className={className}>
      <path d="M4 6.5a4 4 0 0 1 8 0c0 2.5.6 3.6 1.2 4.2.3.3.1.8-.3.8H3.1c-.4 0-.6-.5-.3-.8C3.4 10.1 4 9 4 6.5Z" />
      <path d="M6.5 13.5a1.7 1.7 0 0 0 3 0" />
    </svg>
  )
}

/** Sikkerhet og to-faktor. */
export function Laas({ className }: Props) {
  return (
    <svg {...felles} className={className}>
      <rect x="3" y="7" width="10" height="6.5" rx="1.5" />
      <path d="M5.5 7V5a2.5 2.5 0 0 1 5 0v2" />
    </svg>
  )
}

/** Åpner menyen på små skjermer. */
export function Meny({ className }: Props) {
  return (
    <svg {...felles} className={className}>
      <path d="M2.5 4.5h11M2.5 8h11M2.5 11.5h11" />
    </svg>
  )
}
