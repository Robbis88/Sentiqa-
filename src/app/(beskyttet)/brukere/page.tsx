import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { ROLLE_ETIKETT } from '@/lib/auth/typer'
import { Sidehode, Datatabell, Tomtilstand } from '@/components/ui/side'
import { Sidepanel } from '@/components/ui/sidepanel'
import { NyBruker } from './ny-bruker'
import { fjernBruker } from './handlinger'

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

      <Datatabell
        antall={liste.length}
        tom={(
          <Tomtilstand
            tittel="Ingen brukere ennå"
            forklaring={'Butikksjefer logger inn som seg selv. Nettbrettet har en '
              + 'delt konto, der de ansatte skiller seg med PIN.'}
            handling={nyBrukerPanel}
          />
        )}
      >
        <thead><tr><th>Navn</th><th>Rolle</th><th>Stasjoner</th><th></th></tr></thead>
        <tbody>
          {liste.map((p) => (
            <tr key={p.id}>
              <td>{p.fullt_navn ?? '—'}</td>
              <td>{ROLLE_ETIKETT[p.rolle as keyof typeof ROLLE_ETIKETT] ?? p.rolle}</td>
              <td>{(stasjonerForProfil.get(p.id) ?? []).join(', ') || '—'}</td>
              <td className="tall">
                <form action={fjernBruker}>
                  <input type="hidden" name="id" value={p.id} />
                  <button type="submit" className="liten slett">Fjern</button>
                </form>
              </td>
            </tr>
          ))}
        </tbody>
      </Datatabell>
    </>
  )
}
