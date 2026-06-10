import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { leggTilPunkt, veksle, slettPunkt } from './handlinger'

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

  return (
    <>
      <h1>Min sjekkliste</h1>
      <p className="undertittel">Din private liste — kun du ser den. Daglige punkter nullstilles hver dag.</p>

      <section className="kort">
        <h2>Nytt punkt</h2>
        <form action={leggTilPunkt} className="rutine-form">
          <input name="tittel" placeholder="f.eks. Gå gjennom svinn-rapport" required />
          <label className="avkryss"><input type="checkbox" name="gjentakende" defaultChecked /> Daglig (nullstilles)</label>
          <button type="submit" className="liten">Legg til</button>
        </form>
      </section>

      <section className="kort">
        {(punkter ?? []).length === 0 ? (
          <p className="undertittel">Ingen punkter ennå.</p>
        ) : (
          <ul className="rutine-liste">
            {(punkter ?? []).map((p) => {
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
