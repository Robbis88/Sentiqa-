import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { lesAktivAnsatt, hentStasjonId } from '@/lib/ansatt'
import { StemplingSkjema } from './skjema'

export const dynamic = 'force-dynamic'

const klokke = new Intl.DateTimeFormat('nb-NO', {
  timeZone: 'Europe/Oslo', hour: '2-digit', minute: '2-digit', hour12: false,
})

type Innstemplet = { ansatt_navn: string; tidspunkt: string }

export default async function StemplingSide() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle === 'plattform_redaktor') return <p>Ingen tilgang.</p>

  const supabase = await lagSupabaseServerKlient()
  const aktiv = await lesAktivAnsatt()
  const stasjonId = await hentStasjonId(supabase, aktiv)

  // Kulturvalg per kjede (0110). Noen vil ha den sosiale kontrollen i at
  // alle ser hvem som staar inne; andre vil ikke.
  const { data: kjede } = await supabase
    .from('retailers').select('stempling_vis_innstemplede')
    .maybeSingle<{ stempling_vis_innstemplede: boolean }>()
  const visInne = kjede?.stempling_vis_innstemplede ?? true

  // Hvem staar inne naa: siste hendelse per ansatt er «inn».
  let inne: Innstemplet[] = []
  if (visInne && stasjonId) {
    const { data } = await supabase
      .from('stempling_hendelse')
      .select('ansatt_nr, ansatt_navn, tidspunkt, type')
      .eq('stasjon_id', stasjonId)
      .is('annullert_tid', null)
      .order('tidspunkt', { ascending: false })
      .limit(200)
      .overrideTypes<{ ansatt_nr: string; ansatt_navn: string; tidspunkt: string; type: string }[]>()

    // Foerste rad per ansatt er den siste hendelsen, siden lista er
    // sortert synkende. Er den «inn», staar hun inne.
    const sett = new Set<string>()
    for (const h of data ?? []) {
      if (sett.has(h.ansatt_nr)) continue
      sett.add(h.ansatt_nr)
      if (h.type === 'inn') inne.push({ ansatt_navn: h.ansatt_navn, tidspunkt: h.tidspunkt })
    }
    inne = inne.sort((a, b) => a.tidspunkt.localeCompare(b.tidspunkt))
  }

  return (
    <>
      <header className="tablet-hode">
        <h1>Stemple inn og ut</h1>
      </header>

      <StemplingSkjema />

      {visInne && (
        <section className="kort">
          <h2>Inne nå <span className="undertittel">· {inne.length}</span></h2>
          {inne.length === 0 ? (
            <p className="undertittel">Ingen er stemplet inn på stasjonen akkurat nå.</p>
          ) : (
            <ul className="rutine-liste">
              {inne.map((i) => (
                <li key={i.ansatt_navn + i.tidspunkt}>
                  <div className="rutine-tekst">
                    <strong>{i.ansatt_navn}</strong>
                    <span className="undertittel"> · siden {klokke.format(new Date(i.tidspunkt))}</span>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </section>
      )}
    </>
  )
}
