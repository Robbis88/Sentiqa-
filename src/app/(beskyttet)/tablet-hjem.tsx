import Link from 'next/link'
import { kr } from '@/lib/format'
import type { HjemData } from '@/lib/tablethjem'
import { TabletHero } from './tablet-hero'
import { PulsPopp } from './puls-popp'
import { SendTilSjef } from './send-til-sjef'
import { VekstKort } from './vekst-kort'

const TILES = [
  { sti: '/rutiner', tekst: 'Rutiner', ikon: '✅' },
  { sti: '/sjekkpunkt', tekst: 'Sjekkpunkt', ikon: '☑️' },
  { sti: '/ikmat', tekst: 'IK-mat & avvik', ikon: '🌡️' },
  { sti: '/merker', tekst: 'Merker', ikon: '🏅' },
  { sti: '/anvisninger', tekst: 'Anvisninger', ikon: '📖' },
]

type Melding = { id: string; tekst: string; viktig: boolean }
type PulsRunde = { id: string; tekst: string } | null

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

      {hjem.vekst && <VekstKort metrikker={hjem.vekst.metrikker} />}

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
