import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { Sidehode, Tomtilstand } from '@/components/ui/side'
import { Status } from '@/components/ui/status'

// =====================================================================
// «Har vi råd til timene vi bruker?»
//
// PRODUKTREGELEN, fra Robert 2026-08-21:
//
//   «Timebudsjettet vi har fått skal matche mot timeforbruket vi får.
//    Sier budsjettet 12 000 timer, da skal vi ha 5 millioner i brutto.
//    Så kan man ikke bruke 12 000 timer om vi har 4,8 mill i brutto.»
//
//   Timer man har rett på = ramme × (realisert brutto ÷ BP-brutto)
//
// EIER, IKKE BUTIKKSJEF. Rammen bak dette (`bemanning_budsjett`,
// `bemanning_aar`) er retailer_admin-only med vilje — 0082 sier «IKKE
// synlig for butikksjef». Butikksjefen ser hva hun får PLANLEGGE;
// oppgjøret mot St1s ramme er eierens spørsmål. To ulike spørsmål, to
// ulike lesere.
//
// FRADRAGENE ER EIERENS. 3 % sikkerhet og historisk sykefravær holdes
// tilbake og deles aldri ut — de er margin for lønnsøkninger, overtid
// og det som måtte komme. Stasjonen ser dem aldri, så rettigheten er
// `disponible_timer` og ingenting annet. Timer over har derfor spist av
// den marginen, og det er hele poenget med tallet.
//
// ALL REGNING LIGGER I `v_timeregnskap` (0117, justert i 0119). Siden
// velger rekkefølge og ord — den regner ikke.
// =====================================================================

export const dynamic = 'force-dynamic'

type Stasjon = { id: string; navn: string; butikknummer: string }
type Rad = {
  stasjon_id: string
  maned: string
  grunnlag: string
  bp_brutto_kr: number | null
  realisert_brutto_kr: number | null
  budsjett_timer: number | null
  opptjente_timer: number | null
  brukte_timer: number | null
  timer_over: number | null
  brutto_per_time: number | null
  bp_brutto_per_time: number | null
  ramme_justering_timer: number | null
  arsverk_timer: number | null
  lederdekning: string
}

/**
 * Alvoret i et timeavvik.
 *
 * MÅLT MOT RAMMEN, IKKE I ABSOLUTTE TIMER. 200 timer over er alvorlig
 * på en stasjon med 500 i måneden og støy på en med 1 500. Grensene er
 * 5 og 10 % — samme størrelsesorden som lønnsavviket på `/regnskap`
 * (`lonnOverGul`/`lonnOverRod`), fordi det er det samme pengene.
 */
function timeAlvor(over: number | null, ramme: number | null) {
  if (over == null || !ramme || ramme <= 0) return 'normal' as const
  const pst = (over / ramme) * 100
  if (pst >= 10) return 'handling' as const
  if (pst >= 5) return 'endring' as const
  return 'normal' as const
}

const t0 = (v: number | null) => (v == null ? '—' : Math.round(v).toLocaleString('nb-NO'))

