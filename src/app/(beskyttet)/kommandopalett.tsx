'use client'
import { useEffect, useRef, useState } from 'react'
import { useRouter } from 'next/navigation'
import { spørAssistent } from './assistent/handlinger'

// =====================================================================
// Én inngang til alt. Brukeren skal ikke måtte vite hvilken modul svaret
// ligger i — «hvorfor falt mat?» og «finn regnskap for juni» er samme
// slags spørsmål for den som spør, selv om det ene er en analyse og det
// andre er en side.
//
// Ingen ny backend: spørsmål går til spørAssistent, som allerede driver
// AI-boblen. Dette er et raskere inngangspunkt til samme motor.
// =====================================================================

type Punkt = { sti: string; tekst: string; gruppe: string }

const FORSLAG = [
  'Hvordan gikk vi forrige uke?',
  'Hva bør jeg prioritere denne uken?',
  'Hvorfor falt mat?',
]

export function Kommandopalett({ punkter }: { punkter: Punkt[] }) {
  const [apen, setApen] = useState(false)
  const [tekst, setTekst] = useState('')
  const [svar, setSvar] = useState<string | null>(null)
  const [venter, setVenter] = useState(false)
  const [valgt, setValgt] = useState(0)
  const felt = useRef<HTMLInputElement>(null)
  const router = useRouter()

  // Nullstillingen hører hjemme i lukkingen, ikke i en effekt som reagerer
  // på at noe ble lukket — da kjører den også ved første montering.
  function lukk() {
    setApen(false); setTekst(''); setSvar(null); setValgt(0)
  }

  useEffect(() => {
    const ned = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault()
        setApen((a) => {
          if (a) { setTekst(''); setSvar(null); setValgt(0) }
          return !a
        })
      }
      if (e.key === 'Escape') lukk()
    }
    window.addEventListener('keydown', ned)
    return () => window.removeEventListener('keydown', ned)
  }, [])

  useEffect(() => {
    if (apen) felt.current?.focus()
  }, [apen])

  const sok = tekst.trim().toLowerCase()
  const treff = sok
    ? punkter.filter((p) => p.tekst.toLowerCase().includes(sok) || p.gruppe.toLowerCase().includes(sok)).slice(0, 6)
    : punkter.slice(0, 6)
  // Et spørsmål har som regel flere ord enn et sidenavn, eller et spørsmålstegn.
  const kanSpørre = sok.length > 0 && (sok.includes('?') || sok.split(/\s+/).length >= 3)
  const rader = kanSpørre ? treff.length + 1 : treff.length

  async function spør(sporsmal: string) {
    setVenter(true)
    setSvar(null)
    try {
      const res = await spørAssistent([], sporsmal)
      setSvar(res.svar)
    } catch {
      setSvar('Fikk ikke svar akkurat nå. Prøv igjen, eller åpne assistenten.')
    } finally {
      setVenter(false)
    }
  }

  function velg(i: number) {
    if (kanSpørre && i === 0) { void spør(tekst.trim()); return }
    const p = treff[kanSpørre ? i - 1 : i]
    if (!p) return
    lukk()
    router.push(p.sti)
  }

  return (
    <>
      <button className="sq-sokknapp" onClick={() => setApen(true)} type="button">
        <svg width="14" height="14" viewBox="0 0 16 16" fill="none" aria-hidden="true">
          <circle cx="7" cy="7" r="4.5" stroke="currentColor" strokeWidth="1.5" />
          <path d="M10.5 10.5 14 14" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
        </svg>
        <span>Spør Sentiqa eller finn noe…</span>
        <kbd>⌘K</kbd>
      </button>

      {apen && (
        <div className="sq-dim" onClick={(e) => { if (e.target === e.currentTarget) lukk() }}>
          <div className="sq-palett" role="dialog" aria-modal="true" aria-label="Spør Sentiqa eller finn noe">
            <div className="sq-palett-felt">
              <svg width="15" height="15" viewBox="0 0 16 16" fill="none" aria-hidden="true">
                <circle cx="7" cy="7" r="4.5" stroke="currentColor" strokeWidth="1.5" />
                <path d="M10.5 10.5 14 14" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
              </svg>
              <input
                ref={felt}
                value={tekst}
                placeholder="Spør Sentiqa eller finn noe…"
                autoComplete="off"
                onChange={(e) => { setTekst(e.target.value); setValgt(0); setSvar(null) }}
                onKeyDown={(e) => {
                  if (e.key === 'ArrowDown') { e.preventDefault(); setValgt((v) => Math.min(v + 1, rader - 1)) }
                  if (e.key === 'ArrowUp') { e.preventDefault(); setValgt((v) => Math.max(v - 1, 0)) }
                  if (e.key === 'Enter') { e.preventDefault(); velg(valgt) }
                }}
              />
              {venter && <span className="sq-merkelapp">Tenker …</span>}
            </div>

            {svar ? (
              <div className="sq-palett-svar">
                <p>{svar}</p>
                <button type="button" className="sq-knapp" onClick={() => { setSvar(null); felt.current?.focus() }}>
                  Spør om noe annet
                </button>
              </div>
            ) : (
              <ul className="sq-palett-liste">
                {kanSpørre && (
                  <li data-valgt={valgt === 0} onMouseEnter={() => setValgt(0)} onClick={() => velg(0)}>
                    <span>Spør Sentiqa: «{tekst.trim()}»</span>
                    <span className="sq-k">Svar</span>
                  </li>
                )}
                {treff.map((p, i) => {
                  const idx = kanSpørre ? i + 1 : i
                  return (
                    <li key={p.sti} data-valgt={valgt === idx} onMouseEnter={() => setValgt(idx)} onClick={() => velg(idx)}>
                      <span>{p.tekst}</span>
                      <span className="sq-k">{p.gruppe || 'Gå til'}</span>
                    </li>
                  )
                })}
                {treff.length === 0 && !kanSpørre && (
                  <li className="sq-tom"><span>Ingen treff. Skriv et helt spørsmål for å spørre Sentiqa.</span></li>
                )}
              </ul>
            )}

            {!tekst && !svar && (
              <div className="sq-palett-forslag">
                {FORSLAG.map((f) => (
                  <button key={f} type="button" onClick={() => { setTekst(f); void spør(f) }}>{f}</button>
                ))}
              </div>
            )}
          </div>
        </div>
      )}
    </>
  )
}
