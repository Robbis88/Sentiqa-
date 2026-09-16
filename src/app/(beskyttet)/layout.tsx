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
import { SPALTE, monsterFor } from '@/lib/redesign/monstre'

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

  // Stasjonskonteksten.
  //
  // URL-EN KOMMER FRA ET FORESPØRSELSHODE, ikke fra searchParams — en
  // layout får dem ikke. Uten den kunne ikke skallet vite at siden under
  // sto på en annen stasjon, og det var nettopp feilen trinn 09 lukker.
  //
  // Skallet og siden kaller nå samme funksjon med samme URL og samme
  // informasjonskapsel. Da kan de ikke svare forskjellig.
  const { headers, cookies } = await import('next/headers')
  const urlHode = (await headers()).get(URL_HODE) ?? ''
  const [sti, sokestreng = ''] = urlHode.split('?')

  const erTablet = bruker.rolle === 'butikkbruker_tablet'
  const sprak = erTablet
    ? (await cookies()).get('sprak')?.value ?? 'no'
    : 'no'

  // ===================================================================
  // DE UAVHENGIGE LEDDENE SAMTIDIG
  // ===================================================================
  //
  // MÅLT, ikke antatt. Nettbrettets landingsside gjorde fire
  // nettverksrundturer på rad i denne layouten — 452–552 ms, der det
  // tregeste enkeltleddet var 140–179 ms. Rundt 312–372 ms var altså
  // ren venting, hver eneste render.
  //
  // De fire under har INGEN innbyrdes avhengighet: varseltellingen
  // trenger ikke stasjonene, stasjonene trenger ikke den aktive
  // ansatte, og oversettelsen trenger bare språkkapselen.
  //
  // HVA SOM IKKE ER MED, OG HVORFOR
  //
  //   `hentInnloggetBruker` står foran alt. Rollen avgjør både
  //   MFA-porten og hvilke av leddene under som i det hele tatt skal
  //   kjøre — den kan ikke gå samtidig med noe som leser den.
  //
  //   `mfaHandling` står også foran, med vilje. Den ender i en
  //   `redirect`, og en bruker som skal tvinges til steg-opp skal ikke
  //   utløse spørringer på veien ut. Å flytte den hit ville spart
  //   ingenting for nettbrettet — som hopper over den — og gitt bortkastet
  //   arbeid for alle andre.
  const [ulesteSvar, kontekst, aktivAnsatt, ord] = await Promise.all([
    supabase.from('varsler').select('*', { count: 'exact', head: true }).eq('lest', false),
    stasjonskontekst(supabase, sti || '/', bruker.rolle, new URLSearchParams(sokestreng)),
    erTablet ? lesAktivAnsatt(supabase) : Promise.resolve(null),
    erTablet
      ? import('@/lib/oversett').then((m) => m.oversettTabletOrd(sprak))
      : Promise.resolve(null),
  ])
  const uleste = ulesteSvar.count

  // Innholdsspaltens bredde foelger rutens moenster, ikke siden. Ruta uten
  // moenster finnes ikke - vakthunden krever at hver rute staar i
  // `RUTEMONSTER` - men skjer det likevel, er smal det trygge utfallet:
  // en side som er for smal ser rar ut, en som er for bred er uleselig.
  const monster = monsterFor(sti || '/')
  const bredde = monster ? SPALTE[monster] : 'smal'

  const seksjoner = SEKSJONER.map((s) => ({
    ...s,
    punkter: s.punkter.filter((p) => p.roller.includes(bruker.rolle)),
  })).filter((s) => s.punkter.length > 0)

  // Tableten får sin egen mørke verden — aldri admin-skallet. PIN/vakt gjelder
  // KUN tableten; admin og butikksjef logger inn som seg selv (ingen vakt).
  if (erTablet) {
    // Hentet parallelt over. `ord` er aldri null for et nettbrett —
    // `oversettTabletOrd` gir norsk identitet når språket er `no`.
    return (
      <OversettProvider ord={ord ?? {}}>
        <TabletSkall aktivAnsatt={aktivAnsatt} uleste={uleste ?? 0} sprak={sprak} ord={ord ?? {}}>
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
      bredde={bredde}
      seksjoner={seksjoner.map((s) => ({
        tittel: s.tittel,
        punkter: s.punkter.map((p) => ({ sti: p.sti, tekst: p.tekst })),
      }))}
    >
      {children}
    </Appskall>
  )
}
