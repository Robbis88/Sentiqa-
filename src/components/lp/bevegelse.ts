'use client'
import { useEffect, useRef, useState, useSyncExternalStore } from 'react'

// =====================================================================
// BEVEGELSEN, ETT STED
//
// Tre kroker som resten av sida deler. Å la hver seksjon lage sin egen
// IntersectionObserver ville gitt fem litt ulike terskler og fem litt
// ulike svar på `prefers-reduced-motion` — og den siste er ikke en
// detalj: en bruker som har bedt om ro skal få ro på HELE sida, ikke i
// fire av fem seksjoner.
//
// INGEN SYNKRON `setState` I EN EFFEKT. Regelen finnes fordi det gir
// kaskaderendringer, og den er lett å bryte her: «les media query, sett
// state» er den første formen man skriver. `useSyncExternalStore` er
// laget for nettopp dette — matchMedia ER en ekstern kilde.
// =====================================================================

const SPORSMAL = '(prefers-reduced-motion: reduce)'

function abonner(varsle: () => void) {
  const mq = window.matchMedia(SPORSMAL)
  mq.addEventListener('change', varsle)
  return () => mq.removeEventListener('change', varsle)
}

/**
 * Har brukeren bedt om mindre bevegelse?
 *
 * PÅ SERVEREN SVARER DEN NEI, og klienten retter med en gang den
 * hydrerer. Motsatt standard ville gitt en side som alltid er still i
 * første frame og så begynner å bevege seg — et hopp, ikke en overgang.
 */
export function useRolig(): boolean {
  return useSyncExternalStore(
    abonner,
    () => window.matchMedia(SPORSMAL).matches,
    () => false,
  )
}

/**
 * Sant når elementet har vært synlig én gang.
 *
 * ÉN GANG, IKKE HVER GANG. En animasjon som spilles om igjen hver gang
 * man scroller forbi, blir et blink man venter på i stedet for en
 * forklaring man leser.
 */
export function useSynlig<T extends HTMLElement>(terskel = 0.2) {
  const ref = useRef<T>(null)
  const [synlig, setSynlig] = useState(false)

  useEffect(() => {
    const el = ref.current
    if (!el) return
    const io = new IntersectionObserver((es) => {
      es.forEach((e) => {
        if (!e.isIntersecting) return
        // I en callback, ikke i effektkroppen — derfor ingen kaskade.
        setSynlig(true)
        io.disconnect()
      })
    }, { threshold: terskel })
    io.observe(el)
    return () => io.disconnect()
  }, [terskel])

  return { ref, synlig }
}

const nf = (des: number) =>
  new Intl.NumberFormat('nb-NO', { minimumFractionDigits: des, maximumFractionDigits: des })

/**
 * Teller opp til `til` når `start` blir sant.
 *
 * SLUTTVERDIEN ER HVILETILSTANDEN. Med `prefers-reduced-motion` — og
 * før observeren har sett elementet — står tallet ferdig. Et tall som
 * står på null til noen scroller, er et tall som ikke finnes i
 * thumbnailen, i en delt lenke, eller for den som leser raskt.
 */
export function useTeller(til: number, start: boolean, des = 0): string {
  const rolig = useRolig()
  const [v, setV] = useState(til)
  const kjort = useRef(false)

  useEffect(() => {
    if (!start || rolig || kjort.current) return
    kjort.current = true
    const t0 = performance.now()
    const varighet = 1100
    const steg = (naa: number) => {
      const p = Math.min(1, (naa - t0) / varighet)
      // Settes fra rAF, aldri synkront i effektkroppen.
      setV(til * (1 - (1 - p) ** 3))
      if (p < 1) requestAnimationFrame(steg)
    }
    requestAnimationFrame(steg)
  }, [start, rolig, til])

  return nf(des).format(v)
}
