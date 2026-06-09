'use client'
import { useEffect } from 'react'
import confetti from 'canvas-confetti'

// Skyter konfetti når en vakt er 100 %. Throttlet pr nøkkel (én gang per
// vakt/dag) via sessionStorage, så den ikke spammer ved auto-refresh.
export function Konfetti({ aktiv, nokkel }: { aktiv: boolean; nokkel: string }) {
  useEffect(() => {
    if (!aktiv) return
    const k = `konfetti-${nokkel}`
    try {
      if (sessionStorage.getItem(k)) return
      sessionStorage.setItem(k, '1')
    } catch {
      // ingen sessionStorage → bare kjør
    }
    confetti({ particleCount: 130, spread: 75, origin: { y: 0.6 } })
    setTimeout(() => confetti({ particleCount: 80, spread: 100, origin: { y: 0.5 } }), 250)
  }, [aktiv, nokkel])
  return null
}
