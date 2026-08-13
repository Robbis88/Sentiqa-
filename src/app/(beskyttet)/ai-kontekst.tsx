'use client'
import { useState } from 'react'
import { spørAssistent } from './assistent/handlinger'

// =====================================================================
// AI der spørsmålet oppstår, i stedet for én boble som må fortelles hvor
// den er. Knappen bærer sitt eget spørsmål — brukeren slipper å formulere
// «forklar utviklingen i salget for meg» når hen allerede står på salg.
//
// Samme motor som boblen og kommandopaletten. Svaret vises under knappen
// og forsvinner ikke før man lukker det.
// =====================================================================
export function AiKontekst({ tekst, sporsmal }: { tekst: string; sporsmal: string }) {
  const [svar, setSvar] = useState<string | null>(null)
  const [venter, setVenter] = useState(false)

  async function spor() {
    setVenter(true)
    setSvar(null)
    try {
      const res = await spørAssistent([], sporsmal)
      setSvar(res.svar)
    } catch {
      setSvar('Fikk ikke svar akkurat nå. Prøv igjen om litt.')
    } finally {
      setVenter(false)
    }
  }

  return (
    <div className="sq-aikontekst">
      <button type="button" onClick={() => void spor()} disabled={venter}>
        <span aria-hidden="true">✦</span> {venter ? 'Tenker …' : tekst}
      </button>
      {svar && (
        <div className="sq-aisvar">
          <p>{svar}</p>
          <button type="button" className="sq-knapp" onClick={() => setSvar(null)}>Lukk</button>
        </div>
      )}
    </div>
  )
}
