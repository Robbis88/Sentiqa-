import Link from 'next/link'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { AVDELINGER } from '@/lib/avdelinger'
import { AiKontekst } from '../ai-kontekst'
import { Sidehode, Tomtilstand, Nokkeltall, Datatabell, Forklaring } from '@/components/ui/side'
import { motNormalen, verdtEtBlikk } from '@/lib/salg/normalen'
import { husketStasjon } from '@/lib/stasjonskontekst'
import { stasjonFraUrl, tillatAlleFor } from '@/lib/stasjonsvalg'

const kr = new Intl.NumberFormat('nb-NO', {
  style: 'currency',
  currency: 'NOK',
  maximumFractionDigits: 0,
})
const tall = new Intl.NumberFormat('nb-NO', { maximumFractionDigits: 0 })
const datoFmt = new Intl.DateTimeFormat('nb-NO', { dateStyle: 'long', timeZone: 'Europe/Oslo' })

type StasjonRad = {
  stasjon_id: string
  omsetning: number
  antall: number
  mat_omsetning: number | null
}
type VaregruppeRad = { varegruppe_navn: string | null; omsetning: number; antall: number }

export default async function SalgSide({
  searchParams,
}: {
  searchParams: Promise<{ dato?: string; stasjon?: string }>
}) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) {
    return <p>Du har ikke tilgang til salgsoversikten.</p>
  }

  const supabase = await lagSupabaseServerKlient()
  const sp = await searchParams
  const valgtDato = sp.dato

  // Default: siste dato med data (RLS scoper til brukerens stasjoner)
  let dato = valgtDato && /^\d{4}-\d{2}-\d{2}$/.test(valgtDato) ? valgtDato : null
  if (!dato) {
    const { data } = await supabase
      .from('v_salg_per_stasjon_dag')
      .select('dato')
      .order('dato', { ascending: false })
      .limit(1)
      .maybeSingle<{ dato: string }>()
    dato = data?.dato ?? null
  }

  if (!dato) {
    return (
      <>
        <Sidehode tittel="Salg" undertittel="Omsetning, kategorier og varegrupper." />
        <Tomtilstand
          tittel="Ingen salgsdata ennå"
          forklaring="Last opp en Salgsstatistikk-fil under Import og trykk Behandle, så fylles siden."
          handling={<Link href="/import" className="sq-knapp primar">Gå til Import</Link>}
        />
      </>
    )
  }

  const [{ data: stasjonRader }, { data: stasjoner }] = await Promise.all([
    supabase
      .from('v_salg_per_stasjon_dag')
      .select('stasjon_id, omsetning, antall, mat_omsetning')
      .eq('dato', dato)
      .overrideTypes<StasjonRad[]>(),
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null),
  ])

  // Aatte uker tilbake — nok til at fire like ukedager finnes selv om
  // noen dager mangler. 56 dager x 5 stasjoner er godt under
  const stasjonsliste = (stasjoner ?? []) as { id: string; navn: string; butikknummer: string }[]
  // Stasjonen kommer fra den felles kontrakten (trinn 09): URL foran
  // hukommelse foran forste stasjon. Sida leste for bare `?stasjon=`, og
  // ignorerte dermed valget i toppstripen - skallet kunne vise en stasjon
  // mens tallene her gjaldt alle.
  //
  // `null` betyr fortsatt «alle stasjoner samlet», og at sida TAALER det
  // staar i rutetabellen. Den samme tabellen appskallet leser, saa
  // velgeren tilbyr «Alle stasjoner» noyaktig der den finnes.
  const sok = new URLSearchParams()
  if (sp.stasjon) sok.set('stasjon', sp.stasjon)
  const valgtStasjon = await husketStasjon(
    stasjonsliste, stasjonFraUrl(sok, stasjonsliste),
    tillatAlleFor('/salg', bruker.rolle, stasjonsliste.length),
  )

  // PostgREST-taket paa tusen rader.
  const fraDato = new Date(`${dato}T12:00:00Z`)
  fraDato.setUTCDate(fraDato.getUTCDate() - 56)
  const { data: historikk } = await supabase
    .from('v_salg_per_stasjon_dag')
    .select('stasjon_id, dato, omsetning')
    .gte('dato', fraDato.toISOString().slice(0, 10))
    .lte('dato', dato)

  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))
  const rader = (stasjonRader ?? []).sort((a, b) => b.omsetning - a.omsetning)
  const erStasjon = valgtStasjon != null && navnFor.has(valgtStasjon)
  const valgtNavn = erStasjon ? navnFor.get(valgtStasjon!)! : null
  const valgtRad = erStasjon ? rader.find((r) => r.stasjon_id === valgtStasjon) ?? null : null

  // Salg per AVDELING (kategori) + topp VAREGRUPPER. Begge fra views som
  // aggregerer i databasen. Per stasjon → filtrer på stasjon_id; ellers kjede.
  const avdelingQ = supabase
    .from('v_salg_per_avdeling_dag')
    .select('avdeling_kode, avdeling_navn, omsetning, antall')
    .eq('dato', dato)
  const varegruppeQ = erStasjon
    ? supabase
        .from('v_salg_per_varegruppe_stasjon_dag')
        .select('varegruppe_navn, omsetning, antall')
        .eq('dato', dato)
        .eq('stasjon_id', valgtStasjon!)
        .order('omsetning', { ascending: false })
        .limit(10)
    : supabase
        .from('v_salg_per_varegruppe_dag')
        .select('varegruppe_navn, omsetning, antall')
        .eq('dato', dato)
        .order('omsetning', { ascending: false })
        .limit(10)
  if (erStasjon) avdelingQ.eq('stasjon_id', valgtStasjon!)

  const [{ data: avdData }, { data: vgData }] = await Promise.all([
    avdelingQ.overrideTypes<{ avdeling_kode: string | null; avdeling_navn: string | null; omsetning: number | null; antall: number | null }[]>(),
    varegruppeQ.overrideTypes<VaregruppeRad[]>(),
  ])
  const varegrupper: VaregruppeRad[] = vgData ?? []

  // Avdeling-rader er per (avdeling, stasjon) → summer per avdeling. Pen navn/ikon
  // fra AVDELINGER (St1-kontoplan), fallback til viewets avdeling_navn.
  const pentNavn = new Map(AVDELINGER.map((a) => [a.kode, a.navn]))
  const avdMap = new Map<string, { navn: string; omsetning: number; antall: number }>()
  for (const r of avdData ?? []) {
    const kode = r.avdeling_kode ?? ''
    const a = avdMap.get(kode) ?? { navn: pentNavn.get(kode) ?? r.avdeling_navn ?? kode, omsetning: 0, antall: 0 }
    a.omsetning += r.omsetning ?? 0
    a.antall += r.antall ?? 0
    avdMap.set(kode, a)
  }
  const avdelinger = [...avdMap.entries()]
    .map(([kode, a]) => ({ kode, ...a }))
    .sort((x, y) => y.omsetning - x.omsetning)
  const avdSum = avdelinger.reduce((s, a) => s + a.omsetning, 0)

  // Sammenligningen mot en vanlig ukedag. Per stasjon naar en er valgt,
  // ellers for kjeden samlet - historikken filtreres likt som tallet.
  const histRader = ((historikk ?? []) as { stasjon_id: string; dato: string; omsetning: number }[])
  const perDag = new Map<string, number>()
  for (const h of histRader) {
    if (erStasjon && h.stasjon_id !== valgtStasjon) continue
    perDag.set(h.dato, (perDag.get(h.dato) ?? 0) + Number(h.omsetning ?? 0))
  }

  const totalOms = rader.reduce((a, r) => a + r.omsetning, 0)
  const totalAntall = rader.reduce((a, r) => a + r.antall, 0)

  // SAMMENLIGNINGER SOM FINNES I DATAENE, ikke oppfunnet.
  // Snittbong er omsetning delt paa antall - begge staar allerede i
  // raden. Matandelen likedan. Ingen av dem er et nytt tall; de er det
  // samme tallet sagt slik at det betyr noe.
  const visOms = erStasjon ? (valgtRad?.omsetning ?? 0) : totalOms
  const visAntall = erStasjon ? (valgtRad?.antall ?? 0) : totalAntall
  const snittbong = visAntall > 0 ? Math.round(visOms / visAntall) : null
  const matAndel = erStasjon && (valgtRad?.omsetning ?? 0) > 0
    ? Math.round(((valgtRad?.mat_omsetning ?? 0) / valgtRad!.omsetning) * 100)
    : null
  const mot = motNormalen(
    dato,
    erStasjon ? (valgtRad?.omsetning ?? 0) : totalOms,
    [...perDag].map(([d, o]) => ({ dato: d, omsetning: o })),
  )

  return (
    <>
      <Sidehode
        tittel="Salg"
        undertittel={mot.tekst
          ? `${mot.tekst}. ${datoFmt.format(new Date(dato))} · ${erStasjon ? valgtNavn : 'alle stasjoner samlet'}`
          : `${datoFmt.format(new Date(dato))} · ${erStasjon ? valgtNavn : 'alle stasjoner samlet'}`}
        handlinger={<AiKontekst tekst="Forklar utviklingen" sporsmal="Forklar utviklingen i salget for denne stasjonen den siste tiden. Hva driver den?" />}
      />

      {/* TRE TALL BLE TO.
          «Antall solgt» sto som eget nokkeltall uten noe aa maales mot -
          femten tusen varer er hverken bra eller daarlig for man vet mot
          hva. Tallet er ikke borte: det staar naa som sammenligning paa
          omsetningen, der det svarer paa noe («snittbong»), og i
          kategoritabellen der det kan leses mot omsetningen per rad.

          «Stasjoner med salg» var ikke et resultat, det var en
          opplysning om datagrunnlaget. Den hoerer hjemme i Forklaring
          nederst, ikke i nivaa 1.

          RETNING OG DOM PEKER SAMME VEI HER - salg opp er bra - men de
          settes fortsatt hver for seg, saa /salg og /svinn bruker samme
          spraak selv om dommen faller motsatt. */}
      <div className="sq-nokkelrad">
        <Nokkeltall
          merkelapp="Omsetning eks. mva"
          verdi={kr.format(erStasjon ? (valgtRad?.omsetning ?? 0) : totalOms)}
          sammenlignet={mot.tekst ?? undefined}
          retning={mot.avvikProsent > 0 ? 'opp' : mot.avvikProsent < 0 ? 'ned' : 'flat'}
          bra={verdtEtBlikk(mot) ? mot.avvikProsent > 0 : undefined}
        />
        <Nokkeltall
          merkelapp="Antall solgt"
          verdi={tall.format(erStasjon ? (valgtRad?.antall ?? 0) : totalAntall)}
          sammenlignet={snittbong != null ? `${kr.format(snittbong)} per vare` : undefined}
        />
        {erStasjon && (
          <Nokkeltall
            merkelapp="Matsalg"
            verdi={kr.format(valgtRad?.mat_omsetning ?? 0)}
            sammenlignet={matAndel != null ? `${matAndel} % av omsetningen` : undefined}
          />
        )}
      </div>

      {/* Kortet rundt tabellen var en ramme, ikke et objekt. Datatabell
          gir overskrift, vannrett rulling og tom tilstand - de tre
          tingene hver handskrevne tabell maatte loese selv. */}
      <Datatabell tittel={`Per kategori${erStasjon ? ` · ${valgtNavn}` : ''}`} antall={avdelinger.length}>
          <thead>
            <tr><th>Kategori</th><th>Omsetning</th><th>Antall</th><th>Andel</th></tr>
          </thead>
          <tbody>
            {avdelinger.length === 0 ? (
              <tr><td colSpan={4} className="undertittel">Ingen kategori-salg denne dagen.</td></tr>
            ) : avdelinger.map((a) => (
              <tr key={a.kode}>
                <td>{a.navn}</td>
                <td>{kr.format(a.omsetning)}</td>
                <td>{tall.format(a.antall)}</td>
                <td>{avdSum > 0 ? `${Math.round((a.omsetning / avdSum) * 100)} %` : '—'}</td>
              </tr>
            ))}
          </tbody>
      </Datatabell>

      {!erStasjon && (
        <Datatabell tittel="Per stasjon" antall={rader.length}>
            <thead>
              <tr><th>Stasjon</th><th>Omsetning</th><th>Antall</th><th>Matsalg</th></tr>
            </thead>
            <tbody>
              {rader.map((r) => (
                <tr key={r.stasjon_id}>
                  <td><Link href={`/salg?dato=${dato}&stasjon=${r.stasjon_id}`}>{navnFor.get(r.stasjon_id) ?? '—'}</Link></td>
                  <td>{kr.format(r.omsetning)}</td>
                  <td>{tall.format(r.antall)}</td>
                  <td>{kr.format(r.mat_omsetning ?? 0)}</td>
                </tr>
              ))}
            </tbody>
        </Datatabell>
      )}

      <Datatabell tittel={`Topp varegrupper${erStasjon ? ` · ${valgtNavn}` : ''}`} antall={varegrupper.length}>
          <thead>
            <tr><th>Varegruppe</th><th>Omsetning</th><th>Antall</th></tr>
          </thead>
          <tbody>
            {varegrupper.length === 0 ? (
              <tr><td colSpan={3} className="undertittel">Ingen varegruppe-salg denne dagen.</td></tr>
            ) : varegrupper.map((v, i) => (
              <tr key={i}>
                <td>{v.varegruppe_navn ?? '—'}</td>
                <td>{kr.format(v.omsetning)}</td>
                <td>{tall.format(v.antall)}</td>
              </tr>
            ))}
          </tbody>
      </Datatabell>
      {/* NIVAA 4: grunnlaget. «Stasjoner med salg» sto som nokkeltall -
          det er en opplysning om datagrunnlaget, ikke et resultat, og
          hoerer hjemme her. */}
      <Forklaring sporsmaal="Hva er tallene regnet på?">
        <p>
          {tall.format(rader.length)} {rader.length === 1 ? 'stasjon' : 'stasjoner'} hadde
          salg {datoFmt.format(new Date(dato))}. Omsetningen er eks. mva, og drivstoff
          er holdt utenfor: det betjener seg selv paa pumpa og hoerer ikke med naar
          butikkens tall skal leses.
        </p>
        <p>
          Sammenligningen er mot MEDIANEN for samme ukedag aatte uker tilbake, ikke mot
          snittet. En 17. mai eller en dag med veiarbeid utenfor drar snittet nok til at
          «normalen» blir noe som aldri har skjedd.
        </p>
      </Forklaring>

    </>
  )
}
