import Link from 'next/link'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { TYPE_ETIKETT, FREKVENS_ETIKETT } from '@/lib/ikmat/standard'
import { leggTilPunkt, settOppStandard } from '../handlinger'
import { IkPunktListe, type Punkt } from './ik-punkt-liste'
import { Sidehode, Tomtilstand } from '@/components/ui/side'
import { Sideramme } from '@/components/ui/sideramme'

const TYPER = ['kjol', 'frys', 'oppvarming', 'varmholding', 'skyllevann', 'annet']
const FREKVENSER = ['daglig', 'to_ukentlig', 'ukentlig']

export default async function IkOppsettSide() {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) {
    return <Sideramme><p>IK-mat-oppsett gjøres av eier eller butikksjef.</p></Sideramme>
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

  // NIVÅ 1 på innstillinger: hva som gjelder nå. En stasjon uten
  // kontrollpunkter logger ingenting — den tilstanden måtte man tidligere
  // finne ved å bla forbi de andre stasjonene.
  const liste = stasjoner ?? []
  const totalt = (punkter ?? []).length
  const utenOppsett = liste.filter((s) => (perStasjon.get(s.id) ?? []).length === 0).length
  const svar = [
    `${totalt} ${totalt === 1 ? 'kontrollpunkt' : 'kontrollpunkter'} på ${liste.length} ${liste.length === 1 ? 'stasjon' : 'stasjoner'}`,
    utenOppsett > 0 ? `${utenOppsett} uten oppsett` : null,
  ].filter(Boolean).join(' · ')

  return (
    <Sideramme>
      <Sidehode
        tittel="IK-mat · oppsett"
        undertittel={svar}
        handlinger={<Link href="/ikmat" className="sq-knapp">Til daglig logging</Link>}
      />

      {liste.map((s) => {
        const sineP = perStasjon.get(s.id) ?? []
        return (
          <section className="kort" key={s.id}>
            <h2>{s.butikknummer} {s.navn} <span className="undertittel">· {sineP.length} punkter</span></h2>

            {/* Punktene først. Skjemaet lå over lista, og på en stasjon med
                tjuesju punkter møtte man et tomt skjema før man fikk se
                hva som allerede var satt opp. */}
            {sineP.length > 0 ? (
              <>
                <p className="undertittel">Dra i ⠿-håndtaket for å endre rekkefølgen — sett dem i den rekkefølgen du faktisk går runden.</p>
                <IkPunktListe stasjonId={s.id} punkter={sineP} />
              </>
            ) : (
              <Tomtilstand
                tittel="Ingen kontrollpunkter"
                forklaring="Denne stasjonen logger ingenting før det finnes noe å måle. St1-standarden dekker de vanlige enhetene og kan endres etterpå."
                handling={
                  <form action={settOppStandard}>
                    <input type="hidden" name="stasjon_id" value={s.id} />
                    <button type="submit" className="sq-knapp primar">Sett opp St1-standard (27 punkter)</button>
                  </form>
                }
              />
            )}

            <details className="rediger-detalj nytt-skjema sq-luft-over-liten">
              <summary>Legg til kontrollpunkt</summary>
              <form action={leggTilPunkt} className="skjema-rediger sq-luft-over-liten">
                <input type="hidden" name="stasjon_id" value={s.id} />
                <label className="felt"><span>Navn på enhet</span><input name="navn" placeholder="f.eks. Kjøleskap baguette" required /></label>
                <div className="ik-punkt-rad">
                  <label className="felt"><span>Type</span><select name="type" defaultValue="kjol">{TYPER.map((t) => <option key={t} value={t}>{TYPE_ETIKETT[t] ?? t}</option>)}</select></label>
                  <label className="felt"><span>Frekvens</span><select name="frekvens" defaultValue="daglig">{FREKVENSER.map((f) => <option key={f} value={f}>{FREKVENS_ETIKETT[f] ?? f}</option>)}</select></label>
                  <label className="felt"><span>Min °C</span><input name="min_temp" inputMode="decimal" placeholder="(valgfri)" /></label>
                  <label className="felt"><span>Maks °C</span><input name="max_temp" inputMode="decimal" placeholder="(valgfri)" /></label>
                </div>
                <button type="submit" className="sq-knapp primar">Legg til kontrollpunkt</button>
              </form>
            </details>
          </section>
        )
      })}
    </Sideramme>
  )
}
