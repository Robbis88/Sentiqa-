import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { Sidehode, Tomtilstand } from '@/components/ui/side'
import {
  ARSVERK_TIMER, MANEDER, forklarDekning, justeringPerManed, uavklarte,
  type Dekning,
} from '@/lib/bemanning/lederdekning'
import { settArsverk, settDekning } from './handlinger'

// =====================================================================
// «Var det en fastlønnet butikksjef her?» — én hake per måned.
//
// HVORFOR SIDEN FINNES. St1 trekker ett årsverk fra timebudsjettet
// fordi de antar at butikksjefen går på fastlønn. Holder ikke
// antakelsen — timelønn, permisjon, vikariat, vakanse — må arbeidet
// hennes gjøres av timelønnede, fra en ramme som ikke er dimensjonert
// for det.
//
// SPØRSMÅLET ER IKKE HVA SLAGS KONTRAKT NOEN HAR. Det er om rammen
// dekker arbeidet. En fastlønnet butikksjef i permisjon er ikke på
// plass: noen andre gjør jobben hennes, og de får betalt per time.
//
// TRE TILSTANDER, IKKE TO. En måned ingen har tatt stilling til skal
// ikke justere rammen, og den skal se uavklart ut. Derfor står antall
// uavklarte måneder øverst: en halvferdig konfigurasjon ser ellers
// nøyaktig ut som en ferdig, helt til noen lurer på et tall.
//
// ÅRSVERKET FØRST. `fast_arsverk_timer` er 0 på alle stasjoner i dag,
// og en justering på 0/12 er ingen justering. Hakene gjør altså
// ingenting før tallet er satt — og det står derfor øverst, med
// forklaringen ved siden av hver hake.
// =====================================================================

export const dynamic = 'force-dynamic'

type Stasjon = { id: string; navn: string; butikknummer: string }
type Rad = { stasjon_id: string; maned: number; fastlonnet: boolean; notat: string | null }
type Aar = { stasjon_id: string; fast_arsverk_timer: number }

