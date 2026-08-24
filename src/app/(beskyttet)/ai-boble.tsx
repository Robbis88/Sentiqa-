'use client'
import { useState, useRef, useEffect } from 'react'
import { spørAssistent } from './assistent/handlinger'
import { slippStyringssignal } from '@/lib/styringssignal'
import { blokker, type Bit } from '@/lib/ai-tekst'
import type { Melding } from '@/lib/ai/assistent'

type Visning = Melding & { kilder?: string[] }

const FORSLAG = [
  'Hvor mye solgte vi sist?',
  'Hvordan ligger vi an mot budsjett?',
  'Hvilken stasjon har mest svinn?',
]
// SAMTALEN LAGRES PER BRUKER, IKKE PER DOMENE.
//
// Noekkelen var 'sentiqa-ai-samtale' for hele opprinnelsen. Logget man ut
// og inn som en annen i samme fane, laa forrige samtale igjen - og de
// siste ti meldingene sendes med hvert kall. En butikksjef fikk dermed
// eierens tidligere svar inn som modellens egen kontekst.
//
// Fant det i smoke-testen 2026-08-24: hun spurte «hvordan ligger lone
// an?», og avslaget kom tilbake som «4177 (St1 Lone) ligger utenfor
// tilgangen din». Nummeret og navnet sto ingen steder i verktoeyssvaret -
// de kom fra eierens samtale i samme fane. Ingen tall lekket, RLS holdt,
// men avslaget bekreftet en stasjon hun ikke skal vite noe om.
const LAGER_PREFIKS = 'sentiqa-ai-samtale'

/** Biter av én linje: vanlig tekst og uthevet, aldri HTML. */
function Biter({ biter }: { biter: Bit[] }) {
  return (
    <>
      {biter.map((b, i) =>
        b.type === 'uthevet' ? <strong key={i}>{b.verdi}</strong> : <span key={i}>{b.verdi}</span>,
      )}
    </>
  )
}

/**
 * Svaret, tegnet som avsnitt og lister.
 *
 * Sto som én `<p>` med rå markdown i. Se `ai-tekst.ts` for hvorfor det
 * ikke ble loest i promptet alene.
 */
function Svartekst({ tekst }: { tekst: string }) {
  const deler = blokker(tekst)
  if (deler.length === 0) return <p />
  return (
    <>
      {deler.map((b, i) =>
        b.type === 'liste' ? (
          <ul key={i} className="ai-liste">
            {b.punkter.map((p, j) => <li key={j}><Biter biter={p} /></li>)}
          </ul>
        ) : (
          <p key={i}><Biter biter={b.biter} /></p>
        ),
      )}
    </>
  )
}

