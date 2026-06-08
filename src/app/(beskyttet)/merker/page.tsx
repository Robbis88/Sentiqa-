import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { settOppStandard, leggTilMerke, slettMerke, tildelMerke, fjernTildeling } from './handlinger'

type Merke = { id: string; navn: string; emoji: string; beskrivelse: string | null }
type Ansatt = { id: string; navn: string; stasjon_id: string }
type Tildelt = { id: string; merke_id: string; ansatt_id: string; merker: { navn: string; emoji: string } | null }

export default async function MerkerSide() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle === 'plattform_redaktor') return <p>Ingen tilgang.</p>
  const erLeder = bruker.rolle === 'retailer_admin' || bruker.rolle === 'butikksjef'

  const supabase = await lagSupabaseServerKlient()
  const [{ data: merker }, { data: ansatte }, { data: tildelte }, { data: stasjoner }] = await Promise.all([
    supabase.from('merker').select('id, navn, emoji, beskrivelse').is('slettet_tid', null).order('sortering').overrideTypes<Merke[]>(),
    supabase.from('ansatte').select('id, navn, stasjon_id').eq('aktiv', true).is('slettet_tid', null).order('navn').overrideTypes<Ansatt[]>(),
    supabase.from('tildelte_merker').select('id, merke_id, ansatt_id, merker(navn, emoji)').overrideTypes<Tildelt[]>(),
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null).order('butikknummer'),
  ])

  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))
  const perAnsatt = new Map<string, Tildelt[]>()
  for (const t of tildelte ?? []) {
    const l = perAnsatt.get(t.ansatt_id) ?? []
    l.push(t)
    perAnsatt.set(t.ansatt_id, l)
  }

  return (
    <>
      <h1>Merker</h1>
      <p className="undertittel">Anerkjennelse til de ansatte — vis fram det teamet får til. 🏅</p>

      {erLeder && (merker ?? []).length === 0 && (
        <section className="kort">
          <h2>Kom i gang</h2>
          <p className="undertittel">Start med et sett standardmerker, så kan du tilpasse.</p>
          <form action={settOppStandard}><button type="submit">Sett opp standardmerker</button></form>
        </section>
      )}

      {/* Merkevegg */}
      <section className="kort">
        <h2>Merkeveggen</h2>
        {(ansatte ?? []).length === 0 ? (
          <p className="undertittel">Ingen ansatte ennå (legg dem til under Ansatte).</p>
        ) : (
          <ul className="merkevegg">
            {(ansatte ?? []).map((a) => {
              const sine = perAnsatt.get(a.id) ?? []
              return (
                <li key={a.id}>
                  <div className="merkevegg-navn">
                    <strong>{a.navn}</strong>
                    <span className="undertittel"> · {navnFor.get(a.stasjon_id) ?? '—'}</span>
                  </div>
                  <div className="merkevegg-merker">
                    {sine.length === 0 ? <span className="undertittel">Ingen merker ennå</span> : sine.map((t) => (
                      <span className="merke-pill" key={t.id} title={t.merker?.navn}>
                        <span className="merke-emoji">{t.merker?.emoji}</span> {t.merker?.navn}
                        {erLeder && (
                          <form action={fjernTildeling} style={{ display: 'inline' }}>
                            <input type="hidden" name="id" value={t.id} />
                            <button type="submit" className="merke-fjern" aria-label="Fjern">×</button>
                          </form>
                        )}
                      </span>
                    ))}
                  </div>
                </li>
              )
            })}
          </ul>
        )}
      </section>

      {erLeder && (merker ?? []).length > 0 && (
        <>
          <section className="kort">
            <h2>Tildel et merke</h2>
            <form action={tildelMerke} className="rutine-form">
              <select name="ansatt_id" required defaultValue="">
                <option value="" disabled>Velg ansatt …</option>
                {(ansatte ?? []).map((a) => <option key={a.id} value={a.id}>{a.navn}</option>)}
              </select>
              <select name="merke_id" required defaultValue="">
                <option value="" disabled>Velg merke …</option>
                {(merker ?? []).map((m) => <option key={m.id} value={m.id}>{m.emoji} {m.navn}</option>)}
              </select>
              <button type="submit" className="liten">Tildel</button>
            </form>
          </section>

          <section className="kort">
            <h2>Merker</h2>
            <ul className="laereplan-liste">
              {(merker ?? []).map((m) => (
                <li key={m.id}>
                  <span><span className="merke-emoji">{m.emoji}</span> <strong>{m.navn}</strong>{m.beskrivelse ? <span className="undertittel"> — {m.beskrivelse}</span> : null}</span>
                  <form action={slettMerke}>
                    <input type="hidden" name="id" value={m.id} />
                    <button type="submit" className="liten slett">Slett</button>
                  </form>
                </li>
              ))}
            </ul>
            <form action={leggTilMerke} className="rutine-form" style={{ marginTop: '0.75rem' }}>
              <input name="emoji" placeholder="🏅" maxLength={4} style={{ width: '4rem' }} />
              <input name="navn" placeholder="Merkenavn" required />
              <input name="beskrivelse" placeholder="Beskrivelse (valgfri)" />
              <button type="submit" className="liten">Legg til</button>
            </form>
          </section>
        </>
      )}
    </>
  )
}
