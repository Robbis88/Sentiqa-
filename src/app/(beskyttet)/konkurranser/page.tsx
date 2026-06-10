import Link from 'next/link'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { kr, datoLang } from '@/lib/format'
import { NyKonkurranse } from './ny-konkurranse'
import { kaarVinner, markerUtbetalt, slettKonkurranse } from './handlinger'

type Konk = {
  id: string
  navn: string
  kpi: string
  periode_start: string
  periode_slutt: string
  premie_kr: number | null
  premie_tekst: string | null
  premie_utbetalt: boolean
  status: string
  vinner_stasjon_id: string | null
}

export default async function KonkurranserSide() {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) {
    return <p>Du har ikke tilgang til konkurranser.</p>
  }
  const erEier = bruker.rolle === 'retailer_admin'

  const supabase = await lagSupabaseServerKlient()
  const [{ data: konk }, { data: stasjoner }] = await Promise.all([
    supabase
      .from('konkurranser')
      .select('id, navn, kpi, periode_start, periode_slutt, premie_kr, premie_tekst, premie_utbetalt, status, vinner_stasjon_id')
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
        Opprett her, eller via <Link href="/assistent">Assistenten</Link> — «Lag en konkurranse på pølsesalg neste uke, 1000 kr til vinneren».
      </p>

      {erEier && (
        <section className="kort">
          <h2>Ny konkurranse</h2>
          <NyKonkurranse />
        </section>
      )}

      {konkurranser.length === 0 ? (
        <section className="kort"><p className="undertittel">Ingen konkurranser ennå.</p></section>
      ) : (
        konkurranser.map((k) => {
          const harPremie = Boolean(k.premie_kr || k.premie_tekst)
          return (
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
                {k.premie_tekst ? ` · ${k.premie_tekst}` : ''}
              </p>
              {k.vinner_stasjon_id && (
                <p>🏆 Vinner: <strong>{navnFor.get(k.vinner_stasjon_id) ?? '—'}</strong>
                  {harPremie && (k.premie_utbetalt
                    ? <span className="status-pip gronn" style={{ marginLeft: '0.5rem' }}>Premie utbetalt</span>
                    : <span className="status-pip gul" style={{ marginLeft: '0.5rem' }}>Premie ikke utbetalt</span>)}
                </p>
              )}

              {erEier && (
                <div className="konk-knapper">
                  {k.status === 'aktiv' && (
                    <form action={kaarVinner}>
                      <input type="hidden" name="id" value={k.id} />
                      <button type="submit" className="liten">Kår vinner</button>
                    </form>
                  )}
                  {k.status === 'avsluttet' && k.vinner_stasjon_id && harPremie && !k.premie_utbetalt && (
                    <form action={markerUtbetalt}>
                      <input type="hidden" name="id" value={k.id} />
                      <button type="submit" className="liten">Marker premie utbetalt</button>
                    </form>
                  )}
                  <form action={slettKonkurranse}>
                    <input type="hidden" name="id" value={k.id} />
                    <button type="submit" className="liten slett">Slett</button>
                  </form>
                </div>
              )}
            </section>
          )
        })
      )}
    </>
  )
}
