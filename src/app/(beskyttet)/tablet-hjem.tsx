import Link from 'next/link'
import { TabletHero } from './tablet-hero'

const TILES = [
  { sti: '/rutiner', tekst: 'Rutiner', ikon: '✅' },
  { sti: '/sjekkpunkt', tekst: 'Sjekkpunkt', ikon: '☑️' },
  { sti: '/ikmat', tekst: 'IK-mat', ikon: '🌡️' },
  { sti: '/avvik', tekst: 'Avvik', ikon: '⚠️' },
  { sti: '/puls', tekst: 'Puls', ikon: '💙' },
  { sti: '/merker', tekst: 'Merker', ikon: '🏅' },
]

export function TabletHjem({ navn, streak }: { navn?: string; streak: number }) {
  return (
    <>
      <TabletHero navn={navn} streak={streak} />
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
