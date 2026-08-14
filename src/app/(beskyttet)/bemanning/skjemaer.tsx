'use client'
import { useActionState } from 'react'
import { lagreVindu, leggTilFastVakt, leggTilKrav, type Tilstand } from './handlinger'

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
  const [tilstand, handling, venter] = useActionState<Tilstand, FormData>(lagreVindu, undefined)
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
  const [tilstand, handling, venter] = useActionState<Tilstand, FormData>(leggTilFastVakt, undefined)
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
  const [tilstand, handling, venter] = useActionState<Tilstand, FormData>(leggTilKrav, undefined)
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
