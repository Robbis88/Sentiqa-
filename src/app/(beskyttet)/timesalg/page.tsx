import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { datoLang } from '@/lib/format'
import { TimesalgKart } from './timesalg-kart'
import Link from 'next/link'
import { Sidehode, Tomtilstand, Nokkeltall, Forklaring } from '@/components/ui/side'
import { husketStasjon } from '@/lib/stasjonskontekst'
import { lesDag } from '@/lib/periode'
import { hentDagvindu, sisteDag } from '@/lib/dagvindu'
import { Dagsvelger } from '@/components/ui/periode'
import { stasjonFraUrl, tillatAlleFor } from '@/lib/stasjonsvalg'
import { kr } from '@/lib/format'
import { Sideramme } from '@/components/ui/sideramme'

type Rad = { stasjon_id: string; time: string; salg: number | null; inne_kunder: number | null; ute_kunder: number | null }

export default async function TimesalgSide({ searchParams }: { searchParams: Promise<{ stasjon?: string; dato?: string }> }) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) {
    return <Sideramme><p>Du har ikke tilgang til timesalg.</p></Sideramme>
  }

  const sp = await searchParams

  const supabase = await lagSupabaseServerKlient()

  // SIDA TOK IKKE IMOT `?dato=` I DET HELE TATT. Datoen var alltid
  // nyeste rad, saa timesalget kunne bare leses for den ene siste dagen -
  // ingen vei tilbake, heller ikke via URL-en. `/salg` hadde i det minste
  // parameteren; her fantes den ikke.
  const nyeste = await sisteDag(supabase, 'timesalg')
  const dato = nyeste ? lesDag(sp, nyeste) : null

  if (!dato) {
    return (
      <Sideramme>
        <Sidehode tittel="Timesalg" undertittel="Når på døgnet pengene kommer inn." />
        <Tomtilstand
          tittel="Ingen timesalgsdata ennå"
          forklaring="Last opp en timesalgsrapport under Import, så ser du døgnet time for time — og hvilke timer som faktisk bærer dagen."
          handling={<Link href="/import" className="sq-knapp primar">Gå til Import</Link>}
        />
      </Sideramme>
    )
  }

  const [{ data: rader }, { data: stasjoner }] = await Promise.all([
    supabase.from('timesalg').select('stasjon_id, time, salg, inne_kunder, ute_kunder').eq('dato', dato).overrideTypes<Rad[]>(),
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null).order('butikknummer'),
  ])

  const medData = (stasjoner ?? []).filter((s) => (rader ?? []).some((r) => r.stasjon_id === s.id))
  // Felles stasjonskontrakt (trinn 09): URL foran hukommelse foran
  // forste stasjon. `null` er «alle stasjoner samlet», og at sida taaler
  // det staar i rutetabellen - samme tabell appskallet leser.
  const sok = new URLSearchParams()
  if (sp.stasjon) sok.set('stasjon', sp.stasjon)
  const valgtStasjon = await husketStasjon(
    medData, stasjonFraUrl(sok, medData),
    tillatAlleFor('/timesalg', bruker.rolle, medData.length),
  )

  const erStasjon = valgtStasjon != null && medData.some((s) => s.id === valgtStasjon)
  const valgtNavn = erStasjon ? medData.find((s) => s.id === valgtStasjon)?.navn ?? null : null

  const stasjonsliste = (erStasjon ? medData.filter((s) => s.id === valgtStasjon) : medData).map((s) => ({ id: s.id, navn: s.navn }))
  const kartRaderAlle = (rader ?? []).map((r) => ({
    stasjon_id: r.stasjon_id,
    time: r.time,
    salg: r.salg ?? 0,
    inne: r.inne_kunder ?? 0,
    ute: r.ute_kunder ?? 0,
  }))
  const kartRader = erStasjon ? kartRaderAlle.filter((r) => r.stasjon_id === valgtStasjon) : kartRaderAlle
  const harInneUte = (rader ?? []).some((r) => r.inne_kunder != null || r.ute_kunder != null)

  // Nivaa 1 paa en analyseside er SVARET, ikke perioden. Her er svaret
  // naar pengene kommer inn - det er derfor man aapner siden.
  // `time` er en STRENG i basen, ikke et tall. Den vises som den er
  // framfor aa regne «time + 1» paa et format vi ikke kjenner.
  const perTime = new Map<string, number>()
  for (const r of kartRader) perTime.set(r.time, (perTime.get(r.time) ?? 0) + r.salg)
  const sortert = [...perTime].sort((a, b) => b[1] - a[1])
  const topp = sortert[0] ? { time: sortert[0][0], salg: sortert[0][1] } : null
  const dagsomsetning = [...perTime.values()].reduce((n, v) => n + v, 0)
  const aktiveTimer = [...perTime.values()].filter((v) => v > 0).length

  // Dagene aa gaa til. Kilden er `timesalg`, ikke salgsstatistikken -
  // rapportene lastes opp hver for seg og har ikke de samme dagene.
  const vindu = await hentDagvindu(supabase, 'timesalg', dato)

  return (
    <Sideramme>
      <Sidehode
        tittel="Timesalg"
        undertittel={topp
          ? `Travlest kl. ${topp.time} med ${kr.format(topp.salg)}. `
            + `${datoLang.format(new Date(dato))} · ${erStasjon ? valgtNavn : 'alle stasjoner'}`
          : `${datoLang.format(new Date(dato))} · ${erStasjon ? valgtNavn : 'alle stasjoner'}`}
      />

      <Dagsvelger
        dag={dato}
        forste={vindu.forste}
        siste={vindu.siste}
        forrige={vindu.forrige}
        neste={vindu.neste}
        skjulte={{ stasjon: erStasjon ? valgtStasjon! : undefined }}
      />

      {topp && (
        <div className="sq-nokkelrad">
          <Nokkeltall merkelapp="Travleste time" verdi={`kl. ${topp.time}`} sammenlignet={kr.format(topp.salg)} />
          <Nokkeltall merkelapp="Hele dagen" verdi={kr.format(dagsomsetning)} sammenlignet={`${aktiveTimer} timer med salg`} />
        </div>
      )}

      {/* Kortet rundt kartet var en ramme rundt hele sidas innhold -
          en beholder som ikke skilte noe fra noe. Kartet ER seksjonen. */}
      <TimesalgKart stasjoner={stasjonsliste} rader={kartRader} harInneUte={harInneUte} />

      <Forklaring sporsmaal="Hva viser døgnkurven?">
        <p>
          Salget per klokketime for {datoLang.format(new Date(dato))}, slik det
          kom inn fra timesalgsrapporten. Timene staar som de er skrevet i kilden -
          «11-12» er kildens egen merking, ikke en omregning.
        </p>
        <p>
          Kunder inne og ute telles hver for seg der kilden skiller dem.
          Bemanningsplanleggeren fordeler timer etter kunder INNE: en bil paa pumpa
          krever ikke folk bak disken.
        </p>
      </Forklaring>
    </Sideramme>
  )
}
