import Link from 'next/link'
import { TabletHero } from './tablet-hero'
import { PulsPopp } from './puls-popp'

const TILES = [
  { sti: '/rutiner', tekst: 'Rutiner', ikon: '✅' },
  { sti: '/sjekkpunkt', tekst: 'Sjekkpunkt', ikon: '☑️' },
  { sti: '/ikmat', tekst: 'IK-mat', ikon: '🌡️' },
  { sti: '/avvik', tekst: 'Avvik', ikon: '⚠️' },
  { sti: '/puls', tekst: 'Puls', ikon: '💙' },
  { sti: '/merker', tekst: 'Merker', ikon: '🏅' },
  { sti: '/anvisninger', tekst: 'Anvisninger', ikon: '📖' },
  { sti: '/lenker', tekst: 'Lenker', ikon: '🔗' },
]

type Melding = { id: string; tekst: string; viktig: boolean }
type PulsRunde = { id: string; tekst: string } | null

export function TabletHjem({ navn, streak, meldinger = [], pulsRunde = null }: { navn?: string; streak: number; meldinger?: Melding[]; pulsRunde?: PulsRunde }) {
  return (
    <>
      <PulsPopp runde={pulsRunde} />
      <TabletHero navn={navn} streak={streak} />

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
      <div className="tablet-tiles">
        {TILES.map((t) => (
          <Link key={t.sti} href={t.sti} className="tablet-tile">
            <span className="tablet-tile-ikon">{t.ikon}</span>
            <span className="tablet-tile-tekst">{t.tekst}</span>
          </Link>
        ))}
      </div>
    </>
  )
}
