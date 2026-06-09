import Link from 'next/link'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { VAKTTYPER, VAKTTYPE_ETIKETT, UKEDAG_NAVN } from '@/lib/rutineskjema'
import { leggTilSkjema, slettSkjema, leggTilRutine, slettRutine } from './handlinger'

type Skjema = { id: string; stasjon_id: string; vakttype: string; navn: string | null; tid_start: string; tid_slutt: string; ukedager: number[] }
type Rutine = { id: string; skjema_id: string | null; tittel: string; beskrivelse: string | null; ukedager: number[]; paakrevd_bilde: boolean }

function UkedagVelger() {
  return (
    <span className="ukedag-velger">
      {UKEDAG_NAVN.map((n, i) => (
        <label key={i} className="ukedag"><input type="checkbox" name="ukedager" value={i} /> {n}</label>
      ))}
    </span>
  )
}
function dagerTekst(d: number[]) {
  return d.length === 0 ? 'alle dager' : d.map((i) => UKEDAG_NAVN[i]).join(', ')
}

export default async function OppsettSide() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin' && bruker.rolle !== 'butikksjef') {
    return <p>Kun eier/butikksjef kan sette opp rutineskjemaer.</p>
  }
  const supabase = await lagSupabaseServerKlient()
  const [{ data: stasjoner }, { data: skjemaer }, { data: rutiner }] = await Promise.all([
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null).order('butikknummer'),
    supabase.from('rutineskjemaer').select('id, stasjon_id, vakttype, navn, tid_start, tid_slutt, ukedager').is('slettet_tid', null).overrideTypes<Skjema[]>(),
    supabase.from('rutiner').select('id, skjema_id, tittel, beskrivelse, ukedager, paakrevd_bilde').is('slettet_tid', null).order('sortering').overrideTypes<Rutine[]>(),
  ])

  const rutinerForSkjema = new Map<string, Rutine[]>()
  for (const r of (rutiner ?? []) as unknown as Rutine[]) {
    if (!r.skjema_id) continue
    const l = rutinerForSkjema.get(r.skjema_id) ?? []
    l.push(r)
    rutinerForSkjema.set(r.skjema_id, l)
  }
  const skjemaerForStasjon = new Map<string, Skjema[]>()
  for (const s of (skjemaer ?? []) as unknown as Skjema[]) {
    const l = skjemaerForStasjon.get(s.stasjon_id) ?? []
    l.push(s)
    skjemaerForStasjon.set(s.stasjon_id, l)
  }

  return (
    <>
      <h1>Rutineoppsett</h1>
      <p className="undertittel">Lag et skjema per vakttype, sett tider og ukedager — og legg rutinene inn. <Link href="/rutiner">Til avkryssing →</Link></p>

      {(stasjoner ?? []).map((st) => (
        <section className="kort" key={st.id}>
          <h2>{st.butikknummer} {st.navn}</h2>

          {(skjemaerForStasjon.get(st.id) ?? []).map((sk) => (
            <div className="skjema-kort" key={sk.id}>
              <div className="skjema-topp">
                <strong>{VAKTTYPE_ETIKETT[sk.vakttype]}{sk.navn ? ` · ${sk.navn}` : ''}</strong>
                <span className="undertittel"> {sk.tid_start}–{sk.tid_slutt} · {dagerTekst(sk.ukedager)}</span>
                <form action={slettSkjema} style={{ marginLeft: 'auto' }}>
                  <input type="hidden" name="id" value={sk.id} />
                  <button type="submit" className="liten slett">Slett skjema</button>
                </form>
              </div>

              <ul className="rutine-liste">
                {(rutinerForSkjema.get(sk.id) ?? []).map((r) => (
                  <li key={r.id}>
                    <div className="rutine-tekst">
                      {r.tittel}
                      {r.beskrivelse ? <span className="undertittel"> — {r.beskrivelse}</span> : null}
                      {r.paakrevd_bilde ? <span className="bilde-merke">📷</span> : null}
                      {r.ukedager.length > 0 ? <span className="undertittel"> · {dagerTekst(r.ukedager)}</span> : null}
                    </div>
                    <form action={slettRutine}>
                      <input type="hidden" name="id" value={r.id} />
                      <button type="submit" className="liten slett" aria-label="Slett">✕</button>
                    </form>
                  </li>
                ))}
              </ul>

              <form action={leggTilRutine} className="rutine-form">
                <input type="hidden" name="skjema_id" value={sk.id} />
                <input type="hidden" name="stasjon_id" value={st.id} />
                <input name="tittel" placeholder="Ny rutine" required />
                <input name="beskrivelse" placeholder="Beskrivelse (valgfri)" />
                <UkedagVelger />
                <label className="avkryss"><input type="checkbox" name="paakrevd_bilde" /> 📷 bilde</label>
                <button type="submit" className="liten">Legg til rutine</button>
              </form>
            </div>
          ))}

          <details className="rediger-detalj nytt-skjema">
            <summary>+ Nytt vakttype-skjema</summary>
            <form action={leggTilSkjema} className="skjema-form">
              <input type="hidden" name="stasjon_id" value={st.id} />
              <label className="felt"><span>Vakttype</span>
                <select name="vakttype" defaultValue="morgen">
                  {VAKTTYPER.map((v) => <option key={v} value={v}>{VAKTTYPE_ETIKETT[v]}</option>)}
                </select>
              </label>
              <label className="felt"><span>Navn (valgfri)</span><input name="navn" placeholder="f.eks. Åpning" /></label>
              <div className="rad-2">
                <label className="felt"><span>Fra</span><input type="time" name="tid_start" defaultValue="06:00" required /></label>
                <label className="felt"><span>Til</span><input type="time" name="tid_slutt" defaultValue="14:00" required /></label>
              </div>
              <label className="felt"><span>Ukedager (ingen = alle)</span><UkedagVelger /></label>
              <button type="submit" className="liten">Opprett skjema</button>
            </form>
          </details>
        </section>
      ))}
    </>
  )
}
