import Link from 'next/link'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { loggUt } from '@/lib/auth/handlinger'
import { ROLLE_ETIKETT, type Brukerrolle } from '@/lib/auth/typer'
import { lesAktivAnsatt } from '@/lib/ansatt'
import { Vakt } from './vakt'

// Venstremeny gruppert i seksjoner (§12 Fluent-stil; §3 rollestyrt UI).
type Punkt = { sti: string; tekst: string; roller: Brukerrolle[] }
const A: Brukerrolle = 'retailer_admin'
const B: Brukerrolle = 'butikksjef'
const T: Brukerrolle = 'butikkbruker_tablet'

const SEKSJONER: { tittel: string; punkter: Punkt[] }[] = [
  {
    tittel: '',
    punkter: [{ sti: '/oversikt', tekst: 'Oversikt', roller: [A, B] }],
  },
  {
    tittel: 'Analyse',
    punkter: [
      { sti: '/salg', tekst: 'Salg', roller: [A, B] },
      { sti: '/timesalg', tekst: 'Timesalg', roller: [A, B] },
      { sti: '/produksjonsplan', tekst: 'Produksjonsplan', roller: [A, B] },
      { sti: '/svinn', tekst: 'Svinn', roller: [A, B] },
      { sti: '/kasserer', tekst: 'Kasserer', roller: [A, B] },
      { sti: '/vaer', tekst: 'Vær', roller: [A, B] },
      { sti: '/regnskap', tekst: 'Regnskap', roller: [A] },
      { sti: '/analyse', tekst: 'Regnskapsanalyse', roller: [A] },
    ],
  },
  {
    tittel: 'AI & engasjement',
    punkter: [
      { sti: '/assistent', tekst: 'Assistent', roller: [A, B] },
      { sti: '/fokus', tekst: 'Fokus', roller: [A, B] },
      { sti: '/lederstotte', tekst: 'Lederstøtte', roller: [A, B] },
      { sti: '/konkurranser', tekst: 'Konkurranser', roller: [A, B] },
      { sti: '/puls', tekst: 'Puls', roller: [A, B, T] },
      { sti: '/merker', tekst: 'Merker', roller: [A, B, T] },
    ],
  },
  {
    tittel: 'Drift',
    punkter: [
      { sti: '/oppgaver', tekst: 'Oppgaver', roller: [A, B] },
      { sti: '/rutiner', tekst: 'Rutiner', roller: [A, B, T] },
      { sti: '/sjekkpunkt', tekst: 'Sjekkpunkt', roller: [A, B, T] },
      { sti: '/ikmat', tekst: 'IK-mat', roller: [A, B, T] },
      { sti: '/avvik', tekst: 'Avvik', roller: [A, B, T] },
      { sti: '/opplaring', tekst: 'Opplæring', roller: [A, B] },
      { sti: '/ansatte', tekst: 'Ansatte', roller: [A, B] },
    ],
  },
  {
    tittel: 'Premium',
    punkter: [{ sti: '/avtalevokter', tekst: 'Avtalevokter', roller: [A] }],
  },
  {
    tittel: 'Innstillinger',
    punkter: [
      { sti: '/import', tekst: 'Import', roller: [A] },
      { sti: '/stasjoner', tekst: 'Stasjoner', roller: [A] },
      { sti: '/abonnement', tekst: 'Abonnement', roller: [A] },
    ],
  },
  {
    tittel: 'Plattform',
    punkter: [{ sti: '/redaktor', tekst: 'Publisering', roller: ['plattform_redaktor'] }],
  },
]

export default async function BeskyttetLayout({
  children,
}: {
  children: React.ReactNode
}) {
  // Gate + henter visningsdata. RLS er den egentlige muren; dette er laget over.
  const bruker = await hentInnloggetBruker()
  const supabase = await lagSupabaseServerKlient()
  const { count: uleste } = await supabase
    .from('varsler')
    .select('*', { count: 'exact', head: true })
    .eq('lest', false)
  const aktivAnsatt = await lesAktivAnsatt()
  const seksjoner = SEKSJONER.map((s) => ({
    ...s,
    punkter: s.punkter.filter((p) => p.roller.includes(bruker.rolle)),
  })).filter((s) => s.punkter.length > 0)

  return (
    <div className="skall">
      <aside className="sidemeny">
        <div className="merke">Sentiqa</div>
        <nav>
          {seksjoner.map((s) => (
            <div className="meny-seksjon" key={s.tittel || 'topp'}>
              {s.tittel ? <span className="meny-tittel">{s.tittel}</span> : null}
              {s.punkter.map((p) => (
                <Link key={p.sti} href={p.sti}>{p.tekst}</Link>
              ))}
            </div>
          ))}
        </nav>
      </aside>

      <div className="hoved">
        <header className="toppstripe">
          <span className="bruker">
            {bruker.fulltNavn ?? bruker.epost}
            <span className="rolle-pip">{ROLLE_ETIKETT[bruker.rolle]}</span>
          </span>
          <div className="topp-hoyre">
            <Vakt aktiv={aktivAnsatt} />
            <Link href="/varsler" className="klokke-lenke" aria-label="Varsler">
              🔔
              {(uleste ?? 0) > 0 && <span className="varsel-teller">{uleste}</span>}
            </Link>
            <form action={loggUt}>
              <button type="submit" className="logg-ut">Logg ut</button>
            </form>
          </div>
        </header>
        <main className="innhold">{children}</main>
      </div>
    </div>
  )
}
