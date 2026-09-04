import type { Brukerrolle } from '@/lib/auth/typer'

// =====================================================================
// Navigasjonen som data.
//
// Lå tidligere i layout.tsx. Flyttet hit av én grunn: vakthunden må
// kunne lese den uten å bygge appen, og den må kunne se BÅDE menyen og
// fanene for å svare på det egentlige spørsmålet —
//
//   «kommer alle fortsatt fram til alt de kom fram til før?»
//
// Uten fanegruppene som data ville en side som forsvinner fra menyen se
// ut som tapt tilgang. Med dem kan vakthunden regne ut det som faktisk
// betyr noe: nåbarhet = meny ∪ faner.
// =====================================================================

export type Punkt = { sti: string; tekst: string; roller: Brukerrolle[] }

const A: Brukerrolle = 'retailer_admin'
const B: Brukerrolle = 'butikksjef'
const T: Brukerrolle = 'butikkbruker_tablet'
const P: Brukerrolle = 'plattform_redaktor'

/**
 * Sider som hører sammen, vist som faner inne på siden.
 *
 * Regelen for hva som får bli en gruppe: fanene må svare på SAMME
 * spørsmål fra ulike vinkler. «Rutiner» sett som min liste, som
 * oversikt, som oppsett — samme sak, tre vinkler. Salg og bemanning er
 * derimot to spørsmål, og hører ikke sammen selv om begge er tall.
 *
 * Høyst fem faner. Over det er en gruppe bare en meny med en annen form,
 * og da har man flyttet problemet uten å løse det.
 *
 * Rekkefølgen er den man leser dem i: det man gjør oftest først,
 * oppsett sist.
 */
export type Fanegruppe = { tittel: string; faner: Punkt[] }

export const FANEGRUPPER: Fanegruppe[] = [
  {
    tittel: 'Rutiner',
    faner: [
      { sti: '/rutiner', tekst: 'På vakt', roller: [T] },
      { sti: '/rutiner/min', tekst: 'Min sjekkliste', roller: [A, B] },
      { sti: '/rutiner/oversikt', tekst: 'Oversikt', roller: [A, B] },
      { sti: '/rutiner/oppsett', tekst: 'Oppsett', roller: [B] },
    ],
  },
  {
    tittel: 'Produksjon',
    faner: [
      { sti: '/produksjonsplan', tekst: 'Planen', roller: [A, B] },
      { sti: '/produksjonsplan/treffsikkerhet', tekst: 'Traff vi?', roller: [A, B] },
    ],
  },
  {
    tittel: 'IK-mat',
    faner: [
      { sti: '/ikmat', tekst: 'Kontroll og avvik', roller: [A, B, T] },
      { sti: '/ikmat/oppsett', tekst: 'Oppsett', roller: [A, B] },
    ],
  },
  {
    tittel: 'Salg',
    faner: [
      { sti: '/salg', tekst: 'Dag for dag', roller: [A, B] },
      { sti: '/timesalg', tekst: 'Time for time', roller: [A, B] },
      { sti: '/salgsprognose', tekst: 'Prognose', roller: [A, B] },
    ],
  },
  {
    tittel: 'Puls',
    faner: [
      { sti: '/puls', tekst: 'Målinger', roller: [A, B] },
      { sti: '/puls/sporsmal', tekst: 'Spørsmål', roller: [A, B] },
    ],
  },
  {
    tittel: 'Anerkjennelse',
    faner: [
      { sti: '/skills', tekst: 'Skills-score', roller: [A, B] },
      { sti: '/merker', tekst: 'Merker', roller: [A, B, T] },
      { sti: '/konkurranser', tekst: 'Konkurranser', roller: [A, B] },
      { sti: '/premier', tekst: 'Premiesaldo', roller: [A, B] },
    ],
  },
  {
    tittel: 'Ansatte',
    faner: [
      { sti: '/ansatte', tekst: 'Folkene', roller: [A, B] },
      { sti: '/kontrakt', tekst: 'Arbeidsavtaler', roller: [A, B] },
    ],
  },
]

/** Gruppen en sti hører til — også for dypere sider som `/rutiner/oppsett/[id]`. */
export function gruppeFor(sti: string): Fanegruppe | null {
  let beste: Fanegruppe | null = null
  let lengde = -1
  for (const g of FANEGRUPPER) {
    for (const f of g.faner) {
      if ((sti === f.sti || sti.startsWith(`${f.sti}/`)) && f.sti.length > lengde) {
        beste = g
        lengde = f.sti.length
      }
    }
  }
  return beste
}

/**
 * Nettbrettets egen bunnavigasjon.
 *
 * Laa hardkodet i tablet-nav.tsx og var derfor USYNLIG for vakthunden:
 * den paastod aa maale naabarhet, men saa bare sidemenyen. /anvisninger
 * og /lenker naas av nettbrettet HERFRA, ikke fra menyen — og et tap der
 * ville gaatt upaaaktet hen.
 */
export const TABLETMENY: Punkt[] = [
  { sti: '/oversikt', tekst: 'I dag', roller: [T] },
  { sti: '/rutiner', tekst: 'Rutiner', roller: [T] },
  { sti: '/anvisninger', tekst: 'Hjelp', roller: [T] },
]

