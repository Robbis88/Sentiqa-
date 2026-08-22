import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { datoLang } from '@/lib/format'
import { Sidehode, Tomtilstand, Forklaring } from '@/components/ui/side'
import { Liste, Rad } from '@/components/ui/liste'
import { Status } from '@/components/ui/status'
import { Knapp } from '@/components/ui/knapp'
import { iDag } from '@/lib/format'
import { Sidepanel } from '@/components/ui/sidepanel'
import { NyOppgave } from './ny-oppgave'
import { veksleOppgave, slettOppgave } from './handlinger'
import { SlettKnapp } from '@/components/ui/slett-knapp'

type Oppgave = {
  id: string
  stasjon_id: string
  tittel: string
  beskrivelse: string | null
  status: string
  frist: string | null
  vis_paa_tablet: boolean
}

export default async function OppgaverSide() {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) {
    return <p>Du har ikke tilgang til oppgaver.</p>
  }

  const supabase = await lagSupabaseServerKlient()
  const [{ data: oppgaver }, { data: stasjoner }] = await Promise.all([
    supabase
      .from('oppgaver')
      .select('id, stasjon_id, tittel, beskrivelse, status, frist, vis_paa_tablet')
      .is('slettet_tid', null)
      .order('status')
      .order('frist', { nullsFirst: false })
      .overrideTypes<Oppgave[]>(),
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null).order('butikknummer'),
  ])

  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))
  const apne = (oppgaver ?? []).filter((o) => o.status === 'apen')
  const fullfort = (oppgaver ?? []).filter((o) => o.status === 'fullfort')
  const antallForsinket = (oppgaver ?? []).filter(
    (o) => o.status === 'apen' && o.frist != null && o.frist < iDag(),
  ).length

  // HVA HASTER? Fristen fantes i dataene, men sto som en av fire
  // opplysninger paa rad - like tung som stasjonsnavnet. En oppgave som
  // har gaatt over fristen er noe annet enn en som ikke har det, og det
  // skal kunne leses paa avstand.
  //
  // Rolig som standard: en aapen oppgave innenfor fristen faar INGEN
  // farge. Fylte vi lista med gronne merker for «i rute», var det
  // ingenting igjen den dagen noe faktisk ryker.
  const idag = iDag()
  const forsinket = (o: Oppgave) =>
    o.status === 'apen' && o.frist != null && o.frist < idag

  const rad = (o: Oppgave) => (
    <Rad
      key={o.id}
      primaer={o.tittel}
      sekundaer={[
        navnFor.get(o.stasjon_id) ?? '—',
        o.frist ? `frist ${datoLang.format(new Date(o.frist))}` : null,
        o.vis_paa_tablet ? 'vises på nettbrettet' : null,
        o.beskrivelse,
      ].filter(Boolean).join(' · ')}
      status={forsinket(o) ? <Status nivaa="handling">Over frist</Status> : undefined}
      handlinger={(
        <>
          {/* Handlingen som lukker saken staar forst. Krysset er den
              samme serverhandlingen som for - samme felter, samme verdi. */}
          <form action={veksleOppgave}>
            <input type="hidden" name="id" value={o.id} />
            <input type="hidden" name="til" value={o.status === 'apen' ? 'fullfort' : 'apen'} />
            <Knapp type="submit" variant={o.status === 'apen' ? 'sekundaer' : 'ghost'} liten>
              {o.status === 'apen' ? 'Ferdig' : 'Åpne igjen'}
            </Knapp>
          </form>
          <SlettKnapp hva={o.tittel} handling={slettOppgave} id={o.id} merke="Slett" />
        </>
      )}
    />
  )

  const nyPanel = (
    <Sidepanel
      knapp="Ny oppgave"
      tittel="Ny oppgave"
      beskrivelse="Du kan også si det til Assistenten: «lag en oppgave på Bønes om å bestille kaffe»."
    >
      <NyOppgave stasjoner={(stasjoner ?? []).map((s) => ({ id: s.id, navn: `${s.butikknummer} ${s.navn}` }))} />
    </Sidepanel>
  )

  return (
    <>
      <Sidehode
        tittel="Oppgaver"
        undertittel={apne.length === 0
          ? 'Ingenting åpent akkurat nå.'
          : [
              `${apne.length} ${apne.length === 1 ? 'åpen' : 'åpne'}`,
              // Nivaa 1 paa en liste: hvor mange, og hvor mange krever
              // noe av meg NAA. Det siste tallet maatte man for regne
              // ut selv ved aa lese seg gjennom fristene.
              antallForsinket > 0 ? `${antallForsinket} over frist` : null,
            ].filter(Boolean).join(' · ') + '.'}
        handlinger={nyPanel}
      />

      {apne.length === 0 ? (
        <Tomtilstand
          tittel="Ingen åpne oppgaver"
          forklaring={'Oppgaver kan merkes for nettbrettet, så de ansatte ser dem '
            + 'på vakt og kan kvittere ut.'}
          handling={nyPanel}
        />
      ) : (
        <Liste merkelapp="Åpne oppgaver">{apne.map(rad)}</Liste>
      )}

      {/* Fullforte er dokumentasjon, ikke arbeid. De ligger sammenlagt,
          naa i primitivet som allerede gjor akkurat dette. */}
      {fullfort.length > 0 && (
        <Forklaring sporsmaal={`Fullført (${fullfort.length})`}>
          <Liste merkelapp="Fullførte oppgaver">{fullfort.map(rad)}</Liste>
        </Forklaring>
      )}
    </>
  )
}
