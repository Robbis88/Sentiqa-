// =====================================================================
// DEMODATA FOR DEN OFFENTLIGE SIDA
//
// Alt i denne fila er oppdiktet, og flatene som viser det er merket
// «Demodata». Stasjonsnavnene er det ogsaa — en offentlig side skal
// ikke bære navnet på en kundes stasjoner.
//
// TALLENE ER LIKEVEL EKTE I FORM. Prosentene, kronene og forholdet
// mellom dem er hentet fra hvordan modulene faktisk regner: svinn mot
// kastbudsjett i St1s brøk, lønn mot BP i kroner, produksjonstreff som
// andel dager innenfor. En besøkende som senere ser sin egen skjerm
// skal kjenne igjen formen, ikke bare fargene.
//
// Ingen påstander om resultater hos kunder. Ingen logoer, ingen
// referanser, ingen tall vi ikke kan vise fram kilden til.
// =====================================================================

export const STASJONER = ['Nordbyen', 'Storhaug', 'Vestre', 'Åsheim', 'Kalvøy'] as const

export type Stasjonsstatus = 'ok' | 'folg' | 'stopp'

export type Stasjonsrad = {
  navn: string
  status: Stasjonsstatus
  stikkord: string
  /** Fyllgrad i den lille baren. Andel av det som er målt og innenfor. */
  andel: number
  forklaring: string
}

export const SENTRAL: Stasjonsrad[] = [
  {
    navn: 'Nordbyen', status: 'stopp', stikkord: 'svinn 15,2 %', andel: 88,
    forklaring: 'Kaster 15,2 % av omsetningen mot et krav på 13,6 %. Bakeri og påsmurt '
      + 'står for 14 632 av avviket. Salget ligger samtidig under budsjett i mars, juni '
      + 'og juli — så rommet er strammere enn kastet alene tilsier.',
  },
  {
    navn: 'Storhaug', status: 'folg', stikkord: '+27 t mot plan', andel: 72,
    forklaring: '27 timer over bemanningsplanen i uke 36. Torsdag har 2,3 timer mer enn '
      + 'kundegrunnlaget tilsier, fredag 1,8 for lite. Å flytte én vakt løser begge.',
  },
  {
    navn: 'Vestre', status: 'folg', stikkord: 'regnskap mangler', andel: 54,
    forklaring: 'Regnskapet for august er ikke lastet opp. Lønn kan ikke måles mot ramme, '
      + 'og svinnet kan vises men ikke bedømmes, før det er inne.',
  },
  {
    navn: 'Åsheim', status: 'ok', stikkord: 'innenfor på alt', andel: 96,
    forklaring: 'Innenfor på alle målte områder. Traff produksjonsplanen fem dager på rad, '
      + 'og bakeriet er innenfor på alle fem.',
  },
  {
    navn: 'Kalvøy', status: 'ok', stikkord: '+8,1 % mot i fjor', andel: 91,
    forklaring: 'Omsetning 8,1 % over samme periode i fjor. Bilvask drar mest, med 14 % '
      + 'vekst etter at vaskehallen åpnet igjen i juni.',
  },
]

export type Sporsmal = {
  q: string
  /** Verktøynavnene er de EKTE, fra `VERKTOYNAVN` i lib/ai/verktoy.ts. */
  verktoy: string[]
  svar: string
}

