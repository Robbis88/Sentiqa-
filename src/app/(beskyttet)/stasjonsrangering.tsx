'use client'
import { useState } from 'react'
import { kr } from '@/lib/format'
import { type Avd } from '@/lib/avdelinger'

type AvdVerdi = { regnskap: number; budsjett: number }
export type RangRad = {
  navn: string
  oms: Record<string, AvdVerdi>
  brf: Record<string, AvdVerdi>
  kost: Record<string, AvdVerdi>
  kast: number
  usynlig: number
}

// Butikksjef-påvirkbare kostnadskonti (for kostnad-fanens kilde-velger).
const KOSTNADER: Avd[] = [
  { kode: '633', navn: 'Forbruksmateriell', ikon: '🧴' },
  { kode: '627', navn: 'Renhold', ikon: '🧽' },
  { kode: '628', navn: 'Renovasjon', ikon: '🗑️' },
  { kode: '629', navn: 'Brøyting', ikon: '❄️' },
  { kode: '634', navn: 'Rep & vedlikehold', ikon: '🔧' },
  { kode: '632', navn: 'Utstyr & verktøy', ikon: '🛠️' },
  { kode: '639', navn: 'Telefon', ikon: '📞' },
  { kode: '741', navn: 'Reise, møter, kurs', ikon: '🚗' },
  { kode: '743', navn: 'Diverse', ikon: '📦' },
  { kode: '746', navn: 'Kassedifferanse', ikon: '💵' },
]

const FANER = [
  { id: 'oms', navn: 'Omsetning', ikon: '💰', velger: true },
  { id: 'brf', navn: 'Bruttofortjeneste', ikon: '📈', velger: true },
  { id: 'lonn', navn: 'Lønn %', ikon: '👥', velger: false },
  { id: 'synlig', navn: 'Synlig svinn', ikon: '🗑️', velger: false },
  { id: 'usynlig', navn: 'Usynlig svinn', ikon: '👻', velger: false },
  { id: 'kostnad', navn: 'Kostnader', ikon: '💸', velger: true },
]
const MEDALJE = ['🥇', '🥈', '🥉']
const SVINN_IKON = ['🚨', '⚠️', '⚠️']
// Personalkostnad-konti (St1) — for lønn%-fanen.
const LONN_KONTI = ['501', '502', '503', '505', '508', '509', '540', '541', '590']

