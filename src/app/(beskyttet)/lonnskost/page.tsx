import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { kr, manedAar } from '@/lib/format'
import { Sidehode, Tomtilstand, Nokkeltall, Datatabell, Forklaring } from '@/components/ui/side'
import { Status } from '@/components/ui/status'
import { Sideramme } from '@/components/ui/sideramme'
import { husketStasjon } from '@/lib/stasjonskontekst'
import { stasjonFraUrl, tillatAlleFor } from '@/lib/stasjonsvalg'
import { hentLonnskost } from '@/lib/lonnskost/hent'
import { BP_KONTONAVN } from '@/lib/lonnskost/bp'
import { MANGLER, SATSER } from '@/lib/lonnskost/easyatwork'

// =====================================================================
// LØNNSKOST PER MÅNED
//
// «Koster stasjonen mer i lønn enn den skal, og har den gjort det
// lenge?» Det spørsmålet hadde ingen side: /regnskap viser én måned om
// gangen, /lonn handler om enkeltansatte.
//
// ---------------------------------------------------------------------
// ÉN STASJON, ALDRI EN KJEDESUM
//
// Lønnsbudsjettet er en stasjons ansvar. En sum over kjeden ville vært
// et tall ingen kan gjøre noe med — og den ville dessuten blandet
// avlagte og åpne måneder på tvers av stasjoner, siden regnskapet ikke
// kommer likt for alle.
//
// ---------------------------------------------------------------------
// BUDSJETTET SKIFTER KILDE MIDT I SERIEN, OG DET STÅR PÅ HVER RAD
//
// En avlagt måned bærer St1s månedsbudsjett på samme rad som tallet. En
// åpen måned har bare BP-en. Uten merkelappen ville en serie som bytter
// kilde sett ut som et brudd i tallene.
//
// ÉN BUDSJETTKOLONNE, IKKE TO.
//
// St1s månedsbudsjett og BP-en sto lenge side om side, fordi de svarer
// på hvert sitt spørsmål: hva DENNE måneden ble målt mot, og hva St1
// lovet for året. De er bare aldri ulike. Målt over hele serien bærer de
// samme tall i hver eneste måned — St1 laster BP-en rett inn i
// rapportens budsjettkolonne.
//
// To kolonner som alltid viser samme tall lærer leseren å se forbi dem
// begge. Så det ble én — men sammenligningen står igjen som en STILLE
// SJEKK: spriker de, sier siden fra, og da betyr avviket noe (en revidert
// rapport etter at BP-en ble satt). Signalet er beholdt, støyen er borte.
//
// ---------------------------------------------------------------------
// EASY@WORK STÅR VED SIDEN AV, ALDRI I STEDET FOR
//
// Regnskapet er fasiten og kommer midt i neste måned. easy@work-
// eksporten finnes dagen etter at måneden er over. Den mangler fastlønn,
// refundert sykelønn og bonus per konstruksjon, og det skal stå ved
// siden av tallet — ikke i en fotnote.
// =====================================================================

type Sok = { stasjon?: string }

/** Tretten måneder: nok til å se samme måned i fjor. */
const FRA = new Date(Date.UTC(new Date().getUTCFullYear(), new Date().getUTCMonth() - 12, 1))
  .toISOString().slice(0, 10)

const pst = (a: number, b: number) => (b === 0 ? null : (a - b) / b * 100)

const enPst = (v: number) =>
  `${v.toLocaleString('nb-NO', { minimumFractionDigits: 1, maximumFractionDigits: 1 })} %`

