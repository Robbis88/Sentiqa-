import Link from 'next/link'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { VAKTTYPE_ETIKETT, UKEDAG_NAVN } from '@/lib/rutineskjema'
import { oppdaterSkjema, leggTilRutine, leggTilIkmatRutine, slettRutine } from '../handlinger'
import { IKMAT_RUTINE } from '@/lib/ikmat/rutine'
import { RutineListe } from './rutine-liste'
import { Sidehode, Tomtilstand } from '@/components/ui/side'
import { Sidepanel } from '@/components/ui/sidepanel'
import { SlettKnapp } from '@/components/ui/slett-knapp'

type Skjema = { id: string; stasjon_id: string; vakttype: string; navn: string | null; tid_start: string; tid_slutt: string; ukedager: number[] }
type Rutine = { id: string; tittel: string; beskrivelse: string | null; ukedager: number[]; paakrevd_bilde: boolean; ikmat_frekvens: string | null }

// Mandag først (referansen), men behold verdien 0=Søn..6=Lør.
const DAG_REKKE = [1, 2, 3, 4, 5, 6, 0]
const IKMAT_FREKVENSER = ['daglig', 'to_ukentlig', 'ukentlig']
function dagerKort(d: number[]) { return d.length === 0 ? 'alle dager' : d.map((i) => UKEDAG_NAVN[i]).join(', ') }

function Ukedager({ valgt }: { valgt: number[] }) {
  return (
    <span className="ukedag-velger">
      {DAG_REKKE.map((i) => (
        <label key={i} className="ukedag">
          <input type="checkbox" name="ukedager" value={i} defaultChecked={valgt.includes(i)} /> {UKEDAG_NAVN[i]}
        </label>
      ))}
    </span>
  )
}

