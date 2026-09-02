import Link from 'next/link'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { datoLang } from '@/lib/format'
import { hentUkedata, tilgjengeligeUker } from '@/lib/ukebrief/hent'
import { byggUkebrief, ukenummer } from '@/lib/ukebrief/bygg'
import { Sidehode, Tomtilstand, Forklaring } from '@/components/ui/side'
import { Sideramme } from '@/components/ui/sideramme'
import { Brev } from './brev'

// =====================================================================
// Ukebrief — intern forhåndsvisning.
//
// Dette er DEMOEN, ikke utsendingen. Ingenting sendes herfra, og det
// finnes ingen cron. Siden finnes for å svare på ett spørsmål: er brevet
// godt nok til at en butikksjef ville lest det mandag morgen?
//
// Stasjonslista filtreres på rolle som overalt ellers — en butikksjef
// forhåndsviser bare sin egen stasjon. Demoen er ikke et smutthull.
// =====================================================================

export const maxDuration = 60

type Stasjon = { id: string; butikknummer: string; navn: string }
type Sok = { butikknummer?: string; uke?: string; visning?: string }

function ukelabel(mandag: string): string {
  const sondag = new Date(`${mandag}T12:00:00Z`)
  sondag.setUTCDate(sondag.getUTCDate() + 6)
  return `Uke ${ukenummer(mandag)} · ${datoLang.format(new Date(`${mandag}T12:00:00Z`))}`
    + ` – ${datoLang.format(sondag)}`
}

export default async function UkebriefSide({ searchParams }: { searchParams: Promise<Sok> }) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return <p>Du har ikke tilgang.</p>
  const supabase = await lagSupabaseServerKlient()
  const sp = await searchParams

  const { data: alle } = await supabase
    .from('stasjoner').select('id, butikknummer, navn').is('slettet_tid', null).order('butikknummer')
    .overrideTypes<Stasjon[]>()
  let stasjoner = alle ?? []
  if (bruker.rolle === 'butikksjef') {
    const { data: tilgang } = await supabase
      .from('butikksjef_stasjoner').select('stasjon_id').eq('profil_id', bruker.id)
    const ids = new Set((tilgang ?? []).map((t) => t.stasjon_id))
    stasjoner = stasjoner.filter((s) => ids.has(s.id))
  }

  if (stasjoner.length === 0) {
    return (
      <Sideramme>
        <Sidehode tittel="Ukebrief" />
        <Tomtilstand tittel="Ingen stasjoner" forklaring="Du har ikke tilgang til noen stasjoner." />
      </Sideramme>
    )
  }

  const valgt = stasjoner.find((s) => s.butikknummer === sp.butikknummer) ?? stasjoner[0]
  const uker = await tilgjengeligeUker(supabase, valgt.id)

  if (uker.length === 0) {
    return (
      <Sideramme>
        <Sidehode tittel="Ukebrief" merke={`${valgt.butikknummer} ${valgt.navn}`} />
        <Tomtilstand tittel="Ingen salgsdata" forklaring="Det finnes ingen uker å lage brief for på denne stasjonen." />
      </Sideramme>
    )
  }

  // Nyeste uke er som regel den inneværende og dermed ufullstendig. Brevet
  // sendes mandag om forrige uke, så forvalget er den siste HELE uken.
  const valgtUke = uker.includes(sp.uke ?? '') ? sp.uke! : (uker[1] ?? uker[0])
  const somEpost = sp.visning === 'epost'

  const data = await hentUkedata(supabase, valgt, valgtUke)
  const lenke = (over: Partial<Sok>) => {
    const q = new URLSearchParams({
      butikknummer: valgt.butikknummer, uke: valgtUke,
      ...(somEpost ? { visning: 'epost' } : {}),
      ...over,
    })
    return `/ukebrief?${q.toString()}`
  }

  return (
    <Sideramme>
      <Sidehode
        tittel="Ukebrief"
        merke={`${valgt.butikknummer} ${valgt.navn}`}
        undertittel="Forhåndsvisning. Ingenting sendes herfra."
      />

      <div className="ub-velger">
        {stasjoner.length > 1 && (
          <nav className="periode-trad" aria-label="Stasjon">
            {stasjoner.map((s) => (
              <Link
                key={s.id}
                href={lenke({ butikknummer: s.butikknummer, uke: undefined })}
                className={s.id === valgt.id ? 'periode-chip aktiv' : 'periode-chip'}
              >
                {s.navn}
              </Link>
            ))}
          </nav>
        )}

        <nav className="periode-trad" aria-label="Uke">
          {uker.slice(0, 6).map((u) => (
            <Link
              key={u}
              href={lenke({ uke: u })}
              className={u === valgtUke ? 'periode-chip aktiv' : 'periode-chip'}
            >
              Uke {ukenummer(u)}
            </Link>
          ))}
        </nav>

        <nav className="periode-trad" aria-label="Visning">
          <Link href={lenke({ visning: undefined })} className={somEpost ? 'periode-chip' : 'periode-chip aktiv'}>
            Som side
          </Link>
          <Link href={lenke({ visning: 'epost' })} className={somEpost ? 'periode-chip aktiv' : 'periode-chip'}>
            Som e-post
          </Link>
        </nav>
      </div>

      <p className="undertittel">{ukelabel(valgtUke)}</p>

      {data === null ? (
        <Tomtilstand
          tittel="Ingen data for denne uken"
          forklaring="Det finnes ingen salgslinjer for stasjonen i uken. Brevet ville vært tomt, og et tomt brev er verre enn ingen."
        />
      ) : somEpost ? (
        <div className="ub-innboks">
          <div className="ub-epost-hode">
            <p className="ub-epost-fra">Sentiqa</p>
            <p className="ub-epost-emne">
              Uke {ukenummer(valgtUke)} på {valgt.navn}
            </p>
          </div>
          <Brev brief={byggUkebrief(data)} />
        </div>
      ) : (
        <div className="ub-spalte">
          <Brev brief={byggUkebrief(data)} />
        </div>
      )}

      <Forklaring sporsmaal="Hva er dette?">
        <p>
          Brevet bygges av en ren funksjon: samme uke gir samme brev, hver gang.
          Ingen modell skriver teksten — overskriften og ingressen kommer fra tallene,
          slik pulsen på forsiden allerede gjør.
        </p>
        <p>
          Merkelappen under hvert funn sier hvor sikkert det er.
          <strong> Fakta</strong> er avlest. <strong>Sterk indikasjon</strong> er regnet ut
          gjennom en fordeling — ukesandelen av et månedsbudsjett, for eksempel.
          <strong> Mulig forklaring</strong> passer tallene, men kan være feil.
          Det vi ikke kan svare på, står nederst i stedet for å bli gjettet på.
        </p>
        <p>
          Handlingene er aldri flere enn fem, og hver av dem hører til et funn som står
          i brevet. En anbefaling uten et tall bak seg kommer ikke gjennom.
        </p>
      </Forklaring>
    </Sideramme>
  )
}
