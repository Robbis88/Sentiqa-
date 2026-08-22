import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { kr, datoLang } from '@/lib/format'
import { NyKonkurranse } from './ny-konkurranse'
import { kaarVinner, markerUtbetalt, slettKonkurranse } from './handlinger'
import { Sidehode, Tomtilstand } from '@/components/ui/side'
import { Sidepanel } from '@/components/ui/sidepanel'
import { Status } from '@/components/ui/status'
import { SlettKnapp } from '@/components/ui/slett-knapp'

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

  const aktive = konkurranser.filter((k) => k.status === 'aktiv').length
  const nyPanel = (
    <Sidepanel
      knapp="Ny konkurranse"
      tittel="Ny konkurranse"
      beskrivelse="Du kan også be Assistenten om det, med egne ord."
    >
      <NyKonkurranse />
    </Sidepanel>
  )

  return (
    <>
      <Sidehode
        tittel="Konkurranser"
        undertittel={konkurranser.length === 0
          ? 'Kortvarige mål med en premie — for eksempel pølsesalg neste uke.'
          : `${aktive} ${aktive === 1 ? 'aktiv' : 'aktive'} av ${konkurranser.length}.`}
        handlinger={erEier ? nyPanel : undefined}
      />

      {konkurranser.length === 0 ? (
        <Tomtilstand
          tittel="Ingen konkurranser ennå"
          forklaring={'Du kan også be Assistenten: «Lag en konkurranse på pølsesalg '
            + 'neste uke, 1000 kr til vinneren».'}
          handling={erEier ? nyPanel : undefined}
        />
      ) : (
        konkurranser.map((k) => {
          const harPremie = Boolean(k.premie_kr || k.premie_tekst)
          return (
            <section className="kort" key={k.id}>
              <h2>
                {k.navn}{' '}
                {/* En paagaaende konkurranse er utgangspunktet - `normal`.
                    En avsluttet uten kaaret vinner er derimot noe som
                    venter paa noen, og det staar i teksten. */}
                <Status nivaa={k.status === 'aktiv' ? 'normal' : 'endring'}>
                  {k.status === 'aktiv' ? 'Aktiv' : 'Avsluttet'}
                </Status>
              </h2>
              <p>{k.kpi}</p>
              <p className="undertittel">
                {datoLang.format(new Date(k.periode_start))} – {datoLang.format(new Date(k.periode_slutt))}
                {k.premie_kr ? ` · premie ${kr.format(k.premie_kr)}` : ''}
                {k.premie_tekst ? ` · ${k.premie_tekst}` : ''}
              </p>
              {k.vinner_stasjon_id && (
                <p>Vinner: <strong>{navnFor.get(k.vinner_stasjon_id) ?? '—'}</strong>
                  {harPremie && (k.premie_utbetalt
                    ? <Status nivaa="normal">Premie utbetalt</Status>
                    : <Status nivaa="handling">Premie ikke utbetalt</Status>)}
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
                  <SlettKnapp hva={k.navn} handling={slettKonkurranse} id={k.id} merke="Slett" />
                </div>
              )}
            </section>
          )
        })
      )}
    </>
  )
}