export const SPORSMAL: Sporsmal[] = [
  {
    q: 'Hvorfor falt salget på Nordbyen?',
    verktoy: ['hent_salg', 'hent_timesalg', 'hent_produksjonsplan', 'hent_svinn'],
    svar: 'Salget ligger **6,4 % bak** forventet. Nedgangen er nesten hele veien bakeri '
      + '(−11,8 %) og varmmat (−8,3 %) — kald drikke er opp. Timesalget viser at kundene '
      + 'er der mellom 14 og 17, men produksjonsplanen er ført ferdig 14:30 tre av fem '
      + 'dager. Det ser ut som tomme hyller, ikke færre kunder.',
  },
  {
    q: 'Hvor bruker vi for mange timer?',
    verktoy: ['hent_bemanning', 'hent_stempling', 'hent_timesalg', 'hent_bp_status'],
    svar: '**Storhaug** ligger 27 timer over planen i uke 36, og planen ligger allerede '
      + '12 timer over kundegrunnlaget på torsdag. Nordbyen og Åsheim er innenfor. Vestre '
      + 'kan ikke måles — stemplingene mangler for to dager.',
  },
  {
    q: 'Hvor taper vi mest på svinn?',
    verktoy: ['hent_svinn', 'hent_svinnbudsjett', 'hent_regnskap', 'hent_produksjonsplan'],
    svar: '**Nordbyen**, med 12 259 kroner over det forretningsplanen tåler. Bakeri og '
      + 'påsmurt står for 14 632. Men merk: salget ligger under budsjett tre av sju '
      + 'måneder, og bruttokravet står i kroner — så rommet er strammere enn kastet '
      + 'alene tilsier.',
  },
  {
    q: 'Hva bør vi prioritere neste uke?',
    verktoy: ['hent_svinn', 'hent_bemanning', 'hent_ikmat', 'hent_produksjonsplan', 'hent_avvik'],
    svar: 'Tre ting, i denne rekkefølgen: **1)** siste steking på Nordbyen — den koster '
      + 'mest og er raskest å endre. **2)** torsdagsbemanningen på Storhaug. **3)** IK-mat '
      + 'på Vestre, som mangler to dager og er et lovkrav, ikke en anbefaling.',
  },
]

export type Obsteg = {
  navn: string
  beskjed: string
  status: 'ok' | 'tynt' | 'mangler'
  merke: string
}

/** Formen er `Onboardingsteg` i lib/onboarding.ts: status per kilde, per stasjon. */
export const OPPSTART: Obsteg[] = [
  { navn: 'Kjede og stasjoner', beskjed: '5 stasjoner opprettet', status: 'ok', merke: 'Klar' },
  { navn: 'Salgsstatistikk', beskjed: '5 av 5 stasjoner · 412 dager', status: 'ok', merke: 'Klar' },
  { navn: 'Timesalg', beskjed: '5 av 5 stasjoner · 604 dager', status: 'ok', merke: 'Klar' },
  { navn: 'Forretningsplan', beskjed: 'Alle stasjoner har årgang 2026', status: 'ok', merke: 'Klar' },
  { navn: 'Stemplinger', beskjed: '3 av 5 stasjoner · 88 dager av 365', status: 'tynt', merke: 'Tynt' },
  { navn: 'Varetransaksjoner', beskjed: 'Mangler på to stasjoner', status: 'tynt', merke: 'Ufullstendig' },
  { navn: 'Regnskapsrapport', beskjed: 'Ikke lastet opp ennå', status: 'mangler', merke: 'Mangler' },
  { navn: 'Butikksjef på hver stasjon', beskjed: 'Mangler på 2 stasjoner', status: 'mangler', merke: 'Mangler' },
]

export type Boklinje = { kilde: string; tekst: string; verdi: string }

/** Formen er `RaaSignal` i lib/signaler.ts: en kilde, en måling, en verdi. */
export const BOK: Boklinje[] = [
  { kilde: 'salg', tekst: 'bakeri mot samme uke i fjor', verdi: '−11,8 %' },
  { kilde: 'timesalg', tekst: 'kunder 14–17, snitt fem dager', verdi: '+3,4 %' },
  { kilde: 'produksjon', tekst: 'siste steking ført etter 17:00', verdi: '3 av 5 dager' },
  { kilde: 'svinn', tekst: 'kast bakeri mot kastbudsjett', verdi: '+8 412 kr' },
  { kilde: 'regnskap', tekst: 'usynlig svinn, avlagt måned', verdi: '−8 241 kr' },
  { kilde: 'bemanning', tekst: 'timer over plan, uke 36', verdi: '27 t' },
  { kilde: 'vær', tekst: 'nedbør torsdag og fredag', verdi: '11 mm' },
]

export const BOK_SUM = '→ kontroller tilgjengelighet 14–17 · reduser steking etter 17:00'
