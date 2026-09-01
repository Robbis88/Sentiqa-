import Link from 'next/link'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { markerLest, markerAlle } from './handlinger'
import { PushTilmelding } from './push-tilmelding'
import { Sidehode, Tomtilstand } from '@/components/ui/side'
import { Liste, Rad } from '@/components/ui/liste'
import { Status } from '@/components/ui/status'
import { Knapp } from '@/components/ui/knapp'
import { Sideramme } from '@/components/ui/sideramme'

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
    <Sideramme>
      <Sidehode
        tittel="Varsler"
        undertittel={uleste === 0
          ? 'Alt er lest.'
          : `${uleste} ${uleste === 1 ? 'ulest' : 'uleste'}.`}
        handlinger={uleste > 0 ? (
          <form action={markerAlle}>
            <Knapp type="submit">Marker alle som lest</Knapp>
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
        // KREVER NOE AV MEG NAA, eller er det lest? Det var det eneste
        // skillet paa sida, og det laa i en css-klasse som gjorde teksten
        // blek. Naa staar det som tilstand - og det leste faar ingen
        // farge i det hele tatt, for lest er utgangspunktet.
        <Liste merkelapp="Varsler">
          {varsler.map((v) => (
            <Rad
              key={v.id}
              primaer={v.tittel}
              sekundaer={[v.tekst, tid.format(new Date(v.opprettet_tid))]
                .filter(Boolean).join(' · ')}
              status={v.lest ? undefined : <Status nivaa="endring">Ulest</Status>}
              handlinger={(
                <>
                  {/* Veien videre forst: et varsel uten vei ut er bare
                      en paaminnelse om at man ikke gjorde noe. */}
                  {v.lenke && (
                    <Link href={v.lenke} className="sq-knapp liten">Åpne</Link>
                  )}
                  {!v.lest && (
                    <form action={markerLest}>
                      <input type="hidden" name="id" value={v.id} />
                      <Knapp type="submit" variant="ghost" liten>Lest</Knapp>
                    </form>
                  )}
                </>
              )}
            />
          ))}
        </Liste>
      )}
    </Sideramme>
  )
}
