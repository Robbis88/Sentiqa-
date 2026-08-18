import Link from 'next/link'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { markerLest, markerAlle } from './handlinger'
import { PushTilmelding } from './push-tilmelding'
import { Sidehode, Tomtilstand } from '@/components/ui/side'

type Varsel = {
  id: string
  type: string
  tittel: string
  tekst: string | null
  lenke: string | null
  lest: boolean
  opprettet_tid: string
}

const tid = new Intl.DateTimeFormat('nb-NO', { timeZone: 'Europe/Oslo', dateStyle: 'short', timeStyle: 'short' })

export default async function VarslerSide() {
  await hentInnloggetBruker()
  const supabase = await lagSupabaseServerKlient()
  const { data } = await supabase
    .from('varsler')
    .select('id, type, tittel, tekst, lenke, lest, opprettet_tid')
    .is('slettet_tid', null)
    .order('opprettet_tid', { ascending: false })
    .limit(100)
    .overrideTypes<Varsel[]>()

  const varsler = data ?? []
  const uleste = varsler.filter((v) => !v.lest).length

  return (
    <>
      <Sidehode
        tittel="Varsler"
        undertittel={uleste === 0
          ? 'Alt er lest.'
          : `${uleste} ${uleste === 1 ? 'ulest' : 'uleste'}.`}
        handlinger={uleste > 0 ? (
          <form action={markerAlle}>
            <button type="submit" className="liten">Marker alle som lest</button>
          </form>
        ) : undefined}
      />

      <PushTilmelding />

      {varsler.length === 0 ? (
        <Tomtilstand
          tittel="Ingen varsler"
          forklaring="Systemet sier fra her når noe krever at du ser på det."
        />
      ) : (
        <ul className="varsel-liste">
            {varsler.map((v) => (
              <li key={v.id} className={v.lest ? 'lest' : ''}>
                <div className="varsel-tekst">
                  <strong>{v.tittel}</strong>
                  {v.tekst ? <div className="undertittel">{v.tekst}</div> : null}
                  <div className="undertittel">
                    {tid.format(new Date(v.opprettet_tid))}
                    {v.lenke ? <> · <Link href={v.lenke}>Åpne</Link></> : null}
                  </div>
                </div>
                {!v.lest && (
                  <form action={markerLest}>
                    <input type="hidden" name="id" value={v.id} />
                    <button type="submit" className="liten">Lest</button>
                  </form>
                )}
              </li>
            ))}
        </ul>
      )}
    </>
  )
}
