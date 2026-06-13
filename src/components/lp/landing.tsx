'use client'
import { useEffect, useRef, useState } from 'react'
import Link from 'next/link'

// ---- Scroll-reveal: legg .vis på alle .reveal når de kommer i syne ----
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

// ---- Hero-konsoll: typer ut AI-sekvensen linje for linje ----
const SEKVENS = ['Regn registrert over Bergen.', '+17 % forventet salg av kaffe.', 'Produksjon justert.', 'Bemanning optimalisert.', 'Varebestilling sendt.']
function Konsoll() {
  const [ferdige, setFerdige] = useState<string[]>([])
  const [aktiv, setAktiv] = useState('')
  const [ferdig, setFerdig] = useState(false)
  useEffect(() => {
    let li = 0, ci = 0, t: ReturnType<typeof setTimeout>
    const steg = () => {
      if (li >= SEKVENS.length) { setFerdig(true); return }
      const full = SEKVENS[li]
      if (ci <= full.length) { setAktiv(full.slice(0, ci)); ci++; t = setTimeout(steg, 34) }
      else { setFerdige((p) => [...p, full]); setAktiv(''); li++; ci = 0; t = setTimeout(steg, 430) }
    }
    t = setTimeout(steg, 700)
    return () => clearTimeout(t)
  }, [])
  return (
    <div className="lp-konsoll">
      <div className="lp-konsoll-topp"><i />sentiqa · sanntid</div>
      {ferdige.map((l, i) => <div className="lp-linje" key={i}><span className="pil">→</span><span>{l}</span></div>)}
      {!ferdig && <div className="lp-linje"><span className="pil">→</span><span>{aktiv}<span className="lp-caret" /></span></div>}
      {ferdig && <div className="lp-ferdig">Sentiqa er allerede i gang.</div>}
    </div>
  )
}

// ---- Animert teller når den scrolles inn ----
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

function Chip({ ikon, navn, verdi, retning }: { ikon: string; navn: string; verdi: string; retning?: 'opp' | 'ned' }) {
  return (
    <div className="lp-chip">
      <span className="ikon">{ikon}</span>
      <span>{navn}</span>
      <span className={`verdi ${retning ?? ''}`}>{verdi}</span>
    </div>
  )
}

