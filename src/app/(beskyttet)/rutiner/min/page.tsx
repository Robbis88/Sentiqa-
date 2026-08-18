import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { leggTilPunkt, veksle, slettPunkt } from './handlinger'
import { Sidehode, Tomtilstand } from '@/components/ui/side'
import { Sidepanel } from '@/components/ui/sidepanel'

type Punkt = { id: string; tittel: string; gjentakende: boolean; fullfort_tid: string | null }

export default async function MinSjekkliste() {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) {
    return <p>Personlig sjekkliste er for eier/butikksjef.</p>
  }
  const supabase = await lagSupabaseServerKlient()
  const idag = new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Oslo' }).format(new Date())

  const [{ data: punkter }, { data: kryss }] = await Promise.all([
    supabase.from('personlig_punkt').select('id, tittel, gjentakende, fullfort_tid').is('slettet_tid', null).order('opprettet_tid').overrideTypes<Punkt[]>(),
    supabase.from('personlig_kryss').select('punkt_id').eq('dato', idag).overrideTypes<{ punkt_id: string }[]>(),
  ])
  const kryssetIdag = new Set((kryss ?? []).map((k) => k.punkt_id))

  const erGjort = (p: Punkt) => (p.gjentakende ? kryssetIdag.has(p.id) : Boolean(p.fullfort_tid))

  // NIVÅ 1 på en arbeidsflyt: hvor langt er jeg kommet. Lista viste
  // avhukede punkter, men aldri hvor mange som gjensto — man måtte telle
  // gjennomstrekede rader for å vite om man var ferdig.
  const alle = punkter ?? []
  const gjortAntall = alle.filter(erGjort).length
  const svar = alle.length === 0
    ? 'Din private liste — kun du ser den'
    : gjortAntall >= alle.length
      ? `Alt gjort · ${alle.length} ${alle.length === 1 ? 'punkt' : 'punkter'}`
      : `${alle.length - gjortAntall} igjen av ${alle.length}`

  return (
    <>
      <Sidehode
        tittel="Min sjekkliste"
        undertittel={`${svar}. Kun du ser den, og daglige punkter nullstilles hver dag.`}
        handlinger={
          <Sidepanel
            knapp="Nytt punkt"
            tittel="Nytt punkt"
            beskrivelse="Daglige punkter nullstilles hver natt. Engangspunkter blir stående til du huker dem av."
          >
            <form action={leggTilPunkt} className="rutine-form" style={{ flexDirection: 'column', alignItems: 'stretch' }}>
              <input name="tittel" placeholder="f.eks. Gå gjennom svinn-rapport" required />
              <label className="avkryss"><input type="checkbox" name="gjentakende" defaultChecked /> Daglig (nullstilles)</label>
              <button type="submit" className="sq-knapp primar" style={{ alignSelf: 'flex-start' }}>Legg til</button>
            </form>
          </Sidepanel>
        }
      />

      <section className="kort">
        {alle.length === 0 ? (
          <Tomtilstand
            tittel="Ingen punkter ennå"
            forklaring="Dette er stedet for de tingene du selv vil huske — gå gjennom svinnrapporten, ringe leverandøren, sjekke vaktplanen. Ingen andre ser lista."
          />
        ) : (
          <ul className="rutine-liste">
            {alle.map((p) => {
              const gjort = erGjort(p)
              return (
                <li key={p.id} className={gjort ? 'gjort' : ''}>
                  <form action={veksle}>
                    <input type="hidden" name="punkt_id" value={p.id} />
                    <input type="hidden" name="gjentakende" value={String(p.gjentakende)} />
                    <input type="hidden" name="til" value={gjort ? 'nei' : 'ja'} />
                    <button type="submit" className={`kryss ${gjort ? 'av' : ''}`} aria-label="Veksle">{gjort ? '✓' : ''}</button>
                  </form>
                  <div className="rutine-tekst">
                    <strong>{p.tittel}</strong>
                    <span className="undertittel"> · {p.gjentakende ? 'daglig' : 'engangs'}</span>
                  </div>
                  <form action={slettPunkt}>
                    <input type="hidden" name="id" value={p.id} />
                    <button type="submit" className="liten slett" aria-label="Slett">✕</button>
                  </form>
                </li>
              )
            })}
          </ul>
        )}
      </section>
    </>
  )
}
