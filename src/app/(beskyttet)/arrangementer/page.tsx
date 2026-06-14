import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { iDag, datoLang } from '@/lib/format'
import { leggTilArrangement, bekreftArrangement, forkastArrangement, leggTilKalenderKilde, slettKalenderKilde } from './handlinger'

type Arr = { id: string; dato: string; navn: string; faktor: number; stasjon_id: string | null; status: string }
type Kilde = { id: string; navn: string; ical_url: string; standard_faktor: number; stasjon_ider: string[] | null }

export default async function ArrangementerSide() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin') return <p>Arrangementer styres av eier.</p>

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

  return (
    <>
      <h1>Arrangementer</h1>
      <p className="undertittel">
        Hendelser som løfter salget (kamp, festival, lokale arrangement) — manuelt eller automatisk fra en iCal-kalender.
        Bekreftede arrangementer løfter produksjonsplan og salgsprognose for de stasjonene du velger. Henter du ikke inn noe, påvirkes ingenting.
      </p>

      {forslag.length > 0 && (
        <section className="kort oppmerksomhet">
          <h2>📥 Forslag fra kalender <span className="undertittel">— teller ikke før du bekrefter</span></h2>
          <ul className="arr-liste">
            {forslag.map((f) => (
              <li key={f.id}>
                <span>{dag(f.dato)} · {f.navn} <span className="undertittel">· {stasjonTekst(f.stasjon_id)}</span></span>
                <form action={bekreftArrangement} className="arr-form">
                  <input type="hidden" name="id" value={f.id} />
                  <input name="faktor" type="number" step="0.05" min="0.1" max="5" defaultValue={f.faktor} aria-label="Faktor" style={{ width: '4.5rem' }} />
                  <button type="submit" className="liten">Bekreft</button>
                </form>
                <form action={forkastArrangement}><input type="hidden" name="id" value={f.id} /><button type="submit" className="liten slett">Forkast</button></form>
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
                <form action={forkastArrangement}><input type="hidden" name="id" value={a.id} /><button type="submit" className="liten slett">Fjern</button></form>
              </li>
            ))}
          </ul>
        ) : <p className="undertittel">Ingen bekreftede arrangementer framover ennå.</p>}

        <form action={leggTilArrangement} className="rutine-form arr-form" style={{ marginTop: '1rem', flexDirection: 'column', alignItems: 'stretch' }}>
          <div className="arr-form">
            <input name="navn" placeholder="F.eks. Brann – Rosenborg" required />
            <input name="dato" type="date" required aria-label="Dato" />
            <input name="faktor" type="number" step="0.05" min="0.1" max="5" defaultValue="1.2" aria-label="Faktor" style={{ width: '5rem' }} />
          </div>
          {stasjonsValg}
          <button type="submit" className="liten" style={{ alignSelf: 'flex-start' }}>Legg til arrangement</button>
        </form>
      </section>

      <section className="kort">
        <h2>🗓️ Kalender-kilder (iCal)</h2>
        <p className="undertittel">
          Lim inn en .ics-lenke (kampoppsett, festivalkalender e.l.). Nattjobben henter hendelser 60 dager fram som forslag du bekrefter over.
        </p>
        {(kilder ?? []).length > 0 && (
          <ul className="arr-liste">
            {(kilder ?? []).map((k) => (
              <li key={k.id}>
                <span>{k.navn} <span className="undertittel">×{k.standard_faktor} · {stasjonerTekst(k.stasjon_ider)}</span></span>
                <form action={slettKalenderKilde}><input type="hidden" name="id" value={k.id} /><button type="submit" className="liten slett">Fjern</button></form>
              </li>
            ))}
          </ul>
        )}
        <form action={leggTilKalenderKilde} className="rutine-form arr-form" style={{ marginTop: '1rem', flexDirection: 'column', alignItems: 'stretch' }}>
          <div className="arr-form">
            <input name="navn" placeholder="Navn (f.eks. Brann hjemmekamper)" required />
            <input name="ical_url" type="url" placeholder="https://…/kalender.ics" required style={{ flex: '1 1 18rem' }} />
            <input name="standard_faktor" type="number" step="0.05" min="0.1" max="5" defaultValue="1.2" aria-label="Standardfaktor" style={{ width: '5rem' }} />
          </div>
          {stasjonsValg}
          <button type="submit" className="liten" style={{ alignSelf: 'flex-start' }}>Legg til kilde</button>
        </form>
      </section>
    </>
  )
}
