import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { iDag, datoLang } from '@/lib/format'
import { leggTilArrangement, bekreftArrangement, forkastArrangement, leggTilKalenderKilde, slettKalenderKilde } from './handlinger'
import { Sidehode, Tomtilstand, Forklaring } from '@/components/ui/side'
import { Sidepanel } from '@/components/ui/sidepanel'
import { SlettKnapp } from '@/components/ui/slett-knapp'
import { Sideramme } from '@/components/ui/sideramme'

type Arr = { id: string; dato: string; navn: string; faktor: number; stasjon_id: string | null; status: string }
type Kilde = { id: string; navn: string; ical_url: string; standard_faktor: number; stasjon_ider: string[] | null }

export default async function ArrangementerSide() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin') return <Sideramme><p>Arrangementer styres av eier.</p></Sideramme>

  const supabase = await lagSupabaseServerKlient()
  const idag = iDag()
  const [{ data: stasjoner }, { data: kilder }, { data: arr }] = await Promise.all([
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null).order('butikknummer').overrideTypes<{ id: string; navn: string; butikknummer: string }[]>(),
    supabase.from('kalender_kilder').select('id, navn, ical_url, standard_faktor, stasjon_ider').is('slettet_tid', null).order('navn').overrideTypes<Kilde[]>(),
    supabase.from('arrangementer').select('id, dato, navn, faktor, stasjon_id, status').gte('dato', idag).is('slettet_tid', null).order('dato').overrideTypes<Arr[]>(),
  ])
  const liste = stasjoner ?? []
  const navnFor = new Map(liste.map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))
  const stasjonTekst = (id: string | null) => (id ? navnFor.get(id) ?? 'Ukjent stasjon' : 'Alle stasjoner')
  const stasjonerTekst = (ider: string[] | null) => (ider && ider.length > 0 ? ider.map(stasjonTekst).join(', ') : 'Alle stasjoner')

  const forslag = (arr ?? []).filter((a) => a.status === 'forslag')
  const bekreftet = (arr ?? []).filter((a) => a.status !== 'forslag')
  const dag = (d: string) => datoLang.format(new Date(`${d}T12:00:00Z`))

  const stasjonsValg = (
    <fieldset className="stasjon-valg">
      <legend>Stasjoner <span className="undertittel">— ingen huket = alle</span></legend>
      {liste.map((s) => (
        <label key={s.id} className="stasjon-kryss">
          <input type="checkbox" name="stasjon_id" value={s.id} /> {s.butikknummer} {s.navn}
        </label>
      ))}
    </fieldset>
  )

  // NIVÅ 1 på en liste: hvor mange, og hvor mange krever noe av meg.
  // Forslagene er det eneste på siden som venter på et svar — resten er
  // ting som allerede er avgjort.
  const svar = [
    `${bekreftet.length} ${bekreftet.length === 1 ? 'bekreftet arrangement' : 'bekreftede arrangementer'} framover`,
    forslag.length > 0
      ? `${forslag.length} ${forslag.length === 1 ? 'forslag venter' : 'forslag venter'} på deg`
      : null,
  ].filter(Boolean).join(' · ')

  return (
    <Sideramme>
      <Sidehode
        tittel="Arrangementer"
        undertittel={svar}
        handlinger={
          <>
            <Sidepanel
              knapp="Nytt arrangement"
              tittel="Nytt arrangement"
              beskrivelse="Faktoren er hvor mye salget løftes: 1,2 betyr 20 % over en normal dag."
            >
              <form action={leggTilArrangement} className="sq-skjema arr-form">
                <div className="arr-form">
                  <input name="navn" placeholder="F.eks. Brann – Rosenborg" required />
                  <input name="dato" type="date" required aria-label="Dato" />
                  <input name="faktor" type="number" step="0.05" min="0.1" max="5" defaultValue="1.2" aria-label="Faktor" className="sq-smalt-felt" />
                </div>
                {stasjonsValg}
                <div className="knapperad">
                  <button type="submit" className="sq-knapp primar">Legg til arrangement</button>
                </div>
              </form>
            </Sidepanel>
            <Sidepanel
              knapp="Ny kalender-kilde"
              tittel="Ny kalender-kilde (iCal)"
              beskrivelse="Nattjobben henter hendelser 60 dager fram som forslag du bekrefter selv."
              knappeklasse="sq-knapp"
            >
              <form action={leggTilKalenderKilde} className="sq-skjema arr-form">
                <div className="arr-form">
                  <input name="navn" placeholder="Navn (f.eks. Brann hjemmekamper)" required />
                  <input name="ical_url" type="url" placeholder="https://…/kalender.ics" required aria-label="Kalender-URL" />
                  <input name="standard_faktor" type="number" step="0.05" min="0.1" max="5" defaultValue="1.2" aria-label="Standardfaktor" className="sq-smalt-felt" />
                </div>
                {stasjonsValg}
                <div className="knapperad">
                  <button type="submit" className="sq-knapp primar">Legg til kilde</button>
                </div>
              </form>
            </Sidepanel>
          </>
        }
      />

      {forslag.length > 0 && (
        <section className="kort oppmerksomhet">
          <h2>Forslag fra kalender <span className="undertittel">— teller ikke før du bekrefter</span></h2>
          <ul className="arr-liste">
            {forslag.map((f) => (
              <li key={f.id}>
                <span>{dag(f.dato)} · {f.navn} <span className="undertittel">· {stasjonTekst(f.stasjon_id)}</span></span>
                <form action={bekreftArrangement} className="arr-form">
                  <input type="hidden" name="id" value={f.id} />
                  <input name="faktor" type="number" step="0.05" min="0.1" max="5" defaultValue={f.faktor} aria-label="Faktor" className="sq-smalt-felt" />
                  <button type="submit" className="liten primar">Bekreft</button>
                </form>
                <form action={forkastArrangement}><input type="hidden" name="id" value={f.id} /><button type="submit" className="liten slett primar">Forkast</button></form>
              </li>
            ))}
          </ul>
        </section>
      )}

      <section className="kort">
        <h2>Kommende arrangementer</h2>
        {bekreftet.length > 0 ? (
          <ul className="arr-liste">
            {bekreftet.map((a) => (
              <li key={a.id}>
                <span>{dag(a.dato)} · {a.navn} <span className="undertittel">×{a.faktor} · {stasjonTekst(a.stasjon_id)}</span></span>
                <form action={forkastArrangement}><input type="hidden" name="id" value={a.id} /><button type="submit" className="liten slett primar">Fjern</button></form>
              </li>
            ))}
          </ul>
        ) : (
          <Tomtilstand
            tittel="Ingen bekreftede arrangementer framover"
            forklaring="Legg inn en kamp eller festival selv, eller koble på en iCal-kalender så nattjobben foreslår dem. Uten arrangementer regner prognosene med helt vanlige dager."
          />
        )}
      </section>

      <section className="kort">
        <h2>Kalender-kilder (iCal)</h2>
        {(kilder ?? []).length > 0 ? (
          <ul className="arr-liste">
            {(kilder ?? []).map((k) => (
              <li key={k.id}>
                <span>{k.navn} <span className="undertittel">×{k.standard_faktor} · {stasjonerTekst(k.stasjon_ider)}</span></span>
                <SlettKnapp hva={k.navn} handling={slettKalenderKilde} id={k.id} merke="Fjern" />
              </li>
            ))}
          </ul>
        ) : (
          <p className="undertittel">Ingen kilder koblet på. Alt legges inn manuelt.</p>
        )}
      </section>

      <Forklaring sporsmaal="Hva gjør faktoren, og når slår den inn?">
        <p>
          Faktoren er hvor mye salget løftes den dagen: 1,2 betyr 20 % over en normal
          dag. Den ganges inn i produksjonsplanen og salgsprognosen for de stasjonene
          du huker av — ingen huket betyr alle.
        </p>
        <p>
          Forslag fra kalender teller <strong>ikke</strong> før du bekrefter dem. Det er
          med vilje: en iCal-kalender vet at kampen spilles, men ikke om den faktisk
          gir trafikk forbi din stasjon. Bortekamper og kamper i nabobyen kommer inn i
          samme strøm som hjemmekampene.
        </p>
        <p>
          Henter du ikke inn noe og legger ikke inn noe, påvirkes ingenting. Siden er
          tom til den brukes, og det er en gyldig tilstand.
        </p>
      </Forklaring>
    </Sideramme>
  )
}
