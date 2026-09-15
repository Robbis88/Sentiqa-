import { kr, manedAar } from '@/lib/format'
import { Datatabell } from '@/components/ui/side'
import { Signal } from '@/components/ui/status'
import { Kildemerke } from '@/components/ui/kilde'
import { sikkerhetsgrad, type Felt, type Okonomibilde } from '@/lib/okonomi/bilde'
import { hvaBoerJegViteNaa } from '@/lib/okonomi/vite'

// =====================================================================
// LØNNSBLOKKEN OG «HVA BØR JEG VITE NÅ?»
// =====================================================================
//
// Første flate som leser `byggOkonomibilde`. Alt her er VISNING: ingen
// av tallene regnes, ingen av kildene utledes. Lov 3 sier at kilden
// følger med ut, og at flaten aldri skal finne den selv.
//
// LIGGER VED SIDEN AV SIDA, IKKE I `components/ui/`. Den har én kaller.
// Når /regnskap eller /timeregnskap skal ha samme blokk (E4b), løftes
// den — en delt komponent med én bruker er en gjetning om hva den andre
// brukeren trenger.
// =====================================================================

/**
 * Ett tall med kilden sin.
 *
 * `null` blir en tankestrek, ikke «0 kr». Et manglende tall og et tall
 * som er null er ikke det samme, og en nullverdi der det egentlig
 * mangler er den slags feil som ser rolig ut.
 */
function Tallrad({ navn, felt }: { navn: string; felt: Felt }) {
  return (
    <tr>
      <th scope="row">{navn}</th>
      <td className="tall">{felt.verdi === null ? '—' : kr.format(Math.round(felt.verdi))}</td>
      <td><Kildemerke kilde={felt.kilde} /></td>
      {/* Grunnen står i raden, ikke i en fotnote. Den som ser
          «Prognose» skal kunne se HVA anslaget bygger på uten å lete. */}
      <td className="undertittel">{felt.grunn ?? ''}</td>
    </tr>
  )
}

/**
 * Måneden blokken gjelder, i klartekst.
 *
 * =====================================================================
 * TO LØNNSROM PÅ SAMME SKJERM, MED FAKTOR 2,5 MELLOM SEG
 * =====================================================================
 *
 * Målt i produksjon 2026-09-15. Overskriften sto uten måned, og rett
 * under den viste nøkkeltallene `Lønn av brutto · august 2026` med
 * `Rommet er 346 285 kr` — mens blokken sa `Lønnsrom 137 489 kr`.
 *
 * Tallene motsa ikke hverandre. De gjaldt ULIKE MÅNEDER: nøkkeltallene
 * krever easy@work-data og faller derfor på siste avlagte måned, mens
 * blokken viser den nyeste måneden med et rom — altså den inneværende,
 * halvgåtte. Halve måneden, omtrent halve tallet.
 *
 * Uten måneden i overskriften ser det ut som systemet svarer to ting på
 * samme spørsmål. Det er den farligste formen i dette systemet: to tall
 * som ser sammenlignbare ut og ikke er det.
 *
 * ---------------------------------------------------------------------
 * LESER `bilde.maaned`, UTLEDER INGENTING
 * ---------------------------------------------------------------------
 *
 * Måneden er valgt av kallstedet og båret hele veien gjennom
 * `byggOkonomibilde`. Å regne den ut på nytt her — av dagens dato, av
 * dekningen, av noe som helst — ville gitt en andre mening om hvilken
 * periode tallene gjelder, og da kunne overskriften og radene skilt lag.
 *
 * `okonomiblokk.test.tsx` beviser at perioden kommer herfra.
 */
function periode(bilde: Okonomibilde): string {
  return manedAar.format(new Date(`${bilde.maaned}-01`))
}

