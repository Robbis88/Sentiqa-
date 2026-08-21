'use client'
import { useState, useTransition } from 'react'
import { kvitterTablet } from './oppgaver/handlinger'

export type SjefMelding = {
  id: string
  tittel: string
  beskrivelse: string | null
  bilde_url: string | null
  frist: string | null
  fullfort: boolean
}

// Fristnivå: forbi/i dag = haster (rød), innen 2 dager = snart (gul), ellers nøytral.
function fristNiva(frist: string | null, idag: string): 'haster' | 'snart' | 'ro' | null {
  if (!frist) return null
  const f = frist.slice(0, 10)
  if (f <= idag) return 'haster'
  const om2 = (() => {
    const d = new Date(`${idag}T12:00:00Z`)
    d.setUTCDate(d.getUTCDate() + 2)
    return d.toISOString().slice(0, 10)
  })()
  if (f <= om2) return 'snart'
  return 'ro'
}

function fristTekst(frist: string | null, idag: string, t: (s: string) => string): string {
  if (!frist) return ''
  const f = frist.slice(0, 10)
  if (f < idag) return t('Fristen er forbi')
  if (f === idag) return t('Frist i dag')
  const igaar = (() => {
    const d = new Date(`${idag}T12:00:00Z`)
    d.setUTCDate(d.getUTCDate() + 1)
    return d.toISOString().slice(0, 10)
  })()
  if (f === igaar) return t('Frist i morgen')
  return `${t('Frist')} ${new Intl.DateTimeFormat('nb-NO', { day: 'numeric', month: 'short' }).format(new Date(`${f}T12:00:00Z`))}`
}

function Kort({
  m,
  idag,
  t,
  paaKvitter,
  travel,
}: {
  m: SjefMelding
  idag: string
  t: (s: string) => string
  paaKvitter: (id: string, fullfort: boolean) => void
  travel: boolean
}) {
  const niva = fristNiva(m.frist, idag)
  const frTekst = fristTekst(m.frist, idag, t)
  return (
    <div className={`sjefmelding ${niva ?? ''} ${m.fullfort ? 'ferdig' : ''}`}>
      <div className="sjefmelding-tekst">
        <strong>{m.tittel}</strong>
        {m.beskrivelse && <p>{m.beskrivelse}</p>}
        {m.bilde_url && (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={m.bilde_url} alt="" className="sjefmelding-bilde" />
        )}
        {frTekst && <span className={`sjefmelding-frist ${niva ?? ''}`}>{frTekst}</span>}
      </div>
      <button
        type="button"
        className={`sjefmelding-hak ${m.fullfort ? 'av' : ''}`}
        disabled={travel}
        onClick={() => paaKvitter(m.id, !m.fullfort)}
      >
        {m.fullfort ? `↩︎ ${t('Angre')}` : `✓ ${t('Utført')}`}
      </button>
    </div>
  )
}

export function MeldingerFraSjef({
  meldinger,
  idag,
  ord = {},
}: {
  meldinger: SjefMelding[]
  idag: string
  ord?: Record<string, string>
}) {
  const t = (s: string) => ord[s] ?? s
  const [rader, setRader] = useState(meldinger)
  const [venter, start] = useTransition()
  const [visFerdige, setVisFerdige] = useState(false)

  function kvitter(id: string, fullfort: boolean) {
    setRader((r) => r.map((m) => (m.id === id ? { ...m, fullfort } : m)))
    start(async () => {
      await kvitterTablet(id, fullfort)
    })
  }

  const aapne = rader
    .filter((m) => !m.fullfort)
    .sort((a, b) => {
      // Mest haster øverst: tidligst frist først, uten frist nederst.
      if (!a.frist && !b.frist) return 0
      if (!a.frist) return 1
      if (!b.frist) return -1
      return a.frist.localeCompare(b.frist)
    })
  const ferdige = rader.filter((m) => m.fullfort)

  return (
    // Ankeret koen lenker til. Uten det peker en oppgaverad paa sida den
    // allerede staar paa, og trykket gjor ingenting.
    <section className="tablet-seksjon sjefmeldinger" id="beskjeder">
      <h2>{t('Meldinger fra butikksjef')}</h2>

      {aapne.length === 0 && ferdige.length === 0 && (
        <p className="sjefmeldinger-tom">{t('Ingen nye meldinger fra butikksjef')}</p>
      )}

      {aapne.map((m) => (
        <Kort key={m.id} m={m} idag={idag} t={t} paaKvitter={kvitter} travel={venter} />
      ))}

      {ferdige.length > 0 && (
        <div className="sjefmeldinger-ferdige">
          <button type="button" className="sjefmeldinger-ferdig-knapp" onClick={() => setVisFerdige((v) => !v)}>
            {visFerdige ? '▾' : '▸'} {t('Ferdige')} ({ferdige.length})
          </button>
          {visFerdige &&
            ferdige.map((m) => (
              <Kort key={m.id} m={m} idag={idag} t={t} paaKvitter={kvitter} travel={venter} />
            ))}
        </div>
      )}
    </section>
  )
}
