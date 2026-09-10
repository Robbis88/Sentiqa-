import { AuthKort } from '@/components/ui/auth-kort'
import type { Metadata } from 'next'
import { SettPassordSkjema } from './skjema'

export const metadata: Metadata = { title: 'Sett passord – Sentiqa' }

// SAMME SIDE, TO ÆRENDER. Hit kommer både den som er invitert for første
// gang og den som har glemt passordet sitt. «Velkommen» sto alene her og
// var riktig for den ene og pussig for den andre — /auth/bekreft vet
// hvilken lenke som ble brukt, og sier fra med `?ny=1`.
export default async function SettPassordSide({
  searchParams,
}: {
  searchParams: Promise<{ ny?: string }>
}) {
  const { ny } = await searchParams

  return (
    <AuthKort
      tittel={ny ? 'Velkommen' : 'Nytt passord'}
      undertittel={ny
        ? 'Velg et passord for kontoen din, så er du i gang.'
        : 'Velg et nytt passord, så er du inne igjen.'}
      bunn="ingen"
    >
      <SettPassordSkjema />
    </AuthKort>
  )
}
