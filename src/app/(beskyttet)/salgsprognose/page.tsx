import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { kr, iDag, ramsOpp } from '@/lib/format'
import { AVDELINGER } from '@/lib/avdelinger'
import { leggTilDager, type Vaerdag } from '@/lib/produksjonsplan'
import { lagSalgsprognose, type AvdSalg } from '@/lib/salgsprognose'
import { hentKalibrering } from '@/lib/backtest'
import { hentVaerKoeff } from '@/lib/vaerprofil'
import { erHelligdag, helligdagNavn } from '@/lib/helligdager'
import { husketStasjon } from '@/lib/stasjonskontekst'
import { stasjonFraUrl, tillatAlleFor } from '@/lib/stasjonsvalg'
import { Sidehode, Tomtilstand, Forklaring, Nokkeltall, Datatabell } from '@/components/ui/side'
import { Signal, Status } from '@/components/ui/status'
import Link from 'next/link'

const datoLang = new Intl.DateTimeFormat('nb-NO', { weekday: 'long', day: 'numeric', month: 'long', timeZone: 'Europe/Oslo' })
const UTELAT = new Set(['10', '250', '40']) // drivstoff/pant/CR — ikke butikkdrift

// Signaler bak prognosen. 'live' = i bruk nå, 'kommer' = bygges/venter (lett å
// skru på: bytt status til 'live' når datakilden er på plass).
//
// Sto tidligere som en stripe med emoji-pip nederst på siden. Det gjorde
// metoden til pynt, og ga «kommer»-signalene samme visuelle vekt som de
// som faktisk brukes. Nå er de to setninger i forklaringen.
const SIGNALER: { navn: string; status: 'live' | 'kommer' }[] = [
  { navn: 'vær', status: 'live' },
  { navn: 'helligdager', status: 'live' },
  { navn: 'salgshistorikk år mot år', status: 'live' },
  { navn: 'trend', status: 'live' },
  { navn: 'arrangementer', status: 'live' },
  { navn: 'trafikk (Vegvesenets tellepunkt)', status: 'kommer' },
  { navn: 'drivstoffpriser', status: 'kommer' },
]