/**
 * Lønnsblokken: brutto, rom, lønn og avviket mellom dem.
 *
 * ---------------------------------------------------------------------
 * SIKKERHETEN MÅLES PÅ DET BLOKKEN FAKTISK VISER
 * ---------------------------------------------------------------------
 *
 * `bilde.sikkerhet` dekker hele bildet — royalty og påvirkbar drift
 * også. De to leses ikke på /lonnskost, så de ville dratt blokken ned
 * til `lav` for en måned der alt lønnsblokken viser er avstemt.
 *
 * Derfor kalles `sikkerhetsgrad` på NØYAKTIG de feltene som rendres,
 * utledet av de samme variablene. Det er ikke en annen regel — det er
 * samme funksjon på et annet spørsmål: «hvor sikre er tallene du ser
 * her», ikke «hvor sikkert er hele måneden».
 *
 * At lista bygges av de samme `Felt`-ene som radene, og ikke skrives
 * opp for hånd ved siden av, er det som holder de to i takt.
 */
export function Lonnsblokk({ bilde }: { bilde: Okonomibilde }) {
  const rader: { navn: string; felt: Felt }[] = [
    { navn: 'Bruttofortjeneste', felt: bilde.brutto },
    { navn: 'Lønnsrom', felt: bilde.lonnsrom },
    // LØNN MOT BUDSJETT, IKKE HELE LØNNSKOSTEN.
    //
    // Sto `bilde.lonn` her, ville de tre tallene i blokka ikke gått opp:
    // ni konti over rommet, og et styringsavvik regnet av fem. Leseren
    // ville trukket det ene fra det andre og fått et annet tall enn det
    // som sto under — og på Dale i juli 2026 var forskjellen 35 330 kr,
    // nesten alt sykelønn.
    //
    // «Øvrige lønnskostnader» som egen rad hører til trinn 3. Her holder
    // det at raden ved siden av rommet er den avviket faktisk regnes av.
    { navn: 'Lønn mot budsjett', felt: bilde.styringskost },
  ]

  const avvik = bilde.styringsavvik.avvik
  const sikkerhet = sikkerhetsgrad(rader.map((r) => r.felt))

  return (
    <Datatabell tittel={`Lønnsrommet · ${periode(bilde)} · sikkerhet ${ORD_SIKKERHET[sikkerhet]}`}>
      <thead>
        <tr>
          <th>Post</th>
          <th className="tall">Kroner</th>
          <th>Kilde</th>
          <th>Grunnlag</th>
        </tr>
      </thead>
      <tbody>
        {rader.map((r) => <Tallrad key={r.navn} navn={r.navn} felt={r.felt} />)}
        <tr>
          <th scope="row">Styringsavvik</th>
          <td className="tall">
            {avvik.kroner === null ? '—' : kr.format(Math.round(avvik.kroner))}
          </td>
          <td><Kildemerke kilde={bilde.styringsavvik.kilde} /></td>
          {/* `mangler` er E2 sin egen forklaring på hvorfor det ikke lot
              seg regne. Den gjentas ikke her — den vises. */}
          <td className="undertittel">{avvik.mangler ?? ''}</td>
        </tr>
      </tbody>
    </Datatabell>
  )
}

const ORD_SIKKERHET = { hoy: 'høy', middels: 'middels', lav: 'lav' } as const

/**
 * «Hva bør jeg vite nå?»
 *
 * RENDRES IKKE NÅR DET ER TOMT. Ikke «ingen funn», ikke et grønt kort —
 * ingenting. En måned der alt er i orden skal ikke ha en overskrift som
 * lover at noe er galt. Se `Signal` i status.tsx, som sier det samme.
 */
export function HvaBoerJegVite({ bilde }: { bilde: Okonomibilde }) {
  const beskjeder = hvaBoerJegViteNaa(bilde)
  if (beskjeder.length === 0) return null

  return (
    <section className="sq-vite">
      <h3>Hva bør jeg vite nå?</h3>
      {/* REKKEFØLGEN ER `vite.ts` SIN. Den sorteres ikke her — gjorde
          flaten det, ville vi hatt to meninger om hva som haster. */}
      {beskjeder.map((b) => (
        <Signal key={b.tittel} nivaa={b.nivaa} tittel={b.tittel}>
          {b.folge}
        </Signal>
      ))}
    </section>
  )
}
