import type { ReactNode } from 'react'
import Link from 'next/link'

// =====================================================================
// Liste og Rad.
//
// Den viktigste komponenten i migreringen: 57 rå tabeller står i
// systemet, og de fleste av dem er ikke tabeller. De er lister over
// ting — ansatte, oppgaver, stasjoner — presset inn i et rutenett fordi
// `<table>` var det som fantes.
//
// MEN IKKE ALLE. En ekte sammenligningsmatrise, der kolonnene skal leses
// mot hverandre og tallene stilles opp under hverandre, er en tabell og
// skal forbli en. `Datatabell` finnes fortsatt og skal brukes der.
//
//   Liste     når hver rad er ÉN ting man kan gjøre noe med
//   Datatabell når kolonnene betyr noe på tvers av rader
//
// INGEN KORT PER RAD. En liste med tjue kort er tjue rammer, tjue
// skygger og nitten streker for mye. Radene skilles av én hårlinje, og
// det holder.
//
// RADEN ER HANDLINGEN der det gir mening. En «Åpne»-knapp på hver rad
// er en knapp brukeren må sikte på, i en kolonne som stjeler plass fra
// innholdet. Er det bare én ting å gjøre med raden, skal raden gjøre den.
// =====================================================================

export function Liste({
  children,
  merkelapp,
}: {
  children: ReactNode
  /** Navngir lista for skjermlesere når den ikke står under en overskrift. */
  merkelapp?: string
}) {
  return <ul className="sq-liste" aria-label={merkelapp}>{children}</ul>
}

type RadInnhold = {
  /** Det man leser først. Navnet, tittelen, saken. */
  primaer: ReactNode
  /** Det som gjør primærteksten entydig. Stilling, dato, nummer. */
  sekundaer?: ReactNode
  /** Kort tilstand — bruk `Status`. Står til høyre, rolig. */
  status?: ReactNode
  /** Tall eller nøkler. Justeres mot høyre og får tabulære siffer. */
  metadata?: ReactNode
  /** Knapper. Utelat dem hvis raden selv kan være handlingen. */
  handlinger?: ReactNode
  /** Bilde eller initialer. Valgfritt — ikke lag et for å fylle plass. */
  merke?: ReactNode
}

/**
 * En rad.
 *
 * Med `href` blir hele raden en lenke. Da skal `handlinger` stå tom:
 * en lenke som inneholder en knapp er ugyldig markup, og en knapp inni
 * en lenke er umulig å treffe med tastatur på en forutsigbar måte.
 */
export function Rad({
  href,
  primaer,
  sekundaer,
  status,
  metadata,
  handlinger,
  merke,
}: RadInnhold & { href?: string }) {
  const innhold = (
    <>
      {merke && <span className="sq-rad-merke">{merke}</span>}
      <span className="sq-rad-tekst">
        <span className="sq-rad-primaer">{primaer}</span>
        {sekundaer && <span className="sq-rad-sekundaer">{sekundaer}</span>}
      </span>
      {status && <span className="sq-rad-status">{status}</span>}
      {metadata && <span className="sq-rad-metadata">{metadata}</span>}
    </>
  )

  return (
    <li className="sq-rad">
      {href ? (
        <Link href={href} className="sq-rad-lenke">{innhold}</Link>
      ) : (
        <div className="sq-rad-lenke sq-rad-flat">{innhold}</div>
      )}
      {!href && handlinger && <span className="sq-rad-handlinger">{handlinger}</span>}
    </li>
  )
}
