import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { Forklaring, Sidehode, Tomtilstand } from '@/components/ui/side'
import { Status } from '@/components/ui/status'
import { kr } from '@/lib/format'
import { bruttoKrav, kravtekst } from '@/lib/bemanning/timekrav'

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
  realisert_margin_pst: number | null
  budsjett_timer: number | null
  opptjente_timer: number | null
  brukte_timer: number | null
  timer_over: number | null
  brutto_per_time: number | null
  bp_brutto_per_time: number | null
  ramme_justering_timer: number | null
  arsverk_timer: number | null
  dager_med_salg: number | null
  dager_i_maaned: number | null
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

  // TO ULIKE KRAV TIL DATA, OG DE ER IKKE DE SAMME.
  //
  // OPPGJØRET trenger stemplinger: uten dem finnes ikke forbruket.
  // MÅLET trenger dem ikke — timene du har tjent inn er brutto delt på
  // raten St1 satte, og den kan regnes fra første salgsdag.
  //
  // Robert 2026-08-22: «jeg snakker mer om når vi ikke har stemplinger.»
  // Det er normaltilstanden midt i måneden — de kommer fra easy@work
  // etterskuddsvis — og før dette viste siden da ingenting i det hele
  // tatt for stasjonen. Et mål er nyttig uten et fasitsvar; det er
  // nettopp det som gjør det til et mål.
  const medBrutto = alle.filter((r) => r.opptjente_timer != null)
  const medForbruk = medBrutto.filter((r) => r.brukte_timer != null)

  if (medBrutto.length === 0) {
    return (
      <>
        <Sidehode tittel="Timeregnskap" undertittel="Har vi råd til timene?" />
        <Tomtilstand
          tittel="Ingenting å gjøre opp ennå"
          forklaring={'Timeregnskapet trenger tre ting: timebudsjettet fra BP-en, '
            + 'brutto fra regnskapet eller kassa, og stemplinger. De to '
            + 'første gir målet; stemplingene gir oppgjøret. Uten de to '
            + 'første finnes det ingen ramme å måle mot.'}
          handling={<a className="sq-knapp" href="/import">Til import</a>}
        />
      </>
    )
  }

  // EN DELVIS MÅNED HØRER IKKE HJEMME I EN SUM. Salgstallene stopper på
  // gårsdagen, så den måneden som pågår har to tredjedeler av inntekten
  // og to tredjedeler av timene. Regnestykket stemmer — men lagt sammen
  // med avsluttede måneder kan ingen se hvor mye som er talt.
  //
  // Derfor: totalen dekker det som er ferdig. Den pågående måneden står
  // for seg selv, med hvor langt den er kommet.
  const helMaaned = (r: Rad) =>
    r.dager_med_salg != null && r.dager_i_maaned != null
      && r.dager_med_salg >= r.dager_i_maaned

  const per = liste.map((st) => {
    const mine = medBrutto.filter((r) => r.stasjon_id === st.id)
    // OPPGJØRET: bare avsluttede måneder med stemplinger.
    const ferdige = medForbruk.filter((r) => r.stasjon_id === st.id).filter(helMaaned)
    // MÅLET: den pågående måneden, med eller uten stemplinger.
    const paagaar = mine.find((r) => !helMaaned(r))
    const sum = (rader: Rad[], f: (r: Rad) => number | null) =>
      rader.reduce((s, r) => s + (f(r) ?? 0), 0)
    const opptjent = sum(ferdige, (r) => r.opptjente_timer)
    const brukt = sum(ferdige, (r) => r.brukte_timer)
    return {
      st,
      maaneder: ferdige.length,
      opptjent,
      brukt,
      over: brukt - opptjent,
      justering: sum(ferdige, (r) => r.ramme_justering_timer),
      // «ukjent» = stasjonen har ingen faste vakter registrert, saa
      // lederdekningen kan ikke vurderes.
      uavklart: ferdige.filter((r) => r.lederdekning === 'ukjent').length,
      anslag: ferdige.filter((r) => r.grunnlag === 'anslag').length,
      // HVA SOM SKAL TIL. Regnes paa alt som er maalt - ogsaa den
      // paagaaende maaneden - fordi oppgaven gjelder aaret, ikke en
      // maaned isolert.
      krav: bruttoKrav({
        rammeTimer: sum(mine, (r) => r.budsjett_timer),
        brukteTimer: sum(mine, (r) => r.brukte_timer),
        bpBruttoKr: sum(mine, (r) => r.bp_brutto_kr),
        realisertBruttoKr: sum(mine, (r) => r.realisert_brutto_kr),
        realisertMarginPst: mine[0]?.realisert_margin_pst ?? null,
      }),
      paagaar,
    }
  }).filter((p) => p.maaneder > 0 || p.paagaar)

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
        // EN STASJON UTEN FASTE VAKTER KAN IKKE VURDERES. Da vet vi ikke
        // om St1s fratrekk for en fastlønnet butikksjef holder, og
        // rammen står urørt. Dette står OVER tallene, ikke under: leses
        // de uten dette, leses de som sikrere enn de er.
        <p className="undertittel sq-finstilt">
          {uavklarte} måneder er ikke vurdert, fordi stasjonen ikke har faste
          vakter registrert. Rammen er ikke justert for dem.{' '}
          <a href="/bemanning">Til bemanning</a>
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

            {p.krav && p.krav.bruttoMangler > 0 && (
              // OPPGAVEN, IKKE DOMMEN.
              //
              // «1 745 timer over» er sant, men ikke noe man kan gjøre noe
              // med etter at timene er brukt. Snudd blir det en salgsoppgave:
              //
              //   brutto som kreves = BP-brutto × (brukte timer ÷ ramme)
              //
              // Samme regnestykke, den enden butikksjefen kan ta i — og
              // midt i måneden er den fortsatt mulig å påvirke.
              <p className="tr-krav">
                {kravtekst(p.krav, (n: number) => kr.format(n))}
              </p>
            )}

            {p.paagaar && (
              // PEKEPINNEN. Det eneste tallet på siden som kommer tidsnok
              // til å endre noe — alt annet er oppgjør: sant, men over.
              //
              // REGELEN ER ÉN RATE. 800 timer på 800 000 kr er 1 000 kr
              // brutto per time, og timene du har tjent inn er brutto
              // delt på den raten. Robert 2026-08-22: «da er regelen
              // veldig enkel eller?» — jo, og det er den samme regelen
              // hele siden bygger på.
              //
              // BRUTTOEN ER KORRIGERT, IKKE KASSENS. Står det 700 000 i
              // kassa og regnskapet lander på 600 000 etter telling, er
              // det 600 000 som har tjent inn timer.
              <p className="tr-styring">
                Så langt i inneværende måned ({p.paagaar.dager_med_salg} av{' '}
                {p.paagaar.dager_i_maaned} dager): {t0(p.paagaar.opptjente_timer)}
                {' '}timer tjent inn.
                {/* UTEN STEMPLINGER FINNES INGEN FASIT, og det er
                    normaltilstanden midt i måneden — de kommer fra
                    easy@work etterskuddsvis. Målet er nyttig uten et
                    fasitsvar; det er nettopp det som gjør det til et mål. */}
                {p.paagaar.brukte_timer == null ? (
                  <span className="tr-styring-forbehold">
                    {' '}Ingen stemplinger importert for måneden ennå, så
                    forbruket er ikke kjent. Tallet er vaktplanen din å holde
                    seg innenfor.
                  </span>
                ) : (
                  <>
                    {' '}{t0(p.paagaar.brukte_timer)} timer brukt —{' '}
                    {(p.paagaar.timer_over ?? 0) > 0
                      ? `${t0(p.paagaar.timer_over)} for mye så langt.`
                      : `${t0(Math.abs(p.paagaar.timer_over ?? 0))} å gå på.`}
                    {/* En pekepinne, ikke en dom: tar salget seg opp,
                        hentes avviket inn uten at noen gjorde noe. */}
                    <span className="tr-styring-forbehold">
                      {' '}En pekepinne underveis — tar salget seg opp, hentes
                      avviket inn av seg selv.
                    </span>
                  </>
                )}
              </p>
            )}

            {p.anslag > 0 && (
              <p className="tr-note">
                {p.anslag} av {p.maaneder} måneder er anslag: kassens omsetning
                verdsatt til årets realiserte margin. De korrigeres når
                regnskapet lastes opp.
              </p>
            )}


            {p.justering > 0 && (
              // Hvorfor rammen er større enn St1 ga. Uten denne linja er
              // tallet over uetterprøvbart.
              <p className="tr-note">
                Rammen er økt med {t0(p.justering)} timer: stasjonen har ingen
                fastlønnet fast vakt, så St1s fratrekk for en fastlønnet
                butikksjef dekker ikke arbeidet.
              </p>
            )}
          </article>
        ))}
      </section>

      {/* BAK EN KNAPP, IKKE PAA SKJERMEN.

          Robert 2026-08-22: «der du skriver veldig mye grunner for
          hvorfor ting maales (...) der kunne vi hatt en info knapp
          istedenfor? da slipper vi aa drukne i informasjon som man
          kanskje kjenner til uansett.»

          Den som kjenner regelen trenger den ikke hver gang. Den som
          lurer skal finne den paa stedet - ikke i en haandbok. */}
      <Forklaring sporsmaal="Hva er rammen, og hvordan tjenes timene inn?">
        <p>
          Rammen er timene som faktisk deles ut. De 3 % sikkerhet og det
          historiske sykefraværet holdes tilbake sentralt og inngår ikke
          — de er margin for lønnsøkninger og overtid, ikke timer
          stasjonen disponerer.
        </p>
        <p>
          Timene tjenes inn av brutto. Sier budsjettet 12 000 timer til
          5 millioner, er prisen 417 kr per time — og da kan du ikke
          bruke 12 000 timer på 4,8 millioner.
        </p>
        <p>
          Bruttoen er den <strong>korrigerte</strong>: står det 700 000 i
          kassa og regnskapet lander på 600 000 etter telling og svinn,
          er det 600 000 som teller. Måneder uten ferdig regnskap
          verdsettes med kassens omsetning og årets realiserte margin,
          aldri kassens egen.
        </p>
      </Forklaring>
    </>
  )
}
