import Link from 'next/link'
import { redirect } from 'next/navigation'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { mfaHandling } from '@/lib/auth/mfa'
import { loggUt } from '@/lib/auth/handlinger'
import { ROLLE_ETIKETT } from '@/lib/auth/typer'
import { lesAktivAnsatt } from '@/lib/ansatt'
import { erLeder } from '@/lib/auth/roller'
import { Sidemeny } from './sidemeny'
import { TabletSkall } from './tablet-skall'
import { AiBoble } from './ai-boble'
import { Kommandopalett } from './kommandopalett'
import { OversettProvider } from './oversett-kontekst'
import { SEKSJONER } from './navigasjon'
import { Fanerad } from './fanerad'

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
        <main className="innhold">
          <Fanerad rolle={bruker.rolle} />
          {children}
        </main>
      </div>
      {erLeder(bruker.rolle) && <AiBoble navn={bruker.fulltNavn?.split(' ')[0]} />}
    </div>
  )
}
