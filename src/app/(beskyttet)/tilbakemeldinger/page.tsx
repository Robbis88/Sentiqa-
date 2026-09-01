import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { markerLest } from './handlinger'
import { Sidehode, Tomtilstand } from '@/components/ui/side'
import { Liste, Rad } from '@/components/ui/liste'
import { Status, type Statusnivaa } from '@/components/ui/status'
import { Knapp } from '@/components/ui/knapp'
import { Sideramme } from '@/components/ui/sideramme'

type Tilbake = { id: string; stasjon_id: string; alvorlighet: string; tekst: string; involvert_beskrivelse: string | null; opprettet_tid: string; lest_tid: string | null }

/**
 * Alvorlighet, oversatt til det semantiske spraaket resten av systemet
 * bruker.
 *
 * FIRE EMOJI ERSTATTET AV FIRE NIVAAER. Merkene var 💬🩹⚠️🚫 - ikoner
 * som maa laeres, og som ikke sier hvor alvorlig noe er for man har
 * laert dem. Nivaaet sier det med farge og styrke, og ordet staar der
 * uansett for den som ikke ser fargen.
 *
 * EN KRENKELSE ER KRITISK. Den laa som «rod» sammen med alt annet rodt.
 * Det er den ene tingen paa denne sida som ikke kan vente, og den skal
 * vaere umulig aa overse.
 */
const ALVOR: Record<string, { ord: string; nivaa: Statusnivaa }> = {
  generelt: { ord: 'Generelt', nivaa: 'normal' },
  uhell: { ord: 'Uhell', nivaa: 'handling' },
  nestenuhell: { ord: 'Nestenuhell', nivaa: 'endring' },
  krenkelse: { ord: 'Krenkelse', nivaa: 'kritisk' },
}
const tid = new Intl.DateTimeFormat('nb-NO', { timeZone: 'Europe/Oslo', dateStyle: 'short', timeStyle: 'short' })

export default async function TilbakemeldingerSide() {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return <Sideramme><p>Kun eier/butikksjef.</p></Sideramme>
  const supabase = await lagSupabaseServerKlient()
  const [{ data: meldinger }, { data: stasjoner }] = await Promise.all([
    supabase.from('tilbakemelding').select('id, stasjon_id, alvorlighet, tekst, involvert_beskrivelse, opprettet_tid, lest_tid').order('opprettet_tid', { ascending: false }).limit(100).overrideTypes<Tilbake[]>(),
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null),
  ])
  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))
  const uleste = (meldinger ?? []).filter((m) => !m.lest_tid).length

  const liste = meldinger ?? []

  return (
    <Sideramme>
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
        <Liste merkelapp="Tilbakemeldinger">
          {liste.map((m) => {
            const alvor = ALVOR[m.alvorlighet] ?? ALVOR.generelt
            return (
              <Rad
                key={m.id}
                primaer={m.tekst}
                sekundaer={[
                  navnFor.get(m.stasjon_id) ?? '—',
                  tid.format(new Date(m.opprettet_tid)),
                  m.involvert_beskrivelse ? `involvert: ${m.involvert_beskrivelse}` : null,
                  m.lest_tid ? null : 'ulest',
                ].filter(Boolean).join(' · ')}
                status={<Status nivaa={alvor.nivaa}>{alvor.ord}</Status>}
                handlinger={!m.lest_tid ? (
                  <form action={markerLest}>
                    <input type="hidden" name="id" value={m.id} />
                    <Knapp type="submit" variant="ghost" liten>Lest</Knapp>
                  </form>
                ) : undefined}
              />
            )
          })}
        </Liste>
      )}
    </Sideramme>
  )
}
