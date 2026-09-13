import { ingenFeilVei, rangeringstekst } from '@/lib/kurs/analysevisning'
import { maanedsnavn } from '@/lib/kurs/plan'
import { Analyseblokk } from '../maanedsplan/analyseblokk'
import type { Punkt } from '../maanedsplan/plankort'

// =====================================================================
// Planen slik butikksjefen leser den.
//
// SAMME KORT SOM EIEREN SER, uten knappene. Hun skal ikke kunne slippe
// eller avvise sin egen plan — og hun skal se nøyaktig det eieren
// godkjente, ikke en annen utgave av det.
//
// Analyseblokken er den samme komponenten. To flater som tegner tallene
// hver for seg er to sannheter, og forskjellen ville vist seg først når
// noen sammenlignet skjermene i et møte.
// =====================================================================

export function Planlesing({
  stasjon,
  maaned,
  dom,
  ingress,
  punkter,
  merknad,
  matkast,
  usynlig,
  rangering,
}: {
  stasjon: string
  maaned: string
  dom: 'medvind' | 'motvind' | 'flat'
  ingress: string
  punkter: Punkt[]
  merknad: string | null
  matkast: unknown
  usynlig: unknown
  rangering: { mulig: boolean; kandidater: string[] }
}) {
  const urangert = rangeringstekst(rangering)
  const kr = (n: number) => Math.round(Math.abs(n)).toLocaleString('nb-NO')

  return (
    <article className="sq-plankort">
      <header className="sq-plankort-hode">
        <span className={`sq-dom sq-dom-${dom}`}>{DOMORD[dom]}</span>
        <h3 className="sq-plankort-tittel">
          {stasjon} · {maanedsnavn(maaned)} {maaned.slice(0, 4)}
        </h3>
      </header>

      <p className="sq-plankort-ingress">{ingress}</p>

      <Analyseblokk matkast={matkast} usynlig={usynlig} />

      {ingenFeilVei(punkter, rangering) && (
        <p className="sq-plankort-tom">
          Ingen av løftestengene peker feil vei denne måneden.
        </p>
      )}

      {punkter.map((p, i) => (
        <div key={`${p.tittel}-${i}`} className={`sq-punkt sq-punkt-${p.slag}`}>
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

      {urangert && <p className="sq-plankort-urangert">{urangert}</p>}

      {merknad && <p className="sq-plankort-merknad">{merknad}</p>}
    </article>
  )
}

const DOMORD: Record<string, string> = {
  medvind: 'Medvind',
  motvind: 'Motvind',
  flat: 'Stø kurs',
}
