import Link from 'next/link'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { husketStasjon } from '@/lib/stasjonskontekst'
import { stasjonFraUrl, tillatAlleFor } from '@/lib/stasjonsvalg'
import { kr, tall } from '@/lib/format'
import { Sidehode, Nokkeltall, Datatabell, Forklaring, Tomtilstand } from '@/components/ui/side'
import { Signal } from '@/components/ui/status'
import {
  hentAarganger, hentAarstall, hentPerStasjon, sammenlignbareStasjoner,
} from '@/lib/bp/hent'
import {
  analyser, royaltyandel, royaltyEndring, type Funn, type Aarstall,
} from '@/lib/bp/analyse'

// =====================================================================
// "HVA BETYR DEN NYE BP-EN FOR OSS?"
//
// `/businessplan` svarer paa "ligger vi i rute" - BP mot faktisk, midt i
// aaret. Denne svarer paa noe annet: hva St1 har endret fra en aargang
// til den neste, foer et eneste salg er gjort.
//
// ---------------------------------------------------------------------
// FORMEN ER DEN ROBERT GODKJENTE
//
// Foerste utgave av denne sida var noe annet: en liste med "funn" som
// hovedsak, kjedetotal, og ingen stasjonsvelger. Robert sa fra:
//
//   "det var denne her jeg godkjente, ikke litt det du har bygget
//    engang. ka skjedde?"  - 2026-08-31
//
// Han hadde rett. Han ba om en analyse SOM TILLEGG ("hadde vaert goeyt
// om du gjorde en analyse av bpene"), og jeg lot tillegget fortrenge
// demoen. Rekkefoelgen her er demoens:
//
//   1. Fem noekkeltall, med royaltykostnaden foerst
//   2. Kostnader per konto, linje for linje, med NY/BORTE
//   3. CR-salg per varegruppe
//   4. Timer og timekost per stasjon
//   5. Funnene - som tillegg, til slutt
//
// Stasjonsvelgeren er skallets egen (`TAALER_AGGREGAT`), ikke en ny en:
// demoen hadde en nedtrekksliste, men systemet har alt en velger som
// staar samme sted paa hver side.
//
// ---------------------------------------------------------------------
// SIDA REGNER IKKE
//
// All dom ligger i `analyse.ts`, som er ren og testet mot Kelsars egne
// tall. Sida velger rekkefoelge og ord.
// =====================================================================

export const dynamic = 'force-dynamic'

type Stasjon = { id: string; navn: string; butikknummer: string }

function nivaaFor(f: Funn): 'informasjon' | 'mulighet' | 'oppmerksomhet' {
  // INGENTING ER "kritisk": `Signal` setter `role="alert"`, og en alert er
  // for noe som nettopp skjedde - ikke for et budsjett som ligger stille.
  if (f.dom === 'god') return 'mulighet'
  if (f.dom === 'vond') return 'oppmerksomhet'
  return 'informasjon'
}

const pst = (fjor: number, iAar: number): string => {
  if (fjor === 0) return '—'
  const d = (iAar / fjor - 1) * 100
  return `${d >= 0 ? '+' : '−'}${Math.abs(d).toFixed(1).replace('.', ',')} %`
}

/** En linje i en sammenligningstabell: to år, endring, og kroner. */
function Linje({ navn, fjor, iAar, sum = false, enhet = 'kr' }: {
  navn: string; fjor: number | null; iAar: number | null
  sum?: boolean; enhet?: 'kr' | 't'
}) {
  const f = fjor ?? 0
  const i = iAar ?? 0
  const vis = (v: number | null) =>
    v === null ? '—' : enhet === 't' ? `${tall.format(Math.round(v))} t` : kr.format(Math.round(v))
  return (
    <tr className={sum ? 'sum' : undefined}>
      <th scope="row">
        {navn}{' '}
        {/* NY og BORTE staar som ord, ikke som farge alene. En konto som
            forsvant mellom to aar er det letteste aa overse i en lang
            liste, og fargen er borte for den som ikke ser den. */}
        {fjor === null && iAar !== null && <span className="merke-pill">NY</span>}
        {iAar === null && fjor !== null && <span className="merke-pill">BORTE</span>}
      </th>
      <td className="tall">{vis(fjor)}</td>
      <td className="tall">{vis(iAar)}</td>
      <td className="tall">{fjor === null || iAar === null ? '—' : pst(f, i)}</td>
      <td className="tall">{vis(i - f)}</td>
    </tr>
  )
}