export default async function TimeregnskapSide() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin') {
    return <p>Kun eier har tilgang til timeregnskapet.</p>
  }

  const supabase = await lagSupabaseServerKlient()
  const iAr = new Date().getFullYear()
  const [{ data: stasjoner }, { data: rader }] = await Promise.all([
    supabase.from('stasjoner').select('id, navn, butikknummer')
      .is('slettet_tid', null).order('butikknummer'),
    supabase.from('v_timeregnskap').select('*')
      .gte('maned', `${iAr}-01-01`).order('maned'),
  ])

  const liste = (stasjoner ?? []) as Stasjon[]
  const alle = (rader ?? []) as Rad[]

  // Bare måneder som faktisk er målt. En måned uten stemplinger er ikke
  // et null-forbruk — den er ikke importert ennå.
  const maalte = alle.filter((r) => r.brukte_timer != null && r.opptjente_timer != null)

  if (maalte.length === 0) {
    return (
      <>
        <Sidehode tittel="Timeregnskap" undertittel="Har vi råd til timene?" />
        <Tomtilstand
          tittel="Ingenting å gjøre opp ennå"
          forklaring={'Timeregnskapet trenger tre ting: timebudsjettet fra BP-en, '
            + 'stemplinger, og brutto fra regnskapet. Mangler én av dem, finnes '
            + 'det ingen ramme å måle mot.'}
          handling={<a className="sq-knapp" href="/import">Til import</a>}
        />
      </>
    )
  }

  // Per stasjon, summert over målte måneder.
  const per = liste.map((st) => {
    const mine = maalte.filter((r) => r.stasjon_id === st.id)
    const sum = (f: (r: Rad) => number | null) =>
      mine.reduce((s, r) => s + (f(r) ?? 0), 0)
    const opptjent = sum((r) => r.opptjente_timer)
    const brukt = sum((r) => r.brukte_timer)
    return {
      st,
      maaneder: mine.length,
      opptjent,
      brukt,
      over: brukt - opptjent,
      justering: sum((r) => r.ramme_justering_timer),
      uavklart: mine.filter((r) => r.lederdekning === 'ukjent').length,
      utenArsverk: mine.some((r) => (r.arsverk_timer ?? 0) === 0),
      anslag: mine.filter((r) => r.grunnlag === 'anslag').length,
    }
  }).filter((p) => p.maaneder > 0)

  // DET SOM KOSTER MEST STÅR ØVERST. Ikke alfabetisk: den stasjonen som
  // har brukt flest timer den ikke har tjent inn, er den å se på først.
  const sortert = [...per].sort((a, b) => b.over - a.over)
  const sumOver = sortert.filter((p) => p.over > 0).reduce((s, p) => s + p.over, 0)
  const uavklarte = sortert.reduce((s, p) => s + p.uavklart, 0)

  return (
    <>
      <Sidehode
        tittel={sumOver > 0
          ? `${t0(sumOver)} timer brukt uten dekning i brutto`
          : 'Alle stasjoner innenfor det de har tjent inn'}
        undertittel={'Timebudsjettet er ikke gitt, det er fortjent: rammen '
          + 'ganges med det brutto faktisk ble. Timer over har spist av '
          + 'marginen som holdes tilbake sentralt.'}
      />

      {uavklarte > 0 && (
        // EN HALVFERDIG KONFIGURASJON SER UT SOM EN FERDIG. Derfor står
        // dette over tallene, ikke under: leses de uten dette, leses de
        // som sikrere enn de er.
        <p className="undertittel sq-finstilt">
          {uavklarte} måneder mangler svar på om det var fastlønnet butikksjef.
          Rammen er ikke justert for dem.{' '}
          <a href="/timeregnskap/oppsett">Sett lederdekning</a>
        </p>
      )}

      <section className="tr-liste">
        {sortert.map((p) => (
          <article key={p.st.id} className="tr-rad">
            <div className="tr-topp">
              <h3 className="tr-navn">{p.st.butikknummer} {p.st.navn}</h3>
              <Status nivaa={timeAlvor(p.over, p.opptjent)}>
                {p.over > 0
                  ? `${t0(p.over)} timer over`
                  : `${t0(Math.abs(p.over))} timer igjen`}
              </Status>
            </div>

            <dl className="tr-tall">
              <div>
                <dt>Tjent inn</dt>
                <dd>{t0(p.opptjent)}</dd>
              </div>
              <div>
                <dt>Brukt</dt>
                <dd>{t0(p.brukt)}</dd>
              </div>
              <div>
                <dt>Måneder</dt>
                <dd>{p.maaneder}</dd>
              </div>
            </dl>

            {/* HVA SOM ER ANSLAG OG HVA SOM ER MÅLT. En åpen måned
                verdsettes med kassens omsetning til årets realiserte
                margin — et anslag som skal korrigeres når regnskapet
                kommer, og som ikke skal leses som en måling. */}
            {p.anslag > 0 && (
              <p className="tr-note">
                {p.anslag} av {p.maaneder} måneder er anslag: kassens omsetning
                verdsatt til årets realiserte margin. De korrigeres når
                regnskapet lastes opp.
              </p>
            )}

            {p.justering > 0 && (
              <p className="tr-note">
                Rammen er økt med {t0(p.justering)} timer fordi det ikke var
                fastlønnet butikksjef hele perioden.
              </p>
            )}

            {p.utenArsverk && p.uavklart < p.maaneder && (
              // Haket av, men årsverket er 0 -> justeringen ble null.
              // Dette er nøyaktig den innstillingen som feiler stille.
              <p className="tr-note tr-mangler">
                Årsverket er ikke satt for denne stasjonen, så måneder uten
                fastlønnet leder gir ingen justering.{' '}
                <a href="/timeregnskap/oppsett">Sett det</a>
              </p>
            )}
          </article>
        ))}
      </section>

      <p className="undertittel sq-finstilt">
        Rammen er timene som faktisk deles ut. De 3 % sikkerhet og det
        historiske sykefraværet holdes tilbake sentralt og inngår ikke — de
        er margin for lønnsøkninger og overtid, ikke timer stasjonen
        disponerer.
      </p>
    </>
  )
}
