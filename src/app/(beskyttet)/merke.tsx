import Image from 'next/image'
import Link from 'next/link'
import logo from '../../../public/sentiqa-logo.png'

// =====================================================================
// Ordmerket.
//
// FILA, IKKE CSS. Merket var satt som tekst i systemfonten med en
// gradient over — altså en rekonstruksjon av logoen, ikke logoen.
// Bokstavformene i sentiqa-logoen er ikke systemfontens, og et ordmerke
// som er nesten riktig er verre enn ingen: det leser som en billig kopi.
//
// Ingen effekter. Ingen glød, ingen gradient, ingen skygge. Logoen er
// visuell fasit slik den er.
// =====================================================================

export function Merke({ href = '/oversikt' }: { href?: string }) {
  return (
    <Link href={href} className="merke" aria-label="Sentiqa — til forsiden">
      <Image
        src={logo}
        alt="Sentiqa"
        // Høyden styrer; bredden følger av forholdet i fila, som ikke
        // skal røres.
        height={26}
        priority
        sizes="150px"
      />
    </Link>
  )
}
