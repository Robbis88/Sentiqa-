import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { datoLang } from '@/lib/format'
import { NyAvvik } from './ny-avvik'
import { settGjennomfort } from './handlinger'

type Avvik = {
  id: string
  stasjon_id: string
  lopenr: number
  kategori: string
  dato: string
  beskrivelse: string
  strakstiltak: string | null
  korrigerende: string | null
  frist: string | null
  varslet_til: string | null
  gjennomfort: boolean
  gjennomfort_dato: string | null
}

// Avvik-delen (S01) — gjenbrukbar, vises som seksjon under IK-mat.
export async function AvvikDel() {
  const supabase = await lagSupabaseServerKlient()
  const idag = new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Oslo' }).format(new Date())

  const [{ data: avvik }, { data: stasjoner }] = await Promise.all([
    supabase
      .from('avvik')
      .select('id, stasjon_id, lopenr, kategori, dato, beskrivelse, strakstiltak, korrigerende, frist, varslet_til, gjennomfort, gjennomfort_dato')
      .is('slettet_tid', null)
      .order('opprettet_tid', { ascending: false })
      .overrideTypes<Avvik[]>(),
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null).order('butikknummer'),
  ])

  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))
  const apne = (avvik ?? []).filter((a) => !a.gjennomfort)
  const lukket = (avvik ?? []).filter((a) => a.gjennomfort)

  const kort = (a: Avvik) => (
    <div className={`avvik-kort ${a.gjennomfort ? 'lukket' : ''}`} key={a.id}>
      <div className="avvik-topp">
        <strong>#{String(a.lopenr).padStart(3, '0')}</strong>
        <span className={`status-pip ${a.kategori === 'produkt' ? 'gul' : 'bla'}`}>{a.kategori === 'produkt' ? 'Produkt' : 'Utstyr'}</span>
        <span className="undertittel">{navnFor.get(a.stasjon_id) ?? '—'} · {datoLang.format(new Date(a.dato))}</span>
      </div>
      <p className="avvik-besk">{a.beskrivelse}</p>
      {a.strakstiltak ? <p className="undertittel"><strong>Strakstiltak:</strong> {a.strakstiltak}</p> : null}
      {a.korrigerende ? <p className="undertittel"><strong>Korrigerende:</strong> {a.korrigerende}</p> : null}
      <p className="undertittel">
        {a.frist ? <>Frist {datoLang.format(new Date(a.frist))} · </> : null}
        {a.varslet_til ? <>Varslet: {a.varslet_til} · </> : null}
        {a.gjennomfort ? <>✓ Gjennomført {a.gjennomfort_dato ? datoLang.format(new Date(a.gjennomfort_dato)) : ''}</> : null}
      </p>
      <form action={settGjennomfort}>
        <input type="hidden" name="id" value={a.id} />
        <input type="hidden" name="til" value={a.gjennomfort ? 'nei' : 'ja'} />
        <button type="submit" className="liten primar">{a.gjennomfort ? 'Gjenåpne' : 'Marker gjennomført'}</button>
      </form>
    </div>
  )

  return (
    <>
      <h2 className="del-skille">Avvik (S01)</h2>
      <p className="undertittel">Avviksskjema for hurtigmat — produkt eller utstyr.</p>

      <section className="kort">
        <h2>Nytt avvik</h2>
        <NyAvvik stasjoner={(stasjoner ?? []).map((s) => ({ id: s.id, navn: `${s.butikknummer} ${s.navn}` }))} idag={idag} />
      </section>

      <section className="kort">
        <h2>Åpne ({apne.length})</h2>
        {apne.length === 0 ? <p className="undertittel">Ingen åpne avvik.</p> : <div className="avvik-liste">{apne.map(kort)}</div>}
      </section>

      {lukket.length > 0 && (
        <section className="kort">
          <h2>Lukket ({lukket.length})</h2>
          <div className="avvik-liste">{lukket.map(kort)}</div>
        </section>
      )}
    </>
  )
}
