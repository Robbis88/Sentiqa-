'use client'
import { ingenFeilVei, rangeringstekst } from '@/lib/kurs/analysevisning'
import { lesRangering } from '@/lib/kurs/snapshot'
import { HandlingKnapp } from '@/components/ui/handling-knapp'
import { Analyseblokk } from './analyseblokk'
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
  maanedstekst,
  dom,
  ingress,
  punkter,
  merknad,
  status,
  matkast,
  usynlig,
  rangering,
}: {
  id: string
  stasjon: string
  /**
   * Maaneden, ferdig formatert av sida — «juli 2026».
   *
   * FERDIG FORMATERT MED VILJE. `maanedsnavn` bor i `kurs/plan.ts`, som
   * drar med seg royalty og loeftestenger; en klientkomponent trenger
   * ikke det i bunten for aa skrive tre ord.
   *
   * OG DEN ER PAAKREVD. Bekreftelsen under NAVNGIR maaneden, og en
   * valgfri prop ville latt den falle bort i stillhet — som er nettopp
   * den feilen kortet finnes for aa hindre.
   */
  maanedstekst: string
  dom: 'medvind' | 'motvind' | 'flat'
  ingress: string
  punkter: Punkt[]
  merknad: string | null
  status: string
  /** Lagret oeyeblikksbilde. `unknown` fordi kolonnen er `jsonb`. */
  matkast: unknown
  usynlig: unknown
  /**
   * Kunne hovedtiltaket velges? `unknown` fordi kolonnen er `jsonb` -
   * samme grunn som `matkast` og `usynlig`, og den skal gjennom samme
   * slags leser. `null` ut av `lesRangering` betyr IKKE TILGJENGELIG.
   */
  rangering: unknown
}) {
  const rang = lesRangering(rangering)
  const urangert = rangeringstekst(rang)
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

      <Analyseblokk matkast={matkast} usynlig={usynlig} />

      {ingenFeilVei(punkter, rang) && (
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

      {/*
        * MOTOREN HAR ALLEREDE VALGT naar den kunne. Kunne den ikke -
        * flere kandidater uten kroneverdi - er `rangering.mulig` usann,
        * og INGEN er valgt. Da maa flaten si hvorfor, og hvilke som sto
        * likt. Se `rangeringstekst`.
        */}
      {urangert && <p className="sq-plankort-urangert">{urangert}</p>}

      {merknad && <p className="sq-plankort-merknad">{merknad}</p>}

      {/*
        * BEGGE SPOERSMAALENE NAVNGIR MAANEDEN, OG DET ER HELE POENGET.
        *
        * «Slipp planen for Lone?» ville ikke hindret feilslippet
        * 2026-09-14: stasjonen var riktig, maaneden var ikke. Et
        * spoersmaal som bare bekrefter det man alt trodde, bekrefter
        * ogsaa feilen.
        *
        * Slipp hadde ikke noe spoersmaal i det hele tatt. Avvis hadde et
        * som bare navnga stasjonen. Nu sier begge hvilken maaned, og
        * Slipp sier dessuten at det ikke kan gjoeres om — for det er
        * sant: `maanedsplan_laas_sluppet` (0200) laaser innholdet.
        */}
      {status === 'utkast' && (
        <div className="knapperad">
          <HandlingKnapp
            handling={slippPlan}
            felt={{ id }}
            merke="Slipp"
            oppfrisk
            hva={`månedsplanen for ${stasjon}, ${maanedstekst}`}
            arbeider="Slipper …"
            variant="primar"
            sporsmaal={
              `Slipp månedsplanen for ${stasjon} — ${maanedstekst}?\n\n`
              + 'Butikksjefen ser den med én gang, og innholdet kan ikke '
              + 'skrives om etterpå.'
            }
          />
          <HandlingKnapp
            handling={avvisPlan}
            felt={{ id }}
            merke="Avvis"
            oppfrisk
            hva={`månedsplanen for ${stasjon}, ${maanedstekst}`}
            arbeider="Avviser …"
            sporsmaal={
              `Avvise månedsplanen for ${stasjon} — ${maanedstekst}?\n\n`
              + 'Den sendes ikke.'
            }
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
