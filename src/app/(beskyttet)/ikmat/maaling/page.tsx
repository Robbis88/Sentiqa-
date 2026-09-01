import Link from 'next/link'
import { husketStasjon } from '@/lib/stasjonskontekst'
import { stasjonFraUrl, tillatAlleFor } from '@/lib/stasjonsvalg'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { datoLang } from '@/lib/format'
import { FREKVENS_ETIKETT } from '@/lib/ikmat/standard'
import { MaalingListe, type Punkt, type Logget } from './maaling-liste'
import { TabletMaaling } from './tablet-maaling'
import { TabletHode } from '../../tablet-hode'
import { Sidehode } from '@/components/ui/side'
import { Sideramme } from '@/components/ui/sideramme'

const FREKVENSER = ['daglig', 'to_ukentlig', 'ukentlig']

export default async function MaalingSide({ searchParams }: { searchParams: Promise<{ stasjon?: string; frekvens?: string }> }) {
  const bruker = await hentInnloggetBruker()
  const sp = await searchParams
  const frekvens = FREKVENSER.includes(sp.frekvens ?? '') ? sp.frekvens! : 'daglig'

  const supabase = await lagSupabaseServerKlient()

  // MAALINGEN GJELDER EN STASJON, alltid. Den naas som en dyplenke fra
  // vakta, saa `?stasjon=` er den vanlige veien inn - men manglet den,
  // moette man for en blindgate: «Mangler stasjon».
  //
  // Naa faller den tilbake paa det huskede valget, som alle andre sider.
  // Blindgata staar igjen bare for den som faktisk ikke har noen stasjon
  // - og da er det sant.
  const { data: mine } = await supabase
    .from('stasjoner').select('id, navn, butikknummer')
    .is('slettet_tid', null).order('butikknummer')
  const liste = (mine ?? []) as { id: string; navn: string; butikknummer: string }[]
  const sok = new URLSearchParams()
  if (sp.stasjon) sok.set('stasjon', sp.stasjon)
  const stasjon = await husketStasjon(
    liste, stasjonFraUrl(sok, liste),
    tillatAlleFor('/ikmat/maaling', bruker.rolle, liste.length),
  )
  if (!stasjon) return <Sideramme><p>Ingen stasjon tildelt. <Link href="/rutiner">Tilbake til vakta</Link></p></Sideramme>
  const idag = new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Oslo' }).format(new Date())

  const [{ data: punkter }, { data: avles }, { data: st }] = await Promise.all([
    supabase.from('ik_kontrollpunkter').select('id, navn, min_temp, max_temp').eq('stasjon_id', stasjon).eq('frekvens', frekvens).is('slettet_tid', null).order('sortering').overrideTypes<Punkt[]>(),
    supabase.from('ik_avlesninger').select('kontrollpunkt_id, temperatur, innenfor').eq('stasjon_id', stasjon).eq('dato', idag).order('avlest_tid').overrideTypes<{ kontrollpunkt_id: string; temperatur: number; innenfor: boolean }[]>(),
    supabase.from('stasjoner').select('navn, butikknummer').eq('id', stasjon).maybeSingle<{ navn: string; butikknummer: string }>(),
  ])

  const logget: Record<string, Logget> = {}
  for (const a of avles ?? []) logget[a.kontrollpunkt_id] = { temp: a.temperatur, innenfor: a.innenfor }

  // Hvor langt er jeg kommet — spørsmålet man har når man står med
  // termometeret. Sto ingen steder; man måtte telle avhukede rader selv.
  const antallPunkter = (punkter ?? []).length
  const antallMaalt = Object.keys(logget).length
  const utenfor = Object.values(logget).filter((l) => !l.innenfor).length
  const status = antallPunkter === 0
    ? 'Ingen kontrollpunkter satt opp'
    : antallMaalt >= antallPunkter
      ? `Alle ${antallPunkter} målt`
      : `${antallMaalt} av ${antallPunkter} målt`

  // NETTBRETTET FAAR EN ENHET AV GANGEN. Se tablet-maaling.tsx.
  //
  // Dette er den ene flata der arbeidet faktisk skjer, og den hadde
  // lederens form: alle enhetene under hverandre, hvert felt aapent
  // samtidig. Ruta sto heller ikke i noen bevisliste — verken
  // treffomraade, kontrast eller lekkasje ble maalt her.
  // Rollen leses ut i en variabel foerst, som paa /rutiner, /ikmat og
  // /stempling. Det er ikke bare stil: rollevakten leser kilden, og et
  // `bruker.rolle === '...'` rett foran et fragment-retur leser den som
  // en AVVISNING - «denne rollen faar en tekst i stedet for sida».
  // Med vilkaaret i en variabel er formen den samme som resten av
  // kodebasen, og vakten kan ikke misforstaa den.
  const paaNettbrett = bruker.rolle === 'butikkbruker_tablet'

  if (paaNettbrett) {
    return (
      <Sideramme>
        <TabletHode
          tittel={status}
          undertittel={[FREKVENS_ETIKETT[frekvens], utenfor > 0 ? `${utenfor} utenfor kravet` : null]
            .filter(Boolean).join(' · ')}
        />
        <TabletMaaling
          punkter={(punkter ?? []).map((p) => ({ id: p.id, navn: p.navn, min_temp: p.min_temp, max_temp: p.max_temp }))}
          logget={logget}
          frekvensEtikett={FREKVENS_ETIKETT[frekvens]}
        />
      </Sideramme>
    )
  }

  return (
    <Sideramme>
      <Sidehode
        tittel={`IK-mat · ${FREKVENS_ETIKETT[frekvens]}`}
        undertittel={[
          status,
          utenfor > 0 ? `${utenfor} utenfor kravet` : null,
          st ? `${st.butikknummer} ${st.navn}` : null,
          datoLang.format(new Date(idag)),
        ].filter(Boolean).join(' · ')}
        handlinger={<Link href="/rutiner" className="sq-knapp">Tilbake til vakta</Link>}
      />
      <section className="kort">
        <p className="undertittel">Mål hver enhet og lagre. Er noe utenfor kravet, fyll inn strakstiltak — da opprettes et avvik automatisk.</p>
        <MaalingListe punkter={(punkter ?? []).map((p) => ({ id: p.id, navn: p.navn, min_temp: p.min_temp, max_temp: p.max_temp }))} logget={logget} />
      </section>
    </Sideramme>
  )
}
