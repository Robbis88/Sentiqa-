'use client'
import { useState, useTransition } from 'react'
import { Knapp } from '@/components/ui/knapp'
import { sendProveTilMegSelv } from './handlinger'

// =====================================================================
// «Send til meg selv».
//
// Den eneste veien til en ekte e-post fra denne siden, og den kan bare
// treffe deg. Adressen ligger i sesjonen på serveren og sendes ikke med
// herfra — se `handlinger.ts`.
//
// Ingen `router.refresh()`: ingenting på siden endret seg av å sende en
// e-post. En revalidering ville bare gjort ventetiden lengre og testene
// flakete, slik `useKvittering`-runden viste.
// =====================================================================

export function ProveKnapp({ stasjonId, uke }: { stasjonId: string; uke: string }) {
  const [venter, start] = useTransition()
  const [melding, setMelding] = useState<string | null>(null)

  return (
    <div className="sq-sidehode-handlinger">
      <Knapp
        onClick={() => start(async () => {
          setMelding(null)
          const r = await sendProveTilMegSelv(stasjonId, uke)
          // To utfall, to svar. «Sendt» uten adressen er ikke en kvittering
          // — du vet ikke hvilken innboks du skal se i.
          setMelding(r.ok ? `Sendt til ${r.til}. Emnet er merket [Prøve].` : `Ikke sendt: ${r.feil}`)
        })}
        disabled={venter}
      >
        {venter ? 'Sender …' : 'Send til meg selv'}
      </Knapp>
      {melding && <span className="undertittel">{melding}</span>}
    </div>
  )
}
