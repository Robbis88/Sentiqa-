import Link from 'next/link'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { kr, tall } from '@/lib/format'
import { Sidehode, Nokkeltall, Datatabell, Forklaring, Tomtilstand } from '@/components/ui/side'
import { Signal } from '@/components/ui/status'
import {
  hentAarganger, hentAarstall, hentPerStasjon, sammenlignbareStasjoner,
} from '@/lib/bp/hent'
import { analyser, royaltyandel, type Funn, type Aarstall } from '@/lib/bp/analyse'

// =====================================================================
// "HVA BETYR DEN NYE BP-EN FOR OSS?"
//
// `/businessplan` svarer paa "ligger vi i rute" - BP mot faktisk, midt i
// aaret. Denne svarer paa noe annet: hva St1 har endret fra en aargang
// til den neste, foer et eneste salg er gjort.
//
//   "naar 2027 skal lastes opp er det greit at vi kan sammenligne og se
//    hva den nye er betydning for oss, gaar vi opp i royalty? faar vi
//    mindre loenn, fastloenn?"  - Robert 2026-08-30
//
// MONSTERET ER "ANALYSE": nivaa 1 er SVARET, som en setning paa norsk.
// Ikke et tall. "886 090 kr" betyr ingenting; "royaltyandelen stiger, og
// det koster 886 090 kr i aaret uten at dere gjoer noe annerledes" betyr
// alt.
//
// ---------------------------------------------------------------------
// SIDA REGNER IKKE
//
// All dom ligger i `analyser()`, som er ren og testet mot Kelsars egne
// tall. Sida velger rekkefoelge og ord. Da kan tallene bevises i en
// vitest, og skjermen kan ikke komme til aa si noe annet enn motoren.
// =====================================================================

export const dynamic = 'force-dynamic'

/**
 * Funnets alvor til signalets nivaa.
 *
 * INGENTING ER "kritisk". `Signal` setter `role="alert"` paa den, og en
 * alert er for noe som nettopp skjedde - ikke for et budsjett som ligger
 * stille paa skjermen. En skjermleser ville avbrutt lesingen for aa
 * melde en royaltysats som har staatt der siden fila ble lastet opp.
 */
function nivaaFor(f: Funn): 'informasjon' | 'mulighet' | 'oppmerksomhet' {
  if (f.dom === 'god') return 'mulighet'
  if (f.dom === 'vond') return 'oppmerksomhet'
  return 'informasjon'
}

function Rad({ merkelapp, fjor, iAar, ar }: {
  merkelapp: string; fjor: number; iAar: number; ar: [number, number]
}) {
  const d = fjor === 0 ? null : (iAar / fjor - 1) * 100
  return (
    <tr>
      <th scope="row">{merkelapp}</th>
      <td className="tall">{kr.format(Math.round(fjor))}</td>
      <td className="tall">{kr.format(Math.round(iAar))}</td>
      <td className="tall">
        {d === null ? '—' : `${d >= 0 ? '+' : '−'}${Math.abs(d).toFixed(1).replace('.', ',')} %`}
      </td>
      <td className="tall">{kr.format(Math.round(iAar - fjor))}</td>
      <td className="sq-skjult">{`${ar[0]} mot ${ar[1]}`}</td>
    </tr>
  )
}

