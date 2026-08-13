'use client'
import { useActionState } from 'react'
import { lagreVindu, leggTilFastVakt, leggTilKrav, type Tilstand } from './handlinger'

const UKEDAGER = [
  { nr: 1, kort: 'man' }, { nr: 2, kort: 'tir' }, { nr: 3, kort: 'ons' },
  { nr: 4, kort: 'tor' }, { nr: 5, kort: 'fre' }, { nr: 6, kort: 'lør' }, { nr: 7, kort: 'søn' },
]

function Svar({ tilstand }: { tilstand: Tilstand }) {
  if (tilstand?.ok) return <span className="ok">Lagret.</span>
  if (tilstand?.feil) return <span className="feil">{tilstand.feil}</span>
  return null
}

function Ukedagsvelger() {
  return (
    <span className="ukedager">
      {UKEDAGER.map((u) => (
        <label key={u.nr}>
          <input type="checkbox" name="ukedag" value={u.nr} /> {u.kort}
        </label>
      ))}
    </span>
  )
}

const timer = (navn: string, standard: number) => (
  <select name={navn} defaultValue={standard}>
    {Array.from({ length: 25 }, (_, t) => (
      <option key={t} value={t}>{String(t).padStart(2, '0')}:00</option>
    ))}
  </select>
)

// Bemannet vindu — merk at dette er når det står folk der, ikke når døra er
// åpen. Er noen inne en time før åpning, er det den timen som skal stå.
export function VinduSkjema({ stasjonId, iDag }: { stasjonId: string; iDag: string }) {
  const [tilstand, handling, venter] = useActionState<Tilstand, FormData>(lagreVindu, undefined)
  return (
    <form action={handling} className="rutine-form">
      <input type="hidden" name="stasjon_id" value={stasjonId} />
      <select name="ukedag" defaultValue={1}>
        {UKEDAGER.map((u) => <option key={u.nr} value={u.nr}>{u.kort}</option>)}
      </select>
      {timer('fra_time', 6)}
      {timer('til_time', 23)}
      <label>
        min.{' '}
        <input name="min_bemanning" type="number" min={0} max={20} defaultValue={1} style={{ width: '3.5rem' }} />
      </label>
      <label>
        fra dato <input name="gjelder_fra" type="date" defaultValue={iDag} />
      </label>
      <button type="submit" className="liten" disabled={venter}>{venter ? '…' : 'Lagre'}</button>
      <Svar tilstand={tilstand} />
    </form>
  )
}

// Faste vakter: butikksjefen selv, NK, eller andre som alltid står.
// De går på fastlønn og belaster ikke timerammen, men dekker gulvet.
export function FastVaktSkjema({ stasjonId }: { stasjonId: string }) {
  const [tilstand, handling, venter] = useActionState<Tilstand, FormData>(leggTilFastVakt, undefined)
  return (
    <form action={handling} className="rutine-form">
      <input type="hidden" name="stasjon_id" value={stasjonId} />
      <input name="navn" placeholder="Butikksjef, NK …" required />
      <Ukedagsvelger />
      {timer('fra_time', 7)}
      {timer('til_time', 15)}
      <button type="submit" className="liten" disabled={venter}>{venter ? '…' : 'Legg til'}</button>
      <Svar tilstand={tilstand} />
    </form>
  )
}

// Krav-vinduer: timene som krever flere enn minimumsbemanningen.
// Varemottak er det vanligste, men det kan være hva som helst.
export function KravSkjema({ stasjonId }: { stasjonId: string }) {
  const [tilstand, handling, venter] = useActionState<Tilstand, FormData>(leggTilKrav, undefined)
  return (
    <form action={handling} className="rutine-form">
      <input type="hidden" name="stasjon_id" value={stasjonId} />
      <Ukedagsvelger />
      {timer('fra_time', 6)}
      {timer('til_time', 9)}
      <label>
        antall{' '}
        <input name="antall" type="number" min={2} max={20} defaultValue={2} style={{ width: '3.5rem' }} />
      </label>
      <input name="begrunnelse" placeholder="Varemottak …" />
      <button type="submit" className="liten" disabled={venter}>{venter ? '…' : 'Legg til'}</button>
      <Svar tilstand={tilstand} />
    </form>
  )
}
