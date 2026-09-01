import { hentInnloggetBruker } from '@/lib/auth/dal'
import { SlettKnapp } from '@/components/ui/slett-knapp'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { sendMelding, slettMelding } from './handlinger'
import { Sidehode, Tomtilstand } from '@/components/ui/side'
import { Sidepanel } from '@/components/ui/sidepanel'
import { Liste, Rad } from '@/components/ui/liste'
import { Status } from '@/components/ui/status'
import { Knapp } from '@/components/ui/knapp'
import { Velg } from '@/components/ui/felt'
import { Sideramme } from '@/components/ui/sideramme'

type Melding = { id: string; stasjon_id: string | null; tekst: string; viktig: boolean; opprettet_tid: string }

const tid = new Intl.DateTimeFormat('nb-NO', { timeZone: 'Europe/Oslo', dateStyle: 'short', timeStyle: 'short' })

export default async function MeldingerSide() {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) {
    return <Sideramme><p>Kun eier/butikksjef kan sende meldinger.</p></Sideramme>
  }
  const supabase = await lagSupabaseServerKlient()
  const [{ data: meldinger }, { data: stasjoner }] = await Promise.all([
    supabase.from('tablet_meldinger').select('id, stasjon_id, tekst, viktig, opprettet_tid').is('slettet_tid', null).order('opprettet_tid', { ascending: false }).overrideTypes<Melding[]>(),
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null).order('butikknummer'),
  ])
  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))

  const liste = meldinger ?? []
  const nyMeldingPanel = (
    <Sidepanel
      knapp="Ny melding"
      tittel="Ny melding"
      beskrivelse="Vises på stasjonens nettbrett til du sletter den."
    >
      {/* Samme felter, samme navn, samme serverhandling. Etiketten paa
          avkryssingen sier naa HVA det gjor, ikke hvilken farge det
          faar - fargen er en folge, ikke et valg. */}
      <form action={sendMelding} className="sq-skjema">
        <Velg etikett="Til" name="stasjon_id" defaultValue="">
          <option value="">Alle stasjoner</option>
          {(stasjoner ?? []).map((s) => <option key={s.id} value={s.id}>{s.butikknummer} {s.navn}</option>)}
        </Velg>
        <label className="felt"><span>Melding</span>
          <textarea name="tekst" rows={3} required />
        </label>
        <label className="felt avkryss">
          <input type="checkbox" name="viktig" /> Viktig — vises fremhevet på nettbrettet
        </label>
        <div className="knapperad">
          <Knapp type="submit" variant="primar">Send til nettbrettet</Knapp>
        </div>
      </form>
    </Sidepanel>
  )

  return (
    <Sideramme>
      <Sidehode
        tittel="Meldinger til nettbrettet"
        undertittel={liste.length === 0
          ? 'Korte beskjeder som vises på stasjonens nettbrett.'
          : `${liste.length} aktive. De står på nettbrettet til du sletter dem.`}
        handlinger={nyMeldingPanel}
      />

      {liste.length === 0 ? (
        <Tomtilstand
          tittel="Ingen aktive meldinger"
          forklaring={'En melding her dukker opp på nettbrettet med en gang — nyttig '
            + 'for beskjeder som ikke tåler å vente til neste vakt.'}
          handling={nyMeldingPanel}
        />
      ) : (
        <Liste merkelapp="Aktive meldinger">
          {liste.map((m) => (
            <Rad
              key={m.id}
              primaer={m.tekst}
              sekundaer={`${m.stasjon_id ? navnFor.get(m.stasjon_id) ?? '—' : 'Alle stasjoner'} · ${tid.format(new Date(m.opprettet_tid))}`}
              // «Viktig» er avsenderens eget valg om at dette ikke kan
              // ventes med. Det er en handling for den som leser det paa
              // nettbrettet - derfor `handling`, ikke `kritisk`.
              status={m.viktig ? <Status nivaa="handling">Viktig</Status> : undefined}
              handlinger={(
                <SlettKnapp hva={m.tekst} handling={slettMelding} id={m.id} bekreftelse="Meldingen slettet" />
              )}
            />
          ))}
        </Liste>
      )}
    </Sideramme>
  )
}
