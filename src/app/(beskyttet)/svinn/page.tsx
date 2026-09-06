import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { kr, tall, datoLang, manedAar } from '@/lib/format'
import { AiKontekst } from '../ai-kontekst'
import { Sidehode, Tomtilstand, Nokkeltall, Datatabell, Forklaring } from '@/components/ui/side'
import { Status } from '@/components/ui/status'
import { Knapp } from '@/components/ui/knapp'
import { husketStasjon } from '@/lib/stasjonskontekst'
import { stasjonFraUrl, tillatAlleFor } from '@/lib/stasjonsvalg'
import { Maanedsvelger } from '@/components/ui/periode'
import { lesMaaned, maanederI } from '@/lib/periode'
import {
  byggMaaned, sammenlignbare,
  type Svinnrad, type Dekningsrad, type Maanedsbilde,
} from '@/lib/svinn/maaned'
import { Sideramme } from '@/components/ui/sideramme'
import { hentSvinnbudsjett } from '@/lib/svinn/hent-budsjett'

// =====================================================================
// Svinn: kost mot kost, per maaned.
//
// FOER: 30 dagers vindu fra siste registrerte dato, og en prosent som
// var alt svinn delt paa MATsalget. To feil i samme brook - omfanget
// matchet ikke, og enheten matchet ikke. Den beregningen er faglig
// ugyldig og er borte.
//
// NAA: svinn til kostpris delt paa varekost av solgte varer, samme
// stasjon, samme varegruppe, samme maaned. `nettopris_total` ER
// kostpris - produksjonsdata 2026-08-24 viste 97-99 % treff mot
// enhetskost og 0-1,5 % mot utsalgspris.
//
// MAANED, IKKE DAG. Svinn registreres i batcher paa flere stasjoner:
// dekningen varierte fra 34 % til 93 % av dagene. En daglig eller
// ukentlig kurve ville vist tellefrekvens forkledd som utvikling.
//
// «MOT EN VANLIG UKEDAG» ER FJERNET av samme grunn. Den regnet svinn
// mot et snitt av dager - og en dag uten registrering talte som en dag
// uten svinn.
// =====================================================================

type Sok = { stasjon?: string; maned?: string; gruppe?: string }

type Vare = {
  stasjon_id: string
  maned: string
  gruppe_kode: string | null
  ean: string | null
  varenavn: string | null
  svinn_kr: number | null
  svinn_antall: number | null
  dager: number | null
}

/** Kroner, eller en aerlig strek. */
function Kroner({ v }: { v: number | null }) {
  return <>{v == null ? '—' : kr.format(Math.round(v))}</>
}

/**
 * Prosent, eller «ikke maalbart».
 *
 * ALDRI 0 NAAR NEVNEREN MANGLER. Et manglende tall vist som null ser ut
 * som en maaling, og tas for en.
 */
function Prosent({ v }: { v: number | null }) {
  if (v == null) {
    return <span className="sq-dempet" title="Ingen varekost aa maale mot i denne perioden">ikke målbart</span>
  }
  return <>{v.toLocaleString('nb-NO', { minimumFractionDigits: 1, maximumFractionDigits: 1 })} %</>
}

/**
 * Svinnkroner, eller «ikke registrert».
 *
 * EN MAANED MED SALG OG INGEN TELLING GIR 0 KR, og 0 kr ser ut som en
 * god maaned. Den staar i maaned-for-maaned-tabellen rett ved siden av
 * ekte maalinger, og der er forskjellen umulig aa se paa tallet alene.
 */
function SvinnKr({ b }: { b: Maanedsbilde }) {
  if (!b.registrert) {
    return (
      <span className="sq-dempet" title="Ingen svinn ble registrert i perioden">
        ikke registrert
      </span>
    )
  }
  return <Kroner v={b.totalKr} />
}

/** «(1 av 31 mot 2 av 28 dager)», eller ingenting naar tallene mangler. */
function dekningsord(na: Maanedsbilde, for_: Maanedsbilde): string {
  if (!na.dekning || !for_.dekning) return ''
  return ` (${na.dekning.registrert} av ${na.dekning.mulige}`
    + ` mot ${for_.dekning.registrert} av ${for_.dekning.mulige} dager)`
}

