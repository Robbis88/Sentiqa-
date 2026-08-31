import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { Sidehode } from '@/components/ui/side'
import { Sidepanel } from '@/components/ui/sidepanel'
import { NyAnsatt } from './ny-ansatt'
import { AnsattListe, type Ansatt } from './ansatt-liste'
import { Sideramme } from '@/components/ui/sideramme'

// =====================================================================
// Første side migrert til det nye designsystemet (pilot A).
//
// Den var også diagnosen. Før åpnet siden med skjemaet «Ny ansatt» —
// den sjeldneste handlingen her — og viste lista under. Databasen
// først, brukeren etterpå.
//
// Nå: hvor mange og hva krever noe (nivå 1), «Ny ansatt» som sidepanel
// (nivå 2), lista (nivå 3). Ingenting er fjernet; skjemaet har flyttet
// inn i et panel, så man beholder lista mens man legger til én person.
//
// SPØRRINGEN ER URØRT. Samme filtre, samme sortering, samme kolonner —
// pluss stasjonsnavnene, som alt ble hentet. Det er en designmigrering,
// og da skal datalaget kunne diffes til null.
//
// Mønsteret er beskrevet i src/lib/redesign/monstre.ts under 'liste'.
// =====================================================================

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
  const liste = ansatte ?? []
  const stasjonsvalg = (stasjoner ?? []).map((s) => ({
    id: s.id, navn: `${s.butikknummer} ${s.navn}`,
  }))
  const stasjonsnavn = Object.fromEntries(stasjonsvalg.map((s) => [s.id, s.navn]))

  // Nivå 1 på en liste er «hvor mange, og hvor mange krever noe av meg».
  // Her er det siste antallet uten ansattnummer: de kan ikke stemple, og
  // de kommer ikke med i lønnsfila. Tallet står i toppen slik at det ikke
  // må oppdages ved å lese seg gjennom lista.
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
    <Sideramme>
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

      <AnsattListe
        ansatte={liste}
        stasjonsnavn={stasjonsnavn}
        stasjoner={stasjonsvalg}
        nyAnsattPanel={nyAnsattPanel}
      />
    </Sideramme>
  )
}
