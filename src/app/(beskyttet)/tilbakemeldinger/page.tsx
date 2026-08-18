import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { markerLest } from './handlinger'
import { Sidehode, Tomtilstand } from '@/components/ui/side'

type Tilbake = { id: string; stasjon_id: string; alvorlighet: string; tekst: string; involvert_beskrivelse: string | null; opprettet_tid: string; lest_tid: string | null }

const MERKE: Record<string, { e: string; k: string }> = {
  generelt: { e: '💬 Generelt', k: 'bla' },
  uhell: { e: '🩹 Uhell', k: 'gul' },
  nestenuhell: { e: '⚠️ Nestenuhell', k: 'gul' },
  krenkelse: { e: '🚫 Krenkelse', k: 'rod' },
}
const tid = new Intl.DateTimeFormat('nb-NO', { timeZone: 'Europe/Oslo', dateStyle: 'short', timeStyle: 'short' })

export default async function TilbakemeldingerSide() {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return <p>Kun eier/butikksjef.</p>
  const supabase = await lagSupabaseServerKlient()
  const [{ data: meldinger }, { data: stasjoner }] = await Promise.all([
    supabase.from('tilbakemelding').select('id, stasjon_id, alvorlighet, tekst, involvert_beskrivelse, opprettet_tid, lest_tid').order('opprettet_tid', { ascending: false }).limit(100).overrideTypes<Tilbake[]>(),
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null),
  ])
  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))
  const uleste = (meldinger ?? []).filter((m) => !m.lest_tid).length

  const liste = meldinger ?? []

  return (
    <>
      <Sidehode
        tittel="Tilbakemeldinger fra ansatte"
        undertittel={uleste === 0
          ? (liste.length === 0
            ? 'Ansatte kan si fra om ting uten å måtte ta det ansikt til ansikt.'
            : `Alle ${liste.length} er lest.`)
          : `${uleste} ${uleste === 1 ? 'ulest' : 'uleste'} av ${liste.length}.`}
      />

      {liste.length === 0 ? (
        <Tomtilstand
          tittel="Ingen tilbakemeldinger ennå"
          forklaring={'De ansatte kan sende inn fra nettbrettet. Det er ofte her '
            + 'ting kommer fram som ikke sies på et personalmøte.'}
        />
      ) : (
        <ul className="melding-liste">
          {liste.map((m) => {
            const merke = MERKE[m.alvorlighet] ?? MERKE.generelt
            return (
              <li key={m.id} className={!m.lest_tid ? 'viktig' : ''}>
                <div>
                  <span className={`status-pip ${merke.k}`}>{merke.e}</span>{' '}
                  <span className="undertittel">{navnFor.get(m.stasjon_id) ?? '—'} · {tid.format(new Date(m.opprettet_tid))}</span>
                  <p className="melding-tekst">{m.tekst}</p>
                  {m.involvert_beskrivelse ? <p className="undertittel">Involvert: {m.involvert_beskrivelse}</p> : null}
                </div>
                {!m.lest_tid && (
                  <form action={markerLest}><input type="hidden" name="id" value={m.id} /><button type="submit" className="liten">Lest</button></form>
                )}
              </li>
            )
          })}
        </ul>
      )}
    </>
  )
}
