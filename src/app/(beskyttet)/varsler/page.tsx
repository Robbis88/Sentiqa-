import Link from 'next/link'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { markerLest, markerAlle } from './handlinger'
import { erLeder } from '@/lib/auth/roller'
import { PushTilmelding } from './push-tilmelding'
import { Sidehode, Tomtilstand } from '@/components/ui/side'
import { Liste, Rad } from '@/components/ui/liste'
import { Status } from '@/components/ui/status'
import { Knapp } from '@/components/ui/knapp'
import { Sideramme } from '@/components/ui/sideramme'
import { oversettTabletOrd } from '@/lib/oversett'

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
  const bruker = await hentInnloggetBruker()

  // BJELLA ER NETTBRETTETS OGSAA.
  //
  // /varsler staar med rollen [T] og naas fra toppstripa, men sida var
  // norsk uansett spraakvalg. Rammen rundt - overskrift, tomtilstand,
  // «Ulest» - gaar naa gjennom `t()`.
  //
  // SELVE VARSELTEKSTEN GJOER DET IKKE. Den er dynamisk og ville krevd
  // et Haiku-kall per varsel per spraak. Det er et eget valg med en egen
  // kostnad, og det skal tas med aapne oyne - ikke smugles inn her.
  const { cookies } = await import('next/headers')
  const sprak = bruker.rolle === 'butikkbruker_tablet'
    ? ((await cookies()).get('sprak')?.value ?? 'no') : 'no'
  const ord = await oversettTabletOrd(sprak)
  const t = (x: string) => ord[x] ?? x

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
        tittel={t('Varsler')}
        undertittel={uleste === 0
          ? t('Alt er lest.')
          : `${uleste} ${uleste === 1 ? t('ulest') : t('uleste')}.`}
        // KNAPPEN VISES BARE FOR DEN SOM FAAR BRUKE DEN. Varsler ligger
        // per stasjon, og nettbrettet er en delt enhet - «marker alle»
        // der ville tatt butikksjefens uleste med. Sto knappen igjen for
        // nettbrettet, ville den bare kastet ved trykk, og en knapp som
        // alltid feiler er verre enn ingen.
        handlinger={uleste > 0 && erLeder(bruker.rolle) ? (
          <form action={markerAlle}>
            <Knapp type="submit">{t('Marker alle som lest')}</Knapp>
          </form>
        ) : undefined}
      />

      <PushTilmelding />

      {varsler.length === 0 ? (
        <Tomtilstand
          tittel={t('Ingen varsler')}
          forklaring={t('Systemet sier fra her når noe krever at du ser på det.')}
        />
      ) : (
        // KREVER NOE AV MEG NAA, eller er det lest? Det var det eneste
        // skillet paa sida, og det laa i en css-klasse som gjorde teksten
        // blek. Naa staar det som tilstand - og det leste faar ingen
        // farge i det hele tatt, for lest er utgangspunktet.
        <Liste merkelapp={t('Varsler')}>
          {varsler.map((v) => (
            <Rad
              key={v.id}
              primaer={v.tittel}
              sekundaer={[v.tekst, tid.format(new Date(v.opprettet_tid))]
                .filter(Boolean).join(' · ')}
              status={v.lest ? undefined : <Status nivaa="endring">{t('Ulest')}</Status>}
              handlinger={(
                <>
                  {/* Veien videre forst: et varsel uten vei ut er bare
                      en paaminnelse om at man ikke gjorde noe. */}
                  {v.lenke && (
                    <Link href={v.lenke} className="sq-knapp liten">{t('Åpne')}</Link>
                  )}
                  {!v.lest && (
                    <form action={markerLest}>
                      <input type="hidden" name="id" value={v.id} />
                      <Knapp type="submit" variant="ghost" liten>{t('Lest')}</Knapp>
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
