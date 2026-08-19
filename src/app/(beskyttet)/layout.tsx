import { redirect } from 'next/navigation'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { mfaHandling } from '@/lib/auth/mfa'
import { lesAktivAnsatt } from '@/lib/ansatt'
import { TabletSkall } from './tablet-skall'
import { Appskall } from './appskall'
import { OversettProvider } from './oversett-kontekst'
import { SEKSJONER } from './navigasjon'
import { stasjonskontekst } from '@/lib/stasjonskontekst'

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

  // Stasjonskonteksten. Eieren kan se porteføljen samlet; butikksjefen
  // har som regel én stasjon og skal da ikke se noen velger i det hele
  // tatt. Samme oppslag og samme prioritering som før — de fire linjene
  // bor nå i primitiven, der sidene også kan hente dem.
  const kontekst = await stasjonskontekst(supabase, bruker.rolle)
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

  return (
    <Appskall
      rolle={bruker.rolle}
      navn={bruker.fulltNavn ?? bruker.epost ?? ''}
      uleste={uleste ?? 0}
      kontekst={kontekst}
      seksjoner={seksjoner.map((s) => ({
        tittel: s.tittel,
        punkter: s.punkter.map((p) => ({ sti: p.sti, tekst: p.tekst })),
      }))}
    >
      {children}
    </Appskall>
  )
}
