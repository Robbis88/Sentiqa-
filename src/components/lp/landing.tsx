'use client'
import { useEffect, useRef, useState } from 'react'
import Link from 'next/link'

// ---- Scroll-reveal ----
function useReveal() {
  const ref = useRef<HTMLDivElement>(null)
  useEffect(() => {
    const el = ref.current
    if (!el) return
    const io = new IntersectionObserver(
      (entries) => entries.forEach((e) => { if (e.isIntersecting) { e.target.classList.add('vis'); io.unobserve(e.target) } }),
      { threshold: 0.15, rootMargin: '0px 0px -8% 0px' },
    )
    el.querySelectorAll('.reveal').forEach((n) => io.observe(n))
    return () => io.disconnect()
  }, [])
  return ref
}

// ---- Animert teller ----
function Teller({ til, desim = 0, suffiks = '', merke }: { til: number; desim?: number; suffiks?: string; merke: string }) {
  const [v, setV] = useState(0)
  const ref = useRef<HTMLDivElement>(null)
  const startet = useRef(false)
  useEffect(() => {
    const el = ref.current
    if (!el) return
    const io = new IntersectionObserver((es) => {
      es.forEach((e) => {
        if (e.isIntersecting && !startet.current) {
          startet.current = true
          const t0 = performance.now(), varighet = 1900
          const tick = (now: number) => {
            const p = Math.min(1, (now - t0) / varighet)
            setV(til * (1 - Math.pow(1 - p, 3)))
            if (p < 1) requestAnimationFrame(tick)
          }
          requestAnimationFrame(tick)
        }
      })
    }, { threshold: 0.4 })
    io.observe(el)
    return () => io.disconnect()
  }, [til])
  const fmt = new Intl.NumberFormat('nb-NO', { minimumFractionDigits: desim, maximumFractionDigits: desim }).format(v)
  return (
    <div className="lp-teller">
      <div ref={ref} className="lp-teller-tall">{fmt}{suffiks}</div>
      <div className="lp-teller-merke">{merke}</div>
    </div>
  )
}

// ---- Video-slot: ekte video hvis fila finnes, ellers ren placeholder ----
function VideoSlot({ src, label, tilgjengelig }: { src: string; label: string; tilgjengelig: boolean }) {
  if (tilgjengelig) {
    return (
      <div className="lp-vslot">
        <video autoPlay muted loop playsInline preload="metadata"><source src={src} type="video/mp4" /></video>
      </div>
    )
  }
  return (
    <div className="lp-vslot lp-vslot-tom">
      <div className="lp-vslot-spill">🎬</div>
      <div className="lp-vslot-tekst"><strong>{label}</strong><span>Videoslot — slipp inn <code>{src}</code></span></div>
    </div>
  )
}

function Chip({ ikon, navn, verdi, retning }: { ikon: string; navn: string; verdi?: string; retning?: 'opp' | 'ned' }) {
  return (
    <div className="lp-chip">
      <span className="ikon">{ikon}</span>
      <span>{navn}</span>
      {verdi && <span className={`verdi ${retning ?? ''}`}>{verdi}</span>}
    </div>
  )
}

