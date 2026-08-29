'use client'
import { useKvittering } from '@/components/ui/kvittering'

import {
  lagreStilling, lagreTak, lagreVindu, leggTilFastVakt, leggTilFravaer, leggTilKrav,
  type Tilstand,
} from './handlinger'

const UKEDAGER = [
  { nr: 1, kort: 'man' }, { nr: 2, kort: 'tir' }, { nr: 3, kort: 'ons' },
  { nr: 4, kort: 'tor' }, { nr: 5, kort: 'fre' }, { nr: 6, kort: 'lør' }, { nr: 7, kort: 'søn' },
]

// role="alert" gjør at skjermlesere faktisk annonserer at lagringen feilet.
// Uten den er en mislykket innsending helt stille.
function Svar({ tilstand }: { tilstand: Tilstand }) {
  if (tilstand?.ok) return <span className="ok" role="status">{tilstand.ok}.</span>
  if (tilstand?.feil) return <span className="feil" role="alert">{tilstand.feil}</span>
  return null
}

// Avkryssing er riktig mønster for flervalg av uavhengige dager — men det må
// pakkes: uten fieldset/legend leser skjermleseren sju løsrevne «man/tir» uten
// å si hva de er, og uten pillestil er trykkflaten 13 px.
//
// Alle tre skjemaene bruker nå den samme. Før hadde bemannet vindu enkeltvalg
// og de to andre avkryssing — samme spørsmål, to mekanikker på samme side.
function Ukedagsvelger({ alleAv = false }: { alleAv?: boolean }) {
  return (
    <fieldset className="sq-ukedager">
      <legend>Hvilke dager?</legend>
      <span className="ukedag-velger">
        {UKEDAGER.map((u) => (
          <label className="ukedag" key={u.nr}>
            <input type="checkbox" name="ukedag" value={u.nr} defaultChecked={alleAv} /> {u.kort}
          </label>
        ))}
      </span>
    </fieldset>
  )
}

// To identiske klokkeslettfelt ved siden av hverandre uten ord er en garantert
// forveksling. Etiketten står over feltet, ikke bare som kolonnenavn i tabellen
// under — der ser man den først etter å ha gjettet feil.
//
// step=3600 fordi planleggingsmotoren regner i hele timer. Skriver noen 06:30
// likevel, sier serveren det rett ut i stedet for å runde i stillhet.
function Tid({ navn, merke, standard }: { navn: string; merke: string; standard: string }) {
  return (
    <label className="felt sq-smalt">
      <span>{merke}</span>
      <input type="time" name={navn} defaultValue={standard} step={3600} required />
    </label>
  )
}

export function VinduSkjema({ stasjonId, iDag }: { stasjonId: string; iDag: string }) {
  const [tilstand, handling, venter] = useKvittering<Tilstand, FormData>(lagreVindu, undefined)
  return (
    <form action={handling} className="sq-skjema">
      <input type="hidden" name="stasjon_id" value={stasjonId} />
      {/* Hele uka er huket av på forhånd — de fleste stasjoner har samme vindu
          man–fre, og så retter man helga etterpå. Før måtte man fylle ut og
          lagre sju ganger for å komme i gang. */}
      <Ukedagsvelger alleAv />
      <div className="sq-skjema-rad">
        <Tid navn="fra_time" merke="Fra klokken" standard="06:00" />
        <Tid navn="til_time" merke="Til klokken" standard="23:00" />
        <label className="felt sq-smalt">
          <span>Minst så mange på jobb</span>
          <input name="min_bemanning" type="number" min={0} max={20} defaultValue={1} required />
        </label>
        <label className="felt sq-smalt">
          <span>Gjelder fra dato</span>
          <input name="gjelder_fra" type="date" defaultValue={iDag} required />
        </label>
      </div>
      <div className="sq-skjema-bunn">
        <button type="submit" className="sq-knapp primar" disabled={venter}>
          {venter ? 'Lagrer …' : 'Lagre'}
        </button>
        <Svar tilstand={tilstand} />
      </div>
    </form>
  )
}

