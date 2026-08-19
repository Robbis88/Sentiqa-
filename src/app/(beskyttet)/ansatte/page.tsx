import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { Sidehode, Datatabell, Tomtilstand } from '@/components/ui/side'
import { Sidepanel } from '@/components/ui/sidepanel'
import { NyAnsatt } from './ny-ansatt'
import { AnsattnummerFelt } from './ansattnummer-felt'
import { deaktiverAnsatt } from './handlinger'

// =====================================================================
// Første side migrert til listemønsteret. Den var også diagnosen:
//
// Før åpnet siden med skjemaet «Ny ansatt» — den sjeldneste handlingen
// på siden — og viste lista under. Databasen først, brukeren etterpå.
//
// Nå: hvor mange og hva krever noe (nivå 1), «Ny ansatt» som sidepanel
// (nivå 2), lista (nivå 3). Ingenting er fjernet; skjemaet har flyttet
// inn i et panel, så man beholder lista mens man legger til én person.
//
// Mønsteret er beskrevet i src/lib/redesign/monstre.ts under 'liste'.
// =====================================================================

type Ansatt = {
  id: string; navn: string; stasjon_id: string; ansatt_nr: string | null
}

export default async function AnsatteSide() {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) {
    return <p>Ansatte administreres av eier/butikksjef.</p>
  }
  const supabase = await lagSupabaseServerKlient()
  const [{ data: ansatte }, { data: stasjoner }] = await Promise.all([
    supabase.from('ansatte').select('id, navn, stasjon_id, ansatt_nr').eq('aktiv', true).is('slettet_tid', null).order('navn').overrideTypes<Ansatt[]>(),
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null).order('butikknummer'),
  ])
  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))
  const liste = ansatte ?? []
  const stasjonsvalg = (stasjoner ?? []).map((s) => ({
    id: s.id, navn: `${s.butikknummer} ${s.navn}`,
  }))
  // Nivå 1 på en liste er «hvor mange, og hvor mange krever noe av meg».
  // Her er det siste antallet uten ansattnummer: de kan ikke stemple, og
  // de kommer ikke med i lønnsfila. Tallet står i toppen slik at det ikke
  // må oppdages ved å lese seg gjennom kolonnen.
  const utenNummer = liste.filter((a) => !a.ansatt_nr).length

  const nyAnsattPanel = (
    <Sidepanel
      knapp="Ny ansatt"
      tittel="Ny ansatt"
      beskrivelse="PIN-en vises aldri igjen — den lagres kryptert. Velg en unik PIN per ansatt."
    >
      <NyAnsatt stasjoner={stasjonsvalg} />
    </Sidepanel>
  )

  return (
    <>
      <Sidehode
        tittel="Ansatte"
        undertittel={
          liste.length === 0
            ? 'Ansatte sjekker inn med PIN på nettbrettet.'
            : utenNummer === 0
              ? `${liste.length} aktive, alle med ansattnummer.`
              : `${liste.length} aktive. ${utenNummer} mangler ansattnummer og `
                + 'kan verken stemple eller komme med i lønnsfila.'
        }
        handlinger={nyAnsattPanel}
      />

      <Datatabell
        antall={liste.length}
        tom={(
          <Tomtilstand
            tittel="Ingen ansatte ennå"
            forklaring={
              'Legg inn de som jobber her, så kan de sjekke inn med PIN på '
              + 'nettbrettet og kvittere for rutiner og temperaturer.'
            }
            handling={nyAnsattPanel}
          />
        )}
      >
        <thead>
          <tr><th>Navn</th><th>Stasjon</th><th>Ansattnummer</th><th></th></tr>
        </thead>
        <tbody>
          {liste.map((a) => (
            <tr key={a.id}>
              <td>{a.navn}</td>
              <td>{navnFor.get(a.stasjon_id) ?? '—'}</td>
              <td><AnsattnummerFelt id={a.id} nummer={a.ansatt_nr} /></td>
              <td className="tall">
                <form action={deaktiverAnsatt}>
                  <input type="hidden" name="id" value={a.id} />
                  <button type="submit" className="liten">Deaktiver</button>
                </form>
              </td>
            </tr>
          ))}
        </tbody>
      </Datatabell>
    </>
  )
}
