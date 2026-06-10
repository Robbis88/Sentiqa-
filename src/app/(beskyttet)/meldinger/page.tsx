import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { sendMelding, slettMelding } from './handlinger'

type Melding = { id: string; stasjon_id: string | null; tekst: string; viktig: boolean; opprettet_tid: string }

const tid = new Intl.DateTimeFormat('nb-NO', { timeZone: 'Europe/Oslo', dateStyle: 'short', timeStyle: 'short' })

export default async function MeldingerSide() {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) {
    return <p>Kun eier/butikksjef kan sende meldinger.</p>
  }
  const supabase = await lagSupabaseServerKlient()
  const [{ data: meldinger }, { data: stasjoner }] = await Promise.all([
    supabase.from('tablet_meldinger').select('id, stasjon_id, tekst, viktig, opprettet_tid').is('slettet_tid', null).order('opprettet_tid', { ascending: false }).overrideTypes<Melding[]>(),
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null).order('butikknummer'),
  ])
  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))

  return (
    <>
      <h1>Meldinger til tablet</h1>
      <p className="undertittel">Korte beskjeder som vises på stasjonens nettbrett.</p>

      <section className="kort">
        <h2>Ny melding</h2>
        <form action={sendMelding} className="skjema" style={{ maxWidth: 520 }}>
          <label className="felt"><span>Til</span>
            <select name="stasjon_id" defaultValue="">
              <option value="">Alle stasjoner</option>
              {(stasjoner ?? []).map((s) => <option key={s.id} value={s.id}>{s.butikknummer} {s.navn}</option>)}
            </select>
          </label>
          <label className="felt"><span>Melding</span><textarea name="tekst" rows={3} required /></label>
          <label className="felt avkryss"><input type="checkbox" name="viktig" /> Viktig (rød)</label>
          <button type="submit" className="liten">Send</button>
        </form>
      </section>

      <section className="kort">
        <h2>Aktive ({(meldinger ?? []).length})</h2>
        {(meldinger ?? []).length === 0 ? (
          <p className="undertittel">Ingen aktive meldinger.</p>
        ) : (
          <ul className="melding-liste">
            {(meldinger ?? []).map((m) => (
              <li key={m.id} className={m.viktig ? 'viktig' : ''}>
                <div>
                  <p className="melding-tekst">{m.tekst}</p>
                  <span className="undertittel">{m.stasjon_id ? navnFor.get(m.stasjon_id) ?? '—' : 'Alle stasjoner'} · {tid.format(new Date(m.opprettet_tid))}</span>
                </div>
                <form action={slettMelding}>
                  <input type="hidden" name="id" value={m.id} />
                  <button type="submit" className="liten slett" aria-label="Slett">✕</button>
                </form>
              </li>
            ))}
          </ul>
        )}
      </section>
    </>
  )
}
