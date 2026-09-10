import { AuthKort } from '@/components/ui/auth-kort'
import type { Metadata } from 'next'
import Link from 'next/link'
import { InnloggingSkjema } from './skjema'

export const metadata: Metadata = { title: 'Logg inn – Sentiqa' }

// EN UTLØPT LENKE SA INGENTING. `/auth/bekreft` har sendt hit med
// `?feil=invitasjon` siden den ble skrevet, og siden leste aldri
// parameteren: du klikket på lenken i e-posten, havnet på innlogging, og
// ingenting forklarte hvorfor. Det ser ut som at lenken virket og at du
// bare glemte passordet igjen.
const FEILTEKST: Record<string, string> = {
  invitasjon: 'Lenken er utløpt eller allerede brukt. Be om en ny under.',
  // Lenken bar ingenting. Nesten alltid vår feil, ikke hennes — se
  // kommentaren i /auth/bekreft. Teksten sier derfor ikke «prøv igjen»,
  // for det hjelper ikke: neste lenke vil være like tom.
  'ingen-token': 'Lenken manglet nøkkelen sin. Be om en ny under — kommer '
    + 'samme melding igjen, er det noe galt hos oss, og da må du si fra.',
}

export default async function LoggInnSide({
  searchParams,
}: {
  searchParams: Promise<{ retur?: string; feil?: string }>
}) {
  const { retur, feil } = await searchParams
  const melding = feil ? FEILTEKST[feil] : undefined

  return (
    <AuthKort
      tittel="Logg inn"
      undertittel="Fornemmer. Forstår. Forutser."
      bunnEkstra={<> · <Link href="/personvern">Personvern</Link></>}
    >
      {melding ? <p role="alert" className="feil">{melding}</p> : null}
      <InnloggingSkjema retur={retur} />
    </AuthKort>
  )
}
