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
import { URL_HODE } from '@/lib/supabase/proxy'

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

  // Stasjonskonteksten.
  //
  // URL-EN KOMMER FRA ET FORESPØRSELSHODE, ikke fra searchParams — en
  // layout får dem ikke. Uten den kunne ikke skallet vite at siden under
  // sto på en annen stasjon, og det var nettopp feilen trinn 09 lukker.
  //
  // Skallet og siden kaller nå samme funksjon med samme URL og samme
  // informasjonskapsel. Da kan de ikke svare forskjellig.
  const { headers } = await import('next/headers')
  const urlHode = (await headers()).get(URL_HODE) ?? ''
  const [sti, sokestreng = ''] = urlHode.split('?')
  const kontekst = await stasjonskontekst(
    supabase, sti || '/', bruker.rolle, new URLSearchParams(sokestreng),
  )

  const seksjoner = SEKSJONER.map((s) => ({
    ...s,
    punkter: s.punkter.filter((p) => p.roller.includes(bruker.rolle)),
  })).filter((s) => s.punkter.length > 0)

  // Tableten får sin egen mørke verden — aldri admin-skallet. PIN/vakt gjelder
  // KUN tableten; admin og butikksjef logger inn som seg selv (ingen vakt).
  if (bruker.rolle === 'butikkbruker_tablet') {
    const aktivAnsatt = await lesAktivAnsatt(supabase)
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
      brukerId={bruker.id}
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
