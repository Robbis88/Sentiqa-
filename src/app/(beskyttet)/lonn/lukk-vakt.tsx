'use client'
import { useActionState, useState } from 'react'
import { lukkVakt, annullerHendelse, type RettelseSvar } from './rettelser'

// =====================================================================
// Å rette en glemt utstempling.
//
// To utveier, og de er ikke like: enten jobbet hun og glemte å stemple
// ut — da oppgir vi tiden — eller så stemplet hun inn ved en feil, og da
// finnes det ingen vakt. Å tvinge det andre tilfellet gjennom det første
// ville lagt inn timer hun ikke jobbet.
//
// Begrunnelsen er påkrevd i begge. Den som ser lønnsgrunnlaget et halvt
// år senere skal vite forskjell på «ringte og oppga 22:00» og «systemet
// var nede».
// =====================================================================

type Props = {
  innId: string
  navn: string
  /** ISO-tidspunkt for innstemplingen. */
  siden: string
  /** Datoen innstemplingen hører til, i norsk tid — forhåndsvalgt. */
  dato: string
}

export function LukkVakt({ innId, navn, siden, dato }: Props) {
  const [valg, settValg] = useState<'lukk' | 'annuller'>('lukk')
  const [lukkSvar, lukkHandling, lukkVenter] =
    useActionState<RettelseSvar, FormData>(lukkVakt, undefined)
  const [annSvar, annHandling, annVenter] =
    useActionState<RettelseSvar, FormData>(annullerHendelse, undefined)

  const svar = valg === 'lukk' ? lukkSvar : annSvar
  if (svar?.ok) {
    return <p className="ok">Rettet. Timene er regnet om.</p>
  }

  return (
    <div className="rettelse">
      <p className="undertittel">
        {navn} stemplet inn {new Date(siden).toLocaleString('nb-NO', {
          timeZone: 'Europe/Oslo', day: 'numeric', month: 'long',
          hour: '2-digit', minute: '2-digit',
        })} og aldri ut.
      </p>

      <fieldset className="rettelse-valg">
        <legend>Hva skjedde?</legend>
        <label>
          <input
            type="radio" name="slag" value="lukk"
            checked={valg === 'lukk'} onChange={() => settValg('lukk')}
          />
          <span>Hun jobbet, men glemte å stemple ut</span>
        </label>
        <label>
          <input
            type="radio" name="slag" value="annuller"
            checked={valg === 'annuller'} onChange={() => settValg('annuller')}
          />
          <span>Hun stemplet inn ved en feil og jobbet ikke</span>
        </label>
      </fieldset>

      {valg === 'lukk' ? (
        <form action={lukkHandling} className="rutine-form">
          <input type="hidden" name="inn_id" value={innId} />
          <label className="felt sq-smalt"><span>Dato hun gikk</span>
            <input type="date" name="dato" defaultValue={dato} required />
          </label>
          <label className="felt sq-smalt"><span>Klokkeslett</span>
            <input type="time" name="klokke" required />
          </label>
          <label className="felt"><span>Hvorfor</span>
            <input
              name="begrunnelse" required minLength={5}
              placeholder="Glemte å stemple ut, ringte og oppga tiden"
            />
          </label>
          <button type="submit" className="sq-knapp primar" disabled={lukkVenter}>
            {lukkVenter ? 'Lagrer …' : 'Lukk vakta'}
          </button>
          {lukkSvar?.feil ? <span className="feil">{lukkSvar.feil}</span> : null}
        </form>
      ) : (
        <form action={annHandling} className="rutine-form">
          <input type="hidden" name="hendelse_id" value={innId} />
          <label className="felt"><span>Hvorfor</span>
            <input
              name="begrunnelse" required minLength={5}
              placeholder="Stemplet inn ved en feil, gikk hjem igjen"
            />
          </label>
          <p className="undertittel">
            Innstemplingen blir stående med en merknad om at den ikke teller.
            Ingenting slettes.
          </p>
          <button type="submit" className="sq-knapp" disabled={annVenter}>
            {annVenter ? 'Lagrer …' : 'Annuller innstemplingen'}
          </button>
          {annSvar?.feil ? <span className="feil">{annSvar.feil}</span> : null}
        </form>
      )}
    </div>
  )
}
