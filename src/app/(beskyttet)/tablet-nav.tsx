'use client'
import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { useT } from './oversett-kontekst'
import { TABLETMENY } from './navigasjon'

// Listen bor i navigasjon.ts, sammen med resten av navigasjonen. Da ser
// vakthunden den, og et tap her kan ikke gaa upaaaktet hen.
const FANER = TABLETMENY

// =====================================================================
// TRE FANER, TRE BRUKERAERend.
//
//   I dag    Hva skal jeg gjore naa?
//   Rutiner  Hva skal gjores — utfor rutinearbeid.
//   Hjelp    Jeg trenger hjelp eller informasjon.
//
// Fire faner OG fem fliser var to navigasjonslag over hverandre: ni
// innganger til aatte ruter, med Rutiner og Anvisninger i begge. Flisene
// er borte, og fanene er nede i tre.
//
// PRODUKSJON OG IK-MAT BLE IKKE FANER, og det er ikke fordi de er
// uviktige. Krever de arbeid i dag, kommer de TIL henne gjennom koen paa
// «I dag». Oppsoker hun dem selv, staar de i foten under Rutiner. En
// fane er for et aerend man har hele tiden, ikke for alt som er viktig.
//
// EN FANE DEKKER FLERE RUTER. «Hjelp» er /anvisninger, men /lenker,
// /nyheter og /mine-opplysninger naas fra foten der — og da skal fana
// staa som valgt naar man er nede i en av dem. Ellers ser det ut som man
// falt ut av navigasjonen.
const UNDER: Record<string, string[]> = {
  '/anvisninger': ['/lenker', '/nyheter', '/mine-opplysninger'],
}

export function TabletNav() {
  const sti = usePathname()
  const t = useT()
  return (
    <nav className="tablet-nav">
      {FANER.map((f) => {
        const aktiv = sti === f.sti
          || (f.sti !== '/oversikt' && sti.startsWith(f.sti))
          || (UNDER[f.sti] ?? []).some((u) => sti === u || sti.startsWith(u + '/'))
        return (
          <Link key={f.sti} href={f.sti} className={`tablet-fane ${aktiv ? 'aktiv' : ''}`}>
            <span className="tablet-fane-tekst">{t(f.tekst)}</span>
          </Link>
        )
      })}
    </nav>
  )
}
