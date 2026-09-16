import { kr } from '@/lib/format'
import { Signal } from '@/components/ui/status'
import { Kildemerke } from '@/components/ui/kilde'
import type { Felt, Okonomibilde } from '@/lib/okonomi/bilde'
import { hvaBoerJegViteNaa } from '@/lib/okonomi/vite'

// =====================================================================
// DE TO DELENE AV ØKONOMIBILDET SOM HAR MER ENN ÉN FLATE
// =====================================================================
//
// De sto i `lonnskost/okonomiblokk.tsx`, med en lapp på seg:
//
//   «LIGGER VED SIDEN AV SIDA, IKKE I `components/ui/`. Den har én
//    kaller. Når /regnskap eller /timeregnskap skal ha samme blokk
//    (E4b), løftes den — en delt komponent med én bruker er en gjetning
//    om hva den andre brukeren trenger.»
//
// «Min måned» er den andre brukeren, og gjetningen er ikke lenger en
// gjetning: begge flatene trenger nøyaktig ett tall med kilden sin, og
// nøyaktig én liste over hva som er verdt å vite.
//
// `Lonnsblokk` ble stående igjen i sidemappa. Den har fortsatt én
// kaller, og samme regel gjelder den.
//
// ALT HER ER VISNING. Ingen av tallene regnes, ingen av kildene utledes.
// Lov 3 i `bilde.ts`: kilden følger med ut, og flaten finner den aldri
// selv.
// =====================================================================

/**
 * Ett tall med kilden sin.
 *
 * `null` blir en tankestrek, ikke «0 kr». Et manglende tall og et tall
 * som er null er ikke det samme, og en nullverdi der det egentlig
 * mangler er den slags feil som ser rolig ut.
 */
export function Tallrad({ navn, felt }: { navn: string; felt: Felt }) {
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
 * «Hva bør jeg vite nå?»
 *
 * RENDRES IKKE NÅR DET ER TOMT. Ikke «ingen funn», ikke et grønt kort —
 * ingenting. En måned der alt er i orden skal ikke ha en overskrift som
 * lover at noe er galt. Se `Signal` i status.tsx, som sier det samme.
 *
 * DØMMER IKKE. `vite.ts` eier både hva som sies og i hvilken rekkefølge;
 * gjorde flaten sin egen sortering, ville vi hatt to meninger om hva som
 * haster.
 */
export function HvaBoerJegVite({
  bilde,
  tittel = 'Hva bør jeg vite nå?',
}: {
  bilde: Okonomibilde
  /** Overskriften. «Min måned» setter sin egen; blokken velger den ikke. */
  tittel?: string
}) {
  const beskjeder = hvaBoerJegViteNaa(bilde)
  if (beskjeder.length === 0) return null

  return (
    <section className="sq-vite">
      <h3>{tittel}</h3>
      {beskjeder.map((b) => (
        <Signal key={b.tittel} nivaa={b.nivaa} tittel={b.tittel}>
          {b.folge}
        </Signal>
      ))}
    </section>
  )
}