/**
 * Rutene nettbrettet naar UTEN aa vaere en fane.
 *
 * FASITEN LOEY, OG DEN LOEY I VAAR FAVOER. Fire faner og fem fliser var
 * ni innganger til aatte ruter — men nettbrettet brukte tretten.
 * '/produksjonsplan' sto i koen hver dag, '/varsler' henger i bjella,
 * '/ikmat/maaling' er der temperaturen faktisk skrives, og
 * '/sjekkpunkt' er koens hoyest prioriterte rad. Ingen av dem sto med
 * rollen [T] noe sted, og naabart() kunne derfor ikke se dem.
 *
 * Foelgen var ikke at de var utilgjengelige. Foelgen var at de kunne
 * FORSVINNE uten at vakthunden bjeffet — og en vakt som ikke ser en
 * rute, ser noyaktig ut som en vakt som ikke finner noe galt.
 *
 * Dette er derfor ikke seks nye evner. Det er seks evner som endelig
 * telles. '/vaar-stasjon' er den eneste virkelig nye flata.
 */
export const NETTBRETTFLATER: Punkt[] = [
  // Sekundaerflata: engasjement og innsikt, naadd som EN rad fra «I dag».
  // Ikke en fjerde modus — derfor ikke i TABLETMENY.
  { sti: '/vaar-stasjon', tekst: 'Vår stasjon', roller: [T] },
  // Naas fra koen og fra fremdriften paa «I dag».
  { sti: '/produksjonsplan', tekst: 'Produksjon', roller: [T] },
  // Koens hoyest prioriterte rad.
  { sti: '/sjekkpunkt', tekst: 'Sjekkpunkter', roller: [T] },
  // Der temperaturen faktisk skrives. Naas fra /rutiner og /ikmat.
  { sti: '/ikmat/maaling', tekst: 'IK-mat måling', roller: [T] },
  // Bjella i toppstripa.
  { sti: '/varsler', tekst: 'Varsler', roller: [T] },
  // ARBEIDSDAGEN, IKKE ENHETEN. Vakt-PIN-en i toppstripa sier hvem som
  // holder nettbrettet (informasjonskapsel, 12 t, ingen skriving).
  // Stemplingen skriver lonnsgrunnlag. To evner, ikke en — se
  // stempling/handlinger.ts. Naas som kontekstuell rad paa «I dag».
  { sti: '/stempling', tekst: 'Stemple inn og ut', roller: [T] },
  // Foten under «Hjelp». Laa i TABLETMENY som egen fane til bolge 5.
  { sti: '/lenker', tekst: 'Lenker', roller: [T] },
]

// =====================================================================
// Menyen
// =====================================================================
// Gruppert etter hva brukeren HOLDER PÅ MED, ikke etter hvilken modul
// noe hører til. En butikksjef som lurer på om produksjonsplanen traff,
// tenker ikke «det er analyse».
//
// Sider som ligger i en fanegruppe står med gruppens FØRSTE fane som
// menypunkt. De andre nås som faner — ikke som egne linjer i menyen.
// Menyen faller fra 48 punkter til 36 uten at én rute forsvinner.

// Omgruppert 2026-08-19 (trinn 02). INGEN rute flyttet inn eller ut av
// systemet — `naabart()` gir nøyaktig samme mengde per rolle som før, og
// vakthunden feller hvis det ikke stemmer. Det som endret seg er hvilken
// bås hver rute står i.
//
// «Resultater» var den gamle sekkeposten. Den blandet tre spørsmål:
// hvor mye solgte vi, hva tjente vi, og hva skal folk ha betalt. Nå er
// pengene inn (SALG) skilt fra forståelsen av dem (INNSIKT), og lønn
// ligger der den hører hjemme — hos folkene.
//
// «Mer» het ingenting og betydde ingenting. Alt som lå der var oppsett.

