// Felles typer for parser-laget. Parserne er rene funksjoner: rå fil inn,
// strukturert resultat ut. Ingen DB, ingen sideeffekter (§14: testbart).

export type Rapporttype =
  | 'st1_salgsstatistikk'
  | 'st1_salesperhour_inneute'
  | 'st1_cashierstats'
  | 'salgsgrid_varetrans'
  | 'regnskap_resultat'
  | 'st1_bp'
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
  inneKunder?: number // butikk (0603-rapport)
  uteKunder?: number // forgård/pumpe (0603-rapport)
}
export type SalesPerHourStasjon = {
  butikknummer: string | null // filen har kun navn → matches på navn (§6)
  navn: string
  timer: TimesalgRad[]
}
export type SalesPerHourResultat = {
  rapporttype: 'st1_salesperhour_inneute'
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
  | 'nokkeltall' // «Sammenstilling»-arket: timer, timesats, lønns% per stasjon

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

// --- St1 forretningsplan (BP), årsbudsjett ---------------------------
export type BpKategori = {
  kode: string // '120'
  post: string // '120 Mat' — samme form som regnskapslinjer bruker
  salgKr: number
  varekostKr: number
}
export type BpKonto = {
  kode: string // '6312'
  post: string // '6312 Royalty'
  belopKr: number
}
export type BpMaaned = {
  maned: number // 1–12
  salgKr: number // CR salg, butikk (drivstoff er ikke med i BP-en)
  varekostKr: number
  bruttoKr: number // salg − varekost; kurven timene fordeles etter
  timelonnKr: number // konto 5012
  fastlonnKr: number // konto 5010, butikksjefens fastlønn
  kategorier: BpKategori[] // omsetning og varekost per varegruppe
  konti: BpKonto[] // alle kostnadskonti, hele P&L-en framover
}
export type BpStasjon = {
  butikknummer: string
  timerAar: number | null // variabel årsramme; ett årsverk er allerede trukket fra
  maaneder: BpMaaned[] // alltid 12, januar først
}
export type BpResultat = {
  rapporttype: 'st1_bp'
  ar: number | null
  stasjoner: BpStasjon[] // hele kjeden — filtreres mot retailer ved lagring
}

// Per-stasjon-ark i regnskapsfila (avdelingsnivå: omsetning + bruttofortjeneste).
export type RegnskapStasjon = {
  butikknummer: string
  navn: string
  linjer: RegnskapLinje[]
}