export function Stasjonsrangering({ rader, avdelinger }: { rader: RangRad[]; avdelinger: Avd[] }) {
  const [fane, setFane] = useState('oms')
  const [avd, setAvd] = useState('total')
  const [visAlle, setVisAlle] = useState(false)

  const harKost = rader.some((r) => Object.keys(r.kost ?? {}).length > 0)
  const harLonn = rader.some((r) => LONN_KONTI.some((k) => r.kost?.[k]))
  const faner = FANER.filter((t) => (t.id !== 'kostnad' || harKost) && (t.id !== 'lonn' || harLonn))
  const erKost = fane === 'kostnad'
  const velgerListe = erKost ? KOSTNADER.filter((k) => rader.some((r) => r.kost?.[k.kode])) : avdelinger

  type Linje = { navn: string; verdi: number; budsjett: number | null; pst?: boolean; under?: string }
  let linjer: Linje[]
  if (fane === 'oms' || fane === 'brf') {
    const kilde = fane === 'oms' ? 'oms' : 'brf'
    linjer = rader
      .map((r) => { const v = r[kilde][avd] ?? { regnskap: 0, budsjett: 0 }; return { navn: r.navn, verdi: v.regnskap, budsjett: v.budsjett } })
      .sort((a, b) => b.verdi - a.verdi) // best (mest) øverst
  } else if (fane === 'lonn') {
    linjer = rader
      .map((r) => {
        const lonn = LONN_KONTI.reduce((s, k) => s + (r.kost?.[k]?.regnskap ?? 0), 0)
        const oms = r.oms.total?.regnskap ?? 0
        return { navn: r.navn, verdi: oms > 0 ? (lonn / oms) * 100 : 0, budsjett: null, pst: true, under: `${kr.format(Math.round(lonn))} lønn` }
      })
      .sort((a, b) => a.verdi - b.verdi) // lavest lønn% = best øverst
  } else if (fane === 'kostnad') {
    linjer = rader
      .map((r) => { const v = r.kost?.[avd] ?? { regnskap: 0, budsjett: 0 }; return { navn: r.navn, verdi: v.regnskap, budsjett: v.budsjett } })
      .sort((a, b) => (a.verdi - (a.budsjett ?? 0)) - (b.verdi - (b.budsjett ?? 0))) // mest under budsjett = best øverst
  } else if (fane === 'synlig') {
    linjer = rader.map((r) => ({ navn: r.navn, verdi: Math.round(r.kast), budsjett: null })).sort((a, b) => b.verdi - a.verdi) // verst (mest kast) øverst
  } else {
    linjer = rader.map((r) => ({ navn: r.navn, verdi: Math.round(r.usynlig), budsjett: null })).sort((a, b) => a.verdi - b.verdi) // lavest manko = best øverst
  }
  const vist = visAlle ? linjer : linjer.slice(0, 3)

  return (
    <div className="rang">
      <div className="rang-faner">
        {faner.map((t) => (
          <button key={t.id} type="button" className={`rang-fane ${fane === t.id ? 'aktiv' : ''}`} onClick={() => { setFane(t.id); setVisAlle(false); setAvd(t.id === 'kostnad' ? '633' : 'total') }}>
            {t.ikon} {t.navn}
          </button>
        ))}
      </div>

      {(fane === 'oms' || fane === 'brf' || erKost) && velgerListe.length > 0 && (
        <label className="rang-velger-rad">
          Vis:
          <select className="rang-velger" value={avd} onChange={(e) => setAvd(e.target.value)}>
            {!erKost && <option value="total">Total</option>}
            {velgerListe.map((a) => <option key={a.kode} value={a.kode}>{a.ikon} {a.navn}</option>)}
          </select>
        </label>
      )}

      <ol className="rang-rader">
        {vist.map((l, i) => {
          const avvik = l.budsjett != null ? l.verdi - l.budsjett : null
          const avvikPst = l.budsjett ? (avvik! / l.budsjett) * 100 : null
          const badge = fane === 'synlig' ? (SVINN_IKON[i] ?? `${i + 1}`) : (MEDALJE[i] ?? `${i + 1}`)
          let klasse = ''
          if (fane === 'oms' || fane === 'brf') klasse = avvik != null ? (avvik >= 0 ? 'gronn' : 'rod') : ''
          else if (fane === 'kostnad') klasse = avvik != null ? (avvik <= 0 ? 'gronn' : 'rod') : '' // under budsjett = bra
          else if (fane === 'lonn') klasse = l.verdi > 32 ? 'rod' : 'gronn' // > 32 % av omsetning = høyt
          else klasse = l.verdi > 0 ? 'rod' : 'gronn' // svinn: positivt (kast/manko) = dårlig
          return (
            <li key={l.navn}>
              <span className="rang-badge">{badge}</span>
              <span className="rang-navn">
                {l.navn}
                {l.budsjett ? <span className="rang-budsjett"> · budsjett {kr.format(l.budsjett)}</span> : null}
              </span>
              <span className="rang-tall">
                <span className="rang-verdi">{l.pst ? `${l.verdi.toFixed(1)} %` : kr.format(l.verdi)}</span>
                {l.under ? (
                  <span className={`rang-avvik ${klasse}`}>{l.under}</span>
                ) : avvik != null ? (
                  <span className={`rang-avvik ${klasse}`}>
                    {avvik >= 0 ? '+' : '−'}{kr.format(Math.abs(avvik))}{avvikPst != null ? ` (${avvik >= 0 ? '+' : '−'}${Math.abs(avvikPst).toFixed(0)} %)` : ''}
                  </span>
                ) : (
                  <span className={`rang-avvik ${klasse}`}>{fane === 'synlig' ? 'kast' : (l.verdi > 0 ? 'manko' : 'overskudd')}</span>
                )}
              </span>
            </li>
          )
        })}
      </ol>

      {linjer.length > 3 && (
        <button type="button" className="liten rang-mer" onClick={() => setVisAlle((v) => !v)}>
          {visAlle ? 'Vis færre' : `Vis ${linjer.length - 3} til`}
        </button>
      )}
    </div>
  )
}
