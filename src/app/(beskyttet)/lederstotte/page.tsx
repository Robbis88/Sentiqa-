import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { manedAar } from '@/lib/format'
import type { Lederstotte } from '@/lib/ai/lederstotte'
import { GenererKnapp } from './generer-knapp'

const STATUS_TEKST: Record<string, string> = { gronn: 'Sterkt', gul: 'På god vei', bla: 'Utviklingspotensial' }

type Rad = { stasjon_id: string; periode: string; rapport: Lederstotte }

export default async function LederstotteSide() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin' && bruker.rolle !== 'butikksjef') {
    return <p>Du har ikke tilgang til lederstøtte.</p>
  }

  const supabase = await lagSupabaseServerKlient()
  const { data: siste } = await supabase
    .from('lederstotte_rapporter')
    .select('periode')
    .order('periode', { ascending: false })
    .limit(1)
    .maybeSingle<{ periode: string }>()

  const [{ data: rader }, { data: stasjoner }] = await Promise.all([
    siste
      ? supabase
          .from('lederstotte_rapporter')
          .select('stasjon_id, periode, rapport')
          .eq('periode', siste.periode)
          .overrideTypes<Rad[]>()
      : Promise.resolve({ data: [] as Rad[] }),
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null).order('butikknummer'),
  ])

  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))

  return (
    <>
      <h1>Lederstøtte</h1>
      <p className="undertittel">
        {siste ? manedAar.format(new Date(siste.periode)) : 'Ingen rapporter ennå'} · utviklingsorientert
      </p>

      {bruker.rolle === 'retailer_admin' && <GenererKnapp />}

      {(rader ?? []).length === 0 ? (
        <section className="kort">
          <p className="undertittel">
            {bruker.rolle === 'retailer_admin'
              ? 'Ingen rapporter ennå. Behandle et regnskap og trykk «Generer lederstøtte».'
              : 'Ingen lederstøtte-rapport publisert ennå.'}
          </p>
        </section>
      ) : (
        (rader ?? []).map((rad) => {
          const r = rad.rapport
          return (
            <section className="kort" key={rad.stasjon_id}>
              <h2>
                {navnFor.get(rad.stasjon_id) ?? '—'}{' '}
                <span className={`status-pip ${r.status}`}>{STATUS_TEKST[r.status] ?? r.status}</span>
              </h2>
              <p>{r.oppsummering}</p>
              <div className="fokus-kol">
                <div>
                  <h3 className="fokus-tittel gronn">Styrker</h3>
                  <ul className="fokus-liste">{r.styrker.map((t, i) => <li key={i}>{t}</li>)}</ul>
                </div>
                <div>
                  <h3 className="fokus-tittel bla">Utviklingsområder</h3>
                  <ul className="fokus-liste">{r.utviklingsomrader.map((t, i) => <li key={i}>{t}</li>)}</ul>
                </div>
              </div>
              <h3 className="fokus-tittel" style={{ marginTop: '1rem' }}>Neste steg</h3>
              <ol className="tiltak-liste">{r.nesteSteg.map((t, i) => <li key={i}>{t}</li>)}</ol>
            </section>
          )
        })
      )}
    </>
  )
}
