import Link from 'next/link'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { datoLang } from '@/lib/format'
import { osloNaa, skjemaAktiv, rutineGjelder, VAKTTYPE_ETIKETT, type Vaktvindu } from '@/lib/rutineskjema'
import { beregnRutinestat } from '@/lib/rutinestat'
import { kryssAv, fjernKryss } from './handlinger'

type Skjema = { id: string; stasjon_id: string; vakttype: string; navn: string | null; tid_start: string; tid_slutt: string; ukedager: number[] }
type Rutine = { id: string; skjema_id: string | null; stasjon_id: string; tittel: string; beskrivelse: string | null; ukedager: number[]; opprettet_dato: string; paakrevd_bilde: boolean }

export default async function RutinerSide() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle === 'plattform_redaktor') return <p>Ingen tilgang.</p>
  const erLeder = bruker.rolle === 'retailer_admin' || bruker.rolle === 'butikksjef'

  const supabase = await lagSupabaseServerKlient()
  const naa = osloNaa(new Date())

  const [{ data: stasjoner }, { data: skjemaer }, { data: rutiner }] = await Promise.all([
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null).order('butikknummer'),
    supabase.from('rutineskjemaer').select('id, stasjon_id, vakttype, navn, tid_start, tid_slutt, ukedager').eq('aktiv', true).is('slettet_tid', null).overrideTypes<Skjema[]>(),
    supabase.from('rutiner').select('id, skjema_id, stasjon_id, tittel, beskrivelse, ukedager, opprettet_dato, paakrevd_bilde').not('skjema_id', 'is', null).is('slettet_tid', null).order('sortering').overrideTypes<Rutine[]>(),
  ])

  // Aktive skjemaer nå (med vaktvindu)
  const aktive: { skjema: Skjema; vindu: Vaktvindu }[] = []
  for (const s of (skjemaer ?? []) as unknown as Skjema[]) {
    const vindu = skjemaAktiv(s, naa)
    if (vindu.aktiv) aktive.push({ skjema: s, vindu })
  }

  // Rutiner pr skjema, filtrert på vakten
  const rutinerForSkjema = new Map<string, Rutine[]>()
  for (const r of (rutiner ?? []) as unknown as Rutine[]) {
    if (!r.skjema_id) continue
    const l = rutinerForSkjema.get(r.skjema_id) ?? []
    l.push(r)
    rutinerForSkjema.set(r.skjema_id, l)
  }

  // Hent utføringer for de aktuelle vaktdatoene
  const datoer = [...new Set(aktive.map((a) => a.vindu.vaktdato))]
  const utfort = new Set<string>()
  if (datoer.length > 0) {
    const { data } = await supabase.from('rutine_utforinger').select('rutine_id, dato').in('dato', datoer)
    for (const u of (data ?? []) as { rutine_id: string; dato: string }[]) utfort.add(`${u.rutine_id}|${u.dato}`)
  }

  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))
  // Grupper aktive skjemaer pr stasjon
  const perStasjon = new Map<string, { skjema: Skjema; vindu: Vaktvindu }[]>()
  for (const a of aktive) {
    const l = perStasjon.get(a.skjema.stasjon_id) ?? []
    l.push(a)
    perStasjon.set(a.skjema.stasjon_id, l)
  }

  // Streak pr aktiv stasjon (motivasjon)
  const streaks = new Map<string, number>()
  await Promise.all(
    [...perStasjon.keys()].map(async (sid) => {
      const st = await beregnRutinestat(supabase, sid, naa.dato)
      streaks.set(sid, st.streak)
    }),
  )

  return (
    <>
      <h1>Rutiner</h1>
      <p className="undertittel">
        Aktiv vakt nå · {datoLang.format(new Date(naa.dato))}
        {erLeder ? <> · <Link href="/rutiner/oppsett">Rutineoppsett →</Link></> : null}
      </p>

      {perStasjon.size === 0 ? (
        <section className="kort">
          <p className="undertittel">
            Ingen aktiv vakt akkurat nå.{erLeder ? <> Sett opp vakttype-skjemaer under <Link href="/rutiner/oppsett">Rutineoppsett</Link>.</> : ''}
          </p>
        </section>
      ) : (
        [...perStasjon.entries()].map(([sid, liste]) => (
          <section className="kort" key={sid}>
            <h2>{navnFor.get(sid) ?? '—'}{(streaks.get(sid) ?? 0) > 0 && <span className="streak"> 🔥 {streaks.get(sid)}</span>}</h2>
            {liste.map(({ skjema, vindu }) => {
              const rs = (rutinerForSkjema.get(skjema.id) ?? []).filter((r) => rutineGjelder(r, vindu))
              return (
                <div className="ik-gruppe" key={skjema.id}>
                  <h3>{VAKTTYPE_ETIKETT[skjema.vakttype]}{skjema.navn ? ` · ${skjema.navn}` : ''} <span className="undertittel">{skjema.tid_start}–{skjema.tid_slutt}</span></h3>
                  {rs.length === 0 ? (
                    <p className="undertittel">Ingen rutiner for denne vakten i dag.</p>
                  ) : (
                    <ul className="rutine-liste">
                      {rs.map((r) => {
                        const gjort = utfort.has(`${r.id}|${vindu.vaktdato}`)
                        return (
                          <li key={r.id} className={gjort ? 'gjort' : ''}>
                            <form action={gjort ? fjernKryss : kryssAv}>
                              <input type="hidden" name="rutine_id" value={r.id} />
                              <input type="hidden" name="stasjon_id" value={r.stasjon_id} />
                              <input type="hidden" name="dato" value={vindu.vaktdato} />
                              <button type="submit" className={`kryss ${gjort ? 'av' : ''}`} aria-label="Kryss av">{gjort ? '✓' : ''}</button>
                            </form>
                            <div className="rutine-tekst">
                              <strong>{r.tittel}</strong>
                              {r.beskrivelse ? <span className="undertittel"> — {r.beskrivelse}</span> : null}
                              {r.paakrevd_bilde ? <span className="bilde-merke">📷</span> : null}
                            </div>
                          </li>
                        )
                      })}
                    </ul>
                  )}
                </div>
              )
            })}
          </section>
        ))
      )}
    </>
  )
}