// Faste vakter: butikksjefen selv, NK, eller andre som alltid står. De dekker
// alltid minimumsbemanningen. Om de belaster timerammen, avhenger av lønnsformen
// — derfor er den et eksplisitt valg og ikke en antagelse.
//
// To radioknapper, ikke en avkryssingsboks: «timelønnet ☐» tvinger leseren til
// å tenke ut hva det motsatte er, og gjetter man feil her, roter man budsjettet
// uten å se det. Begge alternativene skal stå synlige side om side.
export function FastVaktSkjema({ stasjonId }: { stasjonId: string }) {
  const [tilstand, handling, venter] = useKvittering<Tilstand, FormData>(leggTilFastVakt, undefined)
  return (
    <form action={handling} className="sq-skjema">
      <input type="hidden" name="stasjon_id" value={stasjonId} />
      <label className="felt">
        <span>Hvem gjelder det?</span>
        <input name="navn" placeholder="Butikksjef" required />
      </label>
      <Ukedagsvelger />
      <div className="sq-skjema-rad">
        <Tid navn="fra_time" merke="Fra klokken" standard="07:00" />
        <Tid navn="til_time" merke="Til klokken" standard="15:00" />
      </div>
      <fieldset className="sq-ukedager">
        <legend>Hvordan lønnes de?</legend>
        <span className="ukedag-velger">
          <label className="ukedag">
            <input type="radio" name="lonnsform" value="fast" defaultChecked /> Fastlønn
          </label>
          <label className="ukedag">
            <input type="radio" name="lonnsform" value="time" /> Timelønn
          </label>
        </span>
        <p className="undertittel">
          Fastlønn koster ikke timerammen. Timelønn gjør det — vakten er like fast,
          men timene trekkes fra.
        </p>
      </fieldset>
      {/* PERIODEN, BEGGE ENDER. Robert 2026-08-22: «har Lone hatt
          fastlønn fra 01.05.26 til 31.12.26 må eg kunne skrive det, og
          skrive timelønn fra 01.01.26–30.04.26.»

          Med bare «fra» kunne to perioder ikke settes presist: den
          forrige ble lukket dagen før den nye, og et opphold mellom dem
          var umulig å uttrykke.

          Fylles ikke ut automatisk med dagens dato: de fleste endringer
          er rettelser av noe som alltid har vært slik, og en
          forhåndsutfylt dato ville delt historikken i to hver gang. */}
      <div className="sq-skjema-rad">
        <label className="felt">
          <span>Gjelder fra</span>
          <input type="date" name="gjelder_fra" />
        </label>
        <label className="felt">
          <span>Gjelder til</span>
          <input type="date" name="gjelder_til" />
        </label>
      </div>
      <p className="undertittel">
        La begge stå tomme hvis vakten alltid har vært slik. Fyller du ut
        «fra», avsluttes en åpen periode dagen før — og tall du så for
        tidligere måneder står som de var. «Til» lar deg lukke perioden
        selv: timelønn 01.01–30.04, fastlønn fra 01.05.
      </p>
      <div className="sq-skjema-bunn">
        <button type="submit" className="sq-knapp primar" disabled={venter}>
          {venter ? 'Legger til …' : 'Legg til'}
        </button>
        <Svar tilstand={tilstand} />
      </div>
    </form>
  )
}

// Timene der én ikke holder. Varemottak er det vanligste.
export function KravSkjema({ stasjonId }: { stasjonId: string }) {
  const [tilstand, handling, venter] = useKvittering<Tilstand, FormData>(leggTilKrav, undefined)
  return (
    <form action={handling} className="sq-skjema">
      <input type="hidden" name="stasjon_id" value={stasjonId} />
      <Ukedagsvelger />
      <div className="sq-skjema-rad">
        <Tid navn="fra_time" merke="Fra klokken" standard="06:00" />
        <Tid navn="til_time" merke="Til klokken" standard="09:00" />
        <label className="felt sq-smalt">
          <span>Så mange må på jobb</span>
          <input name="antall" type="number" min={2} max={20} defaultValue={2} required />
        </label>
        <label className="felt">
          <span>Hvorfor?</span>
          <input name="begrunnelse" placeholder="Varemottak" />
        </label>
      </div>
      <div className="sq-skjema-bunn">
        <button type="submit" className="sq-knapp primar" disabled={venter}>
          {venter ? 'Legger til …' : 'Legg til'}
        </button>
        <Svar tilstand={tilstand} />
      </div>
    </form>
  )
}

