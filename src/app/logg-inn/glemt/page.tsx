import { AuthKort } from '@/components/ui/auth-kort'
import type { Metadata } from 'next'
import Link from 'next/link'
import { GlemtSkjema } from './skjema'

export const metadata: Metadata = { title: 'Glemt passord – Sentiqa' }

// LIGGER UNDER /logg-inn MED VILJE. `OFFENTLIGE_PREFIX` i proxy.ts
// slipper gjennom hele `/logg-inn`-treet, så ruta er åpen uten at lista
// må røres — og en glemt-passord-side som krever innlogging er ikke en
// side, den er en spøk.
export default async function GlemtSide({
  searchParams,
}: {
  searchParams: Promise<{ epost?: string }>
}) {
  const { epost } = await searchParams

  return (
    <AuthKort
      tittel="Glemt passord"
      undertittel="Skriv inn e-postadressen du logger inn med, så sender vi en lenke der du velger et nytt."
      bunnEkstra={<> · <Link href="/personvern">Personvern</Link></>}
    >
      <GlemtSkjema epost={epost} />
    </AuthKort>
  )
}