export default async function BpSammenlign(
  { searchParams }: { searchParams: Promise<{ fra?: string; til?: string }> },
) {
  const bruker = await hentInnloggetBruker()
  // Eierens data. BP-en baerer royaltysats, fastloenn og kjedens
  // kostnadsramme - butikksjefen ser sin maanedsramme i `/bemanning`.
  // RLS sier det samme; dette er for at sida ikke skal love noe policyen
  // avviser, som `tilgang.test.ts` leser ut av kilden.
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

  // ÉN AARGANG ER IKKE EN FEIL. En helt ny kjede har nettopp det, og en
  // tom sammenligning ville sett ut som om noe manglet i systemet.
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
  const { med: felles, utelatt } = await sammenlignbareStasjoner(supabase, fraAar, tilAar)
  const [fjor, iAar] = await Promise.all([
    hentAarstall(supabase, fraAar, felles),
    hentAarstall(supabase, tilAar, felles),
  ])

  // Navnene, så siden kan si HVEM som er holdt utenfor. Et antall alene
  // («1 stasjon holdt utenfor») lar leseren gjette, og gjetningen blir
  // som regel feil stasjon.
  const { data: stasjonsrader } = await supabase
    .from('stasjoner').select('id, navn').is('slettet_tid', null)
  const navnFor = new Map(
    ((stasjonsrader ?? []) as { id: string; navn: string }[]).map((s) => [s.id, s.navn]),
  )

  if (!fjor || !iAar || felles.length === 0) {
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

  // PER STASJON. Kjedetotalen sier hva den nye BP-en betyr samlet; den
  // sier ikke hvilken stasjon som baerer endringen. En royaltyandel som
  // stiger like mye paa alle tre er noe helt annet enn en stasjon som
  // drar snittet.
  const [perFjor, perIAar] = await Promise.all([
    hentPerStasjon(supabase, fraAar, felles),
    hentPerStasjon(supabase, tilAar, felles),
  ])
  const stasjonsvis = felles
    .map((id) => ({
      id,
      navn: navnFor.get(id) ?? id,
      a: perFjor.get(id),
      b: perIAar.get(id),
    }))
    .filter((x): x is { id: string; navn: string; a: Aarstall; b: Aarstall } =>
      Boolean(x.a && x.b))
    .sort((x, y) => y.b.salg - x.b.salg)

  const funn = analyser(fjor, iAar)
  const viktigste = funn.find((f) => f.alvor === 'viktig') ?? funn[0]

  const salgspst = fjor.salg === 0 ? null : (iAar.salg / fjor.salg - 1) * 100
  const rf = royaltyandel(fjor)
  const ri = royaltyandel(iAar)

  const rader: [string, number, number][] = [
    ['Salgsmål', fjor.salg, iAar.salg],
    ['Varekost', fjor.varekost, iAar.varekost],
    ['Bruttofortjeneste', fjor.brutto, iAar.brutto],
    ['Lønnsramme', fjor.personal, iAar.personal],
    ['Andre driftskostnader', fjor.andreKostnader, iAar.andreKostnader],
    ['Royalty', fjor.royalty, iAar.royalty],
  ]

  const kategorier = [...new Set([...fjor.kategorier.keys(), ...iAar.kategorier.keys()])]
    .map((kode) => ({
      kode,
      post: iAar.kategorier.get(kode)?.post ?? fjor.kategorier.get(kode)?.post ?? kode,
      f: fjor.kategorier.get(kode)?.salg ?? 0,
      i: iAar.kategorier.get(kode)?.salg ?? 0,
    }))
    .filter((k) => k.f !== 0 || k.i !== 0)
    .sort((a, b) => b.i - a.i)

  return (
    <>
      <Sidehode
        tittel={`BP ${tilAar} mot BP ${fraAar}`}
        merke={
          felles.length === 1
            ? '1 stasjon, samme periode begge år'
            : `${felles.length} stasjoner, samme periode begge år`
        }
        undertittel={viktigste?.tittel}
      />

      {/* Nivaa 1: svaret. Ikke et tall - en setning. */}
      {viktigste && (
        <Signal nivaa={nivaaFor(viktigste)} tittel={viktigste.tittel}>
          {viktigste.betyr}
        </Signal>
      )}

      {/* VELGEREN, og bare naar det finnes noe aa velge.
          To aarganger gir en sammenligning, og da er en velger med ett
          alternativ stoy som ser ut som en kontroll. */}
      {aarganger.length > 2 && (
        <nav className="sq-faner" aria-label="Velg arganger">
          {aarganger.map((a) => a.ar).filter((a) => a !== tilAar).map((a) => (
            <Link
              key={a}
              href={`/businessplan/sammenlign?fra=${Math.min(a, tilAar)}&til=${Math.max(a, tilAar)}`}
              className="sq-fane"
              aria-current={a === fraAar ? 'page' : undefined}
            >
              {`BP ${tilAar} mot ${a}`}
            </Link>
          ))}
        </nav>
      )}

      {/* Nivaa 2: hva som sammenlignes. */}
      <div className="sq-nokkelrad">
        <Nokkeltall
          merkelapp="Salgsmål"
          verdi={kr.format(Math.round(iAar.salg))}
          sammenlignet={salgspst === null ? undefined
            : `${salgspst >= 0 ? '+' : '−'}${Math.abs(salgspst).toFixed(1).replace('.', ',')} % mot BP ${fraAar}`}
          retning={salgspst === null ? 'flat' : salgspst >= 0 ? 'opp' : 'ned'}
        />
        <Nokkeltall
          merkelapp="Lønnsramme"
          verdi={kr.format(Math.round(iAar.personal))}
          sammenlignet={`${kr.format(Math.round(iAar.personal - fjor.personal))} mot BP ${fraAar}`}
          retning={iAar.personal >= fjor.personal ? 'opp' : 'ned'}
          // MER RAMME ER GODT. Timeprisen og timene er begge penger St1
          // legger inn - ikke en kostnad Kelsar baerer.
          bra={iAar.personal >= fjor.personal}
        />
        <Nokkeltall
          merkelapp="Royaltyandel"
          verdi={ri === null ? '—' : `${(ri * 100).toFixed(2).replace('.', ',')} %`}
          sammenlignet={rf === null || ri === null ? undefined
            : `mot ${(rf * 100).toFixed(2).replace('.', ',')} % i BP ${fraAar}`}
          retning={rf === null || ri === null ? 'flat' : ri > rf ? 'opp' : 'ned'}
          bra={rf === null || ri === null ? undefined : ri <= rf}
        />
        <Nokkeltall
          merkelapp="Timeramme"
          verdi={iAar.timer > 0 ? `${tall.format(Math.round(iAar.timer))} t` : 'Ikke i formatet'}
          sammenlignet={fjor.timer > 0 && iAar.timer > 0
            ? `${tall.format(Math.round(iAar.timer - fjor.timer))} t mot BP ${fraAar}` : undefined}
          retning={fjor.timer > 0 && iAar.timer > 0 && iAar.timer >= fjor.timer ? 'opp' : 'flat'}
          bra={fjor.timer > 0 && iAar.timer > 0 ? iAar.timer >= fjor.timer : undefined}
        />
      </div>

      {/* Nivaa 3: funnene, i regnskapsfoererens leserekkefoelge. */}
      {funn.slice(viktigste ? 1 : 0).map((f) => (
        <Signal key={f.id} nivaa={nivaaFor(f)} tittel={f.tittel}>
          {f.maalt} {f.betyr}
        </Signal>
      ))}

      {/* Nivaa 4: tabellene. */}
      <Datatabell tittel="Rammene">
        <thead>
          <tr>
            <th scope="col">Post</th>
            <th scope="col" className="tall">BP {fraAar}</th>
            <th scope="col" className="tall">BP {tilAar}</th>
            <th scope="col" className="tall">Endring</th>
            <th scope="col" className="tall">Kroner</th>
          </tr>
        </thead>
        <tbody>
          {rader.map(([navn, f, i]) => (
            <Rad key={navn} merkelapp={navn} fjor={f} iAar={i} ar={[fraAar, tilAar]} />
          ))}
        </tbody>
      </Datatabell>

      <Datatabell tittel="Salgsmål per varegruppe" antall={kategorier.length}>
        <thead>
          <tr>
            <th scope="col">Varegruppe</th>
            <th scope="col" className="tall">BP {fraAar}</th>
            <th scope="col" className="tall">BP {tilAar}</th>
            <th scope="col" className="tall">Endring</th>
            <th scope="col" className="tall">Kroner</th>
          </tr>
        </thead>
        <tbody>
          {kategorier.map((k) => (
            <Rad key={k.kode} merkelapp={k.post} fjor={k.f} iAar={k.i} ar={[fraAar, tilAar]} />
          ))}
        </tbody>
      </Datatabell>

      {/* PER STASJON. Kjedetotalen sier hva som er endret; den sier ikke
          hvem som bærer det. Én tabell hver — CR og kostnader for den
          stasjonen alene, aldri blandet. */}
      {stasjonsvis.map(({ id, navn, a, b }) => {
        const ra = royaltyandel(a)
        const rb = royaltyandel(b)
        return (
          <Datatabell key={id} tittel={navn}>
            <thead>
              <tr>
                <th scope="col">Post</th>
                <th scope="col" className="tall">BP {fraAar}</th>
                <th scope="col" className="tall">BP {tilAar}</th>
                <th scope="col" className="tall">Endring</th>
                <th scope="col" className="tall">Kroner</th>
              </tr>
            </thead>
            <tbody>
              <Rad merkelapp="Salgsmål" fjor={a.salg} iAar={b.salg} ar={[fraAar, tilAar]} />
              <Rad merkelapp="Bruttofortjeneste" fjor={a.brutto} iAar={b.brutto} ar={[fraAar, tilAar]} />
              <Rad merkelapp="Lønnsramme" fjor={a.personal} iAar={b.personal} ar={[fraAar, tilAar]} />
              <Rad merkelapp="Andre driftskostnader" fjor={a.andreKostnader} iAar={b.andreKostnader} ar={[fraAar, tilAar]} />
              <Rad merkelapp="Royalty" fjor={a.royalty} iAar={b.royalty} ar={[fraAar, tilAar]} />
              <tr>
                <th scope="row">Royaltyandel av omsetning</th>
                <td className="tall">
                  {ra === null ? '—' : `${(ra * 100).toFixed(2).replace('.', ',')} %`}
                </td>
                <td className="tall">
                  {rb === null ? '—' : `${(rb * 100).toFixed(2).replace('.', ',')} %`}
                </td>
                <td className="tall">
                  {ra === null || rb === null
                    ? '—'
                    : `${rb >= ra ? '+' : '−'}${Math.abs((rb - ra) * 100).toFixed(2).replace('.', ',')} pp`}
                </td>
                {/* Kronene her er ikke en differanse, men hva andelen ALENE
                    koster på årets omsetning — det er tallet som betyr noe. */}
                <td className="tall">
                  {ra === null || rb === null ? '—' : kr.format(Math.round((rb - ra) * b.salg))}
                </td>
                <td className="sq-skjult">{`${fraAar} mot ${tilAar}`}</td>
              </tr>
              {a.timer > 0 && b.timer > 0 && (
                <tr>
                  <th scope="row">Timeramme</th>
                  <td className="tall">{tall.format(Math.round(a.timer))} t</td>
                  <td className="tall">{tall.format(Math.round(b.timer))} t</td>
                  <td className="tall">
                    {`${b.timer >= a.timer ? '+' : '−'}${Math.abs((b.timer / a.timer - 1) * 100).toFixed(1).replace('.', ',')} %`}
                  </td>
                  <td className="tall">{tall.format(Math.round(b.timer - a.timer))} t</td>
                  <td className="sq-skjult">{`${fraAar} mot ${tilAar}`}</td>
                </tr>
              )}
            </tbody>
          </Datatabell>
        )
      })}

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
          tallene. Andelen er derimot eksakt, og endringen deles i hvor mye som
          skyldes at dere selger mer og hvor mye som skyldes at andelen selv har
          flyttet seg.
        </p>
        <p>
          <strong>Lønnsrammen</strong> er alle 5000-konti. Den gamle St1-malen
          fører hele lønnen på én konto, mens den nye splitter i timelønn og
          fastlønn — derfor sammenlignes summen, ikke splitten. Hvilket format
          en BP har følger ikke årstallet: for 2025 er Laguneparken, Varden og
          Bønes på den gamle malen mens Dale er på den nye. Timerammen finnes
          bare i noen av filene, så kroner per time vises ikke når en av
          årgangene mangler den.
        </p>
      </Forklaring>
    </>
  )
}
