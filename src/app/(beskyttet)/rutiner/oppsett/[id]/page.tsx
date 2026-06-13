import Link from 'next/link'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { VAKTTYPE_ETIKETT, UKEDAG_NAVN } from '@/lib/rutineskjema'
import { oppdaterSkjema, leggTilRutine, leggTilIkmatRutine, slettRutine } from '../handlinger'
import { IKMAT_RUTINE } from '@/lib/ikmat/rutine'
import { RutineListe } from './rutine-liste'

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

  return (
    <>
      <h1>{VAKTTYPE_ETIKETT[skjema.vakttype]}{skjema.navn ? ` · ${skjema.navn}` : ''}</h1>
      <p className="undertittel"><Link href="/rutiner/oppsett">← Alle skjemaer</Link></p>

      {/* Når er skjemaet aktivt */}
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
          <button type="submit" className="primaer-knapp">Lagre endringer</button>
        </form>
      </section>

      {/* Legg til ny rutine */}
      <section className="kort">
        <h2>➕ Legg til ny rutine</h2>
        <p className="undertittel">Legg til alle oppgaver som skal gjøres på vakten. Skriv det du vil — f.eks. «Rense kaffemaskin», «Lage baguetter», «Sjekke kjøl».</p>
        <form action={leggTilRutine} className="rutine-rediger">
          <input type="hidden" name="skjema_id" value={skjema.id} />
          <input type="hidden" name="stasjon_id" value={skjema.stasjon_id} />
          <label className="felt"><span>Hva skal gjøres?</span><input name="tittel" placeholder="F.eks. Rense kaffemaskin" required /></label>
          <label className="felt"><span>Notis (valgfri) — vises bak ?-ikon på tableten</span><textarea name="beskrivelse" rows={2} placeholder="F.eks. Husk å bytte filter, tørk av damprøret" /></label>
          <label className="felt"><span>Hvilke ukedager? (tom = alle dager skjemaet er aktivt)</span><Ukedager valgt={[]} /></label>
          <label className="avkryss bilde-krav"><input type="checkbox" name="paakrevd_bilde" /> <span>📷 Krev bilde — rutinen kan ikke hakes av uten bildebevis</span></label>
          <button type="submit" className="primaer-knapp gul">+ Legg til rutine</button>
        </form>
      </section>

      {/* IK-mat-kontroll i vakta */}
      <section className="kort">
        <h2>🌡️ IK-mat-kontroll</h2>
        <p className="undertittel">Legg temperaturkontrollen inn i denne vakta. På tableten blir den et kort som lenker til måle-arket, og hakes av når alt er målt. Velg ukedager for når den skal gjøres.</p>

        {ikmatRutiner.length > 0 && (
          <ul className="rutine-liste">
            {ikmatRutiner.map((r) => (
              <li key={r.id}>
                <div className="rutine-tekst">
                  <strong>{r.tittel}</strong>
                  <span className="undertittel"> · {dagerKort((r.ukedager ?? []) as number[])}</span>
                </div>
                <form action={slettRutine}><input type="hidden" name="id" value={r.id} /><button type="submit" className="liten slett" aria-label="Slett">✕</button></form>
              </li>
            ))}
          </ul>
        )}

        <form action={leggTilIkmatRutine} className="rutine-rediger" style={{ marginTop: '0.6rem' }}>
          <input type="hidden" name="skjema_id" value={skjema.id} />
          <input type="hidden" name="stasjon_id" value={skjema.stasjon_id} />
          <label className="felt"><span>Frekvens-gruppe</span>
            <select name="frekvens" defaultValue="daglig">
              {IKMAT_FREKVENSER.map((f) => <option key={f} value={f}>{IKMAT_RUTINE[f].tittel}</option>)}
            </select>
          </label>
          <label className="felt"><span>Hvilke ukedager?</span><Ukedager valgt={[]} /></label>
          <button type="submit" className="primaer-knapp">+ Legg til IK-mat-kontroll</button>
        </form>
      </section>

      {/* Rutiner i dette skjemaet — drag-and-drop rekkefølge */}
      <section className="kort">
        <h2>Rutiner i dette skjemaet <span className="undertittel">· {rutiner.length}</span></h2>
        {rutiner.length > 0 && <p className="undertittel">Dra i ⠿-håndtaket for å endre rekkefølgen.</p>}
        <RutineListe skjemaId={skjema.id} rutiner={rutiner.map((r) => ({ ...r, ukedager: (r.ukedager ?? []) as number[] }))} />
      </section>
    </>
  )
}
