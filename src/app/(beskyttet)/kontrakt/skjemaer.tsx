'use client'
import { useActionState } from 'react'
import {
  lagreAnsattkort, lagreStandardfelt, lastOppMal, type Tilstand,
} from './handlinger'
import { FORMER, ROLLER } from '@/lib/kontrakt/felter'

function Svar({ tilstand }: { tilstand: Tilstand }) {
  if (tilstand?.ok) return <span className="ok" role="status">{tilstand.ok}.</span>
  if (tilstand?.feil) return <span className="feil" role="alert">{tilstand.feil}</span>
  return null
}

export type Ansattkort = {
  ansattNr: string
  navn: string
  fodselsdato: string | null
  stillingstittel: string | null
  skiftordning: string | null
  harRammeavtale: boolean
}

/**
 * Ansattkortet — de fire opplysningene kontrakten trenger og som ikke
 * finnes i stemplingene.
 *
 * Fødselsdatoen er ikke et skjemafelt blant andre: den avgjør om
 * u18-malen brukes, og om arbeidstidsreglene i aml. kap. 11 gjelder i
 * vaktplanen. Derfor spør vi om den her, én gang, framfor å la
 * butikksjefen huske det per kontrakt.
 */
export function AnsattkortSkjema({ stasjonId, kort }: { stasjonId: string; kort: Ansattkort }) {
  const [tilstand, handling, venter] = useActionState<Tilstand, FormData>(
    lagreAnsattkort, undefined)
  return (
    <form action={handling} className="sq-skjema">
      <input type="hidden" name="stasjon_id" value={stasjonId} />
      <input type="hidden" name="ansatt_nr" value={kort.ansattNr} />
      <input type="hidden" name="navn" value={kort.navn} />
      <div className="sq-skjema-rad">
        <label className="felt sq-smalt">
          <span>Fødselsdato</span>
          <input type="date" name="fodselsdato" defaultValue={kort.fodselsdato ?? ''} />
        </label>
        <label className="felt">
          <span>Stillingstittel</span>
          <input
            name="stillingstittel"
            defaultValue={kort.stillingstittel ?? ''}
            placeholder="Servicemedarbeider"
          />
        </label>
        <label className="felt sq-smalt">
          <span>Arbeidstid</span>
          <select name="skiftordning" defaultValue={kort.skiftordning ?? ''}>
            <option value="">Ikke satt</option>
            <option value="ordinaer">37,5 t/uke</option>
            <option value="to_skift">35,5 t/uke (to skift)</option>
          </select>
        </label>
        <label className="felt sq-smalt">
          <span>Rammeavtale</span>
          <select name="har_rammeavtale" defaultValue={kort.harRammeavtale ? 'ja' : 'nei'}>
            <option value="nei">Nei</option>
            <option value="ja">Ja</option>
          </select>
        </label>
      </div>
      <div className="knapperad">
        <button type="submit" className="liten" disabled={venter}>
          {venter ? 'Lagrer …' : 'Lagre ansattkort'}
        </button>
        <Svar tilstand={tilstand} />
      </div>
    </form>
  )
}

/** Eier laster opp Virke-malen. Ny versjon hver gang, aldri overskriving. */
export function MalSkjema() {
  const [tilstand, handling, venter] = useActionState<Tilstand, FormData>(lastOppMal, undefined)
  return (
    <form action={handling} className="sq-skjema">
      <div className="sq-skjema-rad">
        <label className="felt">
          <span>Gjelder</span>
          <select name="ansettelsesform" defaultValue="fast">
            {FORMER.map((f) => <option key={f.verdi} value={f.verdi}>{f.navn}</option>)}
          </select>
        </label>
        <label className="felt">
          <span>Rolle</span>
          <select name="rolle" defaultValue="ansatt">
            {ROLLER.map((r) => <option key={r.verdi} value={r.verdi}>{r.navn}</option>)}
          </select>
        </label>
        <label className="felt sq-smalt">
          <span>Under 18 år</span>
          <select name="mindreaarig" defaultValue="nei">
            <option value="nei">Nei</option>
            <option value="ja">Ja</option>
          </select>
        </label>
      </div>
      <label className="felt">
        <span>Malfil (.docx)</span>
        <input type="file" name="fil" accept=".docx" required />
      </label>
      <div className="knapperad">
        <button type="submit" className="liten" disabled={venter}>
          {venter ? 'Laster opp …' : 'Last opp mal'}
        </button>
        <Svar tilstand={tilstand} />
      </div>
    </form>
  )
}

/**
 * Kjedens standardfelt. Fylles én gang og går inn i hver kontrakt.
 *
 * Feltnavnene er malens egne klammer — vi finner dem i fila framfor å
 * hardkode dem, så en ny Virke-versjon ikke krever kodeendring.
 */
export function StandardfeltSkjema(
  { felt }: { felt: { navn: string; forklaring: string; verdi: string }[] },
) {
  const [tilstand, handling, venter] = useActionState<Tilstand, FormData>(
    lagreStandardfelt, undefined)
  return (
    <form action={handling} className="sq-skjema">
      {felt.map((f) => (
        <label className="felt" key={f.navn}>
          <span>{f.forklaring}</span>
          <input name={`felt.${f.navn}`} defaultValue={f.verdi} placeholder={f.navn} />
        </label>
      ))}
      <div className="knapperad">
        <button type="submit" className="liten" disabled={venter}>
          {venter ? 'Lagrer …' : 'Lagre'}
        </button>
        <Svar tilstand={tilstand} />
      </div>
    </form>
  )
}
