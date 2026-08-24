import { manedAar } from '@/lib/format'
import { Velg } from './felt'
import { Knapp } from './knapp'
import type { Maaned } from '@/lib/periode'

// =====================================================================
// Månedsvelgeren.
//
// FIRE SIDER SKREV DEN HVER FOR SEG, og ingen av dem likt:
//
//   /bemanning   <Velg skjultEtikett>  + fritekst årstall  + «Vis»
//   /lonn        rå <select aria-label> + fritekst årstall + «Vis»
//   /svinn       <label className="felt"><span>Måned</span> + «Vis måneden»
//   /kasserer    samme som /svinn
//
// To skjulte etiketter, én synlig, to knappetekster, og et årstallsfelt
// som bare halvparten hadde. Den som lærte kontrollen på én side måtte
// lære den på nytt på neste.
//
// ---------------------------------------------------------------------
// DEN LAGER IKKE LISTA. DEN TAR IMOT DEN.
//
// Det er hele grunnen til at dette ikke er én global periodevelger.
// `/svinn` kan bare tilby måneder det finnes svinn i — dekningen svinger
// for mye til at uke betyr noe, og en måned uten registrering er ikke en
// måned med null. `/bemanning` planlegger neste måned, som per
// definisjon ikke har rader ennå. En felles liste ville løyet på minst
// én av dem.
//
// Kilden bestemmer hva som er gyldig. Velgeren bestemmer hvordan det ser
// ut og heter.
// =====================================================================

export function Maanedsvelger({
  maaneder,
  valgt,
  skjulte,
  knapp = 'Vis måneden',
  etikett = 'Måned',
}: {
  /** Gyldige måneder, nyeste først. Kommer fra kilden, ikke herfra. */
  maaneder: Maaned[]
  valgt: Maaned
  /**
   * Felt som skal følge med i URL-en — typisk `stasjon`.
   *
   * UTEN DISSE BYTTER ET MÅNEDSBYTTE STILLE STASJON. Skjemaet sender
   * bare sine egne felt, så alt annet i URL-en forsvinner ved submit.
   * Det var feilen /produksjonsplan fikk rettet med et skjult
   * butikknummer, og den gjelder her også.
   */
  skjulte?: Record<string, string | undefined>
  knapp?: string
  etikett?: string
}) {
  // ÉN MÅNED ER IKKE ET VALG. Å be noen velge fra en liste med ett
  // alternativ er å be om en beslutning som ikke finnes — samme regel
  // som `visVelger` i stasjonsvalget.
  if (maaneder.length <= 1) return null

  return (
    <form method="get" className="sq-listetopp">
      {Object.entries(skjulte ?? {}).map(([n, v]) =>
        v == null || v === '' ? null : <input key={n} type="hidden" name={n} value={v} />,
      )}
      <Velg etikett={etikett} name="maned" defaultValue={valgt}>
        {maaneder.map((m) => (
          <option key={m} value={m}>{manedAar.format(new Date(m))}</option>
        ))}
      </Velg>
      <Knapp type="submit">{knapp}</Knapp>
    </form>
  )
}
