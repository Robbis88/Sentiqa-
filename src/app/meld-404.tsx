'use client'

import { useEffect, useRef } from 'react'
import { usePathname } from 'next/navigation'

/**
 * Melder én 404 til kontrollrommet, fra klienten.
 *
 * Hvorfor klienten og ikke serveren? `not-found.tsx` får ingen props og har
 * ingen tilgang til stien som feilet (Next-dokumentasjonen: bruk `usePathname`
 * på klienten hvis du trenger den). Uten stien er hendelsen ubrukelig — du får
 * vite AT noe 404-et, ikke HVA.
 *
 * At meldingen skjer på klienten løser to ting til:
 *
 *  1. <Link> prefetcher detaljruter når de kommer i viewport. Ligger en slettet
 *     rad igjen i en liste, rendres not-found uten at noen har klikket. Den
 *     prefetchen henter bare RSC-payload — denne komponenten monteres aldri, og
 *     hendelsen uteblir. Det er riktig: ingen så en feil.
 *  2. Bots som ikke kjører JS melder ingenting. Referer-sjekken på serveren tok
 *     mesteparten av den støyen fra før; dette lukker resten.
 *
 * `/api/feil` holder på KONTROLLROM_KEY server-side og rate-limiter per IP.
 */
export default function Meld404({
  meld,
  referer,
}: {
  meld: boolean
  referer: string | null
}) {
  const sti = usePathname()
  const alleredeSendt = useRef(false)

  useEffect(() => {
    if (!meld || alleredeSendt.current) return
    // React kjører effekter to ganger i dev (StrictMode). Uten denne vakten
    // ville hver 404 blitt to hendelser lokalt.
    alleredeSendt.current = true

    void fetch('/api/feil', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        // Stien i tittelen gjør feeden skannbar: du ser med én gang om det er
        // samme døde lenke om og om igjen, eller mange ulike.
        tittel: `404 – ${sti}`,
        alvorlighet: 'warning',
        detaljer: { sti, referer },
      }),
      keepalive: true,
    }).catch(() => {})
  }, [meld, sti, referer])

  return null
}
