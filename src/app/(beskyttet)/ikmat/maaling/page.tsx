import Link from 'next/link'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { datoLang } from '@/lib/format'
import { FREKVENS_ETIKETT } from '@/lib/ikmat/standard'
import { MaalingListe, type Punkt, type Logget } from './maaling-liste'
import { Sidehode } from '@/components/ui/side'

const FREKVENSER = ['daglig', 'to_ukentlig', 'ukentlig']

export default async function MaalingSide({ searchParams }: { searchParams: Promise<{ stasjon?: string; frekvens?: string }> }) {
  await hentInnloggetBruker()
  const sp = await searchParams
  const erUuid = (s?: string) => !!s && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s)
  const stasjon = erUuid(sp.stasjon) ? sp.stasjon! : null
  const frekvens = FREKVENSER.includes(sp.frekvens ?? '') ? sp.frekvens! : 'daglig'
  if (!stasjon) return <p>Mangler stasjon. <Link href="/rutiner">Tilbake til vakta</Link></p>

  const supabase = await lagSupabaseServerKlient()
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

  return (
    <>
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
    </>
  )
}