export default async function LonnskostSide({ searchParams }: { searchParams: Promise<Sok> }) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) {
    return <Sideramme><p>Du har ikke tilgang til lønnskost.</p></Sideramme>
  }

  const sp = await searchParams
  const supabase = await lagSupabaseServerKlient()

  const { data: stasjoner } = await supabase
    .from('stasjoner')
    .select('id, navn, butikknummer')
    .is('slettet_tid', null)
    .order('butikknummer')
    .overrideTypes<{ id: string; navn: string; butikknummer: string }[]>()

  const stasjonsliste = stasjoner ?? []
  const sok = new URLSearchParams()
  if (sp.stasjon) sok.set('stasjon', sp.stasjon)
  // TILLATER IKKE «alle stasjoner». Lønnsbudsjettet er per stasjon, og
  // en kjedesum ville vært et tall ingen har ansvar for.
  const tillatAlle = tillatAlleFor('/lonnskost', bruker.rolle, stasjonsliste.length)
  const valgtStasjon = await husketStasjon(
    stasjonsliste, stasjonFraUrl(sok, stasjonsliste), tillatAlle,
  )
  const navnFor = new Map(stasjonsliste.map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))
  const erStasjon = valgtStasjon != null && navnFor.has(valgtStasjon)

  if (!erStasjon) {
    return (
      <Sideramme>
        <Sidehode tittel="Lønnskost" />
        <Tomtilstand
          tittel="Velg en stasjon"
          forklaring={
            'Lønnsbudsjettet settes per stasjon. En sum over kjeden ville '
            + 'vært et tall ingen har ansvar for.'
          }
        />
      </Sideramme>
    )
  }

  const { maaneder, ukjenteKoder, easyatwork } = await hentLonnskost(supabase, valgtStasjon!, FRA)
  const avlagte = maaneder.filter((m) => m.avlagt)
  const siste = avlagte[0]

  if (maaneder.length === 0) {
    return (
      <Sideramme>
        <Sidehode tittel="Lønnskost" merke={navnFor.get(valgtStasjon!)} />
        <Tomtilstand
          tittel="Ingen lønnstall ennå"
          forklaring={
            'Verken avlagt regnskap eller BP-budsjett er lastet inn for denne '
            + 'stasjonen. Last opp regnskapsrapporten under Import.'
          }
        />
      </Sideramme>
    )
  }

  const avvik = siste && siste.budsjettKr != null ? siste.lonnskostKr - siste.budsjettKr : null
  const eaPerMaaned = new Map(easyatwork.map((e) => [e.maaned, e]))
  const sisteEa = easyatwork[0]
  const ukjenteArter = [...new Set(easyatwork.flatMap((e) => e.ukjenteArter))]

  // Hvor mange maaneder har BEGGE budsjettene, og i hvor mange spriker
  // de? En krone slaar ut - de to kildene skal baere samme tall med
  // mindre rapporten er revidert.
  const medBegge = maaneder.filter((m) => m.budsjettKr != null && m.bpBudsjettKr != null)
  const samsvar = {
    begge: medBegge.length,
    ulike: medBegge.filter((m) => Math.abs(m.budsjettKr! - m.bpBudsjettKr!) >= 1).length,
  }
  const avvikPst = siste && siste.budsjettKr != null
    ? pst(siste.lonnskostKr, siste.budsjettKr) : null

  return (
    <Sideramme>
      <Sidehode
        tittel="Lønnskost"
        merke={navnFor.get(valgtStasjon!)}
        undertittel={siste
          ? `Siste avlagte måned: ${manedAar.format(new Date(`${siste.maaned}-01`))}`
          : 'Ingen avlagt måned ennå'}
        handlinger={!siste ? <Status nivaa="endring">Ingen avlagt måned</Status> : undefined}
      />

      {/* EN UKJENT PERSONALKODE ER ET FUNN, IKKE EN DETALJ.
          St1 gikk fra 18 til over femti konti mellom BP25 og BP26. En ny
          5xxx som ingen har klassifisert ville falt ut av budsjettet i
          stillhet, og avviket ville sett ut som god kostnadsstyring. */}
      {ukjenteKoder.length > 0 && (
        <Status nivaa="handling">
          {`BP-en har ${ukjenteKoder.length} personalkonto(er) som ikke er klassifisert: `}
          {ukjenteKoder.join(', ')}
          {'. Budsjettet under er for lavt til de er tatt stilling til.'}
        </Status>
      )}

      {siste && (
        <div className="sq-nokkelrad">
          <Nokkeltall
            merkelapp="Lønnskost"
            verdi={kr.format(Math.round(siste.lonnskostKr))}
            sammenlignet={siste.budsjettKr != null
              ? `budsjett ${kr.format(Math.round(siste.budsjettKr))}`
              : 'uten budsjett'}
          />
          <Nokkeltall
            merkelapp={avvik == null ? 'Avvik' : avvik > 0 ? 'Over budsjett' : 'Under budsjett'}
            verdi={avvik == null ? '—' : kr.format(Math.abs(Math.round(avvik)))}
            sammenlignet={avvikPst == null ? undefined : enPst(Math.abs(avvikPst))}
            retning={avvik == null ? 'flat' : avvik > 0 ? 'opp' : 'ned'}
            bra={avvik == null ? undefined : avvik <= 0}
          />
          {/* ST1s SATS, IKKE VAAR EGEN BROEK.
              Her sto «Loennskost per time»: hele loennskosten delt paa
              timeloennstimene. Telleren hadde fastloenn i seg, nevneren
              ingen fastloenntimer. Maalt paa juli 2026 ga den 372 kr mot
              St1s 216,21. En total kostnad per time ville krevd timene
              til de fastloennede, og dem finnes det ingen kilde til. */}
          <Nokkeltall
            merkelapp="Timelønn · snittsats"
            verdi={siste.snittsats == null ? '—' : `${Math.round(siste.snittsats)} kr`}
            sammenlignet={siste.timer == null
              ? 'timetallet mangler i rapporten'
              : `${siste.timer.toLocaleString('nb-NO')} timelønnstimer`}
          />
        </div>
      )}

      <Datatabell tittel="Per måned" antall={maaneder.length}>
        <thead>
          <tr>
            <th>Måned</th>
            <th>Lønnskost</th>
            <th>easy@work</th>
            <th>Budsjett</th>
            <th>Avvik</th>
            <th>Timer</th>
            <th>Snittsats</th>
          </tr>
        </thead>
        <tbody>
          {maaneder.map((m) => {
            const a = m.budsjettKr == null ? null : m.lonnskostKr - m.budsjettKr
            const ea = eaPerMaaned.get(m.maaned)
            const spriker = m.budsjettKr != null && m.bpBudsjettKr != null
              && Math.abs(m.budsjettKr - m.bpBudsjettKr) >= 1
            return (
              <tr key={m.maaned}>
                <td>
                  {manedAar.format(new Date(`${m.maaned}-01`))}
                  {/* Kilden står på hver rad. Et budsjett fra BP-en og et
                      fra St1s månedsrapport svarer på ulike spørsmål. */}
                  {!m.avlagt && <> <Status nivaa="endring">budsjett</Status></>}
                </td>
                <td>{m.avlagt ? kr.format(Math.round(m.lonnskostKr)) : '—'}</td>
                {/* ANSLAGET, IKKE FASITEN. Står tomt til fila er lastet
                    opp for måneden — en tom celle er ærligere enn en null. */}
                <td>{ea == null ? '—' : kr.format(Math.round(ea.lonnskostKr))}</td>
                {/* ÉN BUDSJETTKOLONNE. Spriker St1s månedsbudsjett fra
                    BP-en, sier pipen fra — da er rapporten revidert etter
                    at BP-en ble satt, og det er månedsbudsjettet som
                    gjelder. Ellers er de samme tall og fortjener én celle. */}
                <td>
                  {m.budsjettKr == null ? '—' : kr.format(Math.round(m.budsjettKr))}
                  {spriker && <> <Status nivaa="endring">≠ BP</Status></>}
                </td>
                <td>
                  {a == null ? '—' : (
                    <span className={`status-pip ${a > 0 ? 'rod' : 'gronn'}`}>
                      {`${a > 0 ? '+' : '−'}${kr.format(Math.abs(Math.round(a)))}`}
                    </span>
                  )}
                </td>
                <td>{m.timer == null ? '—' : m.timer.toLocaleString('nb-NO')}</td>
                <td>{m.snittsats == null ? '—' : `${Math.round(m.snittsats)} kr`}</td>
              </tr>
            )
          })}
        </tbody>
      </Datatabell>

      {siste && (
        <Datatabell
          tittel={`Kontoene · ${manedAar.format(new Date(`${siste.maaned}-01`))}`}
          antall={siste.linjer.length}
        >
          <thead>
            <tr><th>Konto</th><th>Regnskap</th><th>Budsjett</th><th>Avvik</th></tr>
          </thead>
          <tbody>
            {siste.linjer.map((l) => {
              const a = l.budsjett == null ? null : l.regnskap - l.budsjett
              return (
                <tr key={l.kode}>
                  <td>{BP_KONTONAVN[l.kode] ? `${l.kode} ${BP_KONTONAVN[l.kode]}` : l.post}</td>
                  <td>{kr.format(Math.round(l.regnskap))}</td>
                  <td>{l.budsjett == null ? '—' : kr.format(Math.round(l.budsjett))}</td>
                  <td>{a == null ? '—' : kr.format(Math.round(a))}</td>
                </tr>
              )
            })}
            <tr>
              <td><strong>Lønnskost</strong></td>
              <td><strong>{kr.format(Math.round(siste.lonnskostKr))}</strong></td>
              <td>
                <strong>
                  {siste.budsjettKr == null ? '—' : kr.format(Math.round(siste.budsjettKr))}
                </strong>
              </td>
              <td><strong>{avvik == null ? '—' : kr.format(Math.round(avvik))}</strong></td>
            </tr>
          </tbody>
        </Datatabell>
      )}

      {/* TALLET SOM STAAR I ST1s RAPPORT, og hvorfor det er et annet.
          St1s «Totale personalkostnader» tar konto 590 med: for Boenes
          juli 2026 er deres tall 246 822 og vaart 242 963. Begge er
          riktige, men uten denne setningen ser den som sammenligner ut
          til aa ha funnet en feil. */}
      {siste && siste.andrePersonalKr !== 0 && (
        <p className="undertittel">
          {`I tillegg kommer ${kr.format(Math.round(siste.andrePersonalKr))} i andre `}
          {'personalkostnader (konto 590) — kurs, verneutstyr, bedriftshelsetjeneste. '}
          {'Det er personalkost, men ikke lønn, og følger ingen tariff. '}
          {`St1s rapport oppgir de to samlet som «Totale personalkostnader»: `}
          {`${kr.format(Math.round(siste.lonnskostKr + siste.andrePersonalKr))}.`}
        </p>
      )}

      {/* SIGNALET, IKKE STOEYEN.
          Kolonnen for BP-en er borte fordi de to alltid baerer samme
          tall. Sammenligningen er ikke borte: spriker de, er rapporten
          revidert etter at BP-en ble satt, og DET er verdt en setning.
          Er de like, sier siden ingenting - som den skal. */}
      {samsvar.ulike > 0 && (
        <Status nivaa="handling">
          {`${samsvar.ulike} av ${samsvar.begge} måneder har ulikt tall i St1s `}
          {'månedsbudsjett og BP-en. Rapporten er revidert etter at BP-en ble satt. '}
          {'Budsjettkolonnen viser månedsbudsjettet — det er det måneden måles mot.'}
        </Status>
      )}

      {/* EN UKJENT LOENNSART ER ET FUNN.
          Fristelsen var «alt som ikke er 2 eller 12 er tillegg». Den ville
          lagt en fastloennsart rett i 502 og gjort et hull til et tall. */}
      {ukjenteArter.length > 0 && (
        <Status nivaa="handling">
          {`easy@work-fila har ${ukjenteArter.length} lønnsart(er) uten konto: `}
          {ukjenteArter.join(', ')}
          {'. De er holdt UTENFOR anslaget under, ikke lagt i en bøtte.'}
        </Status>
      )}

      {sisteEa && (
        <Datatabell
          tittel={`easy@work · anslag for ${manedAar.format(new Date(`${sisteEa.maaned}-01`))}`}
          antall={5}
        >
          <thead>
            <tr><th>Post</th><th>Kroner</th><th>Grunnlag</th></tr>
          </thead>
          <tbody>
            <tr>
              <td>Kontantlønn</td>
              <td>{kr.format(Math.round(sisteEa.kontantKr))}</td>
              <td>{`${sisteEa.timer.toLocaleString('nb-NO')} arbeidede timer`}</td>
            </tr>
            <tr>
              <td>{`Feriepenger ${SATSER.feriepengerPst} %`}</td>
              <td>{kr.format(Math.round(sisteEa.feriepengerKr))}</td>
              <td>av kontantlønn</td>
            </tr>
            <tr>
              <td>{`Pensjon ${SATSER.pensjonPst} %`}</td>
              <td>{kr.format(Math.round(sisteEa.pensjonKr))}</td>
              <td>OTP fra første krone</td>
            </tr>
            <tr>
              <td>{`Arbeidsgiveravgift ${SATSER.agaPst} %`}</td>
              <td>{kr.format(Math.round(sisteEa.agaKr))}</td>
              {/* AGA PAALOEPER OGSAA AV FERIEPENGER OG PENSJON. Konto 541
                  finnes nettopp fordi feriepengedelen foeres for seg. */}
              <td>av lønn, feriepenger og pensjon</td>
            </tr>
            <tr>
              <td><strong>Anslått lønnskost</strong></td>
              <td><strong>{kr.format(Math.round(sisteEa.lonnskostKr))}</strong></td>
              <td>{sisteEa.maaned === siste?.maaned && siste?.avlagt
                ? `regnskapet: ${kr.format(Math.round(siste.lonnskostKr))}`
                : 'ingen avlagt måned å måle mot ennå'}</td>
            </tr>
          </tbody>
        </Datatabell>
      )}

      {sisteEa && (
        <p className="undertittel">
          {'Anslaget er regnet av lønnsartene i easy@work-eksporten, ikke lest av '}
          {'regnskapet. Tre ting er ikke med, og de kan ikke oppdages i tallet: '}
          {MANGLER.join(', ')}
          {'. En fastlønnet dukker ikke opp med null i eksporten — hen dukker ikke '}
          {'opp i det hele tatt. Er konto 501 null for stasjonen, er anslaget helt; '}
          {'er den ikke det, mangler anslaget den personen.'}
        </p>
      )}

      <Forklaring sporsmaal="Hva er tatt med, og hva er det målt mot?">
        <p>
          Lønnskost er de ni kontiene 501 Faste lønninger, 502 Lønnstillegg,
          503 Timelønn, 505 Sykelønn, 506 Refundert sykelønn, 508 Påløpte
          feriepenger, 509 Bonus, 540 og 541 arbeidsgiveravgift. Konto 590
          Andre personalkostnader står utenfor — den er personalkost, ikke lønn.
        </p>
        <p>
          Summen er kontrollert mot en uavhengig kilde: Bønes juli 2026 gir
          242 963 kroner både fra regnskapet og fra easy@work-eksporten regnet
          ut med Energiavtalens satser, feriepenger og arbeidsgiveravgift.
        </p>
        <p>
          Budsjettet skifter kilde underveis, og hver rad sier hvilken. En avlagt
          måned måles mot St1s månedsbudsjett, som ligger på samme rad som
          regnskapstallet. En måned som ikke er avlagt måles mot BP-ens årsplan.
          De to bærer samme tall — St1 laster BP-en rett inn i rapportens
          budsjettkolonne — og står derfor i én kolonne. Skiller de lag, er
          rapporten revidert etter at BP-en ble satt, og siden sier fra.
        </p>
        <p>
          easy@work-kolonnen er et anslag, ikke en fasit. Den er regnet av
          lønnsartene i eksporten: timelønn på konto 503, sykelønn på 505,
          kveld-, helg- og overtidstillegg på 502, med {SATSER.feriepengerPst} %
          feriepenger, {SATSER.pensjonPst} % pensjon og {SATSER.agaPst} %
          arbeidsgiveravgift av alle tre. Verdien er at den finnes dagen etter at
          måneden er over, mens regnskapet kommer midt i den neste.
        </p>
        <p>
          Anslaget mangler fastlønn, refundert sykelønn og bonus. Det første er
          det farligste: en fastlønnet dukker ikke opp med null i eksporten, hen
          dukker ikke opp i det hele tatt. På en stasjon der alle er timelønnet
          treffer anslaget nær regnskapet; på en med en fastlønnet butikksjef er
          det for lavt med hele den lønnen.
        </p>
        <p>
          BP-budsjettet er strukturelt litt smalere: det har fastlønn, timelønn,
          feriepenger og arbeidsgiveravgift, men ingen egne poster for
          lønnstillegg, sykelønn eller bonus. Et avvik mot BP kan derfor være
          litt for stort av den grunn alene.
        </p>
        <p>
          Timetallet er St1s eget, «Timelønn - antall timer», og finnes bare for
          avlagte måneder. Uten timer vises ingen timepris — en brøk på et tall vi
          ikke har er verre enn en tom celle.
        </p>
      </Forklaring>
    </Sideramme>
  )
}
