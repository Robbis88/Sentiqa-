import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { manedAar } from '@/lib/format'
import { GenererKnapp } from './generer-knapp'

type Punkt = {
  stasjon_id: string
  periode: string
  type: string
  tekst: string
}

export default async function FokusSide() {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) {
    return <p>Du har ikke tilgang til fokuspunkter.</p>
  }

  const supabase = await lagSupabaseServerKlient()
  const { data: siste } = await supabase
    .from('fokuspunkter')
    .select('periode')
    .order('periode', { ascending: false })
    .limit(1)
    .maybeSingle<{ periode: string }>()

  const [{ data: punkter }, { data: stasjoner }] = await Promise.all([
    siste
      ? supabase
          .from('fokuspunkter')
          .select('stasjon_id, periode, type, tekst')
          .eq('periode', siste.periode)
          .overrideTypes<Punkt[]>()
      : Promise.resolve({ data: [] as Punkt[] }),
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null).order('butikknummer'),
  ])

  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))
  const perStasjon = new Map<string, { forbedring: string[]; positivt: string[] }>()
  for (const p of punkter ?? []) {
    const b = perStasjon.get(p.stasjon_id) ?? { forbedring: [], positivt: [] }
    if (p.type === 'forbedring') b.forbedring.push(p.tekst)
    else b.positivt.push(p.tekst)
    perStasjon.set(p.stasjon_id, b)
  }

  return (
    <>
      <h1>Fokus</h1>
      <p className="undertittel">
        {siste ? manedAar.format(new Date(siste.periode)) : 'Ingen fokuspunkter ennå'} · etter regnskapet
      </p>

      {bruker.rolle === 'retailer_admin' && <GenererKnapp />}

      {[...perStasjon.entries()].length === 0 ? (
        <section className="kort">
          <p className="undertittel">
            {bruker.rolle === 'retailer_admin'
              ? 'Ingen fokuspunkter ennå. Behandle et regnskap og trykk «Generer fokuspunkter».'
              : 'Ingen fokuspunkter publisert ennå.'}
          </p>
        </section>
      ) : (
        [...perStasjon.entries()].map(([id, b]) => (
          <section className="kort" key={id}>
            <h2>{navnFor.get(id) ?? '—'}</h2>
            <div className="fokus-kol">
              <div>
                <h3 className="fokus-tittel gronn">Bra jobbet</h3>
                <ul className="fokus-liste">
                  {b.positivt.map((t, i) => (
                    <li key={i}>{t}</li>
                  ))}
                </ul>
              </div>
              <div>
                <h3 className="fokus-tittel gul">Verdt et blikk</h3>
                <ul className="fokus-liste">
                  {b.forbedring.map((t, i) => (
                    <li key={i}>{t}</li>
                  ))}
                </ul>
              </div>
            </div>
          </section>
        ))
      )}
    </>
  )
}
