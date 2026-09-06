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
// BP-EN HAR SIN EGEN KOLONNE, og den finnes for HVER måned — også de
// avlagte. Her sto det en stund at de to aldri fantes samtidig; det var
// sant om `bp_kostnad` i regnskapslinjer, som importen hopper over når
// måneden er låst, men ikke om `bp_linje` (`0155`), som er BP-en som
// sitt eget dokument.
//
// Målt på Bønes 2026 bærer de samme tall i alle sju avlagte måneder —
// St1 laster BP-en rett inn i rapportens budsjettkolonne. To identiske
// kolonner må forklares, ellers ser de ut som en feil; setningen under
// tabellen sier hvor mange som er like. Kolonnen står likevel, for en
// revidert rapport ville skilt lag med BP-en, og DET er det man vil se.
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

  const { maaneder, ukjenteKoder } = await hentLonnskost(supabase, valgtStasjon!, FRA)
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
            <th>Budsjett</th>
            <th>BP</th>
            <th>Avvik</th>
            <th>Timer</th>
            <th>Snittsats</th>
          </tr>
        </thead>
        <tbody>
          {maaneder.map((m) => {
            const a = m.budsjettKr == null ? null : m.lonnskostKr - m.budsjettKr
            return (
              <tr key={m.maaned}>
                <td>
                  {manedAar.format(new Date(`${m.maaned}-01`))}
                  {/* Kilden står på hver rad. Et budsjett fra BP-en og et
                      fra St1s månedsrapport svarer på ulike spørsmål. */}
                  {!m.avlagt && <> <Status nivaa="endring">budsjett</Status></>}
                </td>
                <td>{m.avlagt ? kr.format(Math.round(m.lonnskostKr)) : '—'}</td>
                <td>{m.budsjettKr == null ? '—' : kr.format(Math.round(m.budsjettKr))}</td>
                {/* BP-EN STAAR I EGEN KOLONNE, IKKE I STEDET FOR.
                    St1s maanedsbudsjett sier hva DENNE maaneden ble maalt
                    mot; BP-en sier hva St1 lovet for aaret. De kan vaere
                    ulike, og det er da man vil se begge. */}
                <td>{m.bpBudsjettKr == null ? '—' : kr.format(Math.round(m.bpBudsjettKr))}</td>
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

      {/* TO IDENTISKE KOLONNER MAA FORKLARES, ellers ser de ut som en
          feil. Maalt paa Boenes 2026: St1s maanedsbudsjett og BP-en er
          samme tall i alle sju avlagte maanedene - St1 laster BP-en rett
          inn i rapportens budsjettkolonne. Kolonnen staar likevel, for
          en revidert BP ville skilt lag med rapporten, og DET er det man
          vil se. */}
      {samsvar.begge > 0 && (
        <p className="undertittel">
          {samsvar.ulike === 0
            ? `St1s månedsbudsjett og BP-en er samme tall i alle ${samsvar.begge} `
              + 'månedene som har begge. Rapporten bærer BP-en videre uendret.'
            : `${samsvar.ulike} av ${samsvar.begge} måneder har ulikt tall i St1s `
              + 'månedsbudsjett og BP-en. Da er rapporten revidert etter at BP-en '
              + 'ble satt, og det er månedsbudsjettet som gjelder for den måneden.'}
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
          De to finnes aldri for samme måned — BP-importen hopper over avlagte
          måneder, fordi regnskapet da bærer budsjettet selv.
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