// Taket. Fordelingen er proporsjonal og bruker opp rammen, så en stasjon med
// mye slakk og én dag som skiller seg ut får alt dumpet der — søndagen med sju
// personer klokka 13. Matematisk riktig, fysisk umulig. Dette er stasjonens
// egen grense, og den kjenner bare butikksjefen.
export function TakSkjema({ stasjonId, naa }: { stasjonId: string; naa: number | null }) {
  const [tilstand, handling, venter] = useKvittering<Tilstand, FormData>(lagreTak, undefined)
  return (
    <form action={handling} className="sq-skjema">
      <input type="hidden" name="stasjon_id" value={stasjonId} />
      <div className="sq-skjema-rad">
        <label className="felt sq-smalt">
          <span>Flest på jobb samtidig</span>
          <input
            name="maks_bemanning"
            type="number"
            min={1}
            max={20}
            defaultValue={naa ?? ''}
            placeholder="uten tak"
          />
        </label>
      </div>
      <div className="sq-skjema-bunn">
        <button type="submit" className="sq-knapp primar" disabled={venter}>
          {venter ? 'Lagrer …' : 'Lagre'}
        </button>
        <Svar tilstand={tilstand} />
      </div>
    </form>
  )
}

// Stillingsprosent: systemet anslår, butikksjefen retter. Feltet står med
// anslaget som placeholder og tomt som verdi — tomt betyr «ikke bestemt»,
// og da gjelder anslaget. Skriver hun et tall, er det hennes.
export function StillingSkjema({
  stasjonId, ansattNr, navn, lagret, anslag,
}: {
  stasjonId: string; ansattNr: string; navn: string
  lagret: number | null; anslag: number
}) {
  const [tilstand, handling, venter] = useKvittering<Tilstand, FormData>(lagreStilling, undefined)
  return (
    <form action={handling} className="stilling-rad">
      <input type="hidden" name="stasjon_id" value={stasjonId} />
      <input type="hidden" name="ansatt_nr" value={ansattNr} />
      <input type="hidden" name="navn" value={navn} />
      <input
        name="stillingsprosent"
        type="number"
        min={1}
        max={150}
        step={5}
        defaultValue={lagret ?? ''}
        placeholder={String(anslag)}
        aria-label={`Stillingsprosent for ${navn}`}
      />
      <span aria-hidden>%</span>
      <button type="submit" className="liten primar" disabled={venter}>
        {venter ? '…' : 'Lagre'}
      </button>
      <Svar tilstand={tilstand} />
    </form>
  )
}

// Fravær. Butikksjefens fem uker er den enkeltposten som flytter mest —
// er han borte, dekker ikke den faste vakten gulvet, og timene må kjøpes.
export function FravaerSkjema({ stasjonId, navn }: { stasjonId: string; navn: string[] }) {
  const [tilstand, handling, venter] = useKvittering<Tilstand, FormData>(leggTilFravaer, undefined)
  return (
    <form action={handling} className="sq-skjema">
      <input type="hidden" name="stasjon_id" value={stasjonId} />
      <div className="sq-skjema-rad">
        <label className="felt">
          <span>Hvem er borte?</span>
          {navn.length > 0 ? (
            <select name="navn" required defaultValue={navn[0]}>
              {navn.map((n) => <option key={n} value={n}>{n}</option>)}
            </select>
          ) : (
            <input name="navn" required placeholder="Butikksjef" />
          )}
        </label>
        <label className="felt sq-smalt">
          <span>Fra og med</span>
          <input name="fra_dato" type="date" required />
        </label>
        <label className="felt sq-smalt">
          <span>Til og med</span>
          <input name="til_dato" type="date" required />
        </label>
        <label className="felt">
          <span>Hvorfor?</span>
          <input name="arsak" placeholder="Ferie" />
        </label>
      </div>
      <div className="sq-skjema-bunn">
        <button type="submit" className="sq-knapp primar" disabled={venter}>
          {venter ? 'Legger til …' : 'Legg til'}
        </button>
        <Svar tilstand={tilstand} />
      </div>
    </form>
  )
}
