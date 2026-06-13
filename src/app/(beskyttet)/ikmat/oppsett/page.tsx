import Link from 'next/link'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { TYPE_ETIKETT, FREKVENS_ETIKETT } from '@/lib/ikmat/standard'
import { leggTilPunkt, settOppStandard } from '../handlinger'
import { IkPunktListe, type Punkt } from './ik-punkt-liste'

const TYPER = ['kjol', 'frys', 'oppvarming', 'varmholding', 'skyllevann', 'annet']
const FREKVENSER = ['daglig', 'to_ukentlig', 'ukentlig']

export default async function IkOppsettSide() {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) {
    return <p>IK-mat-oppsett gjøres av eier eller butikksjef.</p>
  }
  const supabase = await lagSupabaseServerKlient()
  const [{ data: stasjoner }, { data: punkter }] = await Promise.all([
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null).order('butikknummer'),
    supabase.from('ik_kontrollpunkter').select('id, stasjon_id, navn, type, frekvens, min_temp, max_temp').is('slettet_tid', null).order('sortering').overrideTypes<(Punkt & { stasjon_id: string })[]>(),
  ])

  const perStasjon = new Map<string, Punkt[]>()
  for (const p of punkter ?? []) {
    const l = perStasjon.get(p.stasjon_id) ?? []
    l.push({ id: p.id, navn: p.navn, type: p.type, frekvens: p.frekvens, min_temp: p.min_temp, max_temp: p.max_temp })
    perStasjon.set(p.stasjon_id, l)
  }

  return (
    <>
      <h1>IK-mat · oppsett</h1>
      <p className="undertittel">Legg inn alle enhetene som skal måles, sett krav, og dra dem i rekkefølgen du faktisk går runden. <Link href="/ikmat">Til daglig logging →</Link></p>

      {(stasjoner ?? []).map((s) => {
        const sineP = perStasjon.get(s.id) ?? []
        return (
          <section className="kort" key={s.id}>
            <h2>{s.butikknummer} {s.navn} <span className="undertittel">· {sineP.length} punkter</span></h2>

            <details className="rediger-detalj nytt-skjema">
              <summary>➕ Legg til kontrollpunkt</summary>
              <form action={leggTilPunkt} className="skjema-rediger" style={{ marginTop: '0.6rem' }}>
                <input type="hidden" name="stasjon_id" value={s.id} />
                <label className="felt"><span>Navn på enhet</span><input name="navn" placeholder="f.eks. Kjøleskap baguette" required /></label>
                <div className="ik-punkt-rad">
                  <label className="felt"><span>Type</span><select name="type" defaultValue="kjol">{TYPER.map((t) => <option key={t} value={t}>{TYPE_ETIKETT[t] ?? t}</option>)}</select></label>
                  <label className="felt"><span>Frekvens</span><select name="frekvens" defaultValue="daglig">{FREKVENSER.map((f) => <option key={f} value={f}>{FREKVENS_ETIKETT[f] ?? f}</option>)}</select></label>
                  <label className="felt"><span>Min °C</span><input name="min_temp" inputMode="decimal" placeholder="(valgfri)" /></label>
                  <label className="felt"><span>Maks °C</span><input name="max_temp" inputMode="decimal" placeholder="(valgfri)" /></label>
                </div>
                <button type="submit" className="primaer-knapp">+ Legg til kontrollpunkt</button>
              </form>
            </details>

            {sineP.length === 0 && (
              <form action={settOppStandard} style={{ marginTop: '0.6rem' }}>
                <input type="hidden" name="stasjon_id" value={s.id} />
                <p className="undertittel">Eller start fra St1-standarden:</p>
                <button type="submit" className="liten">Sett opp St1-standard (27 punkter)</button>
              </form>
            )}

            <div style={{ marginTop: '0.8rem' }}>
              {sineP.length > 0 && <p className="undertittel">Dra i ⠿-håndtaket for å endre rekkefølgen.</p>}
              <IkPunktListe stasjonId={s.id} punkter={sineP} />
            </div>
          </section>
        )
      })}
    </>
  )
}