export default async function LederdekningOppsett(
  { searchParams }: { searchParams: Promise<{ ar?: string }> },
) {
  const bruker = await hentInnloggetBruker()
  // Hakene utvider stasjonens ramme. Kunne butikksjefen sette dem,
  // kunne hun utvide sin egen — derfor eier, ikke `erLeder`.
  if (bruker.rolle !== 'retailer_admin') {
    return <p>Kun eier har tilgang til oppsettet for timeregnskap.</p>
  }

  const sp = await searchParams
  const iAr = new Date().getFullYear()
  const ar = Number(sp.ar) >= 2020 && Number(sp.ar) <= 2100 ? Number(sp.ar) : iAr

  const supabase = await lagSupabaseServerKlient()
  const [{ data: stasjoner }, { data: dekning }, { data: aar }] = await Promise.all([
    supabase.from('stasjoner').select('id, navn, butikknummer')
      .is('slettet_tid', null).order('butikknummer'),
    supabase.from('bemanning_lederdekning')
      .select('stasjon_id, maned, fastlonnet, notat').eq('ar', ar),
    supabase.from('bemanning_aar')
      .select('stasjon_id, fast_arsverk_timer').eq('ar', ar),
  ])

  const liste = (stasjoner ?? []) as Stasjon[]
  if (liste.length === 0) {
    return (
      <>
        <Sidehode tittel="Lederdekning" undertittel="Var det en fastlønnet butikksjef?" />
        <Tomtilstand
          tittel="Ingen stasjoner"
          forklaring="Legg inn stasjoner før du setter opp lederdekning."
          handling={<a className="sq-knapp" href="/stasjoner">Til stasjoner</a>}
        />
      </>
    )
  }

  const rader = (dekning ?? []) as Rad[]
  const arsverk = new Map((aar ?? []).map((a) => [(a as Aar).stasjon_id, (a as Aar).fast_arsverk_timer]))
  const svar = new Map(rader.map((r) => [`${r.stasjon_id}|${r.maned}`, r]))

  // Bare måneder som har vært. Å be om et svar på desember i august er
  // å be om en gjetning, og en gjetning i en konfigurasjon er verre enn
  // et tomt felt.
  const sisteManed = ar < iAr ? 12 : new Date().getMonth() + 1
  const uteStaende = liste.reduce(
    (s, st) => s + uavklarte(
      rader.filter((r) => r.stasjon_id === st.id && r.maned <= sisteManed),
      sisteManed,
    ), 0,
  )

  return (
    <>
      <Sidehode
        tittel={uteStaende > 0
          ? `${uteStaende} måneder mangler svar`
          : `Lederdekning ${ar} er komplett`}
        undertittel={'St1 trekker ett årsverk fra timebudsjettet fordi de antar '
          + 'at butikksjefen går på fastlønn. Gjør hun ikke det — timelønn, '
          + 'permisjon, vikariat — må arbeidet gjøres av timelønnede, og rammen '
          + 'økes tilsvarende.'}
      />

      <p className="undertittel sq-finstilt">
        Spørsmålet er ikke hva slags kontrakt noen har. Det er om rammen dekker
        arbeidet. En fastlønnet butikksjef i permisjon er ikke på plass.
      </p>

      {liste.map((st) => {
        const timer = arsverk.get(st.id) ?? 0
        const perManed = justeringPerManed(timer)
        return (
          <section key={st.id} className="sq-kort dekning-stasjon">
            <h2 className="dekning-navn">{st.butikknummer} {st.navn}</h2>

            {/* ÅRSVERKET FØRST, og med et tall i feltet. Uten det gjør
                hakene under ingenting, og det ville sett ut som om de
                virket. */}
            <form action={settArsverk} className="dekning-arsverk">
              <input type="hidden" name="stasjon_id" value={st.id} />
              <input type="hidden" name="ar" value={ar} />
              <label>
                Årsverket St1 trakk fra
                <input
                  type="number" name="timer" min={0} max={3000} step={1}
                  defaultValue={timer || ARSVERK_TIMER}
                />
              </label>
              <button type="submit" className="sq-knapp">Lagre</button>
              <span className={timer > 0 ? 'dekning-hint' : 'dekning-mangler'}>
                {timer > 0
                  ? `${perManed} timer per måned uten fastlønnet leder`
                  : 'Ikke satt — hakene under gjør ingenting før dette er lagret'}
              </span>
            </form>

            <ol className="dekning-maaneder">
              {MANEDER.slice(0, sisteManed).map((navn, i) => {
                const m = i + 1
                const r = svar.get(`${st.id}|${m}`)
                const na: Dekning = r === undefined
                  ? 'ukjent'
                  : r.fastlonnet ? 'fastlonnet' : 'ikke_fastlonnet'
                return (
                  <li key={m} className={`dekning-mnd dekning-${na}`}>
                    <form action={settDekning} className="dekning-rad">
                      <input type="hidden" name="stasjon_id" value={st.id} />
                      <input type="hidden" name="ar" value={ar} />
                      <input type="hidden" name="maned" value={m} />
                      <span className="dekning-mnd-navn">{navn}</span>
                      {/* MAANEDSNAVNET ER EN SPAN, IKKE EN LABEL - det
                          staar der for oeyet og gjelder hele raden. En
                          skjermleser hoerte derfor «velg» uten aa vite
                          hvilken maaned eller hvilken stasjon. axe fant
                          det; jsdom-vakten kan ikke se det, fordi den
                          maaler primitivene og ikke sida.
                          Stasjonen staar med: det er fem seksjoner paa
                          sida, og «Mars» alene er ikke et sted. */}
                      <select
                        name="svar"
                        aria-label={`${st.butikknummer} ${st.navn}, ${navn}: lederdekning`}
                        defaultValue={
                        na === 'fastlonnet' ? 'ja' : na === 'ikke_fastlonnet' ? 'nei' : 'ukjent'
                      }>
                        <option value="ukjent">Ikke tatt stilling</option>
                        <option value="ja">Fastlønnet butikksjef på plass</option>
                        <option value="nei">Nei — timelønn, permisjon eller vakanse</option>
                      </select>
                      <input
                        type="text" name="notat" defaultValue={r?.notat ?? ''}
                        aria-label={`${st.butikknummer} ${st.navn}, ${navn}: notat`}
                        placeholder="Hvorfor — «Sissel på timelønn»"
                        maxLength={120}
                      />
                      <button
                        type="submit" className="sq-knapp sq-dempet"
                        aria-label={`Lagre ${navn} for ${st.navn}`}
                      >
                        Lagre
                      </button>
                    </form>
                    {/* HVA HAKEN GJØR, i klartekst. Den som leser dette om
                        et halvt år skal se konsekvensen, ikke gjette den. */}
                    <p className="dekning-forklaring">{forklarDekning(na, perManed)}</p>
                  </li>
                )
              })}
            </ol>
          </section>
        )
      })}
    </>
  )
}
