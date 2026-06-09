import Link from 'next/link'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { datoLang } from '@/lib/format'
import {
  settOppStandard, leggTilOppgave, redigerOppgave, slettOppgave,
  leggTilPeriode, fullforPeriode, slettPeriode, vekslUtfort, leggTilSkift, slettSkift,
} from './handlinger'

type Oppgave = { id: string; kategori: string; tittel: string; beskrivelse: string | null; estimert_min: number | null }
type Periode = { id: string; stasjon_id: string; ansatt_navn: string; start_dato: string; forventet_slutt: string | null; fullfort_tid: string | null }
type Utfort = { periode_id: string; oppgave_id: string }
type Skift = { id: string; dato: string; notater: string | null }

export default async function OpplaringSide({ searchParams }: { searchParams: Promise<{ periode?: string }> }) {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin' && bruker.rolle !== 'butikksjef') {
    return <p>Opplæring administreres av eier/butikksjef.</p>
  }
  const supabase = await lagSupabaseServerKlient()
  const sp = await searchParams

  const [{ data: oppgaver }, { data: perioder }, { data: stasjoner }, { data: utfort }] = await Promise.all([
    supabase.from('opplaering_oppgave').select('id, kategori, tittel, beskrivelse, estimert_min').eq('aktiv', true).is('slettet_tid', null).order('rekkefolge').overrideTypes<Oppgave[]>(),
    supabase.from('opplaering_periode').select('id, stasjon_id, ansatt_navn, start_dato, forventet_slutt, fullfort_tid').order('start_dato', { ascending: false }).overrideTypes<Periode[]>(),
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null).order('butikknummer'),
    supabase.from('opplaering_utfort').select('periode_id, oppgave_id').overrideTypes<Utfort[]>(),
  ])

  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))
  const utfortPer = new Map<string, Set<string>>()
  for (const u of utfort ?? []) {
    const s = utfortPer.get(u.periode_id) ?? new Set<string>()
    s.add(u.oppgave_id)
    utfortPer.set(u.periode_id, s)
  }
  const totalOppgaver = (oppgaver ?? []).length
  const aktiveIds = new Set((oppgaver ?? []).map((o) => o.id))
  const teller = (pid: string) => [...(utfortPer.get(pid) ?? [])].filter((id) => aktiveIds.has(id)).length

  // Grupper master-oppgaver per kategori
  const kategorier: { navn: string; oppgaver: Oppgave[] }[] = []
  for (const o of oppgaver ?? []) {
    let g = kategorier.find((k) => k.navn === o.kategori)
    if (!g) { g = { navn: o.kategori, oppgaver: [] }; kategorier.push(g) }
    g.oppgaver.push(o)
  }

  const valgt = (perioder ?? []).find((p) => p.id === sp.periode)
  let skift: Skift[] = []
  if (valgt) {
    const { data } = await supabase.from('opplaering_skift').select('id, dato, notater').eq('periode_id', valgt.id).order('dato').overrideTypes<Skift[]>()
    skift = data ?? []
  }

  return (
    <>
      <h1>Opplæring</h1>
      <p className="undertittel">Onboarding av nyansatte — sjekkliste, kvittering og vaktplan.</p>

      {totalOppgaver === 0 ? (
        <section className="kort">
          <h2>Sett opp oppgaver</h2>
          <p className="undertittel">Tomt bibliotek. Start med {21} standardoppgaver (Kasse, Drivstoff, Bake, Renhold, Sikkerhet …), så kan du tilpasse.</p>
          <form action={settOppStandard}><button type="submit">Sett opp standardoppgaver</button></form>
        </section>
      ) : (
        <>
          <section className="kort">
            <h2>Under opplæring</h2>
            <form action={leggTilPeriode} className="rutine-form">
              <input name="ansatt_navn" placeholder="Navn på nyansatt" required />
              <select name="stasjon_id" required defaultValue={(stasjoner ?? []).length === 1 ? stasjoner![0].id : ''}>
                {(stasjoner ?? []).length !== 1 && <option value="" disabled>Stasjon …</option>}
                {(stasjoner ?? []).map((s) => <option key={s.id} value={s.id}>{s.butikknummer} {s.navn}</option>)}
              </select>
              <input name="start_dato" type="date" aria-label="Startdato" required />
              <input name="forventet_slutt" type="date" aria-label="Forventet ferdig" />
              <button type="submit" className="liten">Legg til</button>
            </form>

            {(perioder ?? []).length === 0 ? (
              <p className="undertittel" style={{ marginTop: '0.75rem' }}>Ingen under opplæring.</p>
            ) : (
              <ul className="person-liste">
                {(perioder ?? []).map((p) => {
                  const antall = teller(p.id)
                  const pst = totalOppgaver ? Math.round((antall / totalOppgaver) * 100) : 0
                  return (
                    <li key={p.id} className={valgt?.id === p.id ? 'aktiv' : ''}>
                      <Link href={`/opplaring?periode=${p.id}`}>
                        <strong>{p.ansatt_navn}</strong>
                        <span className="undertittel"> · {navnFor.get(p.stasjon_id) ?? '—'} · fra {datoLang.format(new Date(p.start_dato))}{p.fullfort_tid ? ' · ✅ fullført' : ''}</span>
                      </Link>
                      <span className="person-hoyre">
                        <span className={`status-pip ${pst === 100 ? 'gronn' : 'gul'}`}>{antall}/{totalOppgaver}</span>
                        <form action={slettPeriode}><input type="hidden" name="id" value={p.id} /><button type="submit" className="liten slett" aria-label="Fjern">✕</button></form>
                      </span>
                    </li>
                  )
                })}
              </ul>
            )}
          </section>

          {valgt && (
            <>
              <section className="kort">
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '0.5rem' }}>
                  <h2 style={{ margin: 0 }}>{valgt.ansatt_navn} — sjekkliste</h2>
                  <form action={fullforPeriode}>
                    <input type="hidden" name="id" value={valgt.id} />
                    <input type="hidden" name="til" value={valgt.fullfort_tid ? 'nei' : 'ja'} />
                    <button type="submit" className="liten">{valgt.fullfort_tid ? 'Gjenåpne' : 'Marker fullført'}</button>
                  </form>
                </div>
                {kategorier.map((k) => (
                  <div className="ik-gruppe" key={k.navn}>
                    <h3>{k.navn}</h3>
                    <ul className="rutine-liste">
                      {k.oppgaver.map((o) => {
                        const gjort = utfortPer.get(valgt.id)?.has(o.id) ?? false
                        return (
                          <li key={o.id} className={gjort ? 'gjort' : ''}>
                            <form action={vekslUtfort}>
                              <input type="hidden" name="periode_id" value={valgt.id} />
                              <input type="hidden" name="oppgave_id" value={o.id} />
                              <input type="hidden" name="til" value={gjort ? 'nei' : 'ja'} />
                              <button type="submit" className={`kryss ${gjort ? 'av' : ''}`} aria-label="Kvitter">{gjort ? '✓' : ''}</button>
                            </form>
                            <div className="rutine-tekst">
                              <strong>{o.tittel}</strong>
                              {o.estimert_min ? <span className="undertittel"> · ~{o.estimert_min} min</span> : null}
                              {o.beskrivelse ? <span className="undertittel"> — {o.beskrivelse}</span> : null}
                            </div>
                          </li>
                        )
                      })}
                    </ul>
                  </div>
                ))}
              </section>

              <section className="kort">
                <h2>Vaktplan</h2>
                <form action={leggTilSkift} className="rutine-form">
                  <input type="hidden" name="periode_id" value={valgt.id} />
                  <input name="dato" type="date" required aria-label="Vaktdag" />
                  <input name="notater" placeholder="Notat (f.eks. opplærer / fokus)" />
                  <button type="submit" className="liten">Legg til vakt</button>
                </form>
                {skift.length === 0 ? (
                  <p className="undertittel" style={{ marginTop: '0.5rem' }}>Ingen planlagte vakter.</p>
                ) : (
                  <ul className="person-liste">
                    {skift.map((s) => (
                      <li key={s.id}>
                        <span><strong>{datoLang.format(new Date(s.dato))}</strong>{s.notater ? <span className="undertittel"> · {s.notater}</span> : null}</span>
                        <form action={slettSkift}><input type="hidden" name="id" value={s.id} /><button type="submit" className="liten slett" aria-label="Fjern">✕</button></form>
                      </li>
                    ))}
                  </ul>
                )}
              </section>
            </>
          )}

          <section className="kort">
            <h2>Oppgavebibliotek</h2>
            {kategorier.map((k) => (
              <div className="ik-gruppe" key={k.navn}>
                <h3>{k.navn}</h3>
                <ul className="laereplan-liste">
                  {k.oppgaver.map((o) => (
                    <li key={o.id}>
                      <span>{o.tittel}{o.estimert_min ? ` (~${o.estimert_min} min)` : ''}</span>
                      <details className="rediger-detalj">
                        <summary>⋯</summary>
                        <form action={redigerOppgave} className="rediger-form">
                          <input type="hidden" name="id" value={o.id} />
                          <input name="kategori" defaultValue={o.kategori} aria-label="Kategori" />
                          <input name="tittel" defaultValue={o.tittel} aria-label="Tittel" />
                          <button type="submit" className="liten">Lagre</button>
                        </form>
                        <form action={slettOppgave}><input type="hidden" name="id" value={o.id} /><button type="submit" className="liten slett">Slett</button></form>
                      </details>
                    </li>
                  ))}
                </ul>
              </div>
            ))}
            <form action={leggTilOppgave} className="rutine-form" style={{ marginTop: '0.75rem' }}>
              <input name="kategori" placeholder="Kategori" style={{ maxWidth: '9rem' }} />
              <input name="tittel" placeholder="Ny oppgave" required />
              <input name="estimert_min" type="number" min="1" placeholder="min" style={{ maxWidth: '5rem' }} />
              <button type="submit" className="liten">Legg til</button>
            </form>
          </section>
        </>
      )}
    </>
  )
}
