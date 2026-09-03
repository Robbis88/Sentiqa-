'use client'
import { useState, useTransition } from 'react'
import { Knapp } from '@/components/ui/knapp'
import { torrkjorUkebrief, type Torrsvar } from './handlinger'

// =====================================================================
// «Hvem ville fått brevet?»
//
// Den finnes for at mandagens utsending ikke skal være første gang noen
// ser hvem den treffer. Ingenting sendes, ingenting logges.
//
// Det viktigste den viser er ikke mottakerne — det er stasjonene UTEN
// mottaker. En stasjon uten butikksjef får ingenting mandag, og det
// finnes ingen annen flate som sier fra om det.
// =====================================================================

export function Torrkjor({ uke }: { uke: string }) {
  const [venter, start] = useTransition()
  const [svar, setSvar] = useState<Torrsvar | null>(null)

  return (
    <div className="ub-torr">
      <Knapp
        onClick={() => start(async () => {
          setSvar(null)
          setSvar(await torrkjorUkebrief(uke))
        })}
        disabled={venter}
      >
        {venter ? 'Sjekker …' : 'Hvem ville fått brevet?'}
      </Knapp>

      {svar && !svar.ok && <p className="feil" role="alert">{svar.feil}</p>}

      {svar?.ok && (
        <>
          <p className="undertittel" role="status">
            Ingenting ble sendt. Dette er hva mandagens utsending ville gjort.
          </p>
          <ul className="ub-torr-liste">
            {svar.rader.map((r) => {
              const uten = r.mottakere === 0
              return (
                <li key={r.stasjonId} className={uten ? 'ub-torr-rad ub-torr-tom' : 'ub-torr-rad'}>
                  <span className="ub-funn-tittel">{r.navn}</span>
                  <span className="ub-funn-tall">
                    {uten ? 'ingen mottaker' : `${r.mottakere} mottaker${r.mottakere === 1 ? '' : 'e'}`}
                  </span>
                  {r.meldinger.length > 0 && (
                    <ul className="ub-torr-detalj">
                      {r.meldinger.map((m) => <li key={m}>{m}</li>)}
                    </ul>
                  )}
                </li>
              )
            })}
          </ul>
        </>
      )}
    </div>
  )
}
