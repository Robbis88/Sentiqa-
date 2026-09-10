import { AuthKort } from '@/components/ui/auth-kort'
import type { Metadata } from 'next'
import { TotpSkjema } from './totp-skjema'

export const metadata: Metadata = { title: 'Bekreft innlogging – Sentiqa' }

export default async function TotpSide({
  searchParams,
}: {
  searchParams: Promise<{ retur?: string }>
}) {
  const { retur } = await searchParams

  return (
    <AuthKort
      tittel="Bekreft innlogging"
      undertittel="Skriv inn engangskoden fra autentiseringsappen din."
    >
      <TotpSkjema retur={retur} />
    </AuthKort>
  )
}
