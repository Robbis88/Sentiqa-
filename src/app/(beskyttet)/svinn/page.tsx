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
import {
  byggMaaned, sammenlignbare, maanederI,
  type Svinnrad, type Dekningsrad, type Maanedsbilde,
} from '@/lib/svinn/maaned'

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
  if (!erLeder(bruker.rolle)) return <p>Du har ikke tilgang til svinn.</p>

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
    .select('stasjon_id, maned, dager_registrert, dager_i_maaned, dager_hittil, siste_registrering, snitt_intervall_dager')
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
      <>
        <Sidehode tittel="Svinn" undertittel="Registrert svinn til kostpris, per måned." />
        {/* En tomtilstand som ikke tilbyr veien videre er en blindvei.
            Lenka til /import laa i den gamle sida; vakthunden fanget at
            den forsvant. */}
        <Tomtilstand
          tittel="Ingen svinndata ennå"
          forklaring="Svinn kommer fra St1-rapport 0452 Varetransaksjonsliste."
          handling={<Knapp><a href="/import">Gå til import</a></Knapp>}
        />
      </>
    )
  }

  const valgtMaaned = sp.maned && maaneder.includes(sp.maned) ? sp.maned : maaneder[0]

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
    <>
      <Sidehode
        tittel="Svinn"
        undertittel={`${erStasjon ? navnFor.get(valgtStasjon!) : 'Alle stasjoner'} · ${manedAar.format(new Date(valgtMaaned))}`}
        handlinger={
          d && !d.komplett
            ? <Status nivaa="endring">Måneden er ikke ferdig</Status>
            : undefined
        }
      />

      {/* PERIODEVELGER, LOKAL OG BEVISST BEGRENSET.
          Svinn taaler maaned, ikke uke - dekningen varierer for mye.
          Kilden bestemmer hva som er gyldig, ikke en felles komponent
          som tilbyr det samme overalt. */}
      <form method="get" className="sq-listetopp">
        {sp.stasjon && <input type="hidden" name="stasjon" value={sp.stasjon} />}
        <label className="felt">
          <span>Måned</span>
          <select name="maned" defaultValue={valgtMaaned}>
            {maaneder.map((m) => (
              <option key={m} value={m}>{manedAar.format(new Date(m))}</option>
            ))}
          </select>
        </label>
        <Knapp type="submit">Vis måneden</Knapp>
      </form>

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

      {/* DEKNINGEN STAAR VED SIDEN AV TALLET, ikke i en fotnote.
          Manglende registrering er ikke null svinn, og uten dette ser
          en stasjon som teller sjelden ut som en som svinner lite. */}
      <Forklaring sporsmaal="Hvor godt er registreringsgrunnlaget?">
        {d
          ? <>
              Svinn ble registrert <strong>{d.registrert} av {d.mulige} dager</strong>
              {d.komplett ? ' i måneden' : ' hittil i måneden'}
              {d.siste && <> · siste registrering {datoLang.format(new Date(`${d.siste}T12:00:00Z`))}</>}
              {/* EN RYTME ER IKKE ET HULL. Stasjonene teller ulikt - noen
                  daglig, noen hver tredje dag, noen sjeldnere. Sies det
                  bare «10 av 31 dager», leses en fast rutine som en
                  forsømmelse, og tallet får en dom det ikke fortjener. */}
              {d.rytme
                ? <> . Tellingene ligger jevnt, omtrent <strong>hver {d.intervall!.toLocaleString('nb-NO', { maximumFractionDigits: 1 })}. dag</strong> — det er en tellerytme, ikke et hull. Månedstallet er likevel hele måneden.</>
                : d.andel < 1 && (
                    <> . Dager uten registrering betyr <strong>ikke</strong> null svinn — de betyr at det ikke ble talt.</>
                  )}
            </>
          : <>Ingen registrerte svinndager denne måneden. Det betyr ikke at det ikke svant noe.</>}
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
                {/* RYTMEN HOERER HJEMME HER. Det er i denne tabellen
                    stasjoner settes ved siden av hverandre, og det er
                    her «12 av 31» mot «29 av 31» ellers ville sett ut
                    som at den ene slurver. */}
                <td>
                  {x.b.dekning
                    ? <>
                        {x.b.dekning.registrert} av {x.b.dekning.mulige}
                        {x.b.dekning.rytme && (
                          <span className="sq-dempet"> · hver {x.b.dekning.intervall!.toLocaleString('nb-NO', { maximumFractionDigits: 1 })}. dag</span>
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
    </>
  )
}
