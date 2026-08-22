import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { ROLLE_ETIKETT } from '@/lib/auth/typer'
import { Sidehode, Tomtilstand } from '@/components/ui/side'
import { Liste, Rad } from '@/components/ui/liste'
import { Status } from '@/components/ui/status'
import { Sidepanel } from '@/components/ui/sidepanel'
import { NyBruker } from './ny-bruker'
import { fjernBruker } from './handlinger'
import { SlettKnapp } from '@/components/ui/slett-knapp'

type Profil = { id: string; fullt_navn: string | null; rolle: string }
type Kobling = { profil_id: string; stasjon_id: string }

export default async function BrukereSide() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin') return <p>Kun eier kan administrere brukere.</p>

  const supabase = await lagSupabaseServerKlient()
  const [{ data: profiler }, { data: koblinger }, { data: stasjoner }] = await Promise.all([
    supabase
      .from('profiler')
      .select('id, fullt_navn, rolle')
      .in('rolle', ['butikksjef', 'butikkbruker_tablet'])
      .is('slettet_tid', null)
      .overrideTypes<Profil[]>(),
    supabase.from('butikksjef_stasjoner').select('profil_id, stasjon_id').overrideTypes<Kobling[]>(),
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null).order('butikknummer'),
  ])

  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))
  const stasjonerForProfil = new Map<string, string[]>()
  for (const k of koblinger ?? []) {
    const l = stasjonerForProfil.get(k.profil_id) ?? []
    l.push(navnFor.get(k.stasjon_id) ?? '—')
    stasjonerForProfil.set(k.profil_id, l)
  }

  const liste = profiler ?? []
  const nyBrukerPanel = (
    <Sidepanel
      knapp="Ny bruker"
      tittel="Ny bruker"
      beskrivelse={'Tablet-kontoen er delt på nettbrettet — de ansatte skiller seg '
        + 'med PIN (se Ansatte).'}
    >
      <NyBruker stasjoner={(stasjoner ?? []).map((s) => ({ id: s.id, navn: `${s.butikknummer} ${s.navn}` }))} />
    </Sidepanel>
  )

  return (
    <>
      <Sidehode
        tittel="Brukere"
        undertittel={liste.length === 0
          ? 'Opprett butikksjefer og tablet-kontoer, og styr hvilke stasjoner de når.'
          : `${liste.length} med tilgang. Styr hvilke stasjoner hver av dem når.`}
        handlinger={nyBrukerPanel}
      />

      {/* IKKE EN SAMMENLIGNINGSMATRISE. Ingen leser rollekolonnen mot
          stasjonskolonnen - man leter etter EN person og gjor noe med
          henne. Da er det en liste, og radene skilles av en haarlinje i
          stedet for et rutenett.

          Rollen staar som `normal`: at noen ER butikksjef er ikke en
          tilstand som krever noe, det er bare hvem hun er. */}
      {liste.length === 0 ? (
        <Tomtilstand
          tittel="Ingen brukere ennå"
          forklaring={'Butikksjefer logger inn som seg selv. Nettbrettet har en '
            + 'delt konto, der de ansatte skiller seg med PIN.'}
          handling={nyBrukerPanel}
        />
      ) : (
        <Liste merkelapp="Brukere med tilgang">
          {liste.map((p) => (
            <Rad
              key={p.id}
              primaer={p.fullt_navn ?? '—'}
              sekundaer={(stasjonerForProfil.get(p.id) ?? []).join(' · ') || 'ingen stasjoner tildelt'}
              status={(
                <Status nivaa="normal">
                  {ROLLE_ETIKETT[p.rolle as keyof typeof ROLLE_ETIKETT] ?? p.rolle}
                </Status>
              )}
              handlinger={(
                <SlettKnapp hva={p.fullt_navn ?? 'brukeren'} handling={fjernBruker} id={p.id} merke="Fjern" />
              )}
            />
          ))}
        </Liste>
      )}
    </>
  )
}