export default async function SkjemaEditor({ params }: { params: Promise<{ id: string }> }) {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'butikksjef') {
    return <p>Rutineoppsett gjøres av butikksjefen. <Link href="/rutiner/oversikt">Til rutineoversikt</Link>.</p>
  }
  const { id } = await params
  const supabase = await lagSupabaseServerKlient()
  const { data: skjema } = await supabase
    .from('rutineskjemaer').select('id, stasjon_id, vakttype, navn, tid_start, tid_slutt, ukedager')
    .eq('id', id).is('slettet_tid', null).maybeSingle<Skjema>()
  if (!skjema) return <p>Fant ikke skjemaet. <Link href="/rutiner/oppsett">Tilbake</Link></p>

  const { data: rutinerData } = await supabase
    .from('rutiner').select('id, tittel, beskrivelse, ukedager, paakrevd_bilde, ikmat_frekvens')
    .eq('skjema_id', id).is('slettet_tid', null).order('sortering').order('opprettet_tid')
    .overrideTypes<Rutine[]>()
  const alleRutiner = rutinerData ?? []
  const rutiner = alleRutiner.filter((r) => !r.ikmat_frekvens)
  const ikmatRutiner = alleRutiner.filter((r) => r.ikmat_frekvens)

  // NIVÅ 1 på en detaljside: hva er dette, og hvilken tilstand er det i.
  // Skjemaets tilstand er når det gjelder og hvor mye som ligger i det —
  // det sto spredt over tre seksjoner, hvorav den ene var et skjemafelt.
  const totalt = rutiner.length + ikmatRutiner.length
  const dager = (skjema.ukedager ?? []).length === 0
    ? 'alle dager'
    : dagerKort((skjema.ukedager ?? []) as number[])

  return (
    <>
      <Sidehode
        tittel={`${VAKTTYPE_ETIKETT[skjema.vakttype]}${skjema.navn ? ` · ${skjema.navn}` : ''}`}
        undertittel={`${totalt} ${totalt === 1 ? 'rutine' : 'rutiner'} · ${skjema.tid_start.slice(0, 5)}–${skjema.tid_slutt.slice(0, 5)} · ${dager}`}
        handlinger={
          <>
            <Sidepanel
              knapp="Ny rutine"
              tittel="Ny rutine"
              beskrivelse="Alt som skal gjøres på vakten. Skriv det du vil — «Rense kaffemaskin», «Lage baguetter», «Sjekke kjøl»."
            >
              <form action={leggTilRutine} className="rutine-rediger">
                <input type="hidden" name="skjema_id" value={skjema.id} />
                <input type="hidden" name="stasjon_id" value={skjema.stasjon_id} />
                <label className="felt"><span>Hva skal gjøres?</span><input name="tittel" placeholder="F.eks. Rense kaffemaskin" required /></label>
                <label className="felt"><span>Notis (valgfri) — vises bak ?-ikon på tableten</span><textarea name="beskrivelse" rows={2} placeholder="F.eks. Husk å bytte filter, tørk av damprøret" /></label>
                <label className="felt"><span>Hvilke ukedager? (tom = alle dager skjemaet er aktivt)</span><Ukedager valgt={[]} /></label>
                <label className="avkryss bilde-krav"><input type="checkbox" name="paakrevd_bilde" /> <span>Krev bilde — rutinen kan ikke hakes av uten bildebevis</span></label>
                <button type="submit" className="sq-knapp primar">Legg til rutine</button>
              </form>
            </Sidepanel>
            <Sidepanel
              knapp="IK-mat-kontroll"
              tittel="Legg IK-mat-kontroll i vakta"
              beskrivelse="På tableten blir den et kort som lenker til måle-arket, og hakes av når alt er målt."
              knappeklasse="sq-knapp"
            >
              <form action={leggTilIkmatRutine} className="rutine-rediger">
                <input type="hidden" name="skjema_id" value={skjema.id} />
                <input type="hidden" name="stasjon_id" value={skjema.stasjon_id} />
                <label className="felt"><span>Frekvens-gruppe</span>
                  <select name="frekvens" defaultValue="daglig">
                    {IKMAT_FREKVENSER.map((f) => <option key={f} value={f}>{IKMAT_RUTINE[f].tittel}</option>)}
                  </select>
                </label>
                <label className="felt"><span>Hvilke ukedager?</span><Ukedager valgt={[]} /></label>
                <button type="submit" className="sq-knapp primar">Legg til IK-mat-kontroll</button>
              </form>
            </Sidepanel>
            <Link href="/rutiner/oppsett" className="sq-knapp">Alle skjemaer</Link>
          </>
        }
      />

      {/* Lista man kom hit for. Lå nederst, under to opprett-skjemaer. */}
      <section className="kort">
        <h2>Rutiner i dette skjemaet <span className="undertittel">· {rutiner.length}</span></h2>
        {rutiner.length > 0
          ? <p className="undertittel">Dra i ⠿-håndtaket for å endre rekkefølgen.</p>
          : (
            <Tomtilstand
              tittel="Ingen rutiner i skjemaet ennå"
              forklaring="Uten rutiner viser vakta ingenting på nettbrettet. Legg inn det som faktisk skal gjøres på denne vakten."
            />
          )}
        <RutineListe skjemaId={skjema.id} rutiner={rutiner.map((r) => ({ ...r, ukedager: (r.ukedager ?? []) as number[] }))} />
      </section>

      {ikmatRutiner.length > 0 && (
        <section className="kort">
          <h2>IK-mat-kontroll <span className="undertittel">· {ikmatRutiner.length}</span></h2>
          <ul className="rutine-liste">
            {ikmatRutiner.map((r) => (
              <li key={r.id}>
                <div className="rutine-tekst">
                  <strong>{r.tittel}</strong>
                  <span className="undertittel"> · {dagerKort((r.ukedager ?? []) as number[])}</span>
                </div>
                <SlettKnapp hva={r.tittel} handling={slettRutine} id={r.id} merke="Slett" />
              </li>
            ))}
          </ul>
        </section>
      )}

      {/* Oppsettet selv. Sjelden endret — derfor nederst, ikke øverst. */}
      <section className="kort">
        <h2>Når er skjemaet aktivt</h2>
        <form action={oppdaterSkjema} className="skjema-rediger">
          <input type="hidden" name="id" value={skjema.id} />
          <div className="rad-2">
            <label className="felt"><span>Aktiv fra</span><input type="time" name="tid_start" defaultValue={skjema.tid_start} required /></label>
            <label className="felt"><span>Aktiv til</span><input type="time" name="tid_slutt" defaultValue={skjema.tid_slutt} required /></label>
          </div>
          <label className="felt"><span>Navn (valgfri)</span><input name="navn" defaultValue={skjema.navn ?? ''} placeholder="f.eks. Kveldsvakt" /></label>
          <label className="felt"><span>Ukedager</span><Ukedager valgt={(skjema.ukedager ?? []) as number[]} /></label>
          <button type="submit" className="sq-knapp primar">Lagre endringer</button>
        </form>
      </section>
    </>
  )
}
