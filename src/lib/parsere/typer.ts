// Felles typer for parser-laget. Parserne er rene funksjoner: rå fil inn,
// strukturert resultat ut. Ingen DB, ingen sideeffekter (§14: testbart).

export type Rapporttype =
  | 'st1_salgsstatistikk'
  | 'st1_salesperhour'
  | 'st1_cashierstats'
  | 'salgsgrid_varetrans'
  | 'regnskap_resultat'
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

// --- St1 0758 SalesPerHour (timesalg/heatmap) ---
export type TimesalgRad = {
  time: string // "0-1" … "23-24"
  salg: number
  kostpris: number
  mva: number
  antallVarer: number
  antallKunder: number
}
export type SalesPerHourStasjon = {
  butikknummer: string | null // filen har kun navn → matches på navn (§6)
  navn: string
  timer: TimesalgRad[]
}
export type SalesPerHourResultat = {
  rapporttype: 'st1_salesperhour'
  dato: string | null
  stasjoner: SalesPerHourStasjon[]
}

// --- St1 0018 CashierStatistics (kassererstatistikk) ---
export type KassererRad = {
  nr: string
  navn: string
  omsetningInkMva: number
  bonger: number
  returAntall: number
  returBelop: number
  makulerteAntall: number
  makulerteBelop: number
  slettedeAntall: number
  slettedeBelop: number
}
export type CashierStatsStasjon = {
  butikknummer: string
  navn: string
  kasserere: KassererRad[]
}
export type CashierStatsResultat = {
  rapporttype: 'st1_cashierstats'
  dato: string | null
  stasjoner: CashierStatsStasjon[]
}

// --- St1 0452 Varetransaksjonsliste (synlig svinn) ---
export type SvinnTransaksjon = {
  ean: string | null
  varenavn: string
  varenummer: string | null
  operatornr: string | null
  transaksjonstype: string
  arsakskode: string
  dato: string | null
  nettopris: number
  antall: number
  nettoprisTotal: number
}
export type VaretransStasjon = {
  butikknummer: string
  navn: string
  transaksjoner: SvinnTransaksjon[]
}
export type VaretransResultat = {
  rapporttype: 'salgsgrid_varetrans'
  stasjoner: VaretransStasjon[]
}

// --- Regnskaps-/resultatrapport (Azets m.fl., cluster-nivå) ---
export type RegnskapSeksjon =
  | 'omsetning'
  | 'bruttofortjeneste'
  | 'driftskostnader'
  | 'resultat'

export type RegnskapLinje = {
  seksjon: RegnskapSeksjon
  kode: string | null // regnskapskode, f.eks. '120' (null for total-/kostnadslinjer)
  post: string // "120 Mat", "Personalkostnad …", "RESULTAT"
  sortering: number | null
  regnskap: number
  budsjett: number
  avvik: number
  indexPct: number
  regnskapHittil: number
  budsjettHittil: number
}

export type RegnskapResultat = {
  rapporttype: 'regnskap_resultat'
  periode: string | null // ISO første-i-måneden, f.eks. '2025-12-01'
  retailerNavn: string | null
  linjer: RegnskapLinje[]
}

// Per-stasjon-ark i regnskapsfila (avdelingsnivå: omsetning + bruttofortjeneste).
export type RegnskapStasjon = {
  butikknummer: string
  navn: string
  linjer: RegnskapLinje[]
}
