import Link from 'next/link'
import { manedAar } from '@/lib/format'
import { Felt, Velg } from './felt'
import { Knapp } from './knapp'
import type { Dag, Maaned } from '@/lib/periode'

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

// =====================================================================
// Dagsvelgeren.
//
// SAMME REGEL, ETT KORN NED. Månedsvelgeren over tar imot lista fordi
// kilden bestemmer hva som er gyldig. Her er kornet dag, og da kan ikke
// lista være en liste: salgsdata går to kalenderår tilbake, og en
// `<select>` med sju hundre datoer er ikke et valg — det er en katalog.
//
// Derfor et datofelt med `min`/`max` fra første og siste dagen kilden
// faktisk har, pluss to piler.
//
// ---------------------------------------------------------------------
// PILENE HOPPER TIL DAGER SOM FINNES
//
// Ikke til «i går». Er det hull i dataene — og det er det, importen
// kjøres ikke hver dag — ville en kalenderdag ført til en tom side som
// ser ut som en dårlig dag. `forrige`/`neste` kommer fra `hentDagvindu`,
// som spør basen hva nabodagen er.
//
// Står vi ytterst, er de `null`, og pila er ikke der. En knapp som ikke
// fører noe sted er verre enn ingen knapp.
// =====================================================================

export function Dagsvelger({
  dag,
  forste,
  siste,
  forrige,
  neste,
  skjulte,
  etikett = 'Dato',
}: {
  dag: Dag
  /** `min`/`max` i feltet. Kommer fra kilden, ikke herfra. */
  forste: Dag | null
  siste: Dag | null
  /** Nærmeste dag med data på hver side, eller `null` ytterst. */
  forrige: Dag | null
  neste: Dag | null
  /**
   * Felt som skal følge med — typisk `stasjon`.
   *
   * SAMME FELLE SOM I MÅNEDSVELGEREN, og den gjelder pilene også:
   * skjemaet sender bare sine egne felt, og en lenke bærer bare det som
   * står i den. Uten disse bytter et datobytte stille stasjon.
   */
  skjulte?: Record<string, string | undefined>
  etikett?: string
}) {
  // ÉN DAG ER IKKE ET VALG. Har kilden bare den ene dagen, er det
  // ingenting å gå til — verken i feltet eller med pilene.
  if (!forrige && !neste) return null

  const lenke = (til: Dag) => {
    const sok = new URLSearchParams()
    for (const [n, v] of Object.entries(skjulte ?? {})) if (v) sok.set(n, v)
    sok.set('dato', til)
    return `?${sok}`
  }

  return (
    <form method="get" className="sq-listetopp">
      {Object.entries(skjulte ?? {}).map(([n, v]) =>
        v == null || v === '' ? null : <input key={n} type="hidden" name={n} value={v} />,
      )}
      <Felt
        etikett={etikett}
        type="date"
        name="dato"
        defaultValue={dag}
        min={forste ?? undefined}
        max={siste ?? undefined}
      />
      <Knapp type="submit">Vis dagen</Knapp>
      {forrige && <Link className="sq-knapp" href={lenke(forrige)}>← Forrige dag</Link>}
      {neste && <Link className="sq-knapp" href={lenke(neste)}>Neste dag →</Link>}
    </form>
  )
}
