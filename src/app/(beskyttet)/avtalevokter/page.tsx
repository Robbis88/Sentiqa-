import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { kr, datoLang } from '@/lib/format'
import { Opplaster } from './opplaster'
import { ForhandlingKnapp } from './forhandling-knapp'

type Faktura = {
  id: string
  stasjon_id: string | null
  leverandor: string | null
  kategori: string | null
  faktura_dato: string | null
  belop_kr: number | null
  beskrivelse: string | null
}

export default async function AvtalevokterSide() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin') return <p>Kun eier har tilgang til Avtalevokter.</p>

  const supabase = await lagSupabaseServerKlient()
  const [{ data: fakturaer }, { data: stasjoner }] = await Promise.all([
    supabase
      .from('fakturaer')
      .select('id, stasjon_id, leverandor, kategori, faktura_dato, belop_kr, beskrivelse')
      .is('slettet_tid', null)
      .order('faktura_dato', { ascending: false })
      .overrideTypes<Faktura[]>(),
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null).order('butikknummer'),
  ])

  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))

  // Grupper per leverandør
  const perLev = new Map<string, Faktura[]>()
  for (const f of fakturaer ?? []) {
    const k = f.leverandor ?? 'Ukjent'
    const l = perLev.get(k) ?? []
    l.push(f)
    perLev.set(k, l)
  }

  return (
    <>
      <h1>Avtalevokter</h1>
      <p className="undertittel">
        Dra inn fakturaer — AI leser dem og bygger forbruksprofil per leverandør på tvers av stasjoner (§11).
      </p>

      <section className="kort">
        <h2>Last opp faktura</h2>
        <Opplaster stasjoner={(stasjoner ?? []).map((s) => ({ id: s.id, navn: `${s.butikknummer} ${s.navn}` }))} />
      </section>

      {perLev.size === 0 ? (
        <section className="kort"><p className="undertittel">Ingen fakturaer lest ennå.</p></section>
      ) : (
        [...perLev.entries()].map(([lev, liste]) => {
          const total = liste.reduce((a, f) => a + (f.belop_kr ?? 0), 0)
          return (
            <section className="kort" key={lev}>
              <h2>{lev} <span className="undertittel">· {liste[0].kategori ?? '—'} · totalt {kr.format(total)}</span></h2>
              <table className="tabell">
                <thead>
                  <tr><th>Stasjon</th><th>Dato</th><th>Beløp</th><th>Beskrivelse</th></tr>
                </thead>
                <tbody>
                  {liste.map((f) => (
                    <tr key={f.id}>
                      <td>{f.stasjon_id ? navnFor.get(f.stasjon_id) ?? '—' : 'Felles'}</td>
                      <td>{f.faktura_dato ? datoLang.format(new Date(f.faktura_dato)) : '—'}</td>
                      <td>{kr.format(f.belop_kr ?? 0)}</td>
                      <td>{f.beskrivelse}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
              <ForhandlingKnapp leverandor={lev} />
            </section>
          )
        })
      )}
    </>
  )
}
