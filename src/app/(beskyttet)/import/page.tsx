import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { Opplaster } from './opplaster'

const STATUS_ETIKETT: Record<string, { tekst: string; klasse: string }> = {
  mottatt: { tekst: 'Mottatt', klasse: 'gul' },
  behandler: { tekst: 'Behandler', klasse: 'gul' },
  parset: { tekst: 'Parset', klasse: 'gronn' },
  feilet: { tekst: 'Feilet', klasse: 'rod' },
}

// All tidsvisning tvinges til Europe/Oslo (§18)
const tid = new Intl.DateTimeFormat('nb-NO', {
  timeZone: 'Europe/Oslo',
  dateStyle: 'short',
  timeStyle: 'short',
})

type Jobb = {
  id: string
  status: string
  rapporttype: string
  opprettet_tid: string
  raa_filer: { filnavn: string; mottakskanal: string } | null
}

export default async function ImportSide() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin') {
    return <p>Kun eier har tilgang til import.</p>
  }

  const supabase = await lagSupabaseServerKlient()
  const { data } = await supabase
    .from('import_jobber')
    .select('id, status, rapporttype, opprettet_tid, raa_filer(filnavn, mottakskanal)')
    .order('opprettet_tid', { ascending: false })
    .limit(50)
    .overrideTypes<Jobb[]>()

  const jobber = data ?? []

  return (
    <>
      <h1>Import</h1>
      <p className="undertittel">
        Last opp rapporter (St1, Salesgrid, Visma). E-post-inntak kommer senere.
      </p>

      <section className="kort">
        <h2>Last opp filer</h2>
        <Opplaster />
      </section>

      <section className="kort">
        <h2>Status</h2>
        {jobber.length === 0 ? (
          <p className="undertittel">Ingen filer lastet opp ennå.</p>
        ) : (
          <table className="tabell">
            <thead>
              <tr>
                <th>Fil</th>
                <th>Kanal</th>
                <th>Mottatt</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {jobber.map((j) => {
                const s = STATUS_ETIKETT[j.status] ?? { tekst: j.status, klasse: 'gul' }
                return (
                  <tr key={j.id}>
                    <td>{j.raa_filer?.filnavn ?? '—'}</td>
                    <td>{j.raa_filer?.mottakskanal === 'epost' ? 'E-post' : 'Drop-zone'}</td>
                    <td>{tid.format(new Date(j.opprettet_tid))}</td>
                    <td>
                      <span className={`status-pip ${s.klasse}`}>{s.tekst}</span>
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        )}
      </section>
    </>
  )
}