export function Landing() {
  const ref = useReveal()
  // Videofilene ligger i public/video/
  const HAR = { fornemmer: true, forutser: true, direktor: true }
  return (
    <div className="lp" ref={ref}>
      <div className="lp-bg" aria-hidden>
        <div className="lp-aurora" />
        <div className="lp-grid" />
        <div className="lp-orb a" />
        <div className="lp-orb b" />
        <div className="lp-noise" />
      </div>

      <nav className="lp-nav">
        <div className="lp-nav-inn">
          <div className="lp-logo">SENT<b>IQA</b></div>
          <Link href="/logg-inn" className="lp-nav-cta">Logg inn</Link>
        </div>
      </nav>

      <div className="lp-inn">
        {/* 1 — HERO (Video 1) */}
        <header className="lp-hero">
          <div className="lp-hero-video" aria-hidden>
            <video autoPlay muted loop playsInline preload="metadata"><source src="/video/hero.mp4" type="video/mp4" /></video>
            <div className="lp-hero-overlay" />
          </div>
          <div className="lp-mid">
            <span className="lp-merke"><span className="lp-prikk" />AI-drevet drift for servicehandelen</span>
            <h1 className="lp-h1"><span className="grad">Fornemmer.<br />Forstår.<br />Forutser.</span></h1>
            <p className="lp-sub">AI som analyserer <b>vær, trafikk, salg og drift</b> før mulighetene oppstår.</p>
            <div className="lp-knapper">
              <a className="lp-knapp primaer" href="mailto:post@sentiqa.ai?subject=Live demo av Sentiqa">Se live demo →</a>
              <Link className="lp-knapp sekundaer" href="/logg-inn">Logg inn</Link>
            </div>
          </div>
        </header>

        {/* 2 — PROBLEMET */}
        <section className="lp-seksjon">
          <div className="lp-mid">
            <h2 className="lp-stort reveal">De fleste butikker reagerer på <span className="dim">gårsdagen.</span><br />Sentiqa reagerer på <span className="grad">morgendagen.</span></h2>
            <div className="lp-tellere reveal">
              <Teller til={12000000} suffiks="+" merke="datapunkter analysert" />
              <Teller til={94} suffiks=" %" merke="prognosetreff" />
              <Teller til={500} suffiks="+" merke="faktorer overvåket" />
            </div>
          </div>
        </section>

        {/* 3 — FORNEMMER (Video 2) */}
        <section className="lp-seksjon">
          <div className="lp-mid lp-akt">
            <div className="reveal">
              <div className="lp-kapittel">01 — Fornemmer</div>
              <h2 className="lp-akt-h2">Den ser hele bildet, hele tiden.</h2>
              <p className="lp-akt-tekst">Sentiqa tar inn signalene som faktisk styrer dagen din — og kobler dem sammen kontinuerlig.</p>
              <div className="lp-rader" style={{ padding: 0, marginTop: '1.2rem' }}>
                <Chip ikon="☀️" navn="Vær" verdi="Live varsel" />
                <Chip ikon="🚗" navn="Trafikk" verdi="Sanntid" />
                <Chip ikon="⛽" navn="Drivstoffpriser" />
                <Chip ikon="📅" navn="Helligdager" />
                <Chip ikon="🏟️" navn="Arrangementer" />
              </div>
            </div>
            <div className="lp-akt-visuell reveal">
              <VideoSlot src="/video/fornemmer.mp4" label="Vær & signaler" tilgjengelig={HAR.fornemmer} />
            </div>
          </div>
        </section>

        {/* 4 — FORSTÅR (ekte system-mock) */}
        <section className="lp-seksjon">
          <div className="lp-mid">
            <div className="reveal" style={{ marginBottom: '2rem' }}>
              <div className="lp-kapittel">02 — Forstår</div>
              <h2 className="lp-akt-h2">Den vet hva tallene egentlig betyr.</h2>
              <p className="lp-akt-tekst">Ikke et dashbord du må tolke selv — Sentiqa forklarer årsaken, i kroner og prosent.</p>
            </div>
            <div className="lp-skjerm-grid">
              <div className="lp-skjerm reveal">
                <div className="lp-skjerm-topp">📊 Salgsanalyse</div>
                <div className="lp-bars">{[60, 80, 45, 90, 55, 70, 38].map((h, i) => <span key={i} style={{ height: `${h}%` }} />)}</div>
                <div className="lp-skjerm-bunn">Omsetning per avdeling · mot i fjor</div>
              </div>
              <div className="lp-skjerm reveal">
                <div className="lp-skjerm-topp">⚠️ Lavtsalg oppdaget</div>
                <div className="lp-chip"><span className="ikon">🥐</span><span>Bakeri</span><span className="verdi ned">−12 %</span></div>
                <div className="lp-chip"><span className="ikon">🌭</span><span>Pølser</span><span className="verdi ned">−19 %</span></div>
                <div className="lp-skjerm-bunn">Avvik fra forventet, flagget automatisk</div>
              </div>
              <div className="lp-skjerm reveal">
                <div className="lp-skjerm-topp">📋 Produksjonsplan</div>
                <div className="lp-chip"><span className="ikon">☕</span><span>Kaffe</span><span className="verdi opp">+17 %</span></div>
                <div className="lp-chip"><span className="ikon">🥐</span><span>Baguette</span><span className="verdi">48 stk</span></div>
                <div className="lp-skjerm-bunn">Vær- og trendjustert, per avdeling</div>
              </div>
              <div className="lp-skjerm reveal">
                <div className="lp-skjerm-topp">🔎 Svinnanalyse</div>
                <div className="lp-stor-tall ned">−8 940 kr</div>
                <div className="lp-skjerm-bunn">Usynlig manko · Kaffe · forklart i kroner</div>
              </div>
            </div>
            <p className="lp-merknad reveal">Ekte skjermbilder fra ditt eget system kan bytte ut disse mockene.</p>
          </div>
        </section>

        {/* 5 — FORUTSER (Video 3) */}
        <section className="lp-seksjon">
          <div className="lp-mid lp-akt snu">
            <div className="reveal">
              <div className="lp-kapittel">03 — Forutser</div>
              <h2 className="lp-akt-h2">Det blir 23 °C i Bergen på lørdag.</h2>
              <p className="lp-akt-tekst">Sentiqa forventer — og forbereder deg på det, før helga starter:</p>
              <div className="lp-prognose">
                <ProgRad ikon="🚗" navn="Bilvask" til={31} />
                <ProgRad ikon="🥤" navn="Kald drikke" til={18} />
                <ProgRad ikon="⛽" navn="Drivstoff" til={11} />
              </div>
            </div>
            <div className="lp-akt-visuell reveal">
              <VideoSlot src="/video/forutser.mp4" label="Sol, trafikk & bilvask" tilgjengelig={HAR.forutser} />
            </div>
          </div>
        </section>

        {/* 6 — AI-ASSISTENT (ekte chat-eksempel) */}
        <section className="lp-seksjon">
          <div className="lp-mid">
            <div className="reveal" style={{ marginBottom: '2rem', textAlign: 'center' }}>
              <div className="lp-kapittel" style={{ display: 'inline-block' }}>Spør på vanlig norsk</div>
              <h2 className="lp-akt-h2" style={{ marginTop: '0.6rem' }}>AI-assistenten svarer med dine egne tall.</h2>
            </div>
            <div className="lp-chat reveal">
              <div className="lp-chat-boble bruker">Hvorfor falt pølsesalget i går?</div>
              <div className="lp-chat-boble ai">
                <span className="lp-chat-navn">Sentiqa</span>
                Temperaturen nådde <b>27 °C</b>. Iskremsalget økte <b>+34 %</b>, mens pølser falt <b>−19 %</b> — folk valgte kaldt framfor varmt.
                <div className="lp-chat-anbef">💡 Anbefaling: reduser pølseproduksjonen på varme dager, og øk softis og kald drikke.</div>
              </div>
            </div>
          </div>
        </section>

        {/* 7 — DIREKTØR / KJEDE (Video 4) */}
        <section className="lp-seksjon">
          <div className="lp-mid lp-akt">
            <div className="reveal">
              <div className="lp-kapittel">Hele kjeden — ett blikk</div>
              <h2 className="lp-akt-h2">Driftssentralen for ledelsen.</h2>
              <p className="lp-akt-tekst">Status på hver stasjon i sanntid. Grønt går bra, rødt trenger handling — du ser hvor du skal sette inn støtet.</p>
              <div className="lp-status-panel">
                {[
                  { n: 'ST1 Bønes', s: 'gronn' }, { n: 'ST1 Varden', s: 'gronn' },
                  { n: 'ST1 Lone', s: 'gul' }, { n: 'ST1 Dale', s: 'rod' },
                ].map((r) => (
                  <div className="lp-status-rad" key={r.n}><span>{r.n}</span><span className={`lp-prikk-st ${r.s}`} /></div>
                ))}
              </div>
            </div>
            <div className="lp-akt-visuell reveal">
              <VideoSlot src="/video/direktor.mp4" label="Kontrollrom / ledelse" tilgjengelig={HAR.direktor} />
            </div>
          </div>
        </section>

        {/* 8 — CTA */}
        <section className="lp-slutt">
          <div className="lp-mid reveal">
            <h2>Drift basert på <span className="grad">fakta.</span><br />Ikke magefølelse.</h2>
            <p>Ta inn rapportene du allerede eksporterer — få svar, ikke dashbord å lete i.</p>
            <div className="lp-knapper" style={{ justifyContent: 'center' }}>
              <a className="lp-knapp primaer" href="mailto:post@sentiqa.ai?subject=Demo av Sentiqa">Bestill demo →</a>
            </div>
          </div>
        </section>

        <footer className="lp-mid lp-foot">
          <span>© 2026 Sentiqa · Fornemmer. Forstår. Forutser.</span>
          <a href="mailto:post@sentiqa.ai">post@sentiqa.ai</a>
        </footer>
      </div>
    </div>
  )
}

function ProgRad({ ikon, navn, til }: { ikon: string; navn: string; til: number }) {
  return (
    <div className="lp-prog">
      <span className="lp-prog-ikon">{ikon}</span>
      <span className="lp-prog-navn">{navn}</span>
      <Teller til={til} suffiks=" %" merke="" />
    </div>
  )
}
