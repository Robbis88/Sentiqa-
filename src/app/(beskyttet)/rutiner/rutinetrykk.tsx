'use client'
import { useRef, useState, type ReactNode } from 'react'
import { slippStyringssignal } from '@/lib/styringssignal'

/** Hele raden svarer straks, men krysses av først etter bekreftet lagring. */
export function RutineTrykk({ handling, felt, kropp, gjort, lagrerOrd, feilOrd }: {
  handling: (fd: FormData) => Promise<void>
  felt: ReactNode
  kropp: ReactNode
  gjort: boolean
  lagrerOrd: string
  feilOrd: string
}) {
  const sender = useRef(false)
  const [venter, setVenter] = useState(false)
  const [feil, setFeil] = useState(false)

  async function send(fd: FormData) {
    try { await handling(fd) }
    catch (e) {
      slippStyringssignal(e)
      setFeil(true)
    } finally {
      sender.current = false
      setVenter(false)
    }
  }

  return (
    <form action={send} className="tr-form" onSubmit={(e) => {
      if (sender.current) { e.preventDefault(); return }
      sender.current = true
      setVenter(true)
      setFeil(false)
    }}>
      {felt}
      <button type="submit" className="tr-trykk" disabled={venter} aria-label={gjort ? 'Fjern kryss' : 'Kryss av'}>
        {kropp}
      </button>
      {venter && <span className="tr-lagrer" role="status">{lagrerOrd}</span>}
      {feil && <p className="feil" role="alert">{feilOrd}</p>}
    </form>
  )
}
