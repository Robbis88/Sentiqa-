import Link from 'next/link'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { kr, datoLang } from '@/lib/format'

type Konk = {
  id: string
  navn: string
  kpi: string
  periode_start: string
  periode_slutt: string
  premie_kr: number | null
  status: string
  vinner_stasjon_id: string | null
}

export default async function KonkurranserSide() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin' && bruker.rolle !== 'butikksjef') {
    return <p>Du har ikke tilgang til konkurranser.</p>
  }

  const supabase = await lagSupabaseServerKlient()
  const [{ data: konk }, { data: stasjoner }] = await Promise.all([
    supabase
      .from('konkurranser')
      .select('id, navn, kpi, periode_start, periode_slutt, premie_kr, status, vinner_stasjon_id')
      .is('slettet_tid', null)
      .order('opprettet_tid', { ascending: false })
      .overrideTypes<Konk[]>(),
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null),
  ])

  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))
  const konkurranser = konk ?? []

  return (
    <>
      <h1>Konkurranser</h1>
      <p className="undertittel">
        Opprett og kår via <Link href="/assistent">Assistenten</Link> — f.eks. «Lag en konkurranse på
        pølsesalg neste uke, 1000 kr til vinneren».
      </p>

      {konkurranser.length === 0 ? (
        <section className="kort">
          <p className="undertittel">Ingen konkurranser ennå.</p>
        </section>
      ) : (
        konkurranser.map((k) => (
          <section className="kort" key={k.id}>
            <h2>
              {k.navn}{' '}
              <span className={`status-pip ${k.status === 'aktiv' ? 'gronn' : 'gul'}`}>
                {k.status === 'aktiv' ? 'Aktiv' : 'Avsluttet'}
              </span>
            </h2>
            <p>{k.kpi}</p>
            <p className="undertittel">
              {datoLang.format(new Date(k.periode_start))} – {datoLang.format(new Date(k.periode_slutt))}
              {k.premie_kr ? ` · premie ${kr.format(k.premie_kr)}` : ''}
            </p>
            {k.vinner_stasjon_id && (
              <p>
                🏆 Vinner: <strong>{navnFor.get(k.vinner_stasjon_id) ?? '—'}</strong>
              </p>
            )}
          </section>
        ))
      )}
    </>
  )
}