export const SEKSJONER: { tittel: string; punkter: Punkt[] }[] = [
  {
    // Uten tittel med vilje: startpunktet skal alltid være synlig, ikke
    // ligge sammenleggbart bak en gruppe man må åpne.
    tittel: '',
    punkter: [
      { sti: '/oversikt', tekst: 'Hjem', roller: [A, B] },
    ],
  },
  {
    // Det som skjer på stasjonen nå og de nærmeste dagene. Alt her har
    // en handling knyttet til seg i dag eller i morgen.
    tittel: 'Drift',
    punkter: [
      { sti: '/produksjonsplan', tekst: 'Produksjon', roller: [A, B] },
      { sti: '/utsolgt', tekst: 'Mulig utsolgt', roller: [A, B] },
      { sti: '/bemanning', tekst: 'Bemanning', roller: [A, B] },
      { sti: '/oppgaver', tekst: 'Oppgaver', roller: [A, B] },
      { sti: '/rutiner', tekst: 'Rutiner', roller: [T] },
      { sti: '/rutiner/min', tekst: 'Rutiner', roller: [A, B] },
      { sti: '/sjekkpunkt', tekst: 'Sjekkpunkt', roller: [A, B] },
      { sti: '/ikmat', tekst: 'IK-mat & avvik', roller: [A, B, T] },
      { sti: '/svinn', tekst: 'Svinn', roller: [A, B] },
      { sti: '/arrangementer', tekst: 'Arrangementer', roller: [A] },
    ],
  },
  {
    // Pengene inn. Tre vinkler på samme tall: dag, time, framover.
    tittel: 'Salg',
    punkter: [
      { sti: '/salg', tekst: 'Salg', roller: [A, B] },
      { sti: '/timesalg', tekst: 'Timesalg', roller: [A, B] },
      { sti: '/salgsprognose', tekst: 'Prognose', roller: [A, B] },
    ],
  },
  {
    // Menneskene: hva de skal fokusere på, hva de sier, hva de kan — og
    // hva de skal ha betalt. Lønnsgrunnlaget lå under «Resultater», men
    // den som åpner det gjør en oppgave om folk, ikke en analyse.
    tittel: 'Team',
    punkter: [
      { sti: '/ansatte', tekst: 'Ansatte', roller: [A, B] },
      { sti: '/lonn', tekst: 'Lønnsgrunnlag', roller: [A, B] },
      { sti: '/fokus', tekst: 'Fokus', roller: [A, B] },
      { sti: '/tilbakemeldinger', tekst: 'Tilbakemeldinger', roller: [A, B] },
      { sti: '/meldinger', tekst: 'Tablet-meldinger', roller: [A, B] },
      { sti: '/opplaring', tekst: 'Opplæring', roller: [B] },
      { sti: '/skills', tekst: 'Anerkjennelse', roller: [A, B] },
      { sti: '/merker', tekst: 'Merker', roller: [T] },
      { sti: '/puls', tekst: 'Puls', roller: [A, B] },
      { sti: '/lederstotte', tekst: 'Lederstøtte', roller: [A, B] },
      { sti: '/mine-opplysninger', tekst: 'Slik måler vi', roller: [A, B, T] },
    ],
  },
  {
    // Å forstå tallene, ikke å samle dem inn. Alt her svarer på
    // «hvorfor ble det slik», og ingenting krever en handling i dag.
    tittel: 'Innsikt',
    punkter: [
      { sti: '/businessplan', tekst: 'Businessplan', roller: [A, B] },
      // Eierens alene: BP-en baerer royaltysats, fastloenn og kjedens
      // kostnadsramme. Butikksjefen ser sin maanedsramme i /bemanning.
      { sti: '/businessplan/sammenlign', tekst: 'Sammenlign BP', roller: [A] },
      { sti: '/regnskap', tekst: 'Regnskap', roller: [A, B] },
      { sti: '/analyse', tekst: 'Regnskapsanalyse', roller: [A] },
      { sti: '/timeregnskap', tekst: 'Timeregnskap', roller: [A] },
      { sti: '/maaling', tekst: 'Måling', roller: [A, B] },
      { sti: '/kasserer', tekst: 'Kasserer', roller: [A, B] },
      { sti: '/dekning', tekst: 'Datadekning', roller: [A] },
    ],
  },
  {
    // Oppsett og innhold som endres sjelden. Het «Mer», som ikke sa noe.
    tittel: 'Innstillinger',
    punkter: [
      { sti: '/stasjoner', tekst: 'Stasjoner', roller: [A] },
      { sti: '/brukere', tekst: 'Brukere', roller: [A] },
      { sti: '/import', tekst: 'Import', roller: [A] },
      { sti: '/persondata', tekst: 'Persondata', roller: [A, B] },
      { sti: '/nyheter', tekst: 'Nyheter', roller: [A, B, T] },
      { sti: '/anvisninger', tekst: 'Anvisninger', roller: [A, B] },
    ],
  },
  {
    tittel: 'Plattform',
    punkter: [
      { sti: '/plattform', tekst: 'Plattform-oversikt', roller: [P] },
      { sti: '/trafikk', tekst: 'Trafikk', roller: [P] },
      { sti: '/kampanjer', tekst: 'Kampanjer', roller: [P] },
      { sti: '/redaktor', tekst: 'Publisering', roller: [P] },
      { sti: '/kunnskap', tekst: 'Kunnskapsbase', roller: [P] },
    ],
  },
]

/**
 * Alt en rolle kan nå — meny og faner sammen.
 *
 * Dette er det vakthunden måler mot. Å flytte en side fra menyen til en
 * fane er en omorganisering; å ta den ut av begge er et tap.
 */
export function naabart(rolle: Brukerrolle): string[] {
  const ut = new Set<string>()
  for (const s of SEKSJONER) {
    for (const p of s.punkter) if (p.roller.includes(rolle)) ut.add(p.sti)
  }
  for (const g of FANEGRUPPER) {
    for (const f of g.faner) if (f.roller.includes(rolle)) ut.add(f.sti)
  }
  for (const p of TABLETMENY) if (p.roller.includes(rolle)) ut.add(p.sti)
  for (const p of NETTBRETTFLATER) if (p.roller.includes(rolle)) ut.add(p.sti)
  return [...ut].sort()
}
