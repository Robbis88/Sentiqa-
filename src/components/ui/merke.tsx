import Image from 'next/image'
import Link from 'next/link'

// =====================================================================
// Ordmerket.
//
// FILA, IKKE CSS. Merket var satt som tekst i systemfonten med en
// gradient over — altså en rekonstruksjon av logoen, ikke logoen.
// Bokstavformene i sentiqa-logoen er ikke systemfontens, og et ordmerke
// som er nesten riktig er verre enn ingen: det leser som en billig kopi.
//
// Ingen effekter. Ingen glød, gradient eller skygge. Logoen er visuell
// fasit slik den er.
//
// MIDLERTIDIG RESSURS. /sentiqa-logo.png er 348 kB med HVIT bakgrunn,
// ikke gjennomsiktig. Den fungerer i sidemenyen og på innloggingskortet
// fordi begge er hvite, men vil vise en hvit firkant på enhver annen
// flate — og nettbrettets mørke skall er en slik flate. Erstattes med
// SVG når vektorkilden finnes. Ikke behandle dette som designfasit.
// =====================================================================

/** Filas egne mål er 2172×724. Forholdet skal ikke røres. */
const HOYDE = 26
const BREDDE = 78

export function Merke({ href }: { href?: string }) {
  const bilde = (
    <Image
      src="/sentiqa-logo.png"
      alt="Sentiqa"
      width={BREDDE}
      height={HOYDE}
      priority
    />
  )

  // Uten href blir merket ren dekorasjon — riktig på innloggingssidene,
  // der det ikke finnes noe å navigere til ennå.
  return href
    ? <Link href={href} className="merke" aria-label="Sentiqa — til forsiden">{bilde}</Link>
    : <div className="merke">{bilde}</div>
}
