'use client'
import { useState } from 'react'
import { gjenkjennRapporttype } from '@/lib/parsere/gjenkjenn'
import { parseSalgsstatistikk } from '@/lib/parsere/salgsstatistikk'
import { parseSalesPerHourInneUte } from '@/lib/parsere/salesperhourinneute'
import { parseKassererstatistikk } from '@/lib/parsere/kassererstatistikk'
import { parseVaretransaksjon } from '@/lib/parsere/varetransaksjon'
import { parseRegnskap, parseRegnskapStasjoner } from '@/lib/parsere/regnskap'
import { parseUsynligSvinn } from '@/lib/parsere/usynligsvinn'
import type { ForhandsPayload } from '@/lib/import/typer'
import { importerForhandsparset } from './handlinger'

// Nettleseren laster hele arbeidsboka i minnet for å parse den. St1s
// forretningsplan er ~27 MB med et ark på 289 000 rader og koster over 2 GB —
// fanen ryker før den er ferdig. Slike filer skal gjennom drop-zonen, der
// serveren strømmer dem. Grensen ligger godt over alt vi ellers mottar
// (regnskapsrapporten er ~1,2 MB, timesalg noen hundre kB).
const FOR_STOR = 12 * 1024 * 1024

type Tilstand = 'venter' | 'parser' | 'lagrer' | 'ferdig' | 'hoppet' | 'feilet'
type FilRad = { navn: string; tilstand: Tilstand; melding?: string }

const PIP: Record<Tilstand, string> = { venter: '', parser: 'gul', lagrer: 'gul', ferdig: 'gronn', hoppet: 'bla', feilet: 'rod' }
const ETIKETT: Record<Tilstand, string> = { venter: 'Venter', parser: 'Parser …', lagrer: 'Lagrer …', ferdig: 'Importert', hoppet: 'Hoppet over', feilet: 'Feilet' }

async function sha256Hex(buf: ArrayBuffer): Promise<string> {
  const d = await crypto.subtle.digest('SHA-256', buf)
  return [...new Uint8Array(d)].map((b) => b.toString(16).padStart(2, '0')).join('')
}

async function byggPayload(buf: ArrayBuffer): Promise<ForhandsPayload | null> {
  const type = await gjenkjennRapporttype(buf)
  switch (type) {
    case 'st1_salgsstatistikk': return { type, salg: await parseSalgsstatistikk(buf) }
    case 'st1_salesperhour_inneute': return { type, timesalg: await parseSalesPerHourInneUte(buf) }
    case 'st1_cashierstats': return { type, kasserer: await parseKassererstatistikk(buf) }
    case 'salgsgrid_varetrans': return { type, svinn: await parseVaretransaksjon(buf) }
    case 'regnskap_resultat': {
      let usynlig: Awaited<ReturnType<typeof parseUsynligSvinn>> | null = null
      try { usynlig = await parseUsynligSvinn(buf) } catch { usynlig = null }
      return { type, regnskap: await parseRegnskap(buf), stasjoner: await parseRegnskapStasjoner(buf), usynlig }
    }
    default: return null
  }
}

export function KlientOpplaster() {
  const [filer, setFiler] = useState<FilRad[]>([])
  const [kjorer, setKjorer] = useState(false)

  async function kjor(valgte: File[]) {
    if (valgte.length === 0) return
    setKjorer(true)
    setFiler(valgte.map((f) => ({ navn: f.name, tilstand: 'venter' as Tilstand })))
    const sett = (i: number, tilstand: Tilstand, melding?: string) =>
      setFiler((prev) => prev.map((x, j) => (j === i ? { ...x, tilstand, melding } : x)))

    for (let i = 0; i < valgte.length; i++) {
      try {
        if (valgte[i].size > FOR_STOR) {
          sett(i, 'hoppet', `${Math.round(valgte[i].size / 1024 / 1024)} MB — bruk drop-zonen under, den parser på server`)
          continue
        }
        sett(i, 'parser')
        const buf = await valgte[i].arrayBuffer()
        const payload = await byggPayload(buf)
        if (!payload) { sett(i, 'feilet', 'Ukjent/ustøttet filtype'); continue }
        const sha = await sha256Hex(buf)
        sett(i, 'lagrer')
        const res = await importerForhandsparset({ filnavn: valgte[i].name, sha256: sha, storrelse: valgte[i].size, payload })
        if (res.hoppet) sett(i, 'hoppet', 'Allerede importert')
        else if (res.ok) sett(i, 'ferdig', `${res.antallRader ?? 0} linjer`)
        else sett(i, 'feilet', res.feil)
      } catch (e) {
        sett(i, 'feilet', e instanceof Error ? e.message : String(e))
      }
    }
    setKjorer(false)
  }

  const ferdige = filer.filter((f) => f.tilstand === 'ferdig').length
  const feilede = filer.filter((f) => f.tilstand === 'feilet').length
  const hoppede = filer.filter((f) => f.tilstand === 'hoppet').length

  return (
    <div className="klient-opplaster">
      <input
        type="file"
        multiple
        accept=".csv,.txt,.xlsx,.xls"
        disabled={kjorer}
        onChange={(e) => kjor([...(e.target.files ?? [])])}
      />
      <p className="undertittel">Filene parses lokalt i nettleseren din og importeres én og én — store/mange filer timer aldri ut, og én rar fil stopper ikke resten. Ideelt for onboarding (mange salgsdager om gangen).</p>

      {filer.length > 0 && (
        <>
          <p className="undertittel">
            {kjorer ? 'Behandler …' : 'Ferdig.'} {ferdige} importert{hoppede ? ` · ${hoppede} hoppet over` : ''}{feilede ? ` · ${feilede} feilet` : ''} av {filer.length}.
          </p>
          <ul className="arr-liste">
            {filer.map((f, i) => (
              <li key={i}>
                <span>{f.navn} {f.melding ? <span className="undertittel">· {f.melding}</span> : null}</span>
                <span className={`status-pip ${PIP[f.tilstand]}`}>{ETIKETT[f.tilstand]}</span>
              </li>
            ))}
          </ul>
        </>
      )}
    </div>
  )
}
