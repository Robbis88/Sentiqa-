'use client'
import { useRef, useState } from 'react'
import { opprettMalekort, sokVarerAksjon, type MalekortTilstand } from './handlinger'
import type { VareNode, VareTreff } from '@/lib/varehierarki'

type ScopeItem = { nivaa: 'avdeling' | 'vareomrade' | 'varegruppe' | 'ean'; kode: string; navn: string }

export function MalekortSkjema({ tre }: { tre: VareNode[] }) {
  const [valgt, setValgt] = useState<ScopeItem[]>([])
  const [tilstand, setTilstand] = useState<MalekortTilstand>()
  const [venter, setVenter] = useState(false)
  const formRef = useRef<HTMLFormElement>(null)

  const [q, setQ] = useState('')
  const [treff, setTreff] = useState<VareTreff[]>([])
  const [soker, setSoker] = useState(false)

  // Reset skjer her i action-handleren (ikke i en effekt) etter at serveren
  // har bekreftet lagring — unngår kaskaderender fra setState-i-useEffect.
  async function lagre(formData: FormData) {
    setVenter(true)
    const res = await opprettMalekort(undefined, formData)
    setTilstand(res)
    setVenter(false)
    if (res?.ok) {
      setValgt([])
      setQ('')
      setTreff([])
      formRef.current?.reset()
    }
  }

  const erValgt = (nivaa: string, kode: string) => valgt.some((v) => v.nivaa === nivaa && v.kode === kode)
  const toggle = (item: ScopeItem) =>
    setValgt((vs) =>
      erValgt(item.nivaa, item.kode)
        ? vs.filter((v) => !(v.nivaa === item.nivaa && v.kode === item.kode))
        : [...vs, item],
    )
  const fjern = (nivaa: string, kode: string) =>
    setValgt((vs) => vs.filter((v) => !(v.nivaa === nivaa && v.kode === kode)))

  async function sok() {
    if (q.trim().length < 2) return
    setSoker(true)
    setTreff(await sokVarerAksjon(q))
    setSoker(false)
  }

  return (
    <form action={lagre} ref={formRef} className="skjema malekort-skjema">
      <input type="hidden" name="scope" value={JSON.stringify(valgt)} />

      <label className="felt">
        <span>Navn</span>
        <input name="navn" placeholder="Snittkjøp pølser" required />
      </label>

      <label className="felt">
        <span>Hva måler vi?</span>
        <select name="metrikk" defaultValue="omsetning">
          <option value="omsetning">Omsetning</option>
          <option value="antall">Antall solgt</option>
          <option value="brutto">Bruttofortjeneste</option>
          <option value="snittpris_kunde">Snittpris per kunde</option>
          <option value="snittbong">Snittbong</option>
          <option value="kunder">Kunder</option>
        </select>
      </label>

      <fieldset className="felt scope-felt">
        <span>På hvilke varer? <span className="undertittel">(ingen valg = alt salg)</span></span>
        <div className="scope-tre">
          {tre.length === 0 ? (
            <p className="undertittel">Ingen salgsdata ennå — last opp salgsstatistikk først.</p>
          ) : (
            tre.map((avd) => <Node key={avd.kode} node={avd} erValgt={erValgt} toggle={toggle} />)
          )}
        </div>
        <div className="scope-sok">
          <input
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="🔍 søk enkeltvare (f.eks. grillpølse)"
            onKeyDown={(e) => { if (e.key === 'Enter') { e.preventDefault(); sok() } }}
          />
          <button type="button" className="liten" onClick={sok} disabled={soker}>
            {soker ? 'Søker …' : 'Søk'}
          </button>
        </div>
        {treff.length > 0 && (
          <ul className="scope-treff">
            {treff.map((t) => (
              <li key={t.ean}>
                <span>{t.varenavn}{t.varegruppe ? ` · ${t.varegruppe}` : ''}</span>
                <button
                  type="button"
                  className="liten"
                  disabled={erValgt('ean', t.ean)}
                  onClick={() => toggle({ nivaa: 'ean', kode: t.ean, navn: t.varenavn })}
                >
                  {erValgt('ean', t.ean) ? '✓' : '+ legg til'}
                </button>
              </li>
            ))}
          </ul>
        )}
        {valgt.length > 0 && (
          <div className="scope-valgt">
            {valgt.map((v) => (
              <span key={`${v.nivaa}-${v.kode}`} className="scope-chip">
                {v.navn}
                <button type="button" onClick={() => fjern(v.nivaa, v.kode)} aria-label="Fjern">✕</button>
              </span>
            ))}
          </div>
        )}
      </fieldset>

      <div className="malekort-rad-2">
        <label className="felt">
          <span>Periode</span>
          <select name="periode" defaultValue="uke">
            <option value="uke">Uke mot i fjor</option>
            <option value="maaned">Måned mot i fjor</option>
            <option value="rullende4uker">Rullende 4 uker</option>
          </select>
        </label>
        <label className="felt">
          <span>Sammenlign som</span>
          <select name="normalisering" defaultValue="per_kunde">
            <option value="per_kunde">Per kunde (rettferdig)</option>
            <option value="vekst_pst">Vekst % mot i fjor</option>
            <option value="ra">Rå sum</option>
          </select>
        </label>
        <label className="felt">
          <span>Best er</span>
          <select name="retning" defaultValue="hoy">
            <option value="hoy">Høyest øverst</option>
            <option value="lav">Lavest øverst</option>
          </select>
        </label>
      </div>

      <div className="malekort-valg">
        <label className="felt-avkrysning">
          <input type="checkbox" name="krev_fullstendig_periode" defaultChecked />
          <span>Vis kun fullstendige perioder (aldri halv uke — viktig for tablet)</span>
        </label>
        <label className="felt-avkrysning">
          <input type="checkbox" name="vis_butikksjef" defaultChecked />
          <span>Synlig for butikksjef</span>
        </label>
        <label className="felt-avkrysning">
          <input type="checkbox" name="vis_tablet" defaultChecked />
          <span>Synlig på tablet</span>
        </label>
        <label className="felt-avkrysning">
          <input type="checkbox" name="anonymiser" />
          <span>Skjul butikknavn (vis «Butikk #4»)</span>
        </label>
      </div>

      {tilstand?.feil ? <p role="alert" className="feil">{tilstand.feil}</p> : null}
      {tilstand?.ok ? <p className="ok-melding">✓ Målekort lagret.</p> : null}

      <button type="submit" disabled={venter}>{venter ? 'Lagrer …' : 'Lagre målekort'}</button>
    </form>
  )
}

function Node({
  node,
  erValgt,
  toggle,
}: {
  node: VareNode
  erValgt: (n: string, k: string) => boolean
  toggle: (i: ScopeItem) => void
}) {
  const avkrysning = (
    <label className="scope-node-rad" onClick={(e) => e.stopPropagation()}>
      <input
        type="checkbox"
        checked={erValgt(node.nivaa, node.kode)}
        onChange={() => toggle({ nivaa: node.nivaa, kode: node.kode, navn: node.navn })}
      />
      <span>{node.navn}</span>
    </label>
  )
  if (node.barn.length === 0) return avkrysning
  return (
    <details className="scope-gren">
      <summary>{avkrysning}</summary>
      <div className="scope-barn">
        {node.barn.map((b) => <Node key={b.kode} node={b} erValgt={erValgt} toggle={toggle} />)}
      </div>
    </details>
  )
}
