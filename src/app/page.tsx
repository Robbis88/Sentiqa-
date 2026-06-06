import { redirect } from 'next/navigation'

// Rot sender til oversikten. Proxy bouncer uinnloggede til /logg-inn.
export default function Hjem() {
  redirect('/oversikt')
}