export default async function SalgsprognoseSide({ searchParams }: { searchParams: Promise<{ stasjon?: string }> }) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return <p>Salgsprognosen er for eier og butikksjef.</p>
  const sp = await searchParams

  const supabase = await lagSupabaseServerKlient()
  const { data: stasjoner } = await supabase
    .from('stasjoner').select('id, navn, butikknummer, stasjonstype, vaerfolsomhet, vaerfolsomhet_laert').is('slettet_tid', null).order('butikknummer')
    .overrideTypes<{ id: string; navn: string; butikknummer: string; stasjonstype: string; vaerfolsomhet: number | null; vaerfolsomhet_laert: number | null }[]>()
  const liste = stasjoner ?? []
  if (liste.length === 0) {
    return (
      <>
        <Sidehode tittel="Salgsprognose" undertittel="Forventet salg i morgen, per kategori." />
        <Tomtilstand
          tittel="Ingen stasjoner tilgjengelig"
          forklaring="Prognosen regnes per stasjon. Så snart du har tilgang til minst én, ser du den her."
        />
      </>
    )
  }

  // Admin velger fritt; butikksjef er RLS-scopet til egne stasjoner.
  //
  // Prognosen regnes PER STASJON - et snitt over kjeden ville skjult den
  // ene som skiller seg ut - saa `tillatAlleFor` gir false her og sida
  // faar alltid en konkret stasjon. Appskallet leser samme tabell og
  // tilbyr derfor ikke «Alle stasjoner» paa denne ruta.
  const sok = new URLSearchParams()
  if (sp.stasjon) sok.set('stasjon', sp.stasjon)
  const valgtId = await husketStasjon(
    liste, stasjonFraUrl(sok, liste),
    tillatAlleFor('/salgsprognose', bruker.rolle, liste.length),
  ) ?? liste[0].id
  const stasjon = liste.find((s) => s.id === valgtId) ?? liste[0]

  const idag = iDag()
  const maalDato = leggTilDager(idag, 1) // i morgen
  const fjorBase = leggTilDager(maalDato, -364)
  const helligdag = erHelligdag(maalDato)
  const roddagNavn = helligdagNavn(maalDato)

  const [{ data: nylig }, { data: fjor }, { data: vMaal }, { data: vFjor }] = await Promise.all([
    supabase.from('v_salg_per_avdeling_dag').select('dato, avdeling_kode, avdeling_navn, omsetning').eq('stasjon_id', valgtId).gte('dato', leggTilDager(idag, -35)).lte('dato', idag).overrideTypes<{ dato: string; avdeling_kode: string | null; avdeling_navn: string | null; omsetning: number | null }[]>(),
    supabase.from('v_salg_per_avdeling_dag').select('dato, avdeling_kode, avdeling_navn, omsetning').eq('stasjon_id', valgtId).gte('dato', leggTilDager(fjorBase, -28)).lte('dato', leggTilDager(fjorBase, 21)).overrideTypes<{ dato: string; avdeling_kode: string | null; avdeling_navn: string | null; omsetning: number | null }[]>(),
    supabase.from('vaer').select('temp_maks, nedbor_mm').eq('stasjon_id', valgtId).eq('dato', maalDato).maybeSingle<Vaerdag>(),
    supabase.from('vaer').select('temp_maks, nedbor_mm').eq('stasjon_id', valgtId).eq('dato', fjorBase).maybeSingle<Vaerdag>(),
  ])

  const rader = [...(nylig ?? []), ...(fjor ?? [])]
  const salg: AvdSalg[] = rader
    .filter((r) => r.avdeling_kode && !UTELAT.has(r.avdeling_kode))
    .map((r) => ({ dato: r.dato, avdelingKode: r.avdeling_kode!, avdelingNavn: r.avdeling_navn ?? r.avdeling_kode!, omsetning: r.omsetning ?? 0 }))
  const datoer = (nylig ?? []).map((r) => r.dato).sort()
  const sisteSalgsdato = datoer.length ? datoer[datoer.length - 1] : idag

  const vaerKoeff = await hentVaerKoeff(supabase, valgtId, 'avdeling')
  const raaPrognose = salg.length > 0
    ? lagSalgsprognose({ maalDato, sisteSalgsdato, salg, vaerMaal: vMaal ?? null, vaerFjor: vFjor ?? null, vaerfolsomhet: stasjon.vaerfolsomhet_laert ?? stasjon.vaerfolsomhet ?? 0.5, vaerKoeff, stasjonstype: stasjon.stasjonstype, helligdag })
    : null
  // Selvlæring: gang inn korreksjon pr avdeling fra egen treffhistorikk.
  const kalibrering = raaPrognose ? await hentKalibrering(supabase, valgtId, 'salgsprognose') : new Map<string, number>()
  const prognose = raaPrognose
    ? (() => {
        const forslag = raaPrognose.forslag.map((f) => {
          const korr = kalibrering.get(f.kode) ?? 1
          return korr === 1 ? f : { ...f, forventet: Math.max(0, Math.round(f.forventet * korr)) }
        })
        const advarsler = kalibrering.size > 0
          ? [...raaPrognose.advarsler, 'Selvlært kalibrering aktiv — justert mot stasjonens egen treffhistorikk.']
          : raaPrognose.advarsler
        return { ...raaPrognose, forslag, advarsler, totalForventet: forslag.reduce((s, f) => s + f.forventet, 0) }
      })()
    : null

  const navnFor = new Map(AVDELINGER.map((a) => [a.kode, a.navn]))

  // NIVÅ 1 — svaret. Tallet alene sier ingenting om i morgen er en god
  // eller dårlig dag; det er avviket mot en normal ukedag som gjør det.
  const maalTekst = datoLang.format(new Date(`${maalDato}T12:00:00Z`))
  const ukedag = maalTekst.split(' ')[0]
  const avvikPst = prognose
    ? Math.round(((prognose.totalForventet / Math.max(1, prognose.totalBasis)) - 1) * 100)
    : 0
  const svar = prognose && prognose.forslag.length > 0
    ? `${kr.format(prognose.totalForventet)} forventet i morgen, ${avvikPst >= 0 ? '+' : '−'}${Math.abs(avvikPst)} % mot en normal ${ukedag}`
    : null

  // Rødt og vått er kontekst for tallet, ikke en advarsel — derfor i
  // undertittelen og ikke i oppmerksomhetsfeltet.
  const kontekst = [
    `${maalTekst} · ${stasjon.butikknummer} ${stasjon.navn}`,
    roddagNavn ? `${roddagNavn} — prognosen bruker fjorårets samme helligdag` : null,
    vMaal?.temp_maks != null
      ? `varsel ${vMaal.temp_maks.toFixed(0)}°${vMaal.nedbor_mm != null && vMaal.nedbor_mm >= 1 ? `, ${vMaal.nedbor_mm.toFixed(0)} mm regn` : ''}`
      : null,
  ].filter(Boolean).join(' · ')

  return (
    <>
      <Sidehode
        tittel="Salgsprognose"
        undertittel={svar ? `${svar}. ${kontekst}` : kontekst}
      />

      {/* Stasjonsvelgeren staar i toppstripen, ett sted for hele systemet.
          `?stasjon=` bestaar for delte lenker. Se trinn 09. */}

      {!prognose || prognose.forslag.length === 0 ? (
        <Tomtilstand
          tittel="Ikke nok salgshistorikk for denne stasjonen ennå"
          forklaring="Prognosen sammenligner med fjorårets samme ukedag, så den trenger rundt 13 måneder med daglige salgstall før den kan si noe."
          handling={<Link href="/import" className="sq-knapp primar">Gå til Import</Link>}
        />
      ) : (
        <>
          {/* PROGNOSE ER IKKE FAKTA. Begge tallene her er noe systemet
              FORVENTER, ikke noe som har skjedd - og det maa staa, ellers
              leses de som gaardagens resultat.

              Retningen (opp/ned mot en normal dag) og dommen holdes
              fra hverandre: en prognose UNDER normalen er ikke daarlig,
              den er et varsel om en roligere dag. Derfor settes `bra`
              ikke i det hele tatt her - det er ingenting aa felle dom
              over for dagen faktisk er kjort. */}
          <div className="sq-nokkelrad">
            <Nokkeltall
              merkelapp="Forventet omsetning i morgen"
              verdi={kr.format(prognose.totalForventet)}
              sammenlignet="eks. drivstoff og pant"
            />
            <Nokkeltall
              merkelapp={`Mot en normal ${datoLang.format(new Date(`${maalDato}T12:00:00Z`)).split(' ')[0]}`}
              verdi={`${prognose.totalForventet >= prognose.totalBasis ? '+' : '−'}${Math.abs(Math.round(((prognose.totalForventet / Math.max(1, prognose.totalBasis)) - 1) * 100))} %`}
              sammenlignet={`normalen er ${kr.format(prognose.totalBasis)}`}
              retning={prognose.totalForventet > prognose.totalBasis ? 'opp'
                : prognose.totalForventet < prognose.totalBasis ? 'ned' : 'flat'}
            />
          </div>

          {prognose.advarsler.length > 0 && (
            <>
              {/* Motoren returnerer en flat liste og rangerer dem ikke,
                  saa visningen skal ikke finne paa en rangering heller.
                  Samme valg som paa /produksjonsplan. */}
              {prognose.advarsler.map((a, i) => {
                const [tittel, ...resten] = a.split(' \u2014 ')
                return (
                  <Signal key={i} nivaa="informasjon" tittel={tittel}>
                    {resten.length > 0 ? resten.join(' \u2014 ') : undefined}
                  </Signal>
                )
              })}
            </>
          )}

          <Datatabell tittel="Per kategori" antall={prognose.forslag.length}>
              <thead><tr><th>Kategori</th><th>Forventet</th><th>Vær/dag-effekt</th></tr></thead>
              <tbody>
                {prognose.forslag.map((f) => (
                  <tr key={f.kode}>
                    <td>{navnFor.get(f.kode) ?? f.navn}</td>
                    <td>{kr.format(f.forventet)}</td>
                    {/* Vaer- og dageffekten er en RETNING, ikke en dom:
                        varmere vaer som loefter iskrem er hverken bra
                        eller daarlig for dagen er kjort. `endring` er
                        derfor riktig nivaa for begge veier. */}
                    <td>
                      {f.endringPst === 0 ? '—' : (
                        <Status nivaa="endring">
                          {f.endringPst > 0 ? '+' : ''}{f.endringPst} %
                        </Status>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
          </Datatabell>
        </>
      )}

      <Forklaring sporsmaal="Hvordan er prognosen regnet ut?">
        <p>
          Grunnlaget er fjorårets samme ukedag (median ±2 uker), justert med nylig
          trend og værvarselet for i morgen. «Vær/dag-effekt» i tabellen er hvor mye
          vær og ukedag løfter eller demper hver kategori mot en normal dag.
          Drivstoff, pant og CR er holdt utenfor — dette er butikkdrift.
        </p>
        <p>
          Prognosen bruker {ramsOpp(SIGNALER.filter((s) => s.status === 'live').map((s) => s.navn))}.
          {' '}
          {ramsOpp(SIGNALER.filter((s) => s.status === 'kommer').map((s) => s.navn))} er klare å
          koble på når vi avgjør dem, men brukes ikke ennå.
        </p>
        <p>
          Stasjonen kalibrerer seg selv: treffer prognosen skjevt på en kategori over
          tid, korrigeres den mot stasjonens egen treffhistorikk. Er det slått på,
          står det blant meldingene over.
        </p>
      </Forklaring>
    </>
  )
}
