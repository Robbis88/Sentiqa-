'use client'
import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { useEffect, useRef, useState } from 'react'
import { Merke } from '@/components/ui/merke'
import { Meny } from './ikoner'
import { aktivtMenypunkt } from './navigasjon'

type Seksjon = { tittel: string; punkter: { sti: string; tekst: string }[] }

// Progressiv avdekking: gruppen du står i er åpen, resten er foldet sammen.
// Med 32 punkter synlig samtidig blir menyen en innholdsfortegnelse man må
// lese; med én gruppe åpen blir den et sted man er.
//
// Overstyring per gruppe huskes i økten, så den som vil ha alt åpent får det.
export function Sidemeny({ seksjoner }: { seksjoner: Seksjon[] }) {
  const [apen, setApen] = useState(false)
  const [mobil, setMobil] = useState(false)
  const meny = useRef<HTMLElement>(null)
  const utloser = useRef<HTMLButtonElement>(null)
  const [overstyrt, setOverstyrt] = useState<Record<string, boolean>>({})
  const sti = usePathname()
  const aktiv = aktivtMenypunkt(sti, seksjoner)

  useEffect(() => {
    const media = window.matchMedia('(max-width: 900px)')
    const oppdater = () => { setMobil(media.matches); if (!media.matches) setApen(false) }
    oppdater()
    media.addEventListener('change', oppdater)
    return () => media.removeEventListener('change', oppdater)
  }, [])

  useEffect(() => {
    if (!mobil || !apen || !meny.current) return
    const panel = meny.current
    const apneknapp = utloser.current
    const bakgrunn = new Map<HTMLElement, boolean>()
    let gren: HTMLElement = panel
    while (gren.parentElement && gren.parentElement !== document.documentElement) {
      for (const sibling of gren.parentElement.children) {
        if (!(sibling instanceof HTMLElement) || sibling === gren || sibling.matches('.meny-overlay, .meny-hamburger')) continue
        bakgrunn.set(sibling, sibling.inert)
        sibling.inert = true
      }
      gren = gren.parentElement
    }
    const fokuserbare = () => [...panel.querySelectorAll<HTMLElement>('a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex="0"]')]
    ;(fokuserbare()[0] ?? panel).focus()
    const tab = (e: KeyboardEvent) => {
      if (e.key !== 'Tab') return
      const elementer = fokuserbare()
      const forste = elementer[0]
      const siste = elementer[elementer.length - 1]
      if (!forste || !siste) { e.preventDefault(); panel.focus(); return }
      if (e.shiftKey && (document.activeElement === forste || document.activeElement === panel)) {
        e.preventDefault(); siste.focus()
      } else if (!e.shiftKey && document.activeElement === siste) {
        e.preventDefault(); forste.focus()
      }
    }
    panel.addEventListener('keydown', tab)
    return () => {
      panel.removeEventListener('keydown', tab)
      for (const [element, tidligere] of bakgrunn) element.inert = tidligere
      apneknapp?.focus()
    }
  }, [apen, mobil])

  // ESCAPE LUKKER MENYEN.
  //
  // Overlayet var eneste vei ut, og et bakteppe kan ikke naas med
  // tastatur. Kommandopaletten har hatt Escape hele tiden; menyen ble
  // glemt. Den som navigerer med tastatur kom seg inn og ikke ut.
  useEffect(() => {
    if (!apen) return
    const ned = (e: KeyboardEvent) => { if (e.key === 'Escape') setApen(false) }
    window.addEventListener('keydown', ned)
    return () => window.removeEventListener('keydown', ned)
  }, [apen])

  const inneholderAktiv = (s: Seksjon) =>
    s.punkter.some((p) => aktiv === p.sti)
  const erApen = (s: Seksjon) => overstyrt[s.tittel] ?? inneholderAktiv(s)

  return (
    <>
      <button
        ref={utloser}
        className="meny-hamburger"
        aria-label={apen ? 'Lukk meny' : 'Åpne meny'}
        aria-expanded={apen}
        onClick={() => setApen((a) => !a)}
      >
        <Meny />
      </button>
      {apen && <div className="meny-overlay" onClick={() => setApen(false)} aria-hidden />}

      <aside ref={meny} className={`sidemeny ${apen ? 'apen' : ''}`} inert={mobil && !apen} aria-hidden={mobil && !apen ? true : undefined} role={mobil && apen ? 'dialog' : undefined} aria-modal={mobil && apen ? true : undefined} aria-label={mobil && apen ? 'Hovedmeny' : undefined} tabIndex={mobil ? -1 : undefined}>
        {mobil && apen && <button type="button" className="sq-knapp" onClick={() => setApen(false)}>Lukk meny</button>}
        <Merke href="/oversikt" />
        {/* Menyen heter noe: siden har to nav-landemerker — dette og
            fanene — og «navigasjon» to ganger er ubrukelig i en
            skjermleserliste. */}
        <nav aria-label="Hovedmeny">
          {seksjoner.map((s) => {
            const lenker = s.punkter.map((p) => (
              <Link
                key={p.sti}
                href={p.sti}
                aria-current={sti === p.sti ? 'page' : aktiv === p.sti ? 'location' : undefined}
                onClick={() => setApen(false)}
              >
                {p.tekst}
              </Link>
            ))

            // Gruppen uten tittel (I dag) er alltid synlig — den er startpunktet.
            if (!s.tittel) {
              return <div className="meny-seksjon" key="topp">{lenker}</div>
            }

            const vis = erApen(s)
            return (
              <div className={`meny-seksjon ${vis ? 'apen' : ''}`} key={s.tittel}>
                <button
                  type="button"
                  className="meny-tittel"
                  aria-expanded={vis}
                  onClick={() => setOverstyrt((o) => ({ ...o, [s.tittel]: !vis }))}
                >
                  <span>{s.tittel}</span>
                  <svg className="meny-pil" width="10" height="10" viewBox="0 0 10 10" aria-hidden="true">
                    <path d="M3.2 1.8 6.6 5 3.2 8.2" fill="none" stroke="currentColor"
                      strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
                  </svg>
                </button>
                {vis ? lenker : null}
              </div>
            )
          })}
        </nav>
        <div className="meny-bunn">
          <span>R-G Invest AS</span>
          <span>Org.nr 937 861 621</span>
        </div>
      </aside>
    </>
  )
}
