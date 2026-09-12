'use client'
import { HandlingKnapp } from '@/components/ui/handling-knapp'
import { avvisPlan, slippPlan } from './handlinger'

// =====================================================================
// Ett utkast, med de to valgene eieren har.
//
// SLIPP OG AVVIS STÅR SIDE OM SIDE. En plan man bare kan slippe har
// egentlig ingen godkjenning — da er knappen en kvittering på noe som
// allerede er bestemt. Å kunne si nei er det som gjør ja til et valg.
//
// En avvist plan blir stående som avvist, ikke som utkast. Ellers er den
// umulig å skille fra en eieren ikke har sett på ennå, og køen slutter å
// bety noe.
// =====================================================================

export type Punkt = {
  slag: 'bekreftelse' | 'tiltak'
  tittel: string
  tekst: string
  kronerIAret: number | null
}

export function Plankort({
  id,
  stasjon,
  dom,
  ingress,
  punkter,
  merknad,
  status,
}: {
  id: string
  stasjon: string
  dom: 'medvind' | 'motvind' | 'flat'
  ingress: string
  punkter: Punkt[]
  merknad: string | null
  status: string
}) {
  const kr = (n: number) =>
    Math.round(Math.abs(n)).toLocaleString('nb-NO')

  return (
    <article className="sq-plankort">
      <header className="sq-plankort-hode">
        <span className={`sq-dom sq-dom-${dom}`}>{DOMORD[dom]}</span>
        <h3 className="sq-plankort-tittel">{stasjon}</h3>
        {status !== 'utkast' && (
          <span className="sq-plankort-status">{STATUSORD[status] ?? status}</span>
        )}
      </header>

      <p className="sq-plankort-ingress">{ingress}</p>

      {punkter.length === 0 && (
        <p className="sq-plankort-tom">
          Ingen av løftestengene peker feil vei denne måneden.
        </p>
      )}

      {punkter.map((p, i) => (
        <div
          key={`${p.tittel}-${i}`}
          className={`sq-punkt sq-punkt-${p.slag}`}
        >
          <span className="sq-punkt-merke">
            {p.slag === 'tiltak' ? (dom === 'medvind' ? 'Neste' : 'Dette') : 'Går bra'}
          </span>
          <span className="sq-punkt-tittel">{p.tittel}</span>
          <span className="sq-punkt-tekst">{p.tekst}</span>
          {p.kronerIAret !== null && (
            <span className="sq-punkt-kr">
              {p.slag === 'tiltak' ? 'Står på spill' : 'Verdt'}: {kr(p.kronerIAret)} kroner i året
            </span>
          )}
        </div>
      ))}

      {merknad && <p className="sq-plankort-merknad">{merknad}</p>}

      {status === 'utkast' && (
        <div className="knapperad">
          <HandlingKnapp
            handling={slippPlan}
            felt={{ id }}
            merke="Slipp"
            hva={`månedsplanen for ${stasjon}`}
            arbeider="Slipper …"
            variant="primar"
          />
          <HandlingKnapp
            handling={avvisPlan}
            felt={{ id }}
            merke="Avvis"
            hva={`månedsplanen for ${stasjon}`}
            arbeider="Avviser …"
            sporsmaal={`Avvise månedsplanen for ${stasjon}? Den sendes ikke.`}
          />
        </div>
      )}
    </article>
  )
}

const DOMORD: Record<string, string> = {
  medvind: 'Medvind',
  motvind: 'Motvind',
  flat: 'Stø kurs',
}

const STATUSORD: Record<string, string> = {
  sluppet: 'Sluppet',
  sendt: 'Sendt',
  avvist: 'Avvist',
}
