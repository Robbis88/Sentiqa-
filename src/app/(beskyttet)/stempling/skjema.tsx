'use client'
import { useActionState, useEffect, useRef } from 'react'
import { stemple, type StemplingSvar } from './handlinger'

// =====================================================================
// Stemple-skjermen.
//
// «Se → forstå → gjør → ferdig.» To felter og én knapp. Alt er stort
// nok til hansker: 64px felter og en knapp på 72, over de 48 som gjelder
// ellers på nettbrettet - dette er skjermens eneste oppgave, og den
// treffes ofte av folk som har noe i den andre hånda.
//
// Kvitteringen er stor og sier NAVN og KLOKKESLETT. «Lagret» er ikke
// nok: hun skal kunne se at det ble riktig person og riktig tid uten å
// lete, og oppdage med en gang hvis hun tastet naboens nummer.
// =====================================================================

export function StemplingSkjema() {
  const [svar, handling, venter] = useActionState<StemplingSvar | undefined, FormData>(
    stemple, undefined,
  )
  const skjema = useRef<HTMLFormElement>(null)
  const nummerfelt = useRef<HTMLInputElement>(null)

  // Tømmer og setter fokus tilbake etter et vellykket trykk, så neste
  // person kan taste med én gang. Uten dette står forrige persons nummer
  // igjen i feltet — og da stempler nestemann henne ut.
  useEffect(() => {
    if (svar?.ok) {
      skjema.current?.reset()
      nummerfelt.current?.focus()
    }
  }, [svar])

  return (
    <>
      <form ref={skjema} action={handling} className="stempling-skjema">
        <label className="felt">
          <span>Ansattnummer</span>
          <input
            ref={nummerfelt}
            name="ansatt_nr"
            inputMode="numeric"
            autoComplete="off"
            required
            aria-describedby="stempling-hjelp"
          />
        </label>

        <label className="felt">
          <span>PIN</span>
          <input
            name="pin"
            type="password"
            inputMode="numeric"
            autoComplete="off"
            required
            minLength={4}
            maxLength={6}
          />
        </label>

        <button type="submit" className="stempling-knapp primar" disabled={venter}>
          {venter ? 'Registrerer …' : 'Stemple'}
        </button>

        <p id="stempling-hjelp" className="undertittel">
          Nummeret står på lønnsslippen din. Samme knapp brukes til å stemple
          både inn og ut — systemet vet hva som står for tur.
        </p>
      </form>

      {/* aria-live: en skjermleser skal lese kvitteringen uten at noen
          flytter fokus dit. */}
      <div aria-live="polite">
        {svar?.ok && (
          <div className="stempling-kvittering">
            <p className="stempling-retning">
              {svar.navn} stemplet {svar.retning === 'inn' ? 'INN' : 'UT'}
            </p>
            <p className="stempling-klokke">{svar.klokkeslett}</p>
            {svar.advarsel && <p className="notis">{svar.advarsel}</p>}
          </div>
        )}

        {svar?.feil && (
          <div className="stempling-feil" role="alert">
            <p>{svar.feil}</p>
          </div>
        )}
      </div>
    </>
  )
}
