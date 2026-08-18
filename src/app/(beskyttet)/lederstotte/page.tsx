import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { manedAar } from '@/lib/format'
import type { Lederstotte } from '@/lib/ai/lederstotte'
import { GenererKnapp } from './generer-knapp'
import { Sidehode, Tomtilstand, Forklaring } from '@/components/ui/side'

const STATUS_TEKST: Record<string, string> = { gronn: 'Sterkt', gul: 'På god vei', bla: 'Utviklingspotensial' }

type Rad = { stasjon_id: string; periode: string; rapport: Lederstotte }

export default async function LederstotteSide() {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) {
    return <p>Du har ikke tilgang til lederstøtte.</p>
  }

  const supabase = await lagSupabaseServerKlient()
  const { data: siste } = await supabase
    .from('lederstotte_rapporter')
    .select('periode')
    .order('periode', { ascending: false })
    .limit(1)
    .maybeSingle<{ periode: string }>()

  const [{ data: rader }, { data: stasjoner }] = await Promise.all([
    siste
      ? supabase
          .from('lederstotte_rapporter')
          .select('stasjon_id, periode, rapport')
          .eq('periode', siste.periode)
          .overrideTypes<Rad[]>()
      : Promise.resolve({ data: [] as Rad[] }),
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null).order('butikknummer'),
  ])

  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))

  // NIVÅ 1 — svaret. Sidehodet sa perioden og ordet «utviklingsorientert».
  // Det man kommer hit for er hvordan lederne ligger an, og det måtte man
  // lese seg til gjennom én rapport per stasjon.
  const alle = rader ?? []
  const tell = (s: string) => alle.filter((r) => r.rapport.status === s).length
  const sterke = tell('gronn')
  const potensial = tell('bla')
  const svar = alle.length === 0
    ? null
    : [
        sterke > 0 ? `${sterke} av ${alle.length} står sterkt` : null,
        potensial > 0 ? `${potensial} med utviklingspotensial` : null,
      ].filter(Boolean).join(' · ') || `${alle.length} rapporter`

  const periodeTekst = siste ? manedAar.format(new Date(siste.periode)) : 'Ingen rapporter ennå'

  return (
    <>
      <Sidehode
        tittel="Lederstøtte"
        undertittel={svar ? `${svar}. ${periodeTekst}` : periodeTekst}
        handlinger={bruker.rolle === 'retailer_admin' ? <GenererKnapp /> : undefined}
      />

      {alle.length === 0 ? (
        <Tomtilstand
          tittel="Ingen lederstøtte-rapport ennå"
          forklaring={bruker.rolle === 'retailer_admin'
            ? 'Rapporten leser regnskapet for perioden og skriver en utviklingsvurdering per butikksjef — styrker først, så det som kan bli bedre. Behandle et regnskap og trykk «Generer lederstøtte».'
            : 'Eieren genererer rapporten når perioden er ferdig regnskapsført. Da ser du din egen vurdering her.'}
        />
      ) : (
        alle.map((rad) => {
          const r = rad.rapport
          return (
            <section className="kort" key={rad.stasjon_id}>
              <h2>
                {navnFor.get(rad.stasjon_id) ?? '—'}{' '}
                <span className={`status-pip ${r.status}`}>{STATUS_TEKST[r.status] ?? r.status}</span>
              </h2>
              <p>{r.oppsummering}</p>
              <div className="fokus-kol">
                <div>
                  <h3 className="fokus-tittel gronn">Styrker</h3>
                  <ul className="fokus-liste">{r.styrker.map((t, i) => <li key={i}>{t}</li>)}</ul>
                </div>
                <div>
                  <h3 className="fokus-tittel bla">Utviklingsområder</h3>
                  <ul className="fokus-liste">{r.utviklingsomrader.map((t, i) => <li key={i}>{t}</li>)}</ul>
                </div>
              </div>
              <h3 className="fokus-tittel" style={{ marginTop: '1rem' }}>Neste steg</h3>
              <ol className="tiltak-liste">{r.nesteSteg.map((t, i) => <li key={i}>{t}</li>)}</ol>
            </section>
          )
        })
      )}

      <Forklaring sporsmaal="Hvordan skal denne rapporten brukes?">
        <p>
          Vurderingen er skrevet av en språkmodell som leser periodens tall, ikke av
          noen som har vært i butikken. Den ser hva som skjedde, ikke hvorfor — en
          butikksjef som taper på lønn kan ha dekket for en sykmelding.
        </p>
        <p>
          Statusen er derfor utviklingsorientert med vilje: «Sterkt», «På god vei»,
          «Utviklingspotensial». Ingen av dem er en karakter, og ingen av dem hører
          hjemme i en personalsak uten at noen har snakket med den det gjelder først.
        </p>
      </Forklaring>
    </>
  )
}
