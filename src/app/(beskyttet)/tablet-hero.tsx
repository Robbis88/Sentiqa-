'use client'
import { useEffect, useState } from 'react'
import { useT } from './oversett-kontekst'

// =====================================================================
// «God morgen, Alida — 08:14»
//
// STREAKEN STO HER OG STAAR NAA PAA «Vaar stasjon». Den er regnet av
// salg mot fjoraaret (`hentHjemData`), altsaa analyse — og Nivaa 1 skal
// svare paa hva hun skal gjore naa, ikke hvordan butikken ligger an.
// Den forsvant ikke: `VekstKort` viste det samme tallet rett under, saa
// den sto to ganger paa samme flate. Naa staar den ett sted.
// =====================================================================

function hilsen(time: number): string {
  if (time < 6) return 'God natt'
  if (time < 10) return 'God morgen'
  if (time < 14) return 'God formiddag'
  if (time < 18) return 'God ettermiddag'
  return 'God kveld'
}

export function TabletHero({ navn }: { navn?: string }) {
  const t = useT()
  const [tid, setTid] = useState('')
  const [hei, setHei] = useState('Hei')

  useEffect(() => {
    const oppdater = () => {
      const d = new Date()
      setTid(new Intl.DateTimeFormat('nb-NO', { timeZone: 'Europe/Oslo', hour: '2-digit', minute: '2-digit' }).format(d))
      const t = Number(new Intl.DateTimeFormat('en-GB', { timeZone: 'Europe/Oslo', hour: '2-digit', hour12: false }).format(d)) % 24
      setHei(hilsen(t))
    }
    const t0 = setTimeout(oppdater, 0) // deferr (ikke synkron setState i effect)
    const id = setInterval(oppdater, 20000)
    return () => {
      clearTimeout(t0)
      clearInterval(id)
    }
  }, [])

  return (
    <div className="tablet-hero">
      <div className="tablet-hero-tekst">
        <div className="tablet-hilsen">{t(hei)}{navn ? `, ${navn}` : ''}</div>
        <div className="tablet-klokke">{tid}</div>
      </div>
    </div>
  )
}
