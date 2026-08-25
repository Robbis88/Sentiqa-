import Link from 'next/link'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { datoLang } from '@/lib/format'
import { tidsrom } from '@/lib/opplaering/dagens'
import {
  settOppStandard, leggTilOppgave, redigerOppgave, slettOppgave,
  leggTilPeriode, fullforPeriode, slettPeriode, vekslUtfort, leggTilSkift, slettSkift,
} from './handlinger'
import { Sidehode, Tomtilstand } from '@/components/ui/side'
import { Status } from '@/components/ui/status'
import { Sidepanel } from '@/components/ui/sidepanel'
import { SlettKnapp } from '@/components/ui/slett-knapp'

type Oppgave = { id: string; kategori: string; tittel: string; beskrivelse: string | null; estimert_min: number | null }
type Periode = { id: string; stasjon_id: string; ansatt_navn: string; start_dato: string; forventet_slutt: string | null; fullfort_tid: string | null }
type Utfort = { periode_id: string; oppgave_id: string }
type Skift = { id: string; dato: string; start_tid: string | null; slutt_tid: string | null; notater: string | null }

export default async function OpplaringSide({ searchParams }: { searchParams: Promise<{ periode?: string }> }) {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'butikksjef') {
    return <p>Opplæring av nyansatte håndteres av butikksjefen for sin butikk.</p>
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
    const { data } = await supabase.from('opplaering_skift').select('id, dato, start_tid, slutt_tid, notater').eq('periode_id', valgt.id).order('dato').overrideTypes<Skift[]>()
    skift = data ?? []
  }

  // NIVÅ 1 på en arbeidsflyt: hvor langt er jeg kommet. Med flere under
  // opplæring samtidig er det den som har kommet kortest som trenger noe
  // av deg — den sto som en gul pip midt i lista.
  const paagaaende = (perioder ?? []).filter((p) => !p.fullfort_tid)
  const bakerst = paagaaende.length > 0
    ? paagaaende.reduce((a, p) => (teller(p.id) < teller(a.id) ? p : a))
    : null
  const svar = paagaaende.length === 0
    ? 'Ingen under opplæring nå'
    : `${paagaaende.length} under opplæring`
      + (bakerst && paagaaende.length > 1
        ? ` · kortest kommet: ${bakerst.ansatt_navn} (${teller(bakerst.id)}/${totalOppgaver})`
        : bakerst ? ` · ${bakerst.ansatt_navn} ${teller(bakerst.id)}/${totalOppgaver}` : '')

  const nyPeriodePanel = (
    <Sidepanel
      knapp="Ny under opplæring"
      tittel="Ny under opplæring"
      beskrivelse="Sjekklista er den samme for alle. Forventet ferdig er valgfri, men gjør det lettere å se hvem som henger etter."
    >
      <form action={leggTilPeriode} className="sq-skjema">
        <input name="ansatt_navn" placeholder="Navn på nyansatt" required />
        <select name="stasjon_id" required defaultValue={(stasjoner ?? []).length === 1 ? stasjoner![0].id : ''}>
          {(stasjoner ?? []).length !== 1 && <option value="" disabled>Stasjon …</option>}
          {(stasjoner ?? []).map((s) => <option key={s.id} value={s.id}>{s.butikknummer} {s.navn}</option>)}
        </select>
        <input name="start_dato" type="date" aria-label="Startdato" required />
        <input name="forventet_slutt" type="date" aria-label="Forventet ferdig" />
        <button type="submit" className="sq-knapp primar">Legg til</button>
      </form>
    </Sidepanel>
  )

  return (
    <>
      <Sidehode
        tittel="Opplæring"
        undertittel={totalOppgaver === 0
          ? 'Onboarding av nyansatte — sjekkliste, kvittering og vaktplan.'
          : `${svar}. Sjekkliste, kvittering og vaktplan.`}
        handlinger={totalOppgaver === 0 ? undefined : nyPeriodePanel}
      />

      {totalOppgaver === 0 ? (
        <Tomtilstand
          tittel="Tomt oppgavebibliotek"
          forklaring="Opplæringen bygger på en felles sjekkliste alle nyansatte går gjennom. Start med de 21 standardoppgavene (Kasse, Drivstoff, Bake, Renhold, Sikkerhet …) og tilpass dem etterpå."
          handling={
            <form action={settOppStandard}>
              <button type="submit" className="sq-knapp primar">Sett opp standardoppgaver</button>
            </form>
          }
        />
      ) : (
        <>
          <section className="kort">
            <h2>Under opplæring</h2>
            {(perioder ?? []).length === 0 ? (
              <Tomtilstand
                tittel="Ingen under opplæring"
                forklaring="Når du legger inn en nyansatt, får hun sin egen kopi av sjekklista — og du ser hvor langt hun er kommet."
                handling={nyPeriodePanel}
              />
            ) : (
              <ul className="person-liste">
                {(perioder ?? []).map((p) => {
                  const antall = teller(p.id)
                  const pst = totalOppgaver ? Math.round((antall / totalOppgaver) * 100) : 0
                  return (
                    <li key={p.id} className={valgt?.id === p.id ? 'aktiv' : ''}>
                      <Link href={`/opplaring?periode=${p.id}`}>
                        <strong>{p.ansatt_navn}</strong>
                        <span className="undertittel"> · {navnFor.get(p.stasjon_id) ?? '—'} · fra {datoLang.format(new Date(p.start_dato))}{p.fullfort_tid ? ' · fullført' : ''}</span>
                      </Link>
                      <span className="person-hoyre">
                        {/* «7/12» BAERER TALLET; nivaaet forsterker. Ferdig er
                            `normal` - det er maalet, ikke en seier - og alt
                            annet er `endring`, altsaa noe som paagaar. */}
                        <Status nivaa={pst === 100 ? 'normal' : 'endring'}>
                          {antall}/{totalOppgaver}
                        </Status>
                        <SlettKnapp hva={p.ansatt_navn} handling={slettPeriode} id={p.id} merke="Fjern" />
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
                <div className="sq-radtopp">
                  <h2 className="sq-tett">{valgt.ansatt_navn} — sjekkliste</h2>
                  <form action={fullforPeriode}>
                    <input type="hidden" name="id" value={valgt.id} />
                    <input type="hidden" name="til" value={valgt.fullfort_tid ? 'nei' : 'ja'} />
                    <button type="submit" className="liten primar">{valgt.fullfort_tid ? 'Gjenåpne' : 'Marker fullført'}</button>
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
                  {/* KLOKKESLETT ER VALGFRITT, men begge eller ingen.
                      Står de tomme, gjelder vakten hele dagen. Tidene
                      forteller når opplæringen er — de styrer ikke om
                      sjekklista vises, for man haker av etter at noe er
                      lært bort. */}
                  <input name="start_tid" type="time" aria-label="Fra klokken" className="sq-smalt-felt" />
                  <input name="slutt_tid" type="time" aria-label="Til klokken" className="sq-smalt-felt" />
                  <input name="notater" placeholder="Notat (f.eks. opplærer / fokus)" />
                  <button type="submit" className="liten primar">Legg til vakt</button>
                </form>
                {skift.length === 0 ? (
                  <p className="undertittel sq-luft-over-liten">Ingen planlagte vakter.</p>
                ) : (
                  <ul className="person-liste">
                    {skift.map((s) => (
                      <li key={s.id}>
                        <span>
                          <strong>{datoLang.format(new Date(s.dato))}</strong>
                          {tidsrom(s.start_tid, s.slutt_tid)
                            ? <span className="undertittel"> · kl. {tidsrom(s.start_tid, s.slutt_tid)}</span>
                            : <span className="undertittel"> · hele dagen</span>}
                          {s.notater ? <span className="undertittel"> · {s.notater}</span> : null}
                        </span>
                        <SlettKnapp hva={s.dato} handling={slettSkift} id={s.id} merke="Fjern" />
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
                          <button type="submit" className="liten primar">Lagre</button>
                        </form>
                        <SlettKnapp hva={o.tittel} handling={slettOppgave} id={o.id} merke="Slett" />
                      </details>
                    </li>
                  ))}
                </ul>
              </div>
            ))}
            <form action={leggTilOppgave} className="rutine-form sq-luft-over-liten">
              <input name="kategori" placeholder="Kategori" className="sq-mellomfelt" />
              <input name="tittel" placeholder="Ny oppgave" required />
              <input name="estimert_min" type="number" min="1" placeholder="min" className="sq-smalt-felt" />
              <button type="submit" className="liten primar">Legg til</button>
            </form>
          </section>
        </>
      )}
    </>
  )
}
