'use client'
import { useKvittering } from '@/components/ui/kvittering'

import { settLangeUker, type Tilstand } from './handlinger'

// =====================================================================
// «JOBBER LANGE UKER ETTER AVTALE»
//
// Navnet er valgt for den som krysser av, ikke for lovteksten.
// «Gjennomsnittsberegning» er ordet i aml. § 10-5 og står i forklaringen
// — men en butikksjef som skal peke ut tre av ti ansatte skal slippe å
// slå opp et begrep for å tørre å svare.
//
// «Uke på / uke av» ble vurdert, siden det er ordene de bruker selv. Det
// ble forkastet: har én stasjon en to-på-en-av-turnus, ser avkryssingen
// ut som den ikke gjelder, og da blir den ikke satt — og varselet fyrer
// feil igjen. Eksempelet står i forklaringen i stedet.
//
// HVA HAKEN FAKTISK GJØR står i teksten, og det er med vilje: den
// fjerner ikke grensen, den bytter den. Uten den setningen ser den ut
// som et fritak, og et fritak krysser man av mer lettvint.
// =====================================================================

export function LangeUker(
  { stasjonId, ansattNr, navn, verdi }:
  { stasjonId: string; ansattNr: string; navn: string; verdi: boolean },
) {
  const [tilstand, handling, venter] = useKvittering<Tilstand, FormData>(
    settLangeUker, undefined)
  return (
    <form action={handling}>
      <input type="hidden" name="stasjon_id" value={stasjonId} />
      <input type="hidden" name="ansatt_nr" value={ansattNr} />
      <input type="hidden" name="navn" value={navn} />
      <label className="sq-hake">
        <input
          type="checkbox"
          name="lange_uker"
          defaultChecked={verdi}
          disabled={venter}
          // Lagrer ved endring, ikke med egen knapp: står det ti i
          // lista, er ti knappetrykk ti anledninger til å hoppe over en.
          onChange={(e) => e.currentTarget.form?.requestSubmit()}
          // Navnet står i raden ved siden av, men en skjermleser leser
          // ikke raden — uten dette er det «avkrysningsboks» ti ganger.
          aria-label={`Jobber lange uker etter avtale: ${navn}`}
        />
        <span>Lange uker etter avtale</span>
      </label>
      {tilstand?.feil && <p className="sq-feil">{tilstand.feil}</p>}
    </form>
  )
}
