import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { maanederSiden } from '@/lib/personvern/innsyn'
import { HANDLING_TEKST, type Handling } from '@/lib/personvern/logg'
import { FristSkjema, SlettSkjema } from './skjemaer'
import { husketStasjon } from '@/lib/stasjonskontekst'
import { Sidehode, Tomtilstand } from '@/components/ui/side'
import { Sideramme } from '@/components/ui/sideramme'

type Sok = Promise<{ stasjon?: string }>

type Person = { stasjon_id: string; ansatt_nr: string; navn: string; sist_aktivitet: string }

export default async function PersonvernSide({ searchParams }: { searchParams: Sok }) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return <Sideramme><p>Personvern er for butikksjef og eier.</p></Sideramme>
  const eier = bruker.rolle === 'retailer_admin'

  const sok = await searchParams
  const iDag = new Date().toISOString().slice(0, 10)
  const supabase = await lagSupabaseServerKlient()

  const { data: stasjoner } = await supabase
    .from('stasjoner').select('id, navn, butikknummer')
    .is('slettet_tid', null).order('butikknummer')
  const alle = (stasjoner ?? []) as { id: string; navn: string; butikknummer: string }[]
  if (alle.length === 0) return <Sideramme><p>Ingen stasjoner registrert.</p></Sideramme>
  // Stasjonen velges i toppstripen og huskes. URL-en vinner fortsatt,
  // saa en delt lenke viser det den lovet.
  const valgtId = await husketStasjon(alle, sok.stasjon)
  const valgt = alle.find((s) => s.id === valgtId) ?? alle[0]

  const [{ data: retailer }, { data: folk }, { data: loggRader }] = await Promise.all([
    supabase.from('retailers').select('oppbevaring_maaneder')
      .maybeSingle<{ oppbevaring_maaneder: number }>(),
    supabase.from('v_persondata_alder')
      .select('stasjon_id, ansatt_nr, navn, sist_aktivitet')
      .eq('stasjon_id', valgt.id)
      .order('sist_aktivitet'),
    supabase.from('persondata_logg')
      .select('id, tid, bruker_navn, handling, ansatt_navn')
      .order('tid', { ascending: false })
      .limit(100),
  ])
  const frist = retailer?.oppbevaring_maaneder ?? 60
  const personer = (folk ?? []) as Person[]
  const utlopt = personer.filter((p) => maanederSiden(p.sist_aktivitet, iDag) >= frist)
  const logg = (loggRader ?? []) as {
    id: string; tid: string; bruker_navn: string | null
    handling: string; ansatt_navn: string | null
  }[]

  // NIVÅ 1 på innstillinger: hva som gjelder nå. Sletteplikten er det ene
  // her som kan være misligholdt akkurat nå, og den sto som en seksjon
  // blant fire — man måtte bla for å finne ut om man lå etter.
  const svar = [
    `${personer.length} ${personer.length === 1 ? 'person' : 'personer'} på ${valgt.butikknummer} ${valgt.navn}`,
    utlopt.length > 0
      ? `${utlopt.length} klar for sletting`
      : 'ingen over fristen',
    `oppbevaring ${frist} måneder`,
  ].join(' · ')

  return (
    <Sideramme>
      <Sidehode tittel="Personvern" undertittel={svar} />

      <section className="kort">
        <h2>Oppbevaringstid</h2>
        <p className="undertittel">
          Personopplysninger skal ikke lagres lenger enn nødvendig. Fristen regnes
          fra <strong>siste aktivitet</strong>, ikke fra da raden ble skrevet — en
          kontrakt fra 2019 for en som fortsatt jobber her skal ikke slettes, men
          alt om en som sluttet i 2019 skal.
        </p>
        {eier
          ? <FristSkjema naa={frist} />
          : <p><strong>{frist} måneder</strong> etter siste aktivitet.</p>}
        <p className="notis sq-tett">
          60 måneder er standard fordi lønnsgrunnlag er primærdokumentasjon etter
          bokføringsloven og skal oppbevares i fem år. Kortere setter regnskapsplikten
          i konflikt med sletteplikten. Lengre må kunne begrunnes.
        </p>
      </section>

      <section className="kort">
        <h2>Klar for sletting</h2>
        {utlopt.length === 0 ? (
          <Tomtilstand
            tittel="Ingenting å slette"
            forklaring={`Ingen på ${valgt.navn} har passert ${frist} måneder uten aktivitet. Sletteplikten er oppfylt for denne stasjonen.`}
          />
        ) : (
          <>
            <p className="undertittel">
              {utlopt.length} {utlopt.length === 1 ? 'person har' : 'personer har'} ikke
              vært aktive på {frist} måneder. Slettingen fjerner stemplinger,
              ansattkort, arbeidsavtaler og signerte dokumenter — og den kan ikke angres.
            </p>
            <div className="tabellramme">
              <table className="tabell">
                <thead>
                  <tr>
                    <th>Navn</th><th>Ansattnr</th><th>Siste aktivitet</th>
                    <th className="tall">Måneder</th>
                    {eier && <th>Slett</th>}
                  </tr>
                </thead>
                <tbody>
                  {utlopt.map((p) => (
                    <tr key={p.ansatt_nr}>
                      <td>{p.navn}</td>
                      <td>{p.ansatt_nr}</td>
                      <td>{new Date(p.sist_aktivitet).toLocaleDateString('nb-NO')}</td>
                      <td className="tall">{maanederSiden(p.sist_aktivitet, iDag)}</td>
                      {eier && (
                        <td>
                          <SlettSkjema
                            stasjonId={valgt.id}
                            ansattNr={p.ansatt_nr}
                            navn={p.navn}
                          />
                        </td>
                      )}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </>
        )}
        <p className="notis sq-tett">
          <strong>Dette rydder ikke alt.</strong> Ferie, faste vakter og aktivitet på
          nettbrettet henger på navn og PIN, ikke på ansattnummer, og må ryddes for seg.
          Innsynsutskriften under viser hva som finnes av hver del.
        </p>
      </section>

      <section className="kort">
        <h2>Innsyn for en ansatt</h2>
        <p className="undertittel">
          En ansatt kan kreve kopi av alt dere har om henne — personvernforordningen
          artikkel 15. Utskriften samler alle tre stedene opplysningene ligger, og
          merker hver del med om koblingen er sikker (ansattnummer) eller usikker (navn).
        </p>
        <div className="tabellramme">
          <table className="tabell">
            <thead>
              <tr><th>Navn</th><th>Ansattnr</th><th>Siste aktivitet</th><th>Utskrift</th></tr>
            </thead>
            <tbody>
              {personer.map((p) => (
                <tr key={p.ansatt_nr}>
                  <td>{p.navn}</td>
                  <td>{p.ansatt_nr}</td>
                  <td>{new Date(p.sist_aktivitet).toLocaleDateString('nb-NO')}</td>
                  <td>
                    <a href={`/api/personvern/innsyn?stasjon=${valgt.id}&ansatt=${p.ansatt_nr}`}>
                      Last ned
                    </a>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <p className="notis">
          Samme person kan ligge under tre identiteter som ikke er koblet:
          ansattnummeret fra easy@work, PIN-en på nettbrettet, og navnet i
          bemanningsplanen. Utskriften kobler de to siste på navn, og sier fra om det
          i dokumentet — heter to personer det samme, må noen se over.
        </p>
      </section>

      <section className="kort">
        <h2>Hvem har sett hva</h2>
        <p className="undertittel">
          Målrettede oppslag på personopplysninger — innsyn, arbeidsavtaler,
          lønnsfiler og slettinger. Ikke hver sidevisning: en logg full av
          «åpnet /lonn» skjuler den ene raden som betyr noe.
        </p>
        {logg.length === 0 ? (
          <p className="undertittel">Ingen oppslag registrert ennå.</p>
        ) : (
          <div className="tabellramme">
            <table className="tabell">
              <thead>
                <tr><th>Tid</th><th>Hvem</th><th>Gjorde</th><th>Gjaldt</th></tr>
              </thead>
              <tbody>
                {logg.map((l) => (
                  <tr key={l.id}>
                    <td>{new Date(l.tid).toLocaleString('nb-NO')}</td>
                    <td>{l.bruker_navn ?? '—'}</td>
                    <td>{HANDLING_TEKST[l.handling as Handling] ?? l.handling}</td>
                    <td>{l.ansatt_navn ?? 'Hele stasjonen'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
        <p className="notis sq-tett">
          Loggen kan verken endres eller slettes — det finnes ingen policy for det.
          En logg som lar seg redigere av den som er logget, dokumenterer ingenting.
          Slettes en ansatt, blir loggen stående: den viser hvem som slettet, ikke
          hva som sto der.
        </p>
      </section>
    </Sideramme>
  )
}
