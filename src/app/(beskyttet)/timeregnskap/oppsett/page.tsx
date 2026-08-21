import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { Sidehode, Tomtilstand } from '@/components/ui/side'
import {
  ARSVERK_TIMER, MANEDER, forslagHelManed, uavklarte,
  type Dekning,
} from '@/lib/bemanning/lederdekning'
import { ArsverkSkjema, ManedRad } from './maaned-rad'

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
type Rad = {
  stasjon_id: string; maned: number; fastlonnet: boolean
  timer_tilbake: number | null; notat: string | null
}
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
      .select('stasjon_id, maned, fastlonnet, timer_tilbake, notat').eq('ar', ar),
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
        const forslag = forslagHelManed(timer || ARSVERK_TIMER)
        return (
          <section key={st.id} className="sq-kort dekning-stasjon">
            <h2 className="dekning-navn">{st.butikknummer} {st.navn}</h2>

            {/* ÅRSVERKET FØRST. Det inngår ikke i noen beregning - det
                brukes bare til å regne ut forslaget «full måned =
                141,25 timer» som står ved siden av timefeltet. */}
            <ArsverkSkjema
              stasjonId={st.id} ar={ar} timer={timer} forslag={forslag}
            />

            <ol className="dekning-maaneder">
              {MANEDER.slice(0, sisteManed).map((navn, i) => {
                const m = i + 1
                const r = svar.get(`${st.id}|${m}`)
                const na: Dekning = r === undefined
                  ? 'ukjent'
                  : r.fastlonnet ? 'fastlonnet' : 'ikke_fastlonnet'
                return (
                  <ManedRad
                    key={m}
                    stasjonId={st.id}
                    butikknummer={st.butikknummer}
                    stasjonsnavn={st.navn}
                    ar={ar} maned={m} manedsnavn={navn}
                    dekning={na}
                    timerTilbake={r?.timer_tilbake ?? null}
                    notat={r?.notat ?? null}
                    forslag={forslag}
                  />
                )
              })}
            </ol>
          </section>
        )
      })}
    </>
  )
}
