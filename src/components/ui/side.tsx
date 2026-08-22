// =====================================================================
// Sidens faste deler: hode, svar, tom tilstand, tabell, forklaring.
//
// Ingen 'use client' — dette er ren utskrift. Legger man dem i
// klientlaget, drar hver side som bruker dem med seg JavaScript den
// ikke trenger.
//
// Nivåene er de samme overalt (se src/lib/redesign/monstre.ts):
//
//   1  Svar        ett tall eller én setning
//   2  Handling    det brukeren kom for å gjøre
//   3  Begrunnelse hvorfor systemet sier det
//   4  Detaljer    tabellen
//
// Komponentene her er nivå 1, 3 og 4. Nivå 2 er knapper og sidepanel.
// =====================================================================

import type { ReactNode } from 'react'

/**
 * Toppen av en side: hva dette er, og hva man kan gjøre her.
 *
 * `handlinger` ligger til høyre i samme rad som tittelen — ikke i en
 * seksjon under. En knapp som må letes etter, er ikke et tilbud.
 */
export function Sidehode({
  tittel,
  undertittel,
  merke,
  handlinger,
}: {
  tittel: string
  undertittel?: string
  /**
   * Hvem tallene gjelder — som regel stasjonen.
   *
   * STÅR OVER TITTELEN, ikke under. «28 400 kr bak plan» uten et navn
   * er et tall uten eier, og da ser et stasjonsbytte ut som ingenting:
   * samme overskrift, andre tall. Robert meldte nettopp det 2026-08-22
   * som at velgeren ikke virket — den virket, men sa det ikke.
   */
  merke?: string
  handlinger?: ReactNode
}) {
  return (
    <header className="sq-sidehode">
      <div className="sq-sidehode-tekst">
        {merke && <p className="sq-sidehode-merke">{merke}</p>}
        <h1>{tittel}</h1>
        {undertittel && <p className="undertittel">{undertittel}</p>}
      </div>
      {handlinger && <div className="sq-sidehode-handlinger">{handlinger}</div>}
    </header>
  )
}

export type Retning = 'opp' | 'ned' | 'flat'

/**
 * Nivå 1: ett tall, med det tallet betyr ved siden av.
 *
 * `sammenlignet` er ikke valgfri pynt. «34 200 kr» sier ingenting;
 * «+7,8 % mot en vanlig tirsdag» sier alt. Har man ikke noe å
 * sammenligne med, er tallet sjelden verdt nivå 1.
 *
 * `retning` er atskilt fra `bra`, fordi opp ikke alltid er bra: salg opp
 * er bra, svinn opp er ikke. Pilen viser bevegelsen, fargen viser
 * dommen, og de to skal kunne peke hver sin vei.
 */
export function Nokkeltall({
  merkelapp,
  verdi,
  sammenlignet,
  retning = 'flat',
  bra,
}: {
  merkelapp: string
  verdi: string
  sammenlignet?: string
  retning?: Retning
  bra?: boolean
}) {
  const pil = retning === 'opp' ? '↑' : retning === 'ned' ? '↓' : null
  const dom = bra === undefined ? '' : bra ? ' god' : ' darlig'
  return (
    <div className="sq-nokkeltall">
      <span className="sq-nokkeltall-merkelapp">{merkelapp}</span>
      <span className="sq-nokkeltall-verdi">{verdi}</span>
      {sammenlignet && (
        <span className={`sq-nokkeltall-mot${dom}`}>
          {pil && <span aria-hidden>{pil} </span>}
          {sammenlignet}
        </span>
      )}
    </div>
  )
}

/**
 * Når det ikke er noe å vise.
 *
 * En tom liste er et øyeblikk der brukeren enten er ny eller har gjort
 * alt ferdig — begge fortjener et bedre svar enn «Ingen data». Derfor
 * krever komponenten en forklaring, og tilbyr en vei videre.
 */
export function Tomtilstand({
  tittel,
  forklaring,
  handling,
}: {
  tittel: string
  forklaring: string
  handling?: ReactNode
}) {
  return (
    <div className="sq-tom">
      <p className="sq-tom-tittel">{tittel}</p>
      <p className="sq-tom-forklaring">{forklaring}</p>
      {handling && <div className="knapperad">{handling}</div>}
    </div>
  )
}

/**
 * Nivå 4. Tabellen hører hjemme nederst, ikke øverst.
 *
 * Wrapperen finnes for tre ting hver av de 28 håndskrevne tabellene må
 * løse hver for seg: vannrett rulling på liten skjerm, tom tilstand, og
 * at overskriften hører til tabellen framfor å sveve over den.
 */
export function Datatabell({
  tittel,
  antall,
  tom,
  rutenett,
  children,
}: {
  tittel?: string
  /** Vises ved siden av tittelen. «12 ansatte» er raskere enn å telle. */
  antall?: number
  tom?: ReactNode
  /**
   * Tabellen inneholder KONTROLLER, ikke bare tall.
   *
   * Dette er hele det nye mønsteret fra port 0 til bølge 4, og det er
   * med vilje så lite. Kartleggingen av de tre kandidatene viste at et
   * redigeringsrutenett deler LAYOUT med en lesetabell — tett rutenett,
   * rad per objekt, kolonner som betyr noe — men ikke oppførsel:
   *
   *   /produksjonsplan  lagrer i det du endrer (klient, optimistisk)
   *   /stasjoner        lagrer når du trykker Lagre (server, per felt)
   *
   * En komponent som eide lagringen måtte valgt én av dem og tvunget den
   * på den andre. Derfor eier den bare formen: celler som tåler et felt
   * uten å bli halvannen centimeter høye, og kontroller som stiller seg
   * på linje nedover kolonnen.
   *
   * Det tredje kandidatet, /bemanning, viste seg å ikke være et
   * redigeringsrutenett i det hele tatt — radene er lesbare, med slett
   * som eneste handling. Den hører til liste-mønsteret fra bølge 3.
   */
  rutenett?: boolean
  children: ReactNode
}) {
  if (antall === 0 && tom) return <>{tom}</>
  return (
    <div className={`sq-datatabell${rutenett ? ' sq-rutenett' : ''}`}>
      {tittel && (
        <div className="sq-datatabell-topp">
          <h3>{tittel}</h3>
          {antall !== undefined && <span className="undertittel">{antall}</span>}
        </div>
      )}
      <div className="tabellramme">
        <table className="tabell">{children}</table>
      </div>
    </div>
  )
}

/**
 * Nivå 3, sammenleggbar: «Hvorfor sier systemet dette?»
 *
 * Beregningen skal være tilgjengelig, ikke påtrengende. I dag møter
 * brukeren «baseline fra 391 salgsdager + median + trend» før hun har
 * fått svaret — og da har vi bedt henne forstå metoden for å lese tallet.
 *
 * <details> framfor egen tilstand: den husker seg selv, virker uten
 * JavaScript, og er søkbar med Ctrl+F selv når den er lukket i noen
 * nettlesere.
 */
export function Forklaring({
  sporsmaal = 'Hvorfor?',
  children,
}: {
  sporsmaal?: string
  children: ReactNode
}) {
  return (
    <details className="sq-forklaring">
      <summary>{sporsmaal}</summary>
      <div className="sq-forklaring-innhold">{children}</div>
    </details>
  )
}
