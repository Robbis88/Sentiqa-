// Felles typer for parser-laget. Parserne er rene funksjoner: rå fil inn,
// strukturert resultat ut. Ingen DB, ingen sideeffekter (§14: testbart).

export type Rapporttype =
  | 'st1_salgsstatistikk'
  | 'st1_salesperhour'
  | 'st1_cashierstats'
  | 'salgsgrid_varetrans'
  | 'visma_resultat'
  | 'ukjent'

// Én produktlinje fra Salgsstatistikk (St1 0714), med drilldown-kontekst.
export type Salgslinje = {
  ean: string | null
  varenavn: string
  varenr: string | null
  avdelingKode: string | null
  avdelingNavn: string | null
  vareomradeKode: string | null
  vareomradeNavn: string | null
  varegruppeKode: string | null
  varegruppeNavn: string | null
  antallTotalt: number
  antallTilbud: number
  omsetningEksMva: number
  btoFortjenesteKr: number
  btoFortjenestePct: number
}

export type SalgsstatistikkStasjon = {
  butikknummer: string // 4-sifret (§6 matchenøkkel)
  navn: string
  linjer: Salgslinje[]
}

export type SalgsstatistikkResultat = {
  rapporttype: 'st1_salgsstatistikk'
  dato: string // ISO yyyy-mm-dd (fra rad 3)
  inkludererMoms: boolean
  stasjoner: SalgsstatistikkStasjon[]
}
