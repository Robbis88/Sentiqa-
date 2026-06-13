import Link from 'next/link'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { datoLang } from '@/lib/format'
import { FREKVENS_ETIKETT } from '@/lib/ikmat/standard'
import { MaalingListe, type Punkt, type Logget } from './maaling-liste'

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

  return (
    <>
      <h1>🌡️ IK-mat · {FREKVENS_ETIKETT[frekvens]}</h1>
      <p className="undertittel">
        {st ? `${st.butikknummer} ${st.navn} · ` : ''}{datoLang.format(new Date(idag))} · <Link href="/rutiner">← Tilbake til vakta</Link>
      </p>
      <section className="kort">
        <p className="undertittel">Mål hver enhet og lagre. Er noe utenfor kravet, fyll inn strakstiltak — da opprettes et avvik automatisk.</p>
        <MaalingListe punkter={(punkter ?? []).map((p) => ({ id: p.id, navn: p.navn, min_temp: p.min_temp, max_temp: p.max_temp }))} logget={logget} />
      </section>
    </>
  )
}
