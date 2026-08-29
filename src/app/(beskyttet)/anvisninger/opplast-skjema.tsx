'use client'
import { useKvittering } from '@/components/ui/kvittering'

import { Knapp } from '@/components/ui/knapp'
import { Felt } from '@/components/ui/felt'
import type { Kvittering } from '@/lib/kvittering'
import { lastOppAnvisning } from './handlinger'

// =====================================================================
// Last opp et ark.
//
// KLIENTKOMPONENT FORDI SVARET ER POENGET. Duplikatvarselet er en
// kvittering — ««Horn med ost» finnes allerede, huk av «last opp
// likevel» hvis dette er en ny versjon» — og et rent `<form action=…>`
// har ingen plass å vise den. Da ville advarselen forsvunnet, og
// brukeren stått igjen med et skjema som så ut til å ha gjort ingenting.
//
// FILA ER STOR NOK TIL AT VENTINGEN MERKES. 20 MB over butikk-wifi tar
// tid; uten «Laster opp …» trykker folk en gang til, og da ligger arket
// der to ganger.
// =====================================================================

export function OpplastSkjema() {
  const [tilstand, kjor, venter] =
    useKvittering<Kvittering, FormData>(lastOppAnvisning, undefined)

  return (
    <form action={kjor} className="sq-skjema">
      <Felt etikett="Tittel" name="tittel" placeholder="Horn med ost og skinke" required />
      <Felt
        etikett="Kategori"
        name="kategori"
        placeholder="Påsmurt"
        hjelp="Samler anvisninger folk leter etter sammen."
      />
      <Felt
        etikett="Stikkord"
        name="stikkord"
        placeholder="horn, valmue, ost, skinke"
        hjelp="Ordene folk søker på — ingrediensen de har i hånda, ikke produktnavnet."
      />
      <Felt
        etikett="Gjelder fra"
        name="dato"
        type="date"
        hjelp="Datoen som står trykt på arket."
      />
      <Felt etikett="Erstatter ark datert" name="erstatter_dato" type="date" />

      <label className="felt">
        <span>PDF-fil</span>
        <input type="file" name="fil" accept="application/pdf,.pdf" required />
      </label>

      {/* BLOKKERER IKKE, MEN SKAL SEES. En ny versjon av samme ark har
          som regel identisk tittel — og det er nettopp da man vil laste
          opp. */}
      <label className="felt-avkryss">
        <input type="checkbox" name="likevel" value="ja" />
        <span>Last opp likevel, selv om tittelen finnes fra før</span>
      </label>

      <div className="knapperad">
        <Knapp type="submit" variant="primar" disabled={venter}>
          {venter ? 'Laster opp …' : 'Last opp'}
        </Knapp>
      </div>

      {tilstand?.feil && (
        <p className="sq-slett-feil" role="alert">{tilstand.feil}</p>
      )}
      {tilstand?.ok && (
        <p className="sq-slett-ok" role="status">{tilstand.ok}</p>
      )}
    </form>
  )
}
