import Link from 'next/link'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { loggUt } from '@/lib/auth/handlinger'
import { ROLLE_ETIKETT, type Brukerrolle } from '@/lib/auth/typer'

// Venstremeny etter rolle (§12 Fluent-stil; §3 rollestyrt UI).
const MENY: { sti: string; tekst: string; roller: Brukerrolle[] }[] = [
  { sti: '/oversikt', tekst: 'Oversikt', roller: ['retailer_admin', 'butikksjef'] },
  { sti: '/assistent', tekst: 'Assistent', roller: ['retailer_admin', 'butikksjef'] },
  { sti: '/fokus', tekst: 'Fokus', roller: ['retailer_admin', 'butikksjef'] },
  { sti: '/salg', tekst: 'Salg', roller: ['retailer_admin', 'butikksjef'] },
  { sti: '/timesalg', tekst: 'Timesalg', roller: ['retailer_admin', 'butikksjef'] },
  { sti: '/svinn', tekst: 'Svinn', roller: ['retailer_admin', 'butikksjef'] },
  { sti: '/kasserer', tekst: 'Kasserer', roller: ['retailer_admin', 'butikksjef'] },
  { sti: '/regnskap', tekst: 'Regnskap', roller: ['retailer_admin'] },
  { sti: '/analyse', tekst: 'Analyse', roller: ['retailer_admin'] },
  { sti: '/import', tekst: 'Import', roller: ['retailer_admin'] },
  { sti: '/stasjoner', tekst: 'Stasjoner', roller: ['retailer_admin'] },
  { sti: '/redaktor', tekst: 'Publisering', roller: ['plattform_redaktor'] },
]

export default async function BeskyttetLayout({
  children,
}: {
  children: React.ReactNode
}) {
  // Gate + henter visningsdata. RLS er den egentlige muren; dette er laget over.
  const bruker = await hentInnloggetBruker()
  const meny = MENY.filter((m) => m.roller.includes(bruker.rolle))

  return (
    <div className="skall">
      <aside className="sidemeny">
        <div className="merke">Sentiqa</div>
        <nav>
          {meny.map((m) => (
            <Link key={m.sti} href={m.sti}>
              {m.tekst}
            </Link>
          ))}
        </nav>
      </aside>

      <div className="hoved">
        <header className="toppstripe">
          <span className="bruker">
            {bruker.fulltNavn ?? bruker.epost}
            <span className="rolle-pip">{ROLLE_ETIKETT[bruker.rolle]}</span>
          </span>
          <form action={loggUt}>
            <button type="submit" className="logg-ut">
              Logg ut
            </button>
          </form>
        </header>
        <main className="innhold">{children}</main>
      </div>
    </div>
  )
}
