import Link from 'next/link'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { loggUt } from '@/lib/auth/handlinger'
import { ROLLE_ETIKETT, type Brukerrolle } from '@/lib/auth/typer'
import { lesAktivAnsatt } from '@/lib/ansatt'
import { erLeder } from '@/lib/auth/roller'
import { Sidemeny } from './sidemeny'
import { TabletSkall } from './tablet-skall'
import { AiBoble } from './ai-boble'
import { OversettProvider } from './oversett-kontekst'

// Venstremeny gruppert i seksjoner (§12 Fluent-stil; §3 rollestyrt UI).
type Punkt = { sti: string; tekst: string; roller: Brukerrolle[] }
const A: Brukerrolle = 'retailer_admin'
const B: Brukerrolle = 'butikksjef'
const T: Brukerrolle = 'butikkbruker_tablet'

const SEKSJONER: { tittel: string; punkter: Punkt[] }[] = [
  {
    tittel: '',
    punkter: [
      { sti: '/oversikt', tekst: 'Oversikt', roller: [A, B] },
      { sti: '/nyheter', tekst: 'Nyheter', roller: [A, B, T] },
    ],
  },
  {
    tittel: 'Analyse',
    punkter: [
      { sti: '/salg', tekst: 'Salg', roller: [A, B] },
      { sti: '/timesalg', tekst: 'Timesalg', roller: [A, B] },
      { sti: '/produksjonsplan', tekst: 'Produksjonsplan', roller: [A, B] },
      { sti: '/salgsprognose', tekst: 'Salgsprognose', roller: [A, B] },
      { sti: '/arrangementer', tekst: 'Arrangementer', roller: [A] },
      { sti: '/svinn', tekst: 'Svinn', roller: [A, B] },
      { sti: '/kasserer', tekst: 'Kasserer', roller: [A, B] },
      { sti: '/regnskap', tekst: 'Regnskap', roller: [A, B] },
      { sti: '/analyse', tekst: 'Regnskapsanalyse', roller: [A] },
    ],
  },
  {
    tittel: 'AI & engasjement',
    punkter: [
      { sti: '/fokus', tekst: 'Fokus', roller: [A, B] },
      { sti: '/lederstotte', tekst: 'Lederstøtte', roller: [A, B] },
      { sti: '/konkurranser', tekst: 'Konkurranser', roller: [A, B] },
      { sti: '/puls', tekst: 'Puls', roller: [A, B] },
      { sti: '/merker', tekst: 'Merker', roller: [A, B, T] },
    ],
  },
  {
    tittel: 'Drift',
    punkter: [
      { sti: '/oppgaver', tekst: 'Oppgaver', roller: [A, B] },
      { sti: '/rutiner', tekst: 'Rutiner', roller: [T] },
      { sti: '/rutiner/oppsett', tekst: 'Rutineoppsett', roller: [B] },
      { sti: '/rutiner/oversikt', tekst: 'Rutineoversikt', roller: [A, B] },
      { sti: '/rutiner/min', tekst: 'Min sjekkliste', roller: [A, B] },
      { sti: '/sjekkpunkt', tekst: 'Sjekkpunkt', roller: [A, B] },
      { sti: '/ikmat', tekst: 'IK-mat & avvik', roller: [A, B, T] },
      { sti: '/ikmat/oppsett', tekst: 'IK-mat oppsett', roller: [A, B] },
      { sti: '/anvisninger', tekst: 'Anvisninger', roller: [A, B] },
      { sti: '/meldinger', tekst: 'Tablet-meldinger', roller: [A, B] },
      { sti: '/tilbakemeldinger', tekst: 'Tilbakemeldinger', roller: [A, B] },
      { sti: '/skills', tekst: 'Skills-score', roller: [A, B] },
      { sti: '/premier', tekst: 'Premiesaldo', roller: [A, B] },
      { sti: '/opplaring', tekst: 'Opplæring', roller: [B] },
      { sti: '/ansatte', tekst: 'Ansatte', roller: [A, B] },
    ],
  },
  {
    tittel: 'Innstillinger',
    punkter: [
      { sti: '/import', tekst: 'Import', roller: [A] },
      { sti: '/dekning', tekst: 'Datadekning', roller: [A] },
      { sti: '/stasjoner', tekst: 'Stasjoner', roller: [A] },
      { sti: '/brukere', tekst: 'Brukere', roller: [A] },
    ],
  },
  {
    tittel: 'Plattform',
    punkter: [
      { sti: '/plattform', tekst: 'Plattform-oversikt', roller: ['plattform_redaktor'] },
      { sti: '/redaktor', tekst: 'Publisering', roller: ['plattform_redaktor'] },
      { sti: '/kunnskap', tekst: 'Kunnskapsbase', roller: ['plattform_redaktor'] },
    ],
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
  const seksjoner = SEKSJONER.map((s) => ({
    ...s,
    punkter: s.punkter.filter((p) => p.roller.includes(bruker.rolle)),
  })).filter((s) => s.punkter.length > 0)

  // Tableten får sin egen mørke verden — aldri admin-skallet. PIN/vakt gjelder
  // KUN tableten; admin og butikksjef logger inn som seg selv (ingen vakt).
  if (bruker.rolle === 'butikkbruker_tablet') {
    const aktivAnsatt = await lesAktivAnsatt()
    const { cookies } = await import('next/headers')
    const sprak = (await cookies()).get('sprak')?.value ?? 'no'
    const { oversettTabletOrd } = await import('@/lib/oversett')
    const ord = await oversettTabletOrd(sprak)
    return (
      <OversettProvider ord={ord}>
        <TabletSkall aktivAnsatt={aktivAnsatt} uleste={uleste ?? 0} sprak={sprak} ord={ord}>
          {children}
        </TabletSkall>
      </OversettProvider>
    )
  }

  const menyData = seksjoner.map((s) => ({
    tittel: s.tittel,
    punkter: s.punkter.map((p) => ({ sti: p.sti, tekst: p.tekst })),
  }))

  return (
    <div className="skall">
      <Sidemeny seksjoner={menyData} />

      <div className="hoved">
        <header className="toppstripe">
          <span className="bruker">
            {bruker.fulltNavn ?? bruker.epost}
            <span className="rolle-pip">{ROLLE_ETIKETT[bruker.rolle]}</span>
          </span>
          <div className="topp-hoyre">
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
      {erLeder(bruker.rolle) && <AiBoble navn={bruker.fulltNavn?.split(' ')[0]} />}
    </div>
  )
}
