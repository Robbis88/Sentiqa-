import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { datoLang } from '@/lib/format'
import { NyttSjekkpunkt } from './nytt-sjekkpunkt'
import { svar, slettSjekkpunkt } from './handlinger'
import { Sidehode, Tomtilstand } from '@/components/ui/side'
import { Sidepanel } from '@/components/ui/sidepanel'

type Sjekk = {
  id: string
  stasjon_id: string
  sporsmaal: string
  klokkeslett: string | null
  kritisk: boolean
}

export default async function SjekkpunktSide() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle === 'plattform_redaktor') return <p>Du har ikke tilgang til sjekkpunkter.</p>

  const supabase = await lagSupabaseServerKlient()
  const idag = new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Oslo' }).format(new Date())

  const [{ data: punkter }, { data: svarene }, { data: stasjoner }] = await Promise.all([
    supabase
      .from('sjekkpunkter')
      .select('id, stasjon_id, sporsmaal, klokkeslett, kritisk')
      .is('slettet_tid', null)
      .order('klokkeslett')
      .overrideTypes<Sjekk[]>(),
    supabase.from('sjekkpunkt_svar').select('sjekkpunkt_id, svar').eq('dato', idag).overrideTypes<{ sjekkpunkt_id: string; svar: boolean }[]>(),
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null).order('butikknummer'),
  ])

  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))
  const svarFor = new Map((svarene ?? []).map((s) => [s.sjekkpunkt_id, s.svar]))
  const kanLage = bruker.rolle === 'retailer_admin' || bruker.rolle === 'butikksjef'

  const perStasjon = new Map<string, Sjekk[]>()
  for (const p of punkter ?? []) {
    const l = perStasjon.get(p.stasjon_id) ?? []
    l.push(p)
    perStasjon.set(p.stasjon_id, l)
  }

  // NIVÅ 1 på en arbeidsflyt: hvor langt er jeg kommet, og hva stopper meg.
  // Et ubesvart KRITISK punkt er det som stopper deg — det sto med rød pip
  // langt nede i lista, uten at noe i toppen røpet at det fantes.
  const alle = punkter ?? []
  const besvart = alle.filter((p) => svarFor.has(p.id)).length
  const kritiskUbesvart = alle.filter((p) => p.kritisk && !svarFor.has(p.id)).length
  const kritiskNei = alle.filter((p) => p.kritisk && svarFor.get(p.id) === false).length
  const svarTekst = alle.length === 0
    ? 'Ingen sjekkpunkter satt opp'
    : [
        besvart >= alle.length ? `Alle ${alle.length} besvart` : `${besvart} av ${alle.length} besvart`,
        kritiskNei > 0 ? `${kritiskNei} kritisk besvart nei` : null,
        kritiskUbesvart > 0 ? `${kritiskUbesvart} kritisk ubesvart` : null,
      ].filter(Boolean).join(' · ')

  return (
    <>
      <Sidehode
        tittel="Sjekkpunkt"
        undertittel={`${svarTekst} · ${datoLang.format(new Date(idag))}`}
        handlinger={kanLage ? (
          <Sidepanel
            knapp="Nytt sjekkpunkt"
            tittel="Nytt sjekkpunkt"
            beskrivelse="Ett spørsmål med ja/nei-svar. Merk det kritisk hvis et nei skal følges opp samme dag."
          >
            <NyttSjekkpunkt stasjoner={(stasjoner ?? []).map((s) => ({ id: s.id, navn: `${s.butikknummer} ${s.navn}` }))} />
          </Sidepanel>
        ) : undefined}
      />

      {perStasjon.size === 0 ? (
        <Tomtilstand
          tittel="Ingen sjekkpunkter ennå"
          forklaring="Sjekkpunkter er de spørsmålene som skal besvares hver dag — «er kjølen låst?», «er kassen talt opp?». Ett spørsmål, ja eller nei, ingen fritekst."
        />
      ) : (
        [...perStasjon.entries()].map(([sid, liste]) => (
          <section className="kort" key={sid}>
            <h2>{navnFor.get(sid) ?? '—'}</h2>
            <ul className="sjekk-liste">
              {liste.map((p) => {
                const s = svarFor.get(p.id)
                return (
                  <li key={p.id}>
                    <div className="sjekk-sporsmaal">
                      {p.klokkeslett ? <span className="klokke">{p.klokkeslett}</span> : null}
                      <strong>{p.sporsmaal}</strong>
                      {p.kritisk ? <span className="status-pip rod">Kritisk</span> : null}
                    </div>
                    <div className="sjekk-svar">
                      <form action={svar}>
                        <input type="hidden" name="sjekkpunkt_id" value={p.id} />
                        <input type="hidden" name="stasjon_id" value={p.stasjon_id} />
                        <input type="hidden" name="svar" value="ja" />
                        <button type="submit" className={`janei ja ${s === true ? 'valgt' : ''}`}>Ja</button>
                      </form>
                      <form action={svar}>
                        <input type="hidden" name="sjekkpunkt_id" value={p.id} />
                        <input type="hidden" name="stasjon_id" value={p.stasjon_id} />
                        <input type="hidden" name="svar" value="nei" />
                        <button type="submit" className={`janei nei ${s === false ? 'valgt' : ''}`}>Nei</button>
                      </form>
                      {kanLage && (
                        <form action={slettSjekkpunkt}>
                          <input type="hidden" name="id" value={p.id} />
                          <button type="submit" className="liten slett" aria-label="Slett">✕</button>
                        </form>
                      )}
                    </div>
                  </li>
                )
              })}
            </ul>
          </section>
        ))
      )}
    </>
  )
}
