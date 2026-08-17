import Link from 'next/link'
import { redirect } from 'next/navigation'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { mfaHandling } from '@/lib/auth/mfa'
import { loggUt } from '@/lib/auth/handlinger'
import { ROLLE_ETIKETT, type Brukerrolle } from '@/lib/auth/typer'
import { lesAktivAnsatt } from '@/lib/ansatt'
import { erLeder } from '@/lib/auth/roller'
import { Sidemeny } from './sidemeny'
import { TabletSkall } from './tablet-skall'
import { AiBoble } from './ai-boble'
import { Kommandopalett } from './kommandopalett'
import { OversettProvider } from './oversett-kontekst'

// Venstremeny gruppert i seksjoner (§12 Fluent-stil; §3 rollestyrt UI).
type Punkt = { sti: string; tekst: string; roller: Brukerrolle[] }
const A: Brukerrolle = 'retailer_admin'
const B: Brukerrolle = 'butikksjef'
const T: Brukerrolle = 'butikkbruker_tablet'

// Gruppert etter hva brukeren HOLDER PÅ MED, ikke etter hvilken modul noe
// hører til. Tidligere lå 32 punkter flatt fordelt på «Analyse», «AI &
// engasjement», «Drift» og «Innstillinger» — inndelinger som beskriver
// systemet, ikke arbeidet. En butikksjef som lurer på om produksjonsplanen
// traff, tenker ikke «det er analyse».
//
// Ingen ruter er fjernet og ingen roller er endret; punktene er flyttet.
// Tableten ser aldri denne menyen (den returnerer tidlig med TabletSkall).
const SEKSJONER: { tittel: string; punkter: Punkt[] }[] = [
  {
    tittel: '',
    punkter: [
      { sti: '/oversikt', tekst: 'I dag', roller: [A, B] },
    ],
  },
  {
    // Det som skjer på stasjonen nå og de nærmeste dagene.
    tittel: 'Drift',
    punkter: [
      { sti: '/produksjonsplan', tekst: 'Produksjonsplan', roller: [A, B] },
      { sti: '/utsolgt', tekst: 'Mulig utsolgt', roller: [A, B] },
      { sti: '/bemanning', tekst: 'Bemanning', roller: [A, B] },
      // En prognose er det motsatte av "det som har skjedd" - den hoerer hjemme
      // her sammen med produksjonsplan og bemanning.
      { sti: '/salgsprognose', tekst: 'Salgsprognose', roller: [A, B] },
      { sti: '/oppgaver', tekst: 'Oppgaver', roller: [A, B] },
      { sti: '/rutiner', tekst: 'Rutiner', roller: [T] },
      { sti: '/rutiner/oversikt', tekst: 'Rutineoversikt', roller: [A, B] },
      { sti: '/rutiner/min', tekst: 'Min sjekkliste', roller: [A, B] },
      { sti: '/rutiner/oppsett', tekst: 'Rutineoppsett', roller: [B] },
      { sti: '/sjekkpunkt', tekst: 'Sjekkpunkt', roller: [A, B] },
      { sti: '/ikmat', tekst: 'IK-mat & avvik', roller: [A, B, T] },
      { sti: '/ikmat/oppsett', tekst: 'IK-mat oppsett', roller: [A, B] },
      { sti: '/svinn', tekst: 'Svinn', roller: [A, B] },
      { sti: '/arrangementer', tekst: 'Arrangementer', roller: [A] },
    ],
  },
  {
    // Det som allerede har skjedd, til og med siste salgsdag.
    tittel: 'Resultater',
    punkter: [
      { sti: '/salg', tekst: 'Salg', roller: [A, B] },
      { sti: '/timesalg', tekst: 'Timesalg', roller: [A, B] },
      { sti: '/regnskap', tekst: 'Regnskap', roller: [A, B] },
      { sti: '/lonn', tekst: 'Lønnsgrunnlag', roller: [A, B] },
      { sti: '/analyse', tekst: 'Regnskapsanalyse', roller: [A] },
      { sti: '/maaling', tekst: 'Måling', roller: [A, B] },
      { sti: '/kasserer', tekst: 'Kasserer', roller: [A, B] },
      { sti: '/produksjonsplan/treffsikkerhet', tekst: 'Treffsikkerhet', roller: [A, B] },
    ],
  },
  {
    // Menneskene: hva de skal fokusere på, hva de sier, hva de kan.
    tittel: 'Team',
    punkter: [
      { sti: '/fokus', tekst: 'Fokus', roller: [A, B] },
      { sti: '/tilbakemeldinger', tekst: 'Tilbakemeldinger', roller: [A, B] },
      { sti: '/meldinger', tekst: 'Tablet-meldinger', roller: [A, B] },
      { sti: '/ansatte', tekst: 'Ansatte', roller: [A, B] },
      { sti: '/kontrakt', tekst: 'Arbeidsavtaler', roller: [A, B] },
      { sti: '/opplaring', tekst: 'Opplæring', roller: [B] },
      { sti: '/skills', tekst: 'Skills-score', roller: [A, B] },
      { sti: '/merker', tekst: 'Merker', roller: [A, B, T] },
      { sti: '/mine-opplysninger', tekst: 'Slik måler vi', roller: [A, B, T] },
      { sti: '/konkurranser', tekst: 'Konkurranser', roller: [A, B] },
      { sti: '/premier', tekst: 'Premiesaldo', roller: [A, B] },
      { sti: '/puls', tekst: 'Puls', roller: [A, B] },
      { sti: '/lederstotte', tekst: 'Lederstøtte', roller: [A, B] },
    ],
  },
  {
    tittel: 'Mer',
    punkter: [
      { sti: '/nyheter', tekst: 'Nyheter', roller: [A, B, T] },
      { sti: '/anvisninger', tekst: 'Anvisninger', roller: [A, B] },
      { sti: '/import', tekst: 'Import', roller: [A] },
      { sti: '/dekning', tekst: 'Datadekning', roller: [A] },
      { sti: '/stasjoner', tekst: 'Stasjoner', roller: [A] },
      { sti: '/brukere', tekst: 'Brukere', roller: [A] },
      { sti: '/persondata', tekst: 'Persondata', roller: [A, B] },
    ],
  },
  {
    tittel: 'Plattform',
    punkter: [
      { sti: '/plattform', tekst: 'Plattform-oversikt', roller: ['plattform_redaktor'] },
      { sti: '/trafikk', tekst: 'Trafikk', roller: ['plattform_redaktor'] },
      { sti: '/kampanjer', tekst: 'Kampanjer', roller: ['plattform_redaktor'] },
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

  // To-faktor-gate (§3, §15). Tablet er unntatt (delt PIN-enhet). Alle andre:
  //   steg_opp  → har faktor, men sesjonen er aal1 → skriv inn engangskode
  //   innruller → privilegert rolle uten faktor → tving oppsett før innslipp
  if (bruker.rolle !== 'butikkbruker_tablet') {
    const handling = await mfaHandling(supabase, bruker.rolle)
    if (handling === 'steg_opp') redirect('/logg-inn/totp')
    if (handling === 'innruller') redirect('/sikkerhet?paakrevd=1')
  }

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
          {erLeder(bruker.rolle) && (
            <Kommandopalett
              punkter={menyData.flatMap((s) =>
                s.punkter.map((p) => ({ ...p, gruppe: s.tittel })),
              )}
            />
          )}
          <span className="bruker">
            {bruker.fulltNavn ?? bruker.epost}
            <span className="rolle-pip">{ROLLE_ETIKETT[bruker.rolle]}</span>
          </span>
          <div className="topp-hoyre">
            <Link href="/varsler" className="klokke-lenke" aria-label="Varsler">
              🔔
              {(uleste ?? 0) > 0 && <span className="varsel-teller">{uleste}</span>}
            </Link>
            <Link href="/sikkerhet" className="klokke-lenke" aria-label="Sikkerhet" title="To-faktor / sikkerhet">🔒</Link>
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
