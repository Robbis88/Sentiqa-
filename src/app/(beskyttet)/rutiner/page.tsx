import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { datoLang } from '@/lib/format'
import { NyRutine } from './ny-rutine'
import { kryssAv, fjernKryss, slettRutine } from './handlinger'

type Rutine = {
  id: string
  stasjon_id: string
  tittel: string
  beskrivelse: string | null
  paakrevd_bilde: boolean
}

export default async function RutinerSide() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle === 'plattform_redaktor') {
    return <p>Du har ikke tilgang til rutiner.</p>
  }

  const supabase = await lagSupabaseServerKlient()
  const idag = new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Oslo' }).format(new Date())

  const [{ data: rutiner }, { data: utforinger }, { data: stasjoner }] = await Promise.all([
    supabase
      .from('rutiner')
      .select('id, stasjon_id, tittel, beskrivelse, paakrevd_bilde')
      .is('slettet_tid', null)
      .order('tittel')
      .overrideTypes<Rutine[]>(),
    supabase.from('rutine_utforinger').select('rutine_id').eq('dato', idag),
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null).order('butikknummer'),
  ])

  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))
  const utfort = new Set((utforinger ?? []).map((u) => u.rutine_id))
  const kanLage = bruker.rolle === 'retailer_admin' || bruker.rolle === 'butikksjef'

  // Grupper rutiner per stasjon
  const perStasjon = new Map<string, Rutine[]>()
  for (const r of rutiner ?? []) {
    const liste = perStasjon.get(r.stasjon_id) ?? []
    liste.push(r)
    perStasjon.set(r.stasjon_id, liste)
  }

  return (
    <>
      <h1>Rutiner</h1>
      <p className="undertittel">{datoLang.format(new Date(idag))} · kryss av når gjort</p>

      {kanLage && (
        <section className="kort">
          <h2>Ny rutine</h2>
          <NyRutine stasjoner={(stasjoner ?? []).map((s) => ({ id: s.id, navn: `${s.butikknummer} ${s.navn}` }))} />
        </section>
      )}

      {perStasjon.size === 0 ? (
        <section className="kort"><p className="undertittel">Ingen rutiner ennå.</p></section>
      ) : (
        [...perStasjon.entries()].map(([sid, liste]) => (
          <section className="kort" key={sid}>
            <h2>{navnFor.get(sid) ?? '—'}</h2>
            <ul className="rutine-liste">
              {liste.map((r) => {
                const gjort = utfort.has(r.id)
                return (
                  <li key={r.id} className={gjort ? 'gjort' : ''}>
                    <form action={gjort ? fjernKryss : kryssAv}>
                      <input type="hidden" name="rutine_id" value={r.id} />
                      <input type="hidden" name="stasjon_id" value={r.stasjon_id} />
                      <button type="submit" className={`kryss ${gjort ? 'av' : ''}`} aria-label="Kryss av">
                        {gjort ? '✓' : ''}
                      </button>
                    </form>
                    <div className="rutine-tekst">
                      <strong>{r.tittel}</strong>
                      {r.beskrivelse ? <span className="undertittel"> — {r.beskrivelse}</span> : null}
                      {r.paakrevd_bilde ? <span className="bilde-merke">📷</span> : null}
                    </div>
                    {kanLage && (
                      <form action={slettRutine}>
                        <input type="hidden" name="id" value={r.id} />
                        <button type="submit" className="liten slett" aria-label="Slett">✕</button>
                      </form>
                    )}
                  </li>
                )
              })}
            </ul>
          </section>
        ))
      )}
    </>
  )
}
