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
// Ingen effekter. Ingen glød, ingen gradient, ingen skygge. Logoen er
// visuell fasit slik den er.
// =====================================================================

export function Merke({ href = '/oversikt' }: { href?: string }) {
  return (
    <Link href={href} className="merke" aria-label="Sentiqa — til forsiden">
      {/* Sti, ikke statisk import: `tsc` kjører før `next build` i CI, og
          da finnes ikke typedeklarasjonen for .png ennå. Lokalt passerte
          det fordi .next/ lå der fra sist. */}
      <Image
        src="/sentiqa-logo.png"
        alt="Sentiqa"
        // Målene er filas egne (2172×724), skalert. Forholdet skal ikke
        // røres — en logo som er strukket er en logo som er feil.
        width={78}
        height={26}
        priority
      />
    </Link>
  )
}