export function Landing() {
  const ref = useReveal()
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
        {/* HERO */}
        <header className="lp-hero">
          <div className="lp-mid">
            <span className="lp-merke"><span className="lp-prikk" />AI-drevet drift for servicehandelen</span>
            <h1 className="lp-h1"><span className="grad">Fornemmer.<br />Forstår.<br />Forutser.</span></h1>
            <p className="lp-sub">Mindre tid på kontoret. <b>Mer tid i butikken.</b></p>
            <Konsoll />
            <div className="lp-knapper">
              <a className="lp-knapp primaer" href="mailto:post@sentiqa.ai?subject=Demo av Sentiqa">Be om en demo →</a>
              <Link className="lp-knapp sekundaer" href="/logg-inn">Logg inn</Link>
            </div>
          </div>
        </header>

        {/* TELLERE */}
        <div className="lp-mid">
          <div className="lp-tellere reveal">
            <Teller til={12000000} suffiks="+" merke="datapunkter analysert" />
            <Teller til={1500000} suffiks="+" merke="transaksjoner forstått" />
            <Teller til={94} suffiks=" %" merke="prognose­treffsikkerhet" />
            <Teller til={99.9} desim={1} suffiks=" %" merke="systemtilgjengelighet" />
          </div>
        </div>

        {/* AKT 1 — FORNEMMER */}
        <section className="lp-seksjon">
          <div className="lp-mid lp-akt">
            <div className="reveal">
              <div className="lp-kapittel">01 — Fornemmer</div>
              <h2 className="lp-akt-h2">Den ser hele bildet, hele tiden.</h2>
              <p className="lp-akt-tekst">Vær, trafikk, utfartsmønster, drivstoffpriser, kampanjer og historiske salgstall strømmer inn kontinuerlig. Sentiqa kobler det sammen — slik en erfaren driftssjef ville gjort, bare uten å sove.</p>
            </div>
            <div className="lp-akt-visuell reveal">
              <div className="lp-panel">
                <div className="lp-panel-glod" />
                <div className="lp-stream" />
                <div className="lp-rader">
                  <Chip ikon="🌧️" navn="Vær · Bergen" verdi="Regn om 15 min" />
                  <Chip ikon="🚗" navn="Trafikk E39" verdi="+12 %" retning="opp" />
                  <Chip ikon="⛽" navn="Drivstoffpris" verdi="−0,4 kr/l" retning="ned" />
                  <Chip ikon="📈" navn="Historikk · samme dag i fjor" verdi="Matchet" />
                </div>
              </div>
            </div>
          </div>
        </section>

        {/* AKT 2 — FORSTÅR */}
        <section className="lp-seksjon">
          <div className="lp-mid lp-akt snu">
            <div className="reveal">
              <div className="lp-kapittel">02 — Forstår</div>
              <h2 className="lp-akt-h2">Den vet hva tallene egentlig betyr.</h2>
              <p className="lp-akt-tekst">Uforklart svinn, avvik mot budsjett, lavtsalg på en avdeling, lønn som ikke står i stil med bruttoen. Sentiqa forklarer årsaken med kroner og prosent — ikke et dashbord du må tolke selv.</p>
            </div>
            <div className="lp-akt-visuell reveal">
              <div className="lp-panel">
                <div className="lp-panel-glod" />
                <div className="lp-stream" />
                <div className="lp-rader">
                  <Chip ikon="📦" navn="Usynlig manko · Kaffe" verdi="−8 940 kr" retning="ned" />
                  <Chip ikon="🌡️" navn="IK-mat avvik" verdi="Kjøl 7 °C" retning="ned" />
                  <Chip ikon="🥐" navn="Lavtsalg · Bakeri" verdi="−12 %" retning="ned" />
                  <Chip ikon="👥" navn="Lønn vs budsjett" verdi="+29 %" retning="ned" />
                </div>
              </div>
            </div>
          </div>
        </section>

        {/* AKT 3 — FORUTSER */}
        <section className="lp-seksjon">
          <div className="lp-mid lp-akt">
            <div className="reveal">
              <div className="lp-kapittel">03 — Forutser</div>
              <h2 className="lp-akt-h2">Den handler før problemet oppstår.</h2>
              <p className="lp-akt-tekst">Rush klokka 16. Salgstopp i helga. Lagerbehov til fredag. Sentiqa gir konkrete anbefalinger — produksjonsmengde, bemanning, bestilling — slik at du er forberedt, ikke overrasket.</p>
            </div>
            <div className="lp-akt-visuell reveal">
              <div className="lp-panel">
                <div className="lp-panel-glod" />
                <div className="lp-stream" />
                <div className="lp-rader">
                  <Chip ikon="⏰" navn="Forventet rush" verdi="16:00–17:30" />
                  <Chip ikon="☕" navn="Produser kaffe" verdi="+17 %" retning="opp" />
                  <Chip ikon="🧑‍🍳" navn="Bemanning" verdi="+1 person" />
                  <Chip ikon="🛒" navn="Bestilling fredag" verdi="Klar" retning="opp" />
                </div>
              </div>
            </div>
          </div>
        </section>

        {/* WOW — filmsekvens */}
        <section className="lp-wow">
          <div className="lp-mid">
            <div className="reveal" style={{ textAlign: 'center', marginBottom: '2rem' }}>
              <div className="lp-kapittel" style={{ display: 'inline-block' }}>Ett regnskyll. Én ettermiddag.</div>
              <h2 className="lp-akt-h2" style={{ marginTop: '0.6rem' }}>Slik ser intelligens ut i drift.</h2>
            </div>
            <div className="lp-wow-rute reveal">
              <div className="lp-regn" aria-hidden />
              <div className="lp-wow-inn">
                <div className="lp-tidslinje">
                  <div className="lp-steg"><span className="tid">14:02</span><span className="hva"><strong>Det begynner å regne i Bergen.</strong><span>Sentiqa fanger væromslaget før første dråpe treffer taket.</span></span></div>
                  <div className="lp-steg"><span className="tid">14:05</span><span className="hva"><strong>Øk kaffeproduksjonen. Fyll på bakervarer.</strong><span>Anbefaling sendt til tableten — store, enkle knapper for de ansatte.</span></span></div>
                  <div className="lp-steg"><span className="tid">14:18</span><span className="hva"><strong>Bemann én ekstra på kassa.</strong><span>Forventet rush mellom 15:30 og 17:00, basert på vær + trafikk + historikk.</span></span></div>
                  <div className="lp-steg"><span className="tid">17:30</span><span className="hva"><strong>Resultatet er inne.</strong><span>Riktig vare, riktig bemanning, riktig øyeblikk.</span></span></div>
                </div>
                <div className="lp-resultat">
                  <div className="tall">+18 700 kr</div>
                  <div className="merke">over forventet salg — på én ettermiddag</div>
                </div>
              </div>
            </div>
          </div>
        </section>

        {/* VIDEO-PLACEHOLDERE */}
        <section className="lp-seksjon">
          <div className="lp-mid">
            <div className="reveal" style={{ marginBottom: '2rem' }}>
              <div className="lp-kapittel">Se den i arbeid</div>
              <h2 className="lp-akt-h2" style={{ marginTop: '0.6rem' }}>Fire øyeblikk fra driftssentralen.</h2>
            </div>
            <div className="lp-videoer">
              {[
                { t: 'AI analyserer værdata', u: 'Sanntid mot salgshistorikk' },
                { t: 'AI oppdager svinn', u: 'Usynlig manko, forklart i kroner' },
                { t: 'AI lager produksjonsplan', u: 'Vær- og trendjustert, per avdeling' },
                { t: 'Butikksjef chatter med AI', u: 'Spør på norsk, få svar med kilder' },
              ].map((v) => (
                <div className="lp-video reveal" key={v.t} role="img" aria-label={v.t}>
                  <div className="lp-video-spill">▶</div>
                  <div className="lp-video-tekst">{v.t}<span>{v.u}</span></div>
                </div>
              ))}
            </div>
          </div>
        </section>

        {/* AVSENDER */}
        <section className="lp-seksjon">
          <div className="lp-mid lp-sitat reveal">
            <p>«Bygget av en som har stått på gulvet i 24 år — ikke av et programvareselskap. Jeg lagde verktøyet jeg selv ville hatt for å bli best.»</p>
            <div className="sign">— Grunnleggeren av Sentiqa</div>
          </div>
        </section>

        {/* SLUTT-CTA */}
        <section className="lp-slutt">
          <div className="lp-mid reveal">
            <h2>Se fremtidens drift med dine egne tall.</h2>
            <p>Ta inn rapportene du allerede eksporterer — få svar, ikke dashbord å lete i.</p>
            <div className="lp-knapper" style={{ justifyContent: 'center' }}>
              <a className="lp-knapp primaer" href="mailto:post@sentiqa.ai?subject=Demo av Sentiqa">Ta kontakt for pris og demo →</a>
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
