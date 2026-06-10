import Link from 'next/link'
import { kr } from '@/lib/format'
import type { HjemData } from '@/lib/tablethjem'
import { TabletHero } from './tablet-hero'
import { PulsPopp } from './puls-popp'
import { SendTilSjef } from './send-til-sjef'

const TILES = [
  { sti: '/rutiner', tekst: 'Rutiner', ikon: '✅' },
  { sti: '/sjekkpunkt', tekst: 'Sjekkpunkt', ikon: '☑️' },
  { sti: '/ikmat', tekst: 'IK-mat & avvik', ikon: '🌡️' },
  { sti: '/merker', tekst: 'Merker', ikon: '🏅' },
  { sti: '/anvisninger', tekst: 'Anvisninger', ikon: '📖' },
]

type Melding = { id: string; tekst: string; viktig: boolean }
type PulsRunde = { id: string; tekst: string } | null

function VekstRad({ tittel, naa, ifjor }: { tittel: string; naa: number; ifjor: number }) {
  const diff = naa - ifjor
  const pst = ifjor > 0 ? Math.round((diff / ifjor) * 1000) / 10 : null
  const opp = diff >= 0
  return (
    <div className="vekst-rad">
      <div className="vekst-venstre">
        <span className="vekst-merke">{tittel}</span>
        <span className="vekst-tall">{kr.format(naa)}</span>
        {ifjor > 0 && <span className="undertittel">i fjor: {kr.format(ifjor)}</span>}
      </div>
      {ifjor > 0 && (
        <span className={`vekst-diff ${opp ? 'opp' : 'ned'}`}>{opp ? '▲' : '▼'} {kr.format(Math.abs(diff))}{pst != null ? ` (${opp ? '+' : '−'}${Math.abs(pst)} %)` : ''}</span>
      )}
    </div>
  )
}

export function TabletHjem({
  navn,
  streak,
  meldinger = [],
  pulsRunde = null,
  hjem,
}: {
  navn?: string
  streak: number
  meldinger?: Melding[]
  pulsRunde?: PulsRunde
  hjem: HjemData
}) {
  return (
    <>
      <PulsPopp runde={pulsRunde} />

      {meldinger.length > 0 && (
        <div className="tablet-meldinger">
          {meldinger.map((m) => (
            <div className={`tablet-melding ${m.viktig ? 'viktig' : ''}`} key={m.id}>
              <span className="tablet-melding-ikon">{m.viktig ? '❗' : '📣'}</span>
              <span>{m.tekst}</span>
            </div>
          ))}
        </div>
      )}

      <TabletHero navn={navn} streak={streak} />

      <div className="tablet-tiles">
        {TILES.map((t) => (
          <Link key={t.sti} href={t.sti} className="tablet-tile">
            <span className="tablet-tile-ikon">{t.ikon}</span>
            <span className="tablet-tile-tekst">{t.tekst}</span>
          </Link>
        ))}
      </div>

      {hjem.vekst && (hjem.vekst.sisteIfjor > 0 || hjem.vekst.mtdIfjor > 0) && (
        <section className="tablet-seksjon vekst">
          <h2>📈 Vår vekst mot fjoråret</h2>
          <VekstRad tittel="Siste salgsdag" naa={hjem.vekst.sisteOms} ifjor={hjem.vekst.sisteIfjor} />
          <VekstRad tittel="Måneden hittil" naa={hjem.vekst.mtdOms} ifjor={hjem.vekst.mtdIfjor} />
        </section>
      )}

      <section className="tablet-seksjon premie">
        <h2>🎁 Vår premiesaldo</h2>
        <div className="premie-saldo">
          <div><span className="premie-tall">{kr.format(hjem.premie.vunnet)}</span><span className="premie-merke">🏆 Vunnet</span></div>
          <div><span className="premie-tall">{kr.format(hjem.premie.brukt)}</span><span className="premie-merke">🛒 Brukt</span></div>
          <div><span className="premie-tall gronn">{kr.format(hjem.premie.igjen)}</span><span className="premie-merke">💰 Igjen</span></div>
        </div>
      </section>

      {hjem.skills && (
        <section className="tablet-seksjon skills">
          <span className="skills-merke">🏆 Skills-score</span>
          <span className="skills-tall">{hjem.skills.prosent} %</span>
          <span className="skills-tekst">{hjem.skills.tekst}</span>
        </section>
      )}

      <div className="tablet-seksjon send-sjef-boks">
        <SendTilSjef />
      </div>
    </>
  )
}
