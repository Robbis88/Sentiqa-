import type { ReactNode } from 'react'

// =====================================================================
// Sidevis søk og filter.
//
// IKKE GLOBALT SØK. Det finnes allerede — kommandopaletten på ⌘K, som
// søker i navigasjonen og kan sende et spørsmål videre til assistenten.
// Dette er noe annet: å snevre inn lista man alt står i.
//
// SØKET ER ET SKJEMA, ikke en tastetrykklytter. Det virker uten
// JavaScript, det kan bokmerkes, og en delt lenke viser det samme
// treffet. Sidene i dette systemet er serverrendret, og et søk som
// krever klientstate ville gjort dem til noe annet.
//
// FILTERET TELLER. `antall` står i knappen fordi et aktivt filter er
// den vanligste grunnen til at «raden min er borte». Uten telleren
// leter folk etter data som ligger rett bak en innsnevring de har
// glemt at de satte.
// =====================================================================

/**
 * Søk i lista på denne siden.
 *
 * `handling` er sidens egen URL — søket sendes som spørrestreng, ikke
 * som en serverhandling. Da kan treffet deles.
 */
export function Sok({
  navn = 'sok',
  verdi,
  plassholder,
  merkelapp = 'Søk i lista',
  skjulte,
}: {
  navn?: string
  verdi?: string
  plassholder?: string
  /** Etiketten for skjermleser. Feltet har ingen synlig etikett. */
  merkelapp?: string
  /** Andre spørreparametre som skal overleve søket — periode, stasjon. */
  skjulte?: Record<string, string | undefined>
}) {
  return (
    <form className="sq-sok" role="search">
      {Object.entries(skjulte ?? {}).map(([k, v]) =>
        v === undefined ? null : <input key={k} type="hidden" name={k} value={v} />)}
      <label className="sq-sok-felt">
        <span className="sq-skjult">{merkelapp}</span>
        <svg width="15" height="15" viewBox="0 0 16 16" fill="none" aria-hidden="true">
          <circle cx="7" cy="7" r="4.5" stroke="currentColor" strokeWidth="1.5" />
          <path d="M10.5 10.5 14 14" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
        </svg>
        <input
          type="search"
          name={navn}
          defaultValue={verdi}
          placeholder={plassholder}
          autoComplete="off"
        />
      </label>
      {/* Uten JavaScript er dette veien til å søke. Med, gjør Enter jobben. */}
      <noscript><button type="submit" className="sq-knapp liten">Søk</button></noscript>
    </form>
  )
}

/**
 * Filtrene på siden, samlet.
 *
 * Ikke en egen mekanisme — en ramme rundt de `Velg`-feltene siden
 * allerede har. Poenget er telleren og at de står samme sted hver gang.
 */
export function Filter({
  antall = 0,
  children,
}: {
  /** Hvor mange filtre som faktisk snevrer inn nå. */
  antall?: number
  children: ReactNode
}) {
  return (
    <div className="sq-filter">
      <span className="sq-filter-merkelapp">
        Filter
        {antall > 0 && <span className="sq-filter-teller">{antall}</span>}
      </span>
      {children}
    </div>
  )
}