function Hode({ forste, fraAar, tilAar }: { forste: string; fraAar: number; tilAar: number }) {
  return (
    <thead>
      <tr>
        <th scope="col">{forste}</th>
        <th scope="col" className="tall">BP {fraAar}</th>
        <th scope="col" className="tall">BP {tilAar}</th>
        <th scope="col" className="tall">Endring</th>
        <th scope="col" className="tall">I kroner</th>
      </tr>
    </thead>
  )
}

export default async function BpSammenlign(
  { searchParams }: { searchParams: Promise<{ fra?: string; til?: string; stasjon?: string }> },
) {
  const bruker = await hentInnloggetBruker()
  // Eierens data. BP-en baerer royaltysats, fastloenn og kjedens
  // kostnadsramme - butikksjefen ser sin maanedsramme i `/bemanning`.
  if (bruker.rolle !== 'retailer_admin') {
    return <p>Kun eier har tilgang til BP-sammenligningen.</p>
  }

  const supabase = await lagSupabaseServerKlient()
  const aarganger = await hentAarganger(supabase)

  if (aarganger.length === 0) {
    return (
      <>
        <Sidehode tittel="Sammenlign BP" />
        <Tomtilstand
          tittel="Ingen BP er lastet inn ennå"
          forklaring={
            'Last opp forretningsplanen fra St1 under Import. '
            + 'Sammenligningen trenger to årganger for å si noe; med én '
            + 'viser vi årets rammer alene.'
          }
          handling={<Link href="/import">Gå til Import</Link>}
        />
      </>
    )
  }

  const sp = await searchParams
  const finnes = new Set(aarganger.map((a) => a.ar))
  const tilAar = Number(sp.til) && finnes.has(Number(sp.til)) ? Number(sp.til) : aarganger[0].ar
  const eldre = aarganger.map((a) => a.ar).filter((a) => a < tilAar)
  const fraAar = Number(sp.fra) && finnes.has(Number(sp.fra)) ? Number(sp.fra) : eldre[0]

  const { data: stasjonsrader } = await supabase
    .from('stasjoner').select('id, navn, butikknummer')
    .is('slettet_tid', null).order('butikknummer')
  const stasjonsliste = (stasjonsrader ?? []) as Stasjon[]
  const navnFor = new Map(stasjonsliste.map((s) => [s.id, s.navn]))

  // ÉN AARGANG ER IKKE EN FEIL. En helt ny kjede har nettopp det.
  if (fraAar === undefined) {
    const alene = await hentAarstall(supabase, tilAar)
    return (
      <>
        <Sidehode
          tittel={`Businessplan ${tilAar}`}
          undertittel="Bare én årgang er lastet inn, så det finnes ingenting å sammenligne mot ennå."
        />
        {alene && (
          <div className="sq-nokkelrad">
            <Nokkeltall merkelapp="Salgsmål" verdi={kr.format(Math.round(alene.salg))} />
            <Nokkeltall merkelapp="Bruttofortjeneste" verdi={kr.format(Math.round(alene.brutto))} />
            <Nokkeltall merkelapp="Lønnsramme" verdi={kr.format(Math.round(alene.personal))} />
            <Nokkeltall merkelapp="Royalty" verdi={kr.format(Math.round(alene.royalty))} />
          </div>
        )}
        <Forklaring sporsmaal="Hvorfor bare ett år?">
          <p>
            Sammenligningen krever to BP-årganger. Neste gang St1 sender en ny,
            stiller siden den mot denne og sier hva som er endret.
          </p>
        </Forklaring>
      </>
    )
  }

  // TO KRAV, BEGGE ARITMETIKK: stasjonen må finnes i begge årganger, og
  // BP-ene må dekke like mange måneder. Se `sammenlignbareStasjoner`.
  const { med: sammenlignbare, utelatt } = await sammenlignbareStasjoner(supabase, fraAar, tilAar)

  // Skallets egen velger, ikke en ny. `TAALER_AGGREGAT` sier at denne
  // siden tåler «alle» for eier; velgeren står samme sted som ellers.
  const sok = new URLSearchParams()
  if (sp.stasjon) sok.set('stasjon', sp.stasjon)
  const valgtStasjon = await husketStasjon(
    stasjonsliste.filter((s) => sammenlignbare.includes(s.id)),
    stasjonFraUrl(sok, stasjonsliste),
    tillatAlleFor('/businessplan/sammenlign', bruker.rolle, sammenlignbare.length),
  )
  const valgte = valgtStasjon && sammenlignbare.includes(valgtStasjon)
    ? [valgtStasjon]
    : sammenlignbare

  const [fjor, iAar] = await Promise.all([
    hentAarstall(supabase, fraAar, valgte),
    hentAarstall(supabase, tilAar, valgte),
  ])

  if (!fjor || !iAar || valgte.length === 0) {
    return (
      <>
        <Sidehode tittel="Sammenlign BP" />
        <Tomtilstand
          tittel={`Ingen stasjon kan sammenlignes mellom ${fraAar} og ${tilAar}`}
          forklaring={
            utelatt.length > 0
              ? `${utelatt.map((u) => navnFor.get(u.stasjonId) ?? u.stasjonId).join(', ')} `
                + 'har BP-er som dekker ulikt antall måneder i de to årene. '
                + 'Stilt mot hverandre ville forskjellen vært kalender, ikke drift.'
              : 'Sammenligningen bruker bare stasjoner som er med i begge '
                + 'årganger. Ellers ville et oppkjøp blitt målt som vekst.'
          }
        />
      </>
    )
  }

  const [perFjor, perIAar] = await Promise.all([
    hentPerStasjon(supabase, fraAar, valgte),
    hentPerStasjon(supabase, tilAar, valgte),
  ])

  const funn = analyser(fjor, iAar)
  const roy = royaltyEndring(fjor, iAar)
  const rf = royaltyandel(fjor)
  const ri = royaltyandel(iAar)

  // KONTI OG VAREGRUPPER, LINJE FOR LINJE. `null` betyr «fantes ikke
  // dette året» — og det er noe helt annet enn 0 kr, som betyr «budsjettert
  // til null». Linje-komponenten merker dem NY og BORTE.
  const konti = [...new Set([...fjor.konti.keys(), ...iAar.konti.keys()])]
    .map((kode) => ({
      kode,
      post: iAar.konti.get(kode)?.post ?? fjor.konti.get(kode)?.post ?? kode,
      f: fjor.konti.has(kode) ? fjor.konti.get(kode)!.kr : null,
      i: iAar.konti.has(kode) ? iAar.konti.get(kode)!.kr : null,
    }))
    .sort((a, b) => (b.i ?? b.f ?? 0) - (a.i ?? a.f ?? 0))

  const grupper = [...new Set([...fjor.kategorier.keys(), ...iAar.kategorier.keys()])]
    .map((kode) => ({
      kode,
      post: iAar.kategorier.get(kode)?.post ?? fjor.kategorier.get(kode)?.post ?? kode,
      f: fjor.kategorier.has(kode) ? fjor.kategorier.get(kode)!.salg : null,
      i: iAar.kategorier.has(kode) ? iAar.kategorier.get(kode)!.salg : null,
    }))
    .filter((k) => k.f !== 0 || k.i !== 0)
    .sort((a, b) => (b.i ?? b.f ?? 0) - (a.i ?? a.f ?? 0))

  const timerader = valgte
    .map((id) => ({ id, navn: navnFor.get(id) ?? id, a: perFjor.get(id), b: perIAar.get(id) }))
    .filter((x): x is { id: string; navn: string; a: Aarstall; b: Aarstall } => Boolean(x.a && x.b))
    .sort((x, y) => y.b.salg - x.b.salg)
  const harTimer = fjor.timer > 0 && iAar.timer > 0

  const hvem = valgte.length === 1
    ? (navnFor.get(valgte[0]) ?? '')
    : valgte.map((id) => navnFor.get(id) ?? id).join(', ')

  return (
    <>
      <Sidehode
        tittel={`BP ${tilAar} mot BP ${fraAar}`}
        merke={hvem}
        undertittel={
          valgte.length === 1
            ? undefined
            : `${valgte.length} stasjoner med BP for like mange måneder i begge år`
        }
      />

      {/* NIVÅ 1: fem tall, med royaltykostnaden først. Den er den eneste
          som er avtalt og ikke kan jobbes inn. */}
      <div className="sq-nokkelrad">
        <Nokkeltall
          merkelapp="Royaltyandelen koster"
          verdi={roy ? kr.format(Math.round(roy.sats)) : '—'}
          sammenlignet={rf !== null && ri !== null
            ? `${(rf * 100).toFixed(2).replace('.', ',')} % → ${(ri * 100).toFixed(2).replace('.', ',')} % av omsetningen`
            : undefined}
          retning={roy && roy.sats > 0 ? 'opp' : roy && roy.sats < 0 ? 'ned' : 'flat'}
          bra={roy ? roy.sats <= 0 : undefined}
        />
        <Nokkeltall
          merkelapp="Timer"
          verdi={harTimer ? `${tall.format(Math.round(iAar.timer))} t` : 'Ikke i BP-en'}
          sammenlignet={harTimer
            ? `${pst(fjor.timer, iAar.timer)} · ${tall.format(Math.round(iAar.timer - fjor.timer))} timer`
            : `BP ${fraAar} har ikke timebudsjett`}
          retning={harTimer && iAar.timer >= fjor.timer ? 'opp' : 'flat'}
          // TIMENE ER NOE ST1 GIR DERE. Flere timer er mer ramme, ikke
          // en høyere kostnad.
          bra={harTimer ? iAar.timer >= fjor.timer : undefined}
        />
        <Nokkeltall
          merkelapp="Kr per time"
          verdi={harTimer ? kr.format(Math.round(iAar.personal / iAar.timer)) : '—'}
          sammenlignet={harTimer
            ? `${pst(fjor.personal / fjor.timer, iAar.personal / iAar.timer)} mot BP ${fraAar}`
            : undefined}
          retning={harTimer && iAar.personal / iAar.timer >= fjor.personal / fjor.timer ? 'opp' : 'flat'}
          // «det er posetivt om vi får høyere timepris pr time på lønn,
          //  for det er det st1 gir oss» — Robert 2026-08-30
          bra={harTimer ? iAar.personal / iAar.timer >= fjor.personal / fjor.timer : undefined}
        />
        <Nokkeltall
          merkelapp="Salgsmål"
          verdi={kr.format(Math.round(iAar.salg))}
          sammenlignet={`${pst(fjor.salg, iAar.salg)} mot BP ${fraAar}`}
          retning={iAar.salg >= fjor.salg ? 'opp' : 'ned'}
        />
        <Nokkeltall
          merkelapp="Kostnadsramme"
          verdi={kr.format(Math.round(iAar.personal + iAar.andreKostnader))}
          sammenlignet={`${pst(fjor.personal + fjor.andreKostnader, iAar.personal + iAar.andreKostnader)} mot BP ${fraAar}`}
          retning={
            iAar.personal + iAar.andreKostnader >= fjor.personal + fjor.andreKostnader ? 'opp' : 'ned'
          }
        />
      </div>

      <Datatabell
        tittel={`Kostnader per konto · ${valgte.length === 1 ? hvem : 'alle valgte samlet'}`}
        antall={konti.length}
      >
        <Hode forste="Konto" fraAar={fraAar} tilAar={tilAar} />
        <tbody>
          {konti.map((k) => (
            <Linje key={k.kode} navn={k.post} fjor={k.f} iAar={k.i} />
          ))}
        </tbody>
        <tfoot>
          <Linje
            navn="Sum"
            fjor={fjor.personal + fjor.andreKostnader}
            iAar={iAar.personal + iAar.andreKostnader}
            sum
          />
        </tfoot>
      </Datatabell>

      <Datatabell
        tittel={`CR-salg per varegruppe · ${valgte.length === 1 ? hvem : 'alle valgte samlet'}`}
        antall={grupper.length}
      >
        <Hode forste="Varegruppe" fraAar={fraAar} tilAar={tilAar} />
        <tbody>
          {grupper.map((g) => (
            <Linje key={g.kode} navn={g.post} fjor={g.f} iAar={g.i} />
          ))}
        </tbody>
        <tfoot>
          <Linje navn="Sum" fjor={fjor.salg} iAar={iAar.salg} sum />
        </tfoot>
      </Datatabell>

      <Datatabell tittel="Timer og timekost" antall={timerader.length}>
        <thead>
          <tr>
            <th scope="col">Stasjon</th>
            <th scope="col" className="tall">Timer {fraAar}</th>
            <th scope="col" className="tall">Timer {tilAar}</th>
            <th scope="col" className="tall">Endring</th>
            <th scope="col" className="tall">Kr/time {fraAar}</th>
            <th scope="col" className="tall">Kr/time {tilAar}</th>
            <th scope="col" className="tall">Endring</th>
            <th scope="col" className="tall">Lønnsramme</th>
          </tr>
        </thead>
        <tbody>
          {timerader.map(({ id, navn, a, b }) => {
            const kan = a.timer > 0 && b.timer > 0
            return (
              <tr key={id}>
                <th scope="row">{navn}</th>
                <td className="tall">{a.timer > 0 ? `${tall.format(Math.round(a.timer))}` : '—'}</td>
                <td className="tall">{b.timer > 0 ? `${tall.format(Math.round(b.timer))}` : '—'}</td>
                <td className="tall">{kan ? pst(a.timer, b.timer) : '—'}</td>
                <td className="tall">{a.timer > 0 ? kr.format(Math.round(a.personal / a.timer)) : '—'}</td>
                <td className="tall">{b.timer > 0 ? kr.format(Math.round(b.personal / b.timer)) : '—'}</td>
                <td className="tall">
                  {kan ? pst(a.personal / a.timer, b.personal / b.timer) : '—'}
                </td>
                <td className="tall">{pst(a.personal, b.personal)}</td>
              </tr>
            )
          })}
          {timerader.length > 1 && (
            <tr className="sum">
              <th scope="row">Sum</th>
              <td className="tall">{fjor.timer > 0 ? tall.format(Math.round(fjor.timer)) : '—'}</td>
              <td className="tall">{iAar.timer > 0 ? tall.format(Math.round(iAar.timer)) : '—'}</td>
              <td className="tall">{harTimer ? pst(fjor.timer, iAar.timer) : '—'}</td>
              <td className="tall">
                {fjor.timer > 0 ? kr.format(Math.round(fjor.personal / fjor.timer)) : '—'}
              </td>
              <td className="tall">
                {iAar.timer > 0 ? kr.format(Math.round(iAar.personal / iAar.timer)) : '—'}
              </td>
              <td className="tall">
                {harTimer ? pst(fjor.personal / fjor.timer, iAar.personal / iAar.timer) : '—'}
              </td>
              <td className="tall">{pst(fjor.personal, iAar.personal)}</td>
            </tr>
          )}
        </tbody>
      </Datatabell>

      {/* TILLEGGET, og det står sist. «hadde vært gøyt om du gjorde en
          analyse av bpene, gir noen tilbakemeldinger på hva det betyr for
          oss når den lastes opp» — Robert 2026-08-30. Tallene over er
          svaret; dette er hva de betyr. */}
      {funn.length > 0 && (
        <section>
          <h2>Hva tallene betyr</h2>
          {funn.map((f) => (
            <Signal key={f.id} nivaa={nivaaFor(f)} tittel={f.tittel}>
              {f.maalt} {f.betyr}
            </Signal>
          ))}
        </section>
      )}

      <Forklaring sporsmaal="Hvordan er tallene regnet?">
        <p>
          Sammenligningen bruker bare stasjoner som finnes i begge årganger
          <strong> og som har BP for like mange måneder</strong>. Ellers ville
          et oppkjøp blitt målt som vekst, eller en kortere budsjettperiode
          blitt lest som en svakere plan.
        </p>
        {utelatt.length > 0 && (
          <p>
            Holdt utenfor:{' '}
            {utelatt.map((u) => (
              `${navnFor.get(u.stasjonId) ?? u.stasjonId} (${u.fjor} mnd i ${fraAar} mot ${u.iAar} i ${tilAar})`
            )).join(', ')}.
          </p>
        )}
        <p>
          <strong>Royaltyandelen</strong> er royalty delt på CR-salg. Den ordinære
          satsen står ikke i filene og lar seg ikke regne ut av dem: vaskedelen er
          korrigert for appens andel, og den korreksjonen finnes ingen steder i
          tallene. Andelen er derimot eksakt, og «koster»-tallet er den delen av
          royaltyøkningen som skyldes at <em>andelen selv</em> har flyttet seg —
          ikke at dere selger mer.
        </p>
        <p>
          <strong>Lønnsrammen</strong> er alle 5000-konti. Den gamle St1-malen
          fører hele lønnen på én konto, mens den nye splitter i timelønn og
          fastlønn — derfor sammenlignes summen, ikke splitten. Hvilket format
          en BP har følger ikke årstallet: for 2025 er Laguneparken, Varden og
          Bønes på den gamle malen mens Dale er på den nye.
        </p>
        <p>
          <strong>Timerammen</strong> finnes bare i det nye formatet. Mangler den
          i én av årgangene, står kroner per time som «—» i stedet for et tall vi
          ikke kan belegge.
        </p>
      </Forklaring>
    </>
  )
}
