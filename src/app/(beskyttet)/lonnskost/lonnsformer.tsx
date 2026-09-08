import { LonnsformVelger } from '../lonn/lonnsform-velger'
import { kr } from '@/lib/format'
import type { Lonnsbilde } from '@/lib/lonnskost/hent'

// =====================================================================
// HVEM LØNNSDATAENE KJENNER — OG HVEM SOM IKKE SKAL TELLE
//
// Sandra på Lone sto i easy@work-eksporten for august med 193,50 timer
// og en timesats på 285. Ganget ut blir det 57 957 kroner ingen har
// fått utbetalt: hun har fastlønn, og stemplingene hennes er
// arbeidstid, ikke lønnsgrunnlag. En fjerdedel av en butikksjefslønn på
// avveie i lønnsandelen, og det ser ikke ut som en feil — det ser ut
// som en stasjon som bruker for mye folk.
//
// ---------------------------------------------------------------------
// REGELEN FANTES, STEDET Å SETTE DEN GJORDE IKKE
//
// `ansatt_avtale.lonnsform` kom i `0099`. Men den kunne bare settes på
// `/lonn`, og den sida regnes fra STEMPLINGENE. Lone hadde ingen
// stemplinger for august, så sida var tom — og Sandra kunne ikke
// markeres i det hele tatt.
//
// Et ansettelsesforhold skal ikke være avhengig av at en helt annen fil
// er lastet opp. Her står de som lønnsfila kjenner, med kronene sine,
// og valget rett i raden.
//
// ---------------------------------------------------------------------
// SAMME HANDLING SOM PÅ `/lonn`
//
// `settLonnsform` og `LonnsformVelger` er de samme. To innganger til
// samme rad er ikke to sannheter — det er ett felt, nådd fra de to
// stedene spørsmålet faktisk stilles.
// =====================================================================

const UT = {
  fastlonn: 'holdes utenfor — fast beløp, ikke timer',
  tilkalling: 'teller med — betales for timene sine',
} as const

export function Lonnsformer(
  { stasjonId, ansatte, maaned }:
  { stasjonId: string; ansatte: Lonnsbilde['ansatte']; maaned: string | null },
) {
  if (ansatte.length === 0) return null

  const uavklart = ansatte.filter((a) => a.lonnsform === null).length
  const holdtUtenfor = ansatte.filter((a) => a.lonnsform === 'fastlonn')

  return (
    <section className="kort">
      <h2>Lønnsform</h2>
      <p className="undertittel">
        {maaned
          ? `Hvem lønnsfila kjenner for ${maaned}. `
          : 'Hvem lønnsfila kjenner. '}
        {'En fastlønnet stempler også, men timene er arbeidstid — ikke lønn. '}
        {'Merk dem her, så holdes de utenfor lønnskosten ved neste import.'}
      </p>

      {/* UAVKLART ER IKKE FASTLØNNET. Alle uten valg teller som
          timelønn, og det er riktig — men tallet skal stå, ellers ser
          en uavklart liste ut som en ferdig liste. */}
      {uavklart > 0 && (
        <p className="undertittel">
          {`${uavklart} står uten lønnsform og telles som timelønn.`}
        </p>
      )}

      <ul className="sq-lonnsformer">
        {ansatte.map((a) => (
          <li key={a.ansattNr} className={a.lonnsform === 'fastlonn' ? 'utenfor' : undefined}>
            <span className="sq-lf-navn">
              {a.navn}
              <span className="undertittel">{` · ${a.ansattNr}`}</span>
            </span>
            <span className="sq-lf-tall">
              {`${a.timer.toLocaleString('nb-NO')} t · ${kr.format(Math.round(a.belopKr))}`}
              {/* Et beregnet tall og et lest tall er ikke det samme
                  tallet, selv når de er like (0188). */}
              {a.beregnet && <span className="undertittel"> · beregnet</span>}
            </span>
            <LonnsformVelger
              stasjonId={stasjonId}
              ansattNr={a.ansattNr}
              navn={a.navn}
              verdi={a.lonnsform}
            />
            {a.lonnsform && a.lonnsform !== 'timelonn' && (
              <span className="sq-lf-hvorfor undertittel">{UT[a.lonnsform]}</span>
            )}
          </li>
        ))}
      </ul>

      {holdtUtenfor.length > 0 && (
        <p className="undertittel">
          {`${holdtUtenfor.map((a) => a.navn).join(', ')} holdes utenfor. `}
          {'Lønna deres kommer fra konto 501 når måneden er avlagt, eller fra '}
          {'grunnlønna som er lagt inn — ikke fra stemplingene. '}
          {'Last opp lønnsfila på nytt for at endringen skal slå gjennom.'}
        </p>
      )}
    </section>
  )
}
