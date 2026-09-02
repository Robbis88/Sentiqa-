'use client'
import { useState, useTransition } from 'react'
import { useRouter } from 'next/navigation'
import { Knapp } from '@/components/ui/knapp'
import { settSkiftFraSats } from './handlinger'

// =====================================================================
// SYSTEMET GJØR TASTINGEN, LEDEREN TAR BESLUTNINGEN
//
// Timesatsen peker entydig på ordningen — ingen sats i tariffarket finnes
// i begge kolonnene. Men skiftordning er AVTALEFESTET (§ 2.7.1.1: enighet
// med tillitsvalgte, skiftplan fire uker i forveien), og feltet bestemmer
// overtidsgrensen. Utledet automatisk ville en feilført sats avgjort når
// overtid slår inn.
//
// Derfor en knapp, ikke en regel. Navnene står i tabellen over — den som
// trykker har sett hvem det gjelder.
// =====================================================================

export function SkiftFraSats(
  { stasjonId, antall }: { stasjonId: string; antall: number },
) {
  const [venter, start] = useTransition()
  const [melding, setMelding] = useState<string | null>(null)
  const router = useRouter()

  if (antall === 0) return null

  return (
    <div className="sq-sidehode-handlinger">
      <Knapp
        onClick={() => start(async () => {
          setMelding(null)
          const r = await settSkiftFraSats(stasjonId)
          // TRE UTFALL, TRE SVAR. «Lagret» på null endringer ser ut som
          // en handling som virket — samme feil som `bekreftLest` hadde.
          setMelding(
            !r.ok ? `Kunne ikke lagre: ${r.feil}`
              : r.endret === 0 ? 'Ingen å sette — alle har arbeidstid, eller satsen motsier feltet.'
                : `Satt arbeidstid for ${r.endret} ansatt${r.endret === 1 ? '' : 'e'}`
                  + `${r.hoppet > 0 ? `. ${r.hoppet} hoppet over — der motsier feltet satsen, og det må avgjøres av deg.` : '.'}`,
          )
          // Etter svaret, ikke i handlingen. Se `kvitteringsvakt.test.ts`.
          router.refresh()
        })}
        disabled={venter}
      >
        {venter ? 'Setter …' : `Sett arbeidstid for ${antall} etter satsen`}
      </Knapp>
      {melding && <span className="undertittel">{melding}</span>}
    </div>
  )
}
