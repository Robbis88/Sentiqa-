import Link from 'next/link'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { kr, manedAar } from '@/lib/format'
import { Sidehode, Datatabell, Tomtilstand, Forklaring } from '@/components/ui/side'
import { Status } from '@/components/ui/status'
import { Sideramme } from '@/components/ui/sideramme'
import { hentKilder } from '@/lib/lonnskost/kilder'
import { hentAvtaler } from '@/lib/lonnskost/avtale'
import { a1ForStasjonsmaaned, type Vurdertrad } from '@/lib/lonnskost/a1'
import { utfallstekst, KILDEMANGEL, FORBEHOLD_KORT } from '@/lib/lonnskost/a1-sprak'

// =====================================================================
// VAKTENE BAK TALLET
//
// Fra «minst 143 889 kr» til «ansatt 1004, 68 timer» til de ti
// konkrete vaktene. Revisjonskjeden, i brukerens språk.
//
// ---------------------------------------------------------------------
// HELE KJEDEN VISES, IKKE BARE DET UPRISEDE
//
// Bevaringen i motoren garanterer at listen dekker hvert eneste betalte
// minutt. Viste vi bare det upriste, ville siden ikke kunne svare på
// «hvor ble resten av timene av» — og da er den ikke en revisjonskjede,
// bare en feilliste.
//
// Personer med upriset arbeid står først. Det er der handlingen er.
//
// ---------------------------------------------------------------------
// TILGANGEN ER SERVERENS
//
// `erLeder` stenger nettbrett og plattformredaktør. RLS på `stasjoner`
// gir det autoriserte settet, og en stasjon utenfor det finnes ikke i
// lista — siden filtrerer ingenting selv.
// =====================================================================

export const dynamic = 'force-dynamic'

type Sok = Promise<{ stasjon?: string; maned?: string }>

const MAANED = /^\d{4}-(0[1-9]|1[0-2])$/

const timer = new Intl.NumberFormat('nb-NO', {
  minimumFractionDigits: 1, maximumFractionDigits: 1,
})

/** Vaktene til én person, sortert med det upriste først. */
type Person = {
  ansattNr: string
  navn: string
  rader: Vurdertrad[]
  betalteMinutter: number
  uprisedeMinutter: number
  belopKr: number
}

export default async function ArbeidsstedSide({ searchParams }: { searchParams: Sok }) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) {
    return <Sideramme><p>Du har ikke tilgang til lønnskost.</p></Sideramme>
  }

  const sp = await searchParams
  const supabase = await lagSupabaseServerKlient()

  // RLS avgjør settet. Er stasjonen ikke her, finnes den ikke for denne
  // brukeren — og vi sier «ikke funnet», ikke «ikke tilgang», fordi det
  // siste ville bekreftet at den eksisterer.
  const { data: stasjoner } = await supabase
    .from('stasjoner')
    .select('id, navn, butikknummer')
    .is('slettet_tid', null)
    .order('butikknummer')
    .overrideTypes<{ id: string; navn: string; butikknummer: string }[]>()

  const valgt = (stasjoner ?? []).find((s) => s.id === sp.stasjon)
  const maaned = sp.maned && MAANED.test(sp.maned) ? sp.maned : null

  if (!valgt || !maaned) {
    return (
      <Sideramme>
        <Sidehode tittel="Vaktene bak tallet" />
        <Tomtilstand
          tittel="Fant ikke stasjonen eller måneden"
          forklaring={
            'Siden åpnes fra lønnskost, som sender med hvilken stasjon og '
            + 'måned du så på.'
          }
          handling={<Link href="/lonnskost">Til lønnskost</Link>}
        />
      </Sideramme>
    )
  }

  const kilder = await hentKilder(supabase, valgt.id, maaned)
  const avtale = await hentAvtaler(supabase, [valgt.id])
  const ut = a1ForStasjonsmaaned(kilder, avtale)
  const tittel = `${valgt.butikknummer} ${valgt.navn} · ${manedAar.format(new Date(`${maaned}-01`))}`

  if (ut.status === 'kildemangel') {
    const k = ut.kilde
    const hva = k.status === 'mangler_register' ? 'register'
      : k.status === 'mangler_arbeidstid' ? 'arbeidstid' : 'begge'
    return (
      <Sideramme>
        <Sidehode tittel="Vaktene bak tallet" merke={tittel} />
        <Tomtilstand
          tittel="Kan ikke beregnes"
          forklaring={KILDEMANGEL[hva]}
          handling={<Link href="/lonnskost">Tilbake</Link>}
        />
      </Sideramme>
    )
  }

  // Grupper HELE kjeden per person — ikke bare det upriste.
  const per = new Map<string, Person>()
  for (const v of ut.rader) {
    const p = per.get(v.rad.ansattNr) ?? {
      ansattNr: v.rad.ansattNr, navn: v.rad.ansattNavn, rader: [],
      betalteMinutter: 0, uprisedeMinutter: 0, belopKr: 0,
    }
    p.rader.push(v)
    if (v.utfall.slag !== 'ubetalt') p.betalteMinutter += v.rad.minutter
    if (v.utfall.slag === 'upriset') p.uprisedeMinutter += v.rad.minutter
    if (v.utfall.slag === 'priset') p.belopKr = Math.round((p.belopKr + v.utfall.belopKr) * 100) / 100
    per.set(v.rad.ansattNr, p)
  }
  // Upriset arbeid først — der er handlingen.
  const personer = [...per.values()].sort((a, b) =>
    b.uprisedeMinutter - a.uprisedeMinutter || b.betalteMinutter - a.betalteMinutter)

  return (
    <Sideramme>
      <Sidehode
        tittel="Vaktene bak tallet"
        merke={tittel}
        handlinger={<Link href="/lonnskost">Til lønnskost</Link>}
      />

      {ut.status === 'minimum' && (
        <Status nivaa="endring">
          {`${timer.format(ut.uprisedeMinutter / 60)} av `}
          {`${timer.format(ut.betalteMinutter / 60)} betalte timer kunne ikke prises. `}
          {'Det faktiske beløpet er høyere enn '}
          {kr.format(ut.minimum503Kr)}
          {'.'}
        </Status>
      )}

      {personer.map((p) => (
        <Datatabell
          key={p.ansattNr}
          tittel={`${p.ansattNr} · ${p.navn}`}
          antall={p.rader.length}
        >
          <thead>
            <tr>
              <th>Dato</th>
              <th>Tid</th>
              <th>Timer</th>
              <th>Hva skjedde</th>
            </tr>
          </thead>
          <tbody>
            {p.rader.map((v) => (
              <tr key={`${v.rad.fraDato}-${v.rad.fraTid}-${v.rad.tilTid}-${String(v.rad.betalt)}`}>
                <td>{v.rad.dato}</td>
                <td>{`${v.rad.fraTid}–${v.rad.tilTid}`}</td>
                <td className="tall">{timer.format(v.rad.minutter / 60)}</td>
                <td>
                  {v.utfall.slag === 'upriset'
                    ? <Status nivaa="endring">{utfallstekst(v.utfall)}</Status>
                    : utfallstekst(v.utfall)}
                </td>
              </tr>
            ))}
          </tbody>
        </Datatabell>
      ))}

      <p className="undertittel">{FORBEHOLD_KORT}</p>
      <Forklaring sporsmaal="Hva betyr det?">
        {ut.forbehold.map((f) => <p key={f}>{f}</p>)}
      </Forklaring>
    </Sideramme>
  )
}
