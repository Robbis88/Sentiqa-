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
import { maanedsrader } from '@/lib/lonnskost/rom'
import { ManuelleTall } from './manuelle-tall'
import { Lonnsformer } from './lonnsformer'

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

/**
 * ISO-ukenummer. Bare en standardverdi i skjemaet - feltet kan endres.
 *
 * ISO, IKKE «uke siden nyttaar»: uke 1 er uka som inneholder aarets
 * foerste torsdag, og rapporten fra vaskeleverandoeren teller slik. En
 * standardverdi som er tre dager feil ville blitt staaende, fordi ingen
 * sjekker et felt som allerede er fylt ut.
 */
function isoUke(d: Date): number {
  const t = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()))
  const dag = t.getUTCDay() === 0 ? 7 : t.getUTCDay()
  t.setUTCDate(t.getUTCDate() + 4 - dag)
  const nyttaar = new Date(Date.UTC(t.getUTCFullYear(), 0, 1))
  return Math.ceil(((t.getTime() - nyttaar.getTime()) / 86400000 + 1) / 7)
}

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

  // BUTIKKSJEFEN SER TOTALER, IKKE KONTOER.
  //
  // `erLeder()` slipper inn baade eier og butikksjef, og kontotabellen
  // var ikke filtrert - konto 501 Faste loenninger sto aapen for hvem som
  // helst med butikksjefrolle. Paa en stasjon med én fastloennet er den
  // kolonnen én persons loenn.
  //
  // Det butikksjefen trenger er om stasjonen ligger innenfor. Det svaret
  // krever ingen kontoer.
  const erAdmin = bruker.rolle === 'retailer_admin'
  const {
    maaneder, ukjenteKoder, easyatwork, sykelonn, rom, bilvaskUker, fastlonnMaaneder,
    ansatte, ansatteMaaned,
  } = await hentLonnskost(
    supabase, valgtStasjon!, FRA,
  )
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
  const romPer = new Map(rom.map((r) => [r.maaned, r]))

  // ===================================================================
  // RADENE ER UNIONEN, IKKE BARE REGNSKAPETS MAANEDER.
  //
  // `byggLonnskost` hopper over en maaned som verken er avlagt eller har
  // BP-linjer (`if (kilde.length === 0) continue`), og tabellen itererte
  // den lista. En maaned med BARE easy@work-data ble dermed usynlig:
  // fila var lastet opp, raden fantes ikke, og skjermen saa ut som om
  // ingenting var kommet inn.
  //
  // Det er den farligste formen for feil i dette systemet - et fravaer
  // som ser ut som en tom maaned. Boenes august traff den: eksporten var
  // inne, men stasjonen manglet BP-rader for maaneden.
  // ===================================================================
  const maanedPer = new Map(maaneder.map((m) => [m.maaned, m]))
  const rader = maanedsrader(maaneder, easyatwork, rom)

  // ===================================================================
  // ÅRET, MEN LIKE FOR LIKE
  //
  // Aa summere sju avlagte maaneder mot tolv budsjetterte gir et avvik
  // paa flere hundre tusen som ikke betyr noe. Det er samme form som har
  // gaatt igjen hele veien: to tall som ser sammenlignbare ut og ikke er
  // det.
  //
  // Derfor to boelker, og de blandes ikke:
  //
  //   HITTIL I AAR   bare maanedene som ER avlagt - og budsjettet og
  //                  rommet for NOEYAKTIG de samme maanedene
  //   HELE AARET     BP-ens tolv maaneder, som en egen linje
  //
  // Aaret er kalenderaaret til den nyeste maaneden i vinduet. Vinduet er
  // tretten maaneder og krysser aarsskiftet, saa uten den avgrensningen
  // ville «aaret» vaert tretten maaneder over to aar.
  // ===================================================================
  // TO BUDSJETTER SOM IKKE ER DET SAMME TALLET.
  //
  // St1s maanedsrapport baerer sitt eget budsjett; BP-en er kjedens
  // aarsdokument. De var like paa hver maaned tidligere - saa like at
  // sida forklarte hvorfor to kolonner viste samme sum. Fra april 2026
  // spriker de paa Dale: 317 869 mot 625 623.
  //
  // LOENNSROMMET REGNES AV BP-EN. Naar de to spriker, maales altsaa
  // loennskosten mot noe annet enn tallet i budsjettkolonnen - og et
  // avvik paa et kvart million uten en setning som sier hvorfor, er et
  // tall folk enten stoler blindt paa eller slutter aa lese.
  const sprikende = rader.filter((mnd) => {
    const m = maanedPer.get(mnd)
    const r = romPer.get(mnd)
    return m?.budsjettKr != null && r?.bpLonnKr != null
      && Math.abs(m.budsjettKr - r.bpLonnKr) >= 1000
  })

  // Maaneden vi staar i. Rommet for den er tjent SAA LANGT, ikke for
  // hele maaneden - omsetningen dekker bare dagene som har vaert.
  const naaMaaned = new Date().toISOString().slice(0, 7)

  const aar = rader[0]?.slice(0, 4) ?? String(new Date().getUTCFullYear())
  const iAar = <T extends { maaned: string }>(xs: T[]) => xs.filter((x) => x.maaned.startsWith(aar))

  const avlagteIAar = iAar(maaneder).filter((m) => m.avlagt)
  const avlagteSett = new Set(avlagteIAar.map((m) => m.maaned))
  const romAvlagt = iAar(rom).filter((r) => avlagteSett.has(r.maaned))

  const sum = (xs: (number | null | undefined)[]) =>
    xs.reduce<number>((a, v) => a + (typeof v === 'number' && Number.isFinite(v) ? v : 0), 0)

  const aarstall = {
    maaneder: avlagteIAar.length,
    lonnskostKr: sum(avlagteIAar.map((m) => m.lonnskostKr)),
    budsjettKr: sum(avlagteIAar.map((m) => m.budsjettKr ?? romAvlagt.find((r) => r.maaned === m.maaned)?.bpLonnKr)),
    romKr: sum(romAvlagt.map((r) => r.romKr)),
    // Rommet finnes bare for maaneder som har baade BP og brutto. Uten
    // dette ville avviket maalt loennskost for sju maaneder mot et rom
    // for fem - samme felle, ett niva ned.
    romMaaneder: romAvlagt.filter((r) => r.romKr != null).length,
    timer: sum(avlagteIAar.map((m) => m.timer)),
    svinnKr: sum(iAar(rom).filter((r) => avlagteSett.has(r.maaned)).map((r) => r.svinnKr)),
    // HELE AARET er BP-ens tolv maaneder, uavhengig av hva som er avlagt.
    bpHeleAaret: sum(iAar(rom).map((r) => r.bpLonnKr)),
    bpMaaneder: iAar(rom).filter((r) => r.bpLonnKr != null).length,
  }
  const aarsavvik = aarstall.romMaaneder === aarstall.maaneder && aarstall.maaneder > 0
    ? aarstall.lonnskostKr - aarstall.romKr
    : null
  const grunnlagPer = new Map(rom.map((r) => [r.maaned, r]))
  // DEN INNEVAERENDE MAANEDEN ER DEN ENESTE SOM KAN PAAVIRKES.
  //
  // Noekkeltallene sto paa siste AVLAGTE maaned - et tall om noe som er
  // over. Den maaneden det finnes et loennsrom for og et forbruk aa maale
  // mot, er den man fortsatt kan gjoere noe med.
  const naa = rom.find((r) => r.romKr != null && eaPerMaaned.has(r.maaned))
  const naaEa = naa ? eaPerMaaned.get(naa.maaned) : undefined
  const naaAvlagt = naa ? maaneder.find((m) => m.maaned === naa.maaned)?.avlagt : false
  const naaBrukt = naaAvlagt
    ? maaneder.find((m) => m.maaned === naa!.maaned)?.lonnskostKr ?? null
    : naaEa?.lonnskostKr ?? null
  const igjen = naa?.romKr != null && naaBrukt != null ? naa.romKr - naaBrukt : null

  // FAKTISK ANDEL, ikke rommet i kroner. `naaBrukt` delt paa den samme
  // bruttoen rommet er regnet av - saa de to prosentene er sammenlignbare
  // per konstruksjon.
  const naaAndel = naa?.bruttoKr != null && naa.bruttoKr > 0 && naaBrukt != null
    ? naaBrukt / naa.bruttoKr
    : null
  const andelsavvik = naaAndel != null && naa?.lonnsandel != null
    ? naaAndel - naa.lonnsandel
    : null
  const sisteEa = easyatwork[0]
  const ukjenteArter = [...new Set(easyatwork.flatMap((e) => e.ukjenteArter))]
  // Bare der de to faktisk maaler samme maaned. En differanse mot en
  // maaned som ikke er avlagt ville vaert et tall mot ingenting.
  const eaMotRegnskap = sisteEa && siste?.avlagt && sisteEa.maaned === siste.maaned
    ? sisteEa.lonnskostKr - siste.lonnskostKr
    : null

  // DIFFERANSEN SKAL NAVNGIS, IKKE BARE VISES.
  //
  // Vi har begge sider i basen, saa gapet trenger ikke staa som et
  // uforklart tall. Malt paa Dale juli 2026 var sykeloenn 99,6 % av det:
  // regnskapet hadde 34 830, easy@work 5 934. Grunnen er strukturell -
  // easy@work er et VAKTSYSTEM, og en langtidssykmeldt har ingen vakt aa
  // henge loenna paa. Ingen eksport derfra vil noen gang ha den.
  //
  // Paaslagene foelger med: mangler kontantloenn, mangler ogsaa
  // feriepengene og avgiften av den.
  const paaslag = 1 + SATSER.feriepengerPst / 100
  const medPaaslag = (kr0: number) => kr0 * paaslag * (1 + SATSER.agaPst / 100)
  const sykeloennsgap = sisteEa && siste?.avlagt && sisteEa.maaned === siste.maaned
    ? (siste.linjer.find((l) => l.kode === '505')?.regnskap ?? 0)
      - (sisteEa.perKonto['505'] ?? 0)
    : null

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
      {erAdmin && ukjenteKoder.length > 0 && (
        <Status nivaa="handling">
          {`BP-en har ${ukjenteKoder.length} personalkonto(er) som ikke er klassifisert: `}
          {ukjenteKoder.join(', ')}
          {'. Budsjettet under er for lavt til de er tatt stilling til.'}
        </Status>
      )}

      {/* LOENNSROMMET FOERST. Budsjettet forutsetter en brutto som
          kanskje ikke kom; rommet er den samme andelen av det som
          faktisk kom. Er brutto svak, er rommet mindre enn budsjettet -
          og DET er tallet en butikksjef kan handle paa. */}
      {naa && (
        <div className="sq-nokkelrad">
          {/* ===============================================================
              PROSENTEN FOERST, KRONENE UNDER
              ===============================================================
              Her sto kronerommet oeverst, med «Igjen aa bruke» ved siden
              av. Dale juli sto med -298 346 i groent, og det leses som
              «du har 298 000 igjen aa bruke». Det er stikk i strid med
              hvordan tallet skal virke: at brutto ble hoeyere enn planlagt
              gir ikke mer loenn aa bruke - det er ingen opptjent
              rettighet.
              Kontrollen er ANDELEN. Sier BP 52 % i januar, er 52 % det de
              kan bruke; ligger de paa 63, er de over. Det tallet kan ikke
              leses som en invitasjon.
              Kronene staar fortsatt, som underordnet informasjon - de
              trengs for aa vite hvor mye en endring er verdt. */}
          <Nokkeltall
            merkelapp={`Lønn av brutto · ${manedAar.format(new Date(`${naa.maaned}-01`))}`}
            verdi={naaAndel == null ? '—' : enPst(naaAndel * 100)}
            sammenlignet={naa.lonnsandel == null
              ? undefined
              : `budsjettet sier ${enPst(naa.lonnsandel * 100)}`}
            retning={andelsavvik == null ? 'flat' : andelsavvik > 0 ? 'opp' : 'ned'}
            bra={andelsavvik == null ? undefined : andelsavvik <= 0}
          />
          <Nokkeltall
            merkelapp="Brukt så langt"
            verdi={naaBrukt == null ? '—' : kr.format(Math.round(naaBrukt))}
            sammenlignet={naaEa == null
              ? undefined
              : `${naaEa.timer.toLocaleString('nb-NO')} timer`}
          />
          {/* ROMMET ER EN MAALESTOKK, IKKE ET BUDSJETT AA FYLLE OPP.
              Derfor «rommet er» og ikke «igjen aa bruke» - forskjellen
              staar der, men uten et ord som ber noen om aa bruke den. */}
          <Nokkeltall
            merkelapp="Rommet er"
            verdi={naa.romKr == null ? '—' : kr.format(Math.round(naa.romKr))}
            sammenlignet={igjen == null
              ? (naa.anslaatt ? 'brutto er anslått' : 'brutto fra regnskapet')
              : `${igjen < 0 ? 'over med ' : 'under med '}${
                kr.format(Math.abs(Math.round(igjen)))}`}
          />
        </div>
      )}

      {/* HVA ROMMET ER REGNET AV. Et tall uten grunnlag er et tall man
          enten stoler blindt paa eller lar vaere aa lese. */}
      {naa && naa.romKr != null && (
        <p className="undertittel">
          {`Lønnsrommet er ${(naa.lonnsandel! * 100).toLocaleString('nb-NO', {
            minimumFractionDigits: 1, maximumFractionDigits: 1 })} % `}
          {'av bruttofortjenesten — samme andel som budsjettet legger opp til — '}
          {naa.anslaatt
            ? `av en anslått brutto på ${kr.format(Math.round(naa.bruttoKr!))}. `
              + 'Anslaget er BP-ens egen brutto for måneden, skalert med hvor mye av '
              + `salget som har kommet inn (${kr.format(Math.round(naa.omsetningKr))} `
              + 'i omsetning)'
              + (naa.kalibrering != null
                ? `, og justert med ${(naa.kalibrering * 100).toLocaleString('nb-NO', {
                  minimumFractionDigits: 1, maximumFractionDigits: 1 })} % — `
                  + 'hvor mye av planlagt margin stasjonen faktisk treffer. '
                : '. Ingen avlagt måned å kalibrere mot ennå. ')
              + (naa.ekstraSvinnKr > 0
                ? `Svinnet ligger ${kr.format(Math.round(naa.ekstraSvinnKr))} over det `
                  + 'normale, og er trukket fra. Normalt svinn er allerede med i '
                  + 'kalibreringen — regnskapets brutto er fratrukket svinn.'
                : 'Svinnet ligger på det normale, som allerede er med i kalibreringen.')
            : `av regnskapets brutto på ${kr.format(Math.round(naa.bruttoKr!))}.`}
          {/* BIDRAGET NAVNGIS OGSAA HER. Det ligger inne i bruttoen over,
              og et tall som er med uten aa staa noe sted er et tall ingen
              kan etterproeve. */}
          {naa.bilvaskBruttoKr > 0 && (
            ` Av det er ${kr.format(Math.round(naa.bilvaskBruttoKr))} bidrag fra `
            + 'bilvaskabonnementene, som betales rett til konto og aldri går over kassa.'
          )}
        </p>
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

      {/* AARET, MEN LIKE FOR LIKE.
          Sju avlagte maaneder mot tolv budsjetterte gir et avvik paa
          flere hundre tusen som ikke betyr noe. De to bolkene staar
          derfor hver for seg, og hver av dem sier hvor mange maaneder
          den dekker - et sammendrag som ikke sier hva det summerer, er
          et tall man enten stoler blindt paa eller lar vaere aa lese. */}
      {sprikende.length > 0 && (
        <Status nivaa="handling">
          {`St1s månedsbudsjett og BP-en spriker i ${sprikende.length} `}
          {sprikende.length === 1 ? 'måned' : 'måneder'}
          {'. Lønnsrommet regnes av BP-en, så avviket måles mot den — ikke mot '}
          {'tallet i budsjettkolonnen. BP-tallet står på hver rad der de er ulike.'}
        </Status>
      )}

      {aarstall.maaneder > 0 && (
        <Datatabell tittel={`Året ${aar}`} antall={aarstall.maaneder}>
          <thead>
            <tr>
              <th>Periode</th>
              <th>Lønnskost</th>
              <th>Timer</th>
              <th>Svinn</th>
              <th>Budsjett</th>
              <th>Lønnsrom</th>
              <th>Avvik</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>
                {`Hittil i år · ${aarstall.maaneder} avlagt${
                  aarstall.maaneder === 1 ? ' måned' : 'e måneder'}`}
              </td>
              <td><strong>{kr.format(Math.round(aarstall.lonnskostKr))}</strong></td>
              <td>{aarstall.timer > 0 ? aarstall.timer.toLocaleString('nb-NO') : '—'}</td>
              <td>{aarstall.svinnKr > 0 ? kr.format(Math.round(aarstall.svinnKr)) : '—'}</td>
              <td>{kr.format(Math.round(aarstall.budsjettKr))}</td>
              {/* ROMMET SUMMERES BARE OVER DE SAMME MAANEDENE. Mangler
                  det for én av dem, staar avviket tomt heller enn aa
                  maale sju maaneders loenn mot fem maaneders rom. */}
              <td>
                {aarstall.romMaaneder === aarstall.maaneder
                  ? kr.format(Math.round(aarstall.romKr))
                  : `${kr.format(Math.round(aarstall.romKr))} (${aarstall.romMaaneder} mnd)`}
              </td>
              <td>
                {aarsavvik == null ? '—' : (
                  <span className={`status-pip ${aarsavvik > 0 ? 'rod' : 'gronn'}`}>
                    {`${aarsavvik > 0 ? '+' : '−'}${kr.format(Math.abs(Math.round(aarsavvik)))}`}
                  </span>
                )}
              </td>
            </tr>
            {aarstall.bpMaaneder > 0 && (
              <tr>
                <td>{`Hele året etter BP · ${aarstall.bpMaaneder} måneder`}</td>
                <td>—</td>
                <td>—</td>
                <td>—</td>
                <td>{kr.format(Math.round(aarstall.bpHeleAaret))}</td>
                <td>—</td>
                <td>—</td>
              </tr>
            )}
          </tbody>
        </Datatabell>
      )}

      <Datatabell tittel="Per måned" antall={rader.length}>
        <thead>
          <tr>
            <th>Måned</th>
            <th>Lønnskost</th>
            <th>easy@work</th>
            <th>Timer</th>
            <th>Svinn</th>
            <th>Bilvask</th>
            <th>Budsjett</th>
            {/* LOENNSROMMET, IKKE BUDSJETTET, ER DET SOM GJELDER.
                BP-tallet forutsetter en brutto som kanskje ikke kom.
                Begge staar, saa forskjellen er synlig - det er nettopp
                naar de spriker at rommet betyr noe. */}
            <th>Lønnsrom</th>
            {/* ANDELEN VED SIDEN AV KRONENE. Et avvik i kroner sier hvor
                mye; andelen sier om maaneden var innenfor. Den siste er
                den som kan sammenlignes mellom maaneder og stasjoner. */}
            <th>Lønn av brutto</th>
            <th>Avvik</th>
            {erAdmin && <th>Sykelønn</th>}
          </tr>
        </thead>
        <tbody>
          {rader.map((maaned) => {
            const m = maanedPer.get(maaned)
            const ea = eaPerMaaned.get(maaned)
            const r = romPer.get(maaned)
            // ===============================================================
            // SPRIKET MAALES MOT BP-EN SOM FAKTISK BRUKES
            //
            // Her sto `m.bpBudsjettKr`, som kommer fra `bp_kostnad` i
            // regnskapslinjer - og den hopper BP-importen over for hver
            // AVLAGT maaned. Sjekken fyrte derfor aldri naar den trengtes.
            //
            // Malt paa Dale: St1s maanedsbudsjett sto paa 317 869 fra april,
            // mens BP-en sa 625 623. Loennsrommet regnes av BP-en, saa
            // avviket ble et kvart million hver maaned - uten at noe pekte
            // paa hvorfor de to tallene ikke kunne sammenlignes.
            //
            // `r.bpLonnKr` kommer fra 0183 og finnes for HVER maaned.
            // ===============================================================
            const spriker = m?.budsjettKr != null && r?.bpLonnKr != null
              && Math.abs(m.budsjettKr - r.bpLonnKr) >= 1000
            // BRUKT ER REGNSKAPET NAAR DET FINNES, ellers anslaget. Uten
            // det ville den inneVAERENDE maaneden - den eneste som fortsatt
            // kan paavirkes - staatt uten avvik.
            // BUDSJETTET MAA VIRKE FOR BEGGE ROLLER.
            //
            // `m.budsjettKr` kommer fra `bp_linje`, som butikksjefen ikke
            // leser - BP-en er kjedens dokument. `r.bpLonnKr` kommer fra
            // 0183, som gir hver rolle sine egne stasjoner. Uten
            // reserven sto budsjettkolonnen tom for nettopp den rollen
            // sida er bygget for.
            const budsjettKr = m?.budsjettKr ?? r?.bpLonnKr ?? null
            const brukt = m?.avlagt ? m.lonnskostKr : ea?.lonnskostKr ?? null
            const avvikRom = r?.romKr != null && brukt != null ? brukt - r.romKr : null
            // ANDELEN PER RAD, regnet av samme brutto som rommet - saa den
            // og budsjettandelen er sammenlignbare per konstruksjon.
            const radAndel = r?.bruttoKr != null && r.bruttoKr > 0 && brukt != null
              ? brukt / r.bruttoKr
              : null
            const radAndelsavvik = radAndel != null && r?.lonnsandel != null
              ? radAndel - r.lonnsandel
              : null
            return (
              <tr key={maaned}>
                <td>
                  {manedAar.format(new Date(`${maaned}-01`))}
                  {/* Kilden står på hver rad. Et budsjett fra BP-en og et
                      fra St1s månedsrapport svarer på ulike spørsmål. */}
                  {!m?.avlagt && <> <Status nivaa="endring">budsjett</Status></>}
                </td>
                <td>{m?.avlagt ? kr.format(Math.round(m.lonnskostKr)) : '—'}</td>
                {/* ANSLAGET, IKKE FASITEN. Står tomt til fila er lastet
                    opp for måneden — en tom celle er ærligere enn en null. */}
                <td>{ea == null ? '—' : kr.format(Math.round(ea.lonnskostKr))}</td>
                {/* TIMENE ER FRA REGNSKAPET NAAR MAANEDEN ER AVLAGT, ellers
                    fra easy@work. De arbeidede timene er de samme tallene -
                    juli sto 0,10 fra hverandre - saa den aapne maaneden
                    faar et timetall i stedet for en strek. */}
                <td>
                  {m?.timer != null
                    ? m.timer.toLocaleString('nb-NO')
                    : ea != null ? ea.timer.toLocaleString('nb-NO') : '—'}
                </td>
                {/* SVINN HOERER HJEMME HER, ikke bare paa svinnsida.
                    Kastet vare er brutto som aldri ble til noe, og det er
                    nettopp derfor loennsrommet krymper av det. Staar de to
                    tallene fra hverandre, ser man aldri koblingen. */}
                <td>{r == null ? '—' : kr.format(Math.round(r.svinnKr))}</td>
                {/* BIDRAGET MAA NAVNGIS DER DET VIRKER.
                    Uke 35 paa Boenes er 4 860 -> 3 645 i brutto, paa en
                    maanedsbrutto rundt en million. Det flytter rommet en
                    halv prosent - og uten en kolonne som sier hva det er,
                    ser en riktig innlegging ut som ingenting. */}
                <td>
                  {r == null || r.bilvaskBruttoKr === 0
                    ? '—'
                    : kr.format(Math.round(r.bilvaskBruttoKr))}
                </td>
                {/* ÉN BUDSJETTKOLONNE. Spriker St1s månedsbudsjett fra
                    BP-en, sier pipen fra — da er rapporten revidert etter
                    at BP-en ble satt, og det er månedsbudsjettet som
                    gjelder. Ellers er de samme tall og fortjener én celle. */}
                <td>
                  {budsjettKr == null ? '—' : kr.format(Math.round(budsjettKr))}
                  {/* TALLET, IKKE BARE ET MERKE. «≠ BP» sier at de er
                      ulike; det sier ikke hvor mye eller hvilken vei -
                      og det er nettopp forskjellen som er poenget. */}
                  {spriker && (
                    <> <Status nivaa="endring">
                      {`BP: ${kr.format(Math.round(r!.bpLonnKr!))}`}
                    </Status></>
                  )}
                </td>
                {/* LOENNSROMMET. Budsjettet ganget med den brutto maaneden
                    faktisk fikk. Er den anslaatt, staar det paa raden -
                    et anslag som ser ut som en fasit er verre enn ingen. */}
                <td>
                  {r?.romKr == null ? '—' : kr.format(Math.round(r.romKr))}
                  {/* «HITTIL», IKKE «ANSLAG», FOR MAANEDEN VI STAAR I.
                      Rommet foelger omsetningen, og i en maaned som ikke
                      er over dekker den bare dagene som har vaert. Merket
                      «anslag» ved siden av et helmaanedsbudsjett leses som
                      «dette er hva du har til raadighet i september» - og
                      det er ikke det tallet betyr. */}
                  {r?.anslaatt && (
                    <> <Status nivaa="endring">
                      {maaned === naaMaaned ? 'hittil i måneden' : 'anslag'}
                    </Status></>
                  )}
                </td>
                {/* AVVIKET MAALES MOT ROMMET, IKKE MOT BP.
                    BP-tallet forutsetter en brutto som kanskje ikke kom.
                    Uten rommet ville en maaned med svak brutto sett ut som
                    god kostnadsstyring helt til regnskapet kom. */}
                <td>
                  {radAndel == null ? '—' : (
                    <span className={`status-pip ${
                      radAndelsavvik != null && radAndelsavvik > 0 ? 'rod' : 'gronn'}`}>
                      {enPst(radAndel * 100)}
                    </span>
                  )}
                  {r?.lonnsandel != null && (
                    <> <span className="undertittel">
                      {`av ${enPst(r.lonnsandel * 100)}`}
                    </span></>
                  )}
                </td>
                <td>
                  {avvikRom == null ? '—' : (
                    <span className={`status-pip ${avvikRom > 0 ? 'rod' : 'gronn'}`}>
                      {`${avvikRom > 0 ? '+' : '−'}${kr.format(Math.abs(Math.round(avvikRom)))}`}
                    </span>
                  )}
                </td>
                {/* SYKELOENNA MED MAANEDEN DEN KOM FRA. En diagnose, ikke
                    et styringstall - derfor bare for eier. */}
                {erAdmin && (
                  <td>
                    {ea == null || ea.sykelonnFraMaaned == null
                      ? '—'
                      : kr.format(Math.round(ea.perKonto['505'] ?? 0))}
                    {ea?.sykelonnFraMaaned != null && ea.sykelonnFraMaaned !== ea.maaned && (
                      <> <span className="undertittel">
                        {`fra ${manedAar.format(new Date(`${ea.sykelonnFraMaaned}-01`))}`}
                      </span></>
                    )}
                  </td>
                )}
              </tr>
            )
          })}
        </tbody>
      </Datatabell>

      {/* KONTOENE ER EIERENS, IKKE BUTIKKSJEFENS.
          `erLeder()` slipper inn begge, og tabellen var ikke filtrert -
          konto 501 Faste loenninger sto aapen for hvem som helst med
          butikksjefrolle. Paa en stasjon med én fastloennet er den raden
          én persons loenn.
          Butikksjefen trenger aa vite om stasjonen ligger innenfor. Det
          svaret krever ingen kontoer. */}
      {erAdmin && siste && (
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
      {erAdmin && siste && siste.andrePersonalKr !== 0 && (
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
      {erAdmin && ukjenteArter.length > 0 && (
        <Status nivaa="handling">
          {`easy@work-fila har ${ukjenteArter.length} lønnsart(er) uten konto: `}
          {ukjenteArter.join(', ')}
          {'. De er holdt UTENFOR anslaget under, ikke lagt i en bøtte.'}
        </Status>
      )}

      {/* PAAMINNELSEN, OG DEN ER MAALT - IKKE EN INNSTILLING.
          Regnskapskontoret sa at sykeloenna KAN periodiseres om Kelsar
          ber om det. Gjoer de det, oppdager detektoren det selv og denne
          linja forsvinner. Fram til da staar den her hver gang et nytt
          regnskap er lastet opp, som er akkurat naar valget er aktuelt. */}
      {erAdmin && sykelonn.moenster === 'forrige_maaned' && (
        <Status nivaa="endring">
          {`Sykelønna bokføres måneden etter fraværet — målt i ${sykelonn.forsinkede} `}
          {`av ${sykelonn.maalte} måneder som lot seg sammenligne. Kolonnen under `}
          {'viser hvilken måned tallet kom fra. Regnskapskontoret kan periodisere '}
          {'den om du vil ha fraværet i sin egen måned; velger du det, oppdager '}
          {'siden det selv og slutter å flytte.'}
        </Status>
      )}

      {erAdmin && sisteEa && (
        <Datatabell
          tittel={`easy@work · anslag for ${manedAar.format(new Date(`${sisteEa.maaned}-01`))}`}
          antall={5}
        >
          <thead>
            <tr><th>Post</th><th>Kroner</th><th>Grunnlag</th></tr>
          </thead>
          <tbody>
            {/* FASTLOENNA STAAR FOERST OG MED KILDEN SIN.
                Den finnes aldri i easy@work - en fastloennet stempler
                ikke for aa faa betalt - saa den hentes fra regnskapets
                konto 501. Er den baaret fram fra en tidligere maaned, er
                det en antakelse, og den skal staa paa skjermen. */}
            {sisteEa.fastlonnKr > 0 && (
              <tr>
                <td>Fastlønn</td>
                <td>{kr.format(Math.round(sisteEa.fastlonnKr))}</td>
                <td>{sisteEa.fastlonnFraMaaned === sisteEa.maaned
                  ? 'fra regnskapets konto 501'
                  : `båret fram fra ${manedAar.format(
                    new Date(`${sisteEa.fastlonnFraMaaned}-01`))} — fastlønn er fast`}</td>
              </tr>
            )}
            <tr>
              <td>Timelønn og tillegg</td>
              <td>{kr.format(Math.round(sisteEa.perKonto['503'] ?? 0))}</td>
              <td>{`${sisteEa.timer.toLocaleString('nb-NO')} arbeidede timer`}</td>
            </tr>
            <tr>
              <td>Sykelønn</td>
              <td>{kr.format(Math.round(sisteEa.perKonto['505'] ?? 0))}</td>
              {/* MAANEDEN SKAL STAA. Uten den ser tallet ut som maanedens
                  eget, og forskyvningen blir en skjult regel. */}
              <td>{sisteEa.sykelonnFraMaaned == null
                ? 'måneden før mangler i eksporten'
                : `ført i regnskapet måneden etter, fra ${
                  manedAar.format(new Date(`${sisteEa.sykelonnFraMaaned}-01`))}`}</td>
            </tr>
            <tr>
              <td>Kontantlønn</td>
              <td>{kr.format(Math.round(sisteEa.kontantKr))}</td>
              <td>grunnlag for feriepenger og avgift</td>
            </tr>
            <tr>
              <td>{`Feriepenger ${SATSER.feriepengerPst} %`}</td>
              <td>{kr.format(Math.round(sisteEa.feriepengerKr))}</td>
              <td>av kontantlønn</td>
            </tr>
            <tr>
              <td>{`Arbeidsgiveravgift ${SATSER.agaPst} %`}</td>
              <td>{kr.format(Math.round(sisteEa.agaKr))}</td>
              {/* AV LOENN OG FERIEPENGER, IKKE AV PENSJONEN. Konti 540 og
                  541 er nettopp de to. */}
              <td>av lønn og feriepenger</td>
            </tr>
            <tr>
              <td><strong>Anslått lønnskost</strong></td>
              <td><strong>{kr.format(Math.round(sisteEa.lonnskostKr))}</strong></td>
              <td>{eaMotRegnskap == null
                ? 'ingen avlagt måned å måle mot ennå'
                : `regnskapet: ${kr.format(Math.round(siste!.lonnskostKr))}`}</td>
            </tr>
            {/* DIFFERANSEN SKAL STAA PAA SKJERMEN.
                Den sto ikke her foerst, og da maatte noen spoerre hvorfor
                de to tallene ikke var like. Et anslag uten avstanden til
                fasiten er et tall man enten stoler blindt paa eller lar
                vaere aa lese. */}
            {eaMotRegnskap != null && (
              <tr>
                <td>Differanse mot regnskapet</td>
                <td>
                  <span className={`status-pip ${Math.abs(eaMotRegnskap) < 2000 ? 'gronn' : 'gul'}`}>
                    {`${eaMotRegnskap > 0 ? '+' : '−'}${kr.format(Math.abs(Math.round(eaMotRegnskap)))}`}
                  </span>
                </td>
                <td>
                  {sykeloennsgap != null && sykeloennsgap > 1000
                    ? `${kr.format(Math.round(medPaaslag(sykeloennsgap)))} av det er sykelønn `
                      + 'easy@work ikke kan se'
                    : `anslaget er ${eaMotRegnskap > 0 ? 'høyere' : 'lavere'} enn fasiten`}
                </td>
              </tr>
            )}
            {/* PENSJONEN STAAR UNDER SUMMEN, IKKE I DEN.
                St1 foerer OTP som 5945 under konto 590, som denne siden
                holder utenfor loennskosten med vilje. Laa den inne, ville
                anslaget vaert usammenlignbart med regnskapet - og det var
                den fram til 2026-09-07. */}
            <tr>
              <td>{`Pensjon ${SATSER.pensjonPst} % — utenfor lønnskost`}</td>
              <td>{kr.format(Math.round(sisteEa.pensjonKr))}</td>
              <td>OTP fra første krone, føres på konto 590</td>
            </tr>
          </tbody>
        </Datatabell>
      )}

      {sisteEa && (
        <>
        <p className="undertittel">
          {'Anslaget er regnet av lønnsartene i easy@work-eksporten, ikke lest av '}
          {'regnskapet. Hvilken måned sykelønna hører til blir MÅLT, ikke antatt: '}
          {'for hver avlagt måned sammenlignes regnskapets konto 505 med både '}
          {'månedens egen sykelønn og forrige måneds, og den som treffer vinner. '}
          {'På Dale juli 2026 hadde regnskapet 34 830 kroner og easy@works juni '}
          {'34 829,52 — 48 øre fra hverandre. Endrer regnskapsføringen seg, følger '}
          {'siden etter av seg selv; kolonnen sier alltid hvilken måned tallet kom '}
          {'fra, så flyttingen aldri er en skjult regel.'}
        </p>
        <p className="undertittel">
          {'Med den på plass er hele avviket for juli 373 kroner av 441 172, altså '}
          {'0,08 %. Det som gjenstår er '}
          {MANGLER.join('; ')}
          {'. Fastlønn står ikke der lenger: den finnes aldri i easy@work, men '}
          {'regnskapets konto 501 har den, og fastlønn er fast — så sist kjente '}
          {'verdi bæres inn i den åpne måneden, med måneden den kom fra.'}
          {' — og at de faktiske påslagssatsene er 12,16 % feriepenger og 14,00 % '}
          {'avgift, ikke de 12 og 14,1 anslaget regner med. Sykelønn etter dag 16 '}
          {'mangler i eksporten, men mangler i regnskapet også: den betaler NAV.'}
        </p>
        </>
      )}

      {/* HVEM SOM SKAL TELLE, foer skjemaene. En fastloennet i lista
          gjoer hvert eneste tall over feil, saa spoersmaalet hoerer
          hjemme naermere tallene enn en ukentlig innlegging gjoer. */}
      <Lonnsformer
        stasjonId={valgtStasjon!}
        ansatte={ansatte}
        maaned={ansatteMaaned}
      />

      {/* TALLENE INGEN FIL LEVERER, nederst - de brukes én gang i uka,
          mens tallene over leses hver dag. */}
      <ManuelleTall
        stasjonId={valgtStasjon!}
        erAdmin={erAdmin}
        aar={Number(naaMaaned.slice(0, 4))}
        uke={isoUke(new Date())}
        maaned={Number(naaMaaned.slice(5, 7))}
        uker={bilvaskUker}
        maaneder={fastlonnMaaneder}
      />

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