export default async function SvinnSide({ searchParams }: { searchParams: Promise<Sok> }) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return <Sideramme><p>Du har ikke tilgang til svinn.</p></Sideramme>

  const sp = await searchParams
  const supabase = await lagSupabaseServerKlient()

  // RLS ER AUTORITETEN. Lista kommer fra `stasjoner`, som gir
  // butikksjefen sine egne og eieren sin kjede. Ingenting her utvider
  // det - stasjonsvalget er en innsnevring, aldri en utvidelse.
  const { data: stasjoner } = await supabase
    .from('stasjoner')
    .select('id, navn, butikknummer')
    .is('slettet_tid', null)
    .order('butikknummer')
    .overrideTypes<{ id: string; navn: string; butikknummer: string }[]>()

  const stasjonsliste = stasjoner ?? []
  const sok = new URLSearchParams()
  if (sp.stasjon) sok.set('stasjon', sp.stasjon)
  const tillatAlle = tillatAlleFor('/svinn', bruker.rolle, stasjonsliste.length)
  const valgtStasjon = await husketStasjon(
    stasjonsliste, stasjonFraUrl(sok, stasjonsliste), tillatAlle,
  )
  const navnFor = new Map(stasjonsliste.map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))
  const erStasjon = valgtStasjon != null && navnFor.has(valgtStasjon)

  // Tretten maaneder: nok til aar mot aar.
  const fra = new Date(Date.UTC(new Date().getUTCFullYear(), new Date().getUTCMonth() - 12, 1))
    .toISOString().slice(0, 10)

  let q = supabase.from('v_svinn_maaned')
    .select('stasjon_id, maned, gruppe_kode, gruppe_navn, koblet, svinn_kr, svinn_antall, svinn_linjer, varekost_kr, omsetning_kr, solgt_antall')
    .gte('maned', fra)
  let qd = supabase.from('v_svinn_dekning')
    .select('stasjon_id, maned, dager_registrert, dager_i_maaned, dager_hittil, siste_registrering, snitt_intervall_dager, storste_linje_kr, storste_linje_varenavn, storste_linje_dato, storste_linje_antall, storste_linje_andel')
    .gte('maned', fra)
  if (erStasjon) {
    q = q.eq('stasjon_id', valgtStasjon!)
    qd = qd.eq('stasjon_id', valgtStasjon!)
  }

  const [{ data: raa }, { data: raaDekning }] = await Promise.all([
    q.limit(20000).overrideTypes<Svinnrad[]>(),
    qd.limit(2000).overrideTypes<Dekningsrad[]>(),
  ])

  const rader = raa ?? []
  const dekningsrader = raaDekning ?? []
  const maaneder = maanederI(rader)

  if (maaneder.length === 0) {
    return (
      <Sideramme>
        <Sidehode tittel="Svinn" undertittel="Registrert svinn til kostpris, per måned." />
        {/* En tomtilstand som ikke tilbyr veien videre er en blindvei.
            Lenka til /import laa i den gamle sida; vakthunden fanget at
            den forsvant. */}
        <Tomtilstand
          tittel="Ingen svinndata ennå"
          forklaring="Svinn kommer fra St1-rapport 0452 Varetransaksjonsliste."
          handling={<Knapp><a href="/import">Gå til import</a></Knapp>}
        />
      </Sideramme>
    )
  }

  // FELLES KONTRAKT: `?maned=2026-03-01`. `lesMaaned` tar imot den gamle
  // formen `?maned=3&ar=2026` ogsaa, saa en bokmerket lenke fra /lonn
  // eller /bemanning treffer riktig maaned i stedet for aa falle stille
  // tilbake. Kilden avgjoer fortsatt hva som er GYLDIG.
  const onsket = lesMaaned(sp, maaneder[0])
  const valgtMaaned = maaneder.includes(onsket) ? onsket : maaneder[0]

  // ÉN DEKNINGSRAD PER STASJON PER MAANED. Ser eieren flere stasjoner,
  // summeres registrerte dager ikke - da ville fem stasjoner med 20
  // dager hver sett ut som 100 av 24 mulige. Den daarligste dekningen
  // er den som avgjoer hvor sikkert bildet kan tolkes.
  const dekningFor = (maned: string): Dekningsrad | undefined => {
    const mine = dekningsrader.filter((d) => d.maned === maned)
    if (mine.length === 0) return undefined
    return mine.reduce((a, b) =>
      (a.dager_registrert / Math.max(1, a.dager_hittil))
      <= (b.dager_registrert / Math.max(1, b.dager_hittil)) ? a : b)
  }

  // KASTBUDSJETTET. Bare for én stasjon: kravet er per stasjon, og en
  // sum over kjeden ville vaert et tall ingen har ansvar for.
  const budsjettbilde = erStasjon
    ? await hentSvinnbudsjett(supabase, valgtStasjon!, Number(valgtMaaned.slice(0, 4)))
    : null

  const bilde = byggMaaned(valgtMaaned, rader, dekningFor(valgtMaaned))
  const forrige = maaneder[maaneder.indexOf(valgtMaaned) + 1]
  const forrigeBilde = forrige ? byggMaaned(forrige, rader, dekningFor(forrige)) : null
  const kanSammenlignes = forrigeBilde
    ? sammenlignbare(bilde.dekning, forrigeBilde.dekning) : false

  // Varenivaa innen valgt kategori. Bare koblede varer kan ligge under
  // en kategori; `?gruppe=ikke-koblet` viser de ukoblede for seg.
  const valgtGruppe = sp.gruppe ?? null
  let varer: Vare[] = []
  {
    let qv = supabase.from('v_svinn_vare_maaned')
      .select('stasjon_id, maned, gruppe_kode, ean, varenavn, svinn_kr, svinn_antall, dager')
      .eq('maned', valgtMaaned)
    // Gruppefilteret er en INNSNEVRING av topplista, ikke en
    // forutsetning for den. Uten valgt gruppe skal brukeren fortsatt se
    // hvilke varer som svinner mest - det var det den gamle sida gjorde,
    // og vakthunden fanget at jeg hadde fjernet det.
    if (valgtGruppe === 'ikke-koblet') qv = qv.is('gruppe_kode', null)
    else if (valgtGruppe) qv = qv.eq('gruppe_kode', valgtGruppe)
    if (erStasjon) qv = qv.eq('stasjon_id', valgtStasjon!)
    const { data } = await qv.limit(5000).overrideTypes<Vare[]>()
    const per = new Map<string, Vare & { kr: number; ant: number }>()
    for (const v of data ?? []) {
      const n = v.ean ?? v.varenavn ?? '?'
      const f = per.get(n) ?? { ...v, kr: 0, ant: 0 }
      f.kr += v.svinn_kr ?? 0
      f.ant += v.svinn_antall ?? 0
      per.set(n, f)
    }
    varer = [...per.values()].sort((a, b) => b.kr - a.kr).slice(0, 20)
      .map((v) => ({ ...v, svinn_kr: v.kr, svinn_antall: v.ant }))
  }

  // PER STASJON, med samme brook som totalen. Eieren skal kunne
  // sammenligne clusteret; butikksjefen med én stasjon ser den ikke.
  const perStasjon = erStasjon ? [] : stasjonsliste
    .map((st) => {
      const b = byggMaaned(
        valgtMaaned,
        rader.filter((r) => r.stasjon_id === st.id),
        dekningsrader.find((d) => d.stasjon_id === st.id && d.maned === valgtMaaned),
      )
      return { navn: `${st.butikknummer} ${st.navn}`, b }
    })
    .filter((x) => x.b.totalKr !== 0 || x.b.varekostKr != null)
    .sort((a, b) => b.b.totalKr - a.b.totalKr)

  const gruppeNavn = valgtGruppe === 'ikke-koblet'
    ? 'Ikke koblet'
    : bilde.kategorier.find((k) => k.kode === valgtGruppe)?.navn ?? valgtGruppe

  const d = bilde.dekning
  const lenke = (p: Partial<Sok>) => {
    const u = new URLSearchParams()
    if (sp.stasjon) u.set('stasjon', sp.stasjon)
    const m = p.maned ?? valgtMaaned
    if (m !== maaneder[0]) u.set('maned', m)
    if (p.gruppe) u.set('gruppe', p.gruppe)
    const s = u.toString()
    return s ? `/svinn?${s}` : '/svinn'
  }

  return (
    <Sideramme>
      <Sidehode
        tittel="Svinn"
        undertittel={`${erStasjon ? navnFor.get(valgtStasjon!) : 'Alle stasjoner'} · ${manedAar.format(new Date(valgtMaaned))}`}
        handlinger={
          d && !d.komplett
            ? <Status nivaa="endring">Måneden er ikke ferdig</Status>
            : undefined
        }
      />

      {/* KILDEN BESTEMMER UTVALGET, velgeren bestemmer formen.
          Svinn taaler maaned, ikke uke - dekningen svinger for mye. */}
      <Maanedsvelger
        maaneder={maaneder}
        valgt={valgtMaaned}
        skjulte={{ stasjon: sp.stasjon, gruppe: sp.gruppe }}
      />

      {/* RETNING OG DOM PEKER HVER SIN VEI HER: svinn opp er ikke bra.
          Samme spraak som /salg, motsatt dom. */}
      <div className="sq-nokkelrad">
        <Nokkeltall
          merkelapp="Svinn totalt"
          verdi={bilde.registrert ? kr.format(Math.round(bilde.totalKr)) : 'ikke registrert'}
          sammenlignet={forrigeBilde && kanSammenlignes
            ? `${kr.format(Math.round(forrigeBilde.totalKr))} i ${manedAar.format(new Date(forrigeBilde.maned))}`
            : undefined}
          retning={forrigeBilde && kanSammenlignes
            ? (bilde.totalKr > forrigeBilde.totalKr ? 'opp'
              : bilde.totalKr < forrigeBilde.totalKr ? 'ned' : 'flat')
            : 'flat'}
          bra={forrigeBilde && kanSammenlignes
            ? bilde.totalKr < forrigeBilde.totalKr
            : undefined}
        />
        <Nokkeltall
          merkelapp="Av varekost solgt"
          verdi={bilde.prosent == null
            ? 'ikke målbart'
            : `${bilde.prosent.toLocaleString('nb-NO', { minimumFractionDigits: 1, maximumFractionDigits: 1 })} %`}
          sammenlignet="svinn til kostpris / varekost solgt"
        />
        <Nokkeltall
          merkelapp="Kategorisert"
          verdi={bilde.kobletAndel == null ? '—' : `${Math.round(bilde.kobletAndel * 100)} %`}
          sammenlignet={bilde.ikkeKobletKr !== 0
            ? `${kr.format(Math.round(bilde.ikkeKobletKr))} ikke koblet`
            : undefined}
        />
      </div>

      {/* KASTBUDSJETTET.
          Staar OEVERST, foer tallene for maaneden: «hvor mye har vi lov
          til» er rammen alt annet leses innenfor. Uten den er svinnet
          bare et tall som gaar opp og ned.

          St1s broek, ikke Sentiqas - se `mot-budsjett.ts`. Derfor staar
          det i teksten hva prosenten er av; ellers ser sida ut til aa
          motsi seg selv to skjermhoeyder ned. */}
      {budsjettbilde && budsjettbilde.total && (
        <section className="kort">
          <div className="sq-seksjon-hode">
            <h2>Kastbudsjett {valgtMaaned.slice(0, 4)}</h2>
            <span className="sq-merkelapp">hittil i år</span>
          </div>

          {/* EN BROEK SOM IKKE KAN REGNES SKAL SI DET, IKKE SVARE LIKEVEL.
              Kastede kroner kan ikke overstige omsetningen. Skjer det, er
              det salgstallet som mangler - og da er BUDSJETTET ogsaa feil,
              siden det er `kast% x salg hittil`. Begge holdes tilbake.
              Sida sto med 778,6 % en hel kveld uten at noe sa fra. */}
          {budsjettbilde.total.nevnerMistenkelig ? (
            <>
              <Status nivaa="kritisk">
                Salgstallet mangler for dette året
              </Status>
              <p className="undertittel">
                {`Det er ført ${kr.format(Math.round(budsjettbilde.total.kastHittilKr))} i kast, `}
                {`men bare ${kr.format(Math.round(budsjettbilde.total.salgHittilKr))} i omsetning. `}
                {'Kast føres til kostpris og salg til utsalgspris, så kastet kan aldri '
                  + 'være størst — her mangler salgsdata. Budsjettet regnes av salget, '
                  + 'så både prosenten og avviket holdes tilbake til tallet er hentet inn.'}
              </p>
            </>
          ) : (
            <>
              <div className="sq-nokkeltall">
                <Nokkeltall
                  merkelapp="Kastet hittil"
                  verdi={kr.format(Math.round(budsjettbilde.total.kastHittilKr))}
                  sammenlignet={`budsjett ${kr.format(Math.round(budsjettbilde.total.budsjettHittilKr))}`}
                />
                <Nokkeltall
                  merkelapp={budsjettbilde.total.avvikKr > 0 ? 'Over budsjett' : 'Under budsjett'}
                  verdi={kr.format(Math.abs(Math.round(budsjettbilde.total.avvikKr)))}
                  retning={budsjettbilde.total.avvikKr > 0 ? 'opp' : 'ned'}
                  bra={budsjettbilde.total.avvikKr <= 0}
                />
                <Nokkeltall
                  merkelapp="Kast av omsetning"
                  verdi={budsjettbilde.total.faktiskPst == null
                    ? '—'
                    : `${(budsjettbilde.total.faktiskPst * 100).toFixed(1)} %`}
                  sammenlignet={`kravet er ${(budsjettbilde.total.linje.kastPstAvSalg * 100).toFixed(1)} %`}
                />
              </div>

              <p className="undertittel">{budsjettbilde.notat}</p>
            </>
          )}

          {/* USYNLIG SVINN — DEN ANDRE HALVDELEN.
              teoretisk brutto - faktisk brutto = synlig + usynlig.
              Kast er det som ble slaatt inn; usynlig er resten: manko,
              feilslag, tyveri, feil pris.

              AVLAGTE MAANEDER ALENE, for BEGGE tallene. Usynlig svinn
              oppstaar per definisjon uten at noen registrerer noe, saa
              det finnes foerst naar maaneden er talt opp. Legges det
              sammen med et kast som ogsaa har inneveaerende maaned,
              dekker de to halvdelene ulike perioder - og totalen blir
              for lav paa en maate ingen ser. */}
          {budsjettbilde.usynlig && (
            <>
              <div className="sq-seksjon-hode">
                <h3>Hele svinnet</h3>
                <span className="sq-merkelapp">
                  {`${budsjettbilde.usynlig.maaneder} avlagte måneder`}
                </span>
              </div>

              <div className="sq-nokkeltall">
                <Nokkeltall
                  merkelapp="Registrert kast"
                  verdi={kr.format(Math.round(budsjettbilde.usynlig.kastAvlagtKr))}
                  sammenlignet="slått inn som kastet"
                />
                <Nokkeltall
                  merkelapp={budsjettbilde.usynlig.usynligKr < 0 ? 'Usynlig overskudd' : 'Usynlig svinn'}
                  verdi={kr.format(Math.abs(Math.round(budsjettbilde.usynlig.usynligKr)))}
                  sammenlignet="manko, feilslag, tyveri"
                  retning={budsjettbilde.usynlig.usynligKr > 0 ? 'opp' : 'ned'}
                  bra={budsjettbilde.usynlig.usynligKr <= 0}
                />
                <Nokkeltall
                  merkelapp="Totalt svinn"
                  verdi={kr.format(Math.round(budsjettbilde.usynlig.totaltKr))}
                  sammenlignet={budsjettbilde.usynlig.tillattSvinnKr == null
                    ? 'kast + usynlig, samme måneder'
                    : `BP tåler ${kr.format(Math.round(budsjettbilde.usynlig.tillattSvinnKr))}`}
                  retning={budsjettbilde.usynlig.avvikMotBpKr == null
                    ? 'flat'
                    : budsjettbilde.usynlig.avvikMotBpKr > 0 ? 'opp' : 'ned'}
                  bra={budsjettbilde.usynlig.avvikMotBpKr == null
                    ? undefined
                    : budsjettbilde.usynlig.avvikMotBpKr <= 0}
                />
              </div>

              <p className="undertittel">
                {budsjettbilde.usynlig.usynligKr < 0
                  ? 'Negativt usynlig svinn er et OVERSKUDD — tellingen fant mer enn '
                    + 'forventet. Det er ikke gratis: det betyr som regel at noe er '
                    + 'ført feil et annet sted. '
                  : 'Usynlig svinn er differansen mellom teoretisk og faktisk brutto '
                    + 'som ingen registrerte — manko, feilslag, tyveri, feil pris. '}
                {budsjettbilde.usynlig.tillattSvinnKr != null
                  ? 'Grensen er BP-en, ikke et eget svinnbudsjett: teoretisk brutto '
                    + `(${kr.format(Math.round(budsjettbilde.usynlig.teoretiskBruttoKr!))}) `
                    + 'minus bruttoen BP-en budsjetterer '
                    + `(${kr.format(Math.round(budsjettbilde.usynlig.bpBruttoKr!))}) `
                    + 'er alt svinnet stasjonen har råd til. Kast og usynlig spiser av '
                    + 'samme brutto, så de deler den grensen.'
                  : 'BP-tall mangler for disse månedene, så det finnes ingen grense å '
                    + 'måle mot ennå.'}
              </p>
            </>
          )}

          {budsjettbilde.linjer.length > 1 && (
            <Datatabell tittel="Per undergruppe" antall={budsjettbilde.linjer.length}>
              <thead>
                <tr>
                  <th>Undergruppe</th><th>Kastet</th><th>Budsjett</th>
                  <th>Avvik</th><th>Kast av oms.</th>
                </tr>
              </thead>
              <tbody>
                {budsjettbilde.linjer.map((l) => (
                  <tr key={l.linje.kode}>
                    <td>{l.linje.navn}</td>
                    <td><Kroner v={l.kastHittilKr} /></td>
                    <td><Kroner v={l.budsjettHittilKr} /></td>
                    <td>
                      {/* Samme pille som regnskapet bruker. En egen
                          fargeklasse for denne ene tabellen ville vaert
                          et sjette sted aa vedlikeholde det samme. */}
                      <span className={`status-pip ${l.avvikKr > 0 ? 'rod' : 'gronn'}`}>
                        <Kroner v={l.avvikKr} />
                      </span>
                    </td>
                    <td>{l.faktiskPst == null ? '—' : `${(l.faktiskPst * 100).toFixed(1)} %`}</td>
                  </tr>
                ))}
              </tbody>
            </Datatabell>
          )}

          <Forklaring sporsmaal="Hvorfor er prosenten en annen enn over?">
            <p>
              St1 regner kastede kroner (kostpris) delt på <strong>omsetning</strong>.
              Tallet lenger nede på siden er kost mot kost — <strong>varekost solgt</strong> i
              nevneren.
            </p>
            <p>
              De måler ulike ting og vil aldri stemme overens. Her brukes St1s brøk,
              fordi det er den budsjettet er uttrykt i: en oppfyllelsesgrad må bruke
              samme brøk som kravet.
            </p>
          </Forklaring>
        </section>
      )}

      {/* DEKNINGEN STAAR VED SIDEN AV TALLET, ikke i en fotnote.
          Manglende registrering er ikke null svinn, og uten dette ser
          en stasjon som teller sjelden ut som en som svinner lite. */}
      <Forklaring sporsmaal="Hvor godt er registreringsgrunnlaget?">
        {d
          ? <>
              Svinn ble registrert <strong>{d.registrert} av {d.mulige} dager</strong>
              {d.komplett ? ' i måneden' : ' hittil i måneden'}
              {d.siste && <> · siste registrering {datoLang.format(new Date(`${d.siste}T12:00:00Z`))}</>}
              {/* SIDA VET IKKE HVORFOR DAGENE ER FÅ, og skal ikke late som.
                  Maten kastes hver dag ved stengetid. Det som varierer er
                  når det blir ført: de fleste fører før de går hjem, noen
                  skriver det ned og butikksjefen fører det dagen etter
                  eller samler opp flere dager. `dato` er transaksjons-
                  datoen fra rapport 0452 — når det ble slått inn, ikke når
                  maten ble kastet. De to årsakene ser like ut her, og
                  forskjellen mellom dem avgjør om månedstallet holder. */}
              {d.andel < 1 && (
                <>
                  {' '}. Maten kastes hver dag, så færre føringsdager betyr
                  enten at noe <strong>ikke ble ført</strong>, eller at flere
                  dager ble <strong>ført samlet</strong>
                  {d.spredt && <> (i snitt {d.intervall!.toLocaleString('nb-NO', { maximumFractionDigits: 1 })} dager mellom føringene)</>}
                  . I det andre tilfellet er månedens kroner de samme; i det
                  første er de for lave. De to kan ikke skilles fra hverandre
                  her.
                </>
              )}
            </>
          : <>Ingen registrerte svinndager denne måneden. Det betyr ikke at det ikke svant noe.</>}

        {/* ÉN LINJE KAN EIE HELE MÅNEDEN, og da måler ikke tallet
            driften. Lone i mai 2026: én linje strøssel til 36 016 kr var
            52 % av stasjonens svinn — 186,61 kr per enhet. Uten den lå
            stasjonen midt i flokken; med den så den ut til å ha et
            problem den ikke hadde.

            INGEN TERSKEL, OG ALLTID SYNLIG. En feilføring er ikke noe
            systemet kan kjenne igjen — 193 stk av noe kan være en ekte
            bulkavskriving, og et filter ville fjernet begge deler i
            stillhet. Er andelen 3 %, er setningen beroligende; er den
            52 %, skriver advarselen seg selv. Leseren avgjør, ikke en
            grense noen fant på. */}
        {d?.storsteLinje && (
          <>
            {' '}Største enkeltlinje er{' '}
            <strong><Kroner v={d.storsteLinje.kr} /></strong>
            {d.storsteLinje.andel != null && (
              <> — {Math.round(d.storsteLinje.andel * 100)} % av måneden</>
            )}
            {d.storsteLinje.varenavn && <> ({d.storsteLinje.varenavn}</>}
            {d.storsteLinje.varenavn && d.storsteLinje.antall != null && (
              <>, {tall.format(Math.round(d.storsteLinje.antall))} stk</>
            )}
            {d.storsteLinje.varenavn && d.storsteLinje.dato && (
              <>, {datoLang.format(new Date(`${d.storsteLinje.dato}T12:00:00Z`))}</>
            )}
            {d.storsteLinje.varenavn && <>)</>}.
          </>
        )}
      </Forklaring>

      {bilde.ikkeKobletKr !== 0 && (
        <Forklaring sporsmaal="Hva er ikke koblet svinn?">
          <strong><Kroner v={bilde.ikkeKobletKr} /></strong> av totalen kunne ikke knyttes til en
          varegruppe. Det er varmmat laget i huset og registrert på produksjonskode, samt
          ingredienser og bulk som kjøpes inn men ikke selges som enhet. Kronene er ekte og
          ligger i totalen — de har bare ingen salgsmotpart å måles mot.
        </Forklaring>
      )}

      <Datatabell tittel="Svinn per varegruppe" antall={bilde.kategorier.length}>
        <thead>
          <tr>
            <th>Varegruppe</th>
            <th>Svinn</th>
            <th>Antall</th>
            <th>Varekost solgt</th>
            <th>Svinn %</th>
          </tr>
        </thead>
        <tbody>
          {bilde.kategorier.map((k) => (
            <tr key={k.kode ?? 'ikke-koblet'}>
              <td>
                <a href={lenke({ gruppe: k.kode ?? 'ikke-koblet' })}>{k.navn}</a>
              </td>
              <td><Kroner v={k.svinnKr} /></td>
              <td>{tall.format(Math.round(k.svinnAntall))}</td>
              <td><Kroner v={k.varekostKr} /></td>
              <td><Prosent v={k.prosent} /></td>
            </tr>
          ))}
        </tbody>
      </Datatabell>

      {perStasjon.length > 0 && (
        <Datatabell tittel={`Per stasjon · ${manedAar.format(new Date(valgtMaaned))}`} antall={perStasjon.length}>
          <thead>
            <tr>
              <th>Stasjon</th><th>Svinn</th><th>Svinn %</th>
              <th>Ikke koblet</th><th>Registrerte dager</th>
            </tr>
          </thead>
          <tbody>
            {perStasjon.map((x) => (
              <tr key={x.navn}>
                <td>{x.navn}</td>
                <td><SvinnKr b={x.b} /></td>
                <td><Prosent v={x.b.prosent} /></td>
                <td><Kroner v={x.b.ikkeKobletKr} /></td>
                {/* AVSTANDEN HOERER HJEMME HER. Det er i denne tabellen
                    stasjoner settes ved siden av hverandre, og «12 av 31»
                    mot «29 av 31» sier ingenting om hvorfor. Snittet er
                    beskrivende, ikke en dom. */}
                <td>
                  {x.b.dekning
                    ? <>
                        {x.b.dekning.registrert} av {x.b.dekning.mulige}
                        {x.b.dekning.spredt && (
                          <span className="sq-dempet"> · {x.b.dekning.intervall!.toLocaleString('nb-NO', { maximumFractionDigits: 1 })} dager mellom</span>
                        )}
                      </>
                    : '—'}
                </td>
              </tr>
            ))}
          </tbody>
        </Datatabell>
      )}

      <Datatabell
        tittel={valgtGruppe ? `Mest svinn (varer) · ${gruppeNavn}` : 'Mest svinn (varer)'}
        antall={varer.length}
      >
        <thead>
          <tr><th>Vare</th><th>Svinn</th><th>Antall</th><th>Dager</th></tr>
        </thead>
        <tbody>
          {varer.map((v) => (
            <tr key={v.ean ?? v.varenavn ?? '?'}>
              <td>{v.varenavn ?? v.ean ?? '—'}</td>
              <td><Kroner v={v.svinn_kr} /></td>
              <td>{tall.format(Math.round(v.svinn_antall ?? 0))}</td>
              <td>{v.dager ?? '—'}</td>
            </tr>
          ))}
        </tbody>
      </Datatabell>

      <Datatabell tittel="Måned for måned" antall={maaneder.length}>
        <thead>
          <tr>
            <th>Måned</th><th>Svinn</th><th>Svinn %</th><th>Registrerte dager</th>
          </tr>
        </thead>
        <tbody>
          {maaneder.map((m) => {
            const b = byggMaaned(m, rader, dekningFor(m))
            return (
              <tr key={m}>
                <td><a href={lenke({ maned: m })}>{manedAar.format(new Date(m))}</a></td>
                <td><SvinnKr b={b} /></td>
                <td><Prosent v={b.prosent} /></td>
                <td>
                  {b.dekning
                    ? `${b.dekning.registrert} av ${b.dekning.mulige}`
                    : '—'}
                </td>
              </tr>
            )
          })}
        </tbody>
      </Datatabell>

      {/* SAMMENLIGNING SOM VET NAAR DEN IKKE HOLDER.
          Er dekningen vidt forskjellig mellom to maaneder, maaler en
          «utvikling» tellevane snarere enn svinn. Da sier vi det i
          stedet for aa vise en pil. */}
      {forrigeBilde && (
        <Forklaring sporsmaal={`Hvordan ligger dette mot ${manedAar.format(new Date(forrigeBilde.maned))}?`}>
          {/* DEKNINGSTALLENE STAAR I BEGGE GRENENE.
              Foerst sto de bare i «ikke sammenlignbar»-grenen, og da
              kunne sida si «grunnlaget er omtrent likt» om to maaneder
              med én og to registrerte dager. Regelen maaler LIKHET, ikke
              om grunnlaget er stort nok - og den forskjellen maa leseren
              kunne se selv. */}
          {kanSammenlignes
            ? <>
                {manedAar.format(new Date(forrigeBilde.maned))}: <SvinnKr b={forrigeBilde} />
                {' · '}<Prosent v={forrigeBilde.prosent} />.
                {' '}Registreringsgrunnlaget er omtrent likt
                {dekningsord(bilde, forrigeBilde)}, så utviklingen kan leses.
              </>
            : <>
                Månedene har ulikt registreringsgrunnlag
                {dekningsord(bilde, forrigeBilde)}
                . En endring mellom dem kan like gjerne være tellevane som svinn, og vises derfor ikke som utvikling.
              </>}
        </Forklaring>
      )}

      <AiKontekst
        tekst="Forklar svinnet denne måneden"
        sporsmal={`Hvordan ligger vi an på svinn i ${manedAar.format(new Date(valgtMaaned))}? Bruk svinn til kostpris mot varekost på solgte varer.`}
      />
    </Sideramme>
  )
}
