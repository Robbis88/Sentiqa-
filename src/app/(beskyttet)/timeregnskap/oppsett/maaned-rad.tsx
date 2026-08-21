'use client'
import { useActionState } from 'react'
import { settArsverk, settDekning, type DekningTilstand } from './handlinger'
import { forklarDekning, timetall, type Dekning } from '@/lib/bemanning/lederdekning'

// =====================================================================
// Én måned, og én stasjons årsverk — begge med svar.
//
// HVORFOR DISSE ER KLIENTKOMPONENTER. Første utgave var rene
// server-skjemaer uten tilbakemelding: handlingen returnerte `void`, og
// en avvist lagring så nøyaktig ut som en vellykket. Knappen ble
// trykket, siden lastet, ingenting hadde skjedd — og det er umulig å
// feilsøke fordi det ikke finnes noe å se.
//
// `useActionState` koster en klientkomponent. Det er verdt det: en
// innstilling som styrer 141,25 timer i måneden må kunne svare på om
// den ble lagret.
// =====================================================================

/** Kvitteringen. Grønn er kort, rød blir stående til neste forsøk. */
function Svar({ tilstand }: { tilstand: DekningTilstand }) {
  if (!tilstand) return null
  if (tilstand.feil) {
    return <p className="dekning-feil" role="alert">{tilstand.feil}</p>
  }
  return <p className="dekning-lagret" role="status">Lagret</p>
}

export function ArsverkSkjema(
  { stasjonId, ar, timer, forslag }:
  { stasjonId: string; ar: number; timer: number; forslag: number },
) {
  const [tilstand, handling, venter] =
    useActionState<DekningTilstand, FormData>(settArsverk, undefined)

  return (
    <div className="dekning-arsverk-boks">
      <form action={handling} className="dekning-arsverk">
        <input type="hidden" name="stasjon_id" value={stasjonId} />
        <input type="hidden" name="ar" value={ar} />
        <label>
          Årsverket St1 trakk fra
          <input
            type="text" name="timer" inputMode="decimal"
            defaultValue={timetall(timer || 1695)}
          />
        </label>
        <button type="submit" className="sq-knapp" disabled={venter}>
          {venter ? 'Lagrer …' : 'Lagre'}
        </button>
        <span className={timer > 0 ? 'dekning-hint' : 'dekning-mangler'}>
          {timer > 0
            ? `Forslag full måned: ${timetall(forslag)} timer`
            : `Ikke satt — forslaget bruker ${timetall(forslag)} som standard`}
        </span>
      </form>
      <Svar tilstand={tilstand} />
    </div>
  )
}

export function ManedRad(
  { stasjonId, butikknummer, stasjonsnavn, ar, maned, manedsnavn,
    dekning, timerTilbake, notat, forslag }:
  {
    stasjonId: string; butikknummer: string; stasjonsnavn: string
    ar: number; maned: number; manedsnavn: string
    dekning: Dekning; timerTilbake: number | null; notat: string | null
    forslag: number
  },
) {
  const [tilstand, handling, venter] =
    useActionState<DekningTilstand, FormData>(settDekning, undefined)

  const merke = `${butikknummer} ${stasjonsnavn}, ${manedsnavn}`

  return (
    <li className={`dekning-mnd dekning-${dekning}`}>
      <form action={handling} className="dekning-rad">
        <input type="hidden" name="stasjon_id" value={stasjonId} />
        <input type="hidden" name="ar" value={ar} />
        <input type="hidden" name="maned" value={maned} />

        <span className="dekning-mnd-navn">{manedsnavn}</span>

        {/* MÅNEDSNAVNET ER EN SPAN, ikke en label — det gjelder hele
            raden. Uten aria-label hørte en skjermleser «velg» tolv
            ganger per stasjon. Stasjonen står med: det er fem seksjoner
            på siden, og «Mars» alene er ikke et sted. */}
        <select
          name="svar"
          aria-label={`${merke}: lederdekning`}
          defaultValue={
            dekning === 'fastlonnet' ? 'ja'
              : dekning === 'ikke_fastlonnet' ? 'nei' : 'ukjent'
          }
        >
          <option value="ukjent">Ikke tatt stilling</option>
          <option value="ja">Fastlønnet butikksjef på plass</option>
          <option value="nei">Nei — timelønn, permisjon eller vakanse</option>
        </select>

        {/* TIMETALLET FYLLES ALDRI INN AUTOMATISK. Forslaget står som
            tekst i plassholderen. Det var automatikken i 0119 som ga
            Laguneparken 953 timer uten at noen hadde tatt stilling — og
            et forhåndsutfylt felt er automatikk med et ekstra klikk. */}
        <input
          type="text" name="timer_tilbake" inputMode="decimal"
          className="dekning-timer"
          defaultValue={timerTilbake != null ? timetall(timerTilbake) : ''}
          aria-label={`${merke}: timer lagt tilbake`}
          placeholder={`0 — full måned ${timetall(forslag)}`}
          maxLength={7}
        />

        <input
          type="text" name="notat" defaultValue={notat ?? ''}
          aria-label={`${merke}: notat`}
          placeholder="Hvorfor — «Sissel på timelønn»"
          maxLength={120}
        />

        <button
          type="submit" className="sq-knapp sq-dempet" disabled={venter}
          aria-label={`Lagre ${manedsnavn} for ${stasjonsnavn}`}
        >
          {venter ? 'Lagrer …' : 'Lagre'}
        </button>
      </form>

      {/* HVA RADEN GJØR, i klartekst. Den som leser dette om et halvt år
          skal se konsekvensen, ikke gjette den. */}
      <p className="dekning-forklaring">{forklarDekning(dekning, timerTilbake)}</p>
      <Svar tilstand={tilstand} />
    </li>
  )
}