export function AiBoble({ navn, brukerId }: { navn?: string; brukerId: string }) {
  const LAGER = `${LAGER_PREFIKS}:${brukerId}`
  const [apen, setApen] = useState(false)
  const [meldinger, setMeldinger] = useState<Visning[]>([])
  const [tekst, setTekst] = useState('')
  const [venter, setVenter] = useState(false)
  const [strommer, setStrommer] = useState(false)
  const bunn = useRef<HTMLDivElement>(null)
  const felt = useRef<HTMLInputElement>(null)
  const intervall = useRef<number | null>(null)

  // Hent lagret samtale (deferd, så vi ikke setter state synkront i effekt / bryter hydrering)
  useEffect(() => {
    let raw: string | null = null
    try {
      // Rydd bort samtaler lagret under den gamle, brukeruavhengige
      // noekkelen. Uten dette ligger de igjen til fanen lukkes.
      sessionStorage.removeItem(LAGER_PREFIKS)
      raw = sessionStorage.getItem(LAGER)
    } catch { /* */ }
    if (!raw) return
    try {
      const data = JSON.parse(raw) as Visning[]
      if (Array.isArray(data) && data.length) {
        const t = setTimeout(() => setMeldinger(data), 0)
        return () => clearTimeout(t)
      }
    } catch { /* */ }
  }, [LAGER])

  // Lagre samtalen (ikke midt i strømming)
  useEffect(() => {
    if (strommer) return
    try { sessionStorage.setItem(LAGER, JSON.stringify(meldinger)) } catch { /* */ }
  }, [meldinger, strommer, LAGER])

  useEffect(() => {
    if (apen) bunn.current?.scrollIntoView({ behavior: 'smooth' })
  }, [meldinger, venter, apen])

  useEffect(() => {
    if (apen) felt.current?.focus()
  }, [apen])

  useEffect(() => () => { if (intervall.current) clearInterval(intervall.current) }, [])

  // Åpnes også fra AI-inngangskortet på dashbordet (sentiqa-ai-open-event).
  useEffect(() => {
    const aapne = () => setApen(true)
    window.addEventListener('sentiqa-ai-open', aapne)
    return () => window.removeEventListener('sentiqa-ai-open', aapne)
  }, [])

  function strømUt(full: string, kilder?: string[]) {
    setMeldinger((f) => [...f, { rolle: 'assistent', tekst: '', kilder }])
    setStrommer(true)
    let i = 0
    const steg = Math.max(2, Math.ceil(full.length / 140)) // ferdig på ~2 sek uansett lengde
    if (intervall.current) clearInterval(intervall.current)
    intervall.current = window.setInterval(() => {
      i += steg
      setMeldinger((f) => {
        const k = [...f]
        k[k.length - 1] = { ...k[k.length - 1], tekst: full.slice(0, i) }
        return k
      })
      if (i >= full.length) {
        if (intervall.current) clearInterval(intervall.current)
        setMeldinger((f) => {
          const k = [...f]
          k[k.length - 1] = { ...k[k.length - 1], tekst: full }
          return k
        })
        setStrommer(false)
      }
    }, 16)
  }

  async function send(melding: string) {
    const m = melding.trim()
    if (!m || venter || strommer) return
    const historikk = meldinger.map(({ rolle, tekst }) => ({ rolle, tekst }))
    setMeldinger((f) => [...f, { rolle: 'bruker', tekst: m }])
    setTekst('')
    setVenter(true)
    try {
      const svar = await spørAssistent(historikk, m)
      setVenter(false)
      strømUt(svar.svar, svar.kilder)
    } catch (e) {
      // En utloept sesjon gir `redirect('/logg-inn')`, som kaster. Uten
      // denne linja ble innlogging til «Noe gikk galt», og brukeren satt
      // fast i en loekke der alt feilet og ingenting sa hvorfor.
      slippStyringssignal(e)
      setVenter(false)
      setMeldinger((f) => [...f, {
        rolle: 'assistent',
        tekst: 'Fikk ikke svar fra assistenten. Er du fortsatt logget inn? '
          + 'Last siden på nytt — spørsmålet ditt er i orden.',
      }])
    }
  }

  function nySamtale() {
    if (intervall.current) clearInterval(intervall.current)
    setStrommer(false)
    setMeldinger([])
    try { sessionStorage.removeItem(LAGER) } catch { /* */ }
    felt.current?.focus()
  }

  const hei = navn ? `Hei, ${navn}! 👋` : 'Hei! 👋'

  return (
    <>
      {apen && (
        <div className="ai-panel" role="dialog" aria-label="Sentiqa AI-assistent">
          <header className="ai-topp">
            <span className="ai-avatar">✨</span>
            <span className="ai-tittel-blokk">
              <span className="ai-tittel">Sentiqa AI-assistent</span>
              <span className="ai-und"><span className="ai-prikk" /> Tilkoblet · svarer fra dine tall</span>
            </span>
            {meldinger.length > 0 && (
              <button type="button" className="ai-ny" aria-label="Ny samtale" title="Ny samtale" onClick={nySamtale}>↺</button>
            )}
            <button type="button" className="ai-lukk" aria-label="Lukk" onClick={() => setApen(false)}>✕</button>
          </header>

          <div className="ai-logg">
            {meldinger.length === 0 && (
              <div className="ai-tom">
                <p>{hei}</p>
                <p>Spør meg om salget, svinnet eller regnskapet ditt — jeg svarer med tall fra dine egne data, og viser kildene.</p>
                <div className="forslag">
                  {FORSLAG.map((f) => (
                    <button key={f} type="button" onClick={() => send(f)} className="liten">{f}</button>
                  ))}
                </div>
              </div>
            )}
            {meldinger.map((m, i) => (
              <div key={i} className={`boble ${m.rolle} ${strommer && i === meldinger.length - 1 ? 'strommer' : ''}`}>
                <Svartekst tekst={m.tekst} />
                {m.kilder && m.kilder.length > 0 && <p className="kilder">Kilder: {m.kilder.join(', ')}</p>}
              </div>
            ))}
            {venter && <div className="boble assistent venter">Tenker …</div>}
            <div ref={bunn} />
          </div>

          <form className="ai-skriv" onSubmit={(e) => { e.preventDefault(); send(tekst) }}>
            <input ref={felt} value={tekst} onChange={(e) => setTekst(e.target.value)} placeholder="Skriv en melding …" disabled={venter} />
            <button type="submit" disabled={venter || strommer || !tekst.trim()} aria-label="Send">➤</button>
          </form>
        </div>
      )}

      <button
        type="button"
        className={`ai-fab ${apen ? 'apen' : ''}`}
        aria-label={apen ? 'Lukk AI-assistent' : 'Åpne AI-assistent'}
        aria-expanded={apen}
        onClick={() => setApen((v) => !v)}
      >
        {apen ? '✕' : '✨'}
      </button>
    </>
  )
}
