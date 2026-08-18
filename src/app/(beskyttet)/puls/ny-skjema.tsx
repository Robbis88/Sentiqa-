import Link from 'next/link'
import { startRunde } from './handlinger'

// Lå som egen side på /puls/ny. En måling er ett spørsmål og to datoer —
// å bytte side for det kostet lista man kom fra, og ga skjemaet en egen
// h1 som om det var et sted man skulle være.
//
// Ingen 'use client': skjemaet poster til en serverhandling og trenger
// ingen tilstand. Det rendres som children av Sidepanel, som er klienten.
export type PulsSporsmal = { id: string; tekst: string; kategori: string }

export function NyRundeSkjema({ sporsmal, idag, om7 }: {
  sporsmal: PulsSporsmal[]
  idag: string
  om7: string
}) {
  return (
    <form action={startRunde} className="skjema">
      <label className="felt"><span>Spørsmål</span>
        <input name="nytt_sporsmal" placeholder="f.eks. Hvordan har trivselen vært denne uka?" />
      </label>
      <label className="felt"><span>Kategori</span>
        <input name="kategori" defaultValue="Trivsel" placeholder="Trivsel" />
      </label>

      {sporsmal.length > 0 && (
        <label className="felt"><span>… eller gjenbruk et tidligere spørsmål</span>
          <select name="sporsmal_id" defaultValue="">
            <option value="">– skriv et nytt over –</option>
            {sporsmal.map((s) => <option key={s.id} value={s.id}>{s.kategori}: {s.tekst}</option>)}
          </select>
        </label>
      )}

      <div className="rad-2">
        <label className="felt"><span>Fra</span><input type="date" name="start_dato" defaultValue={idag} required /></label>
        <label className="felt"><span>Til</span><input type="date" name="slutt_dato" defaultValue={om7} required /></label>
      </div>
      <label className="felt"><span>Notat (valgfri)</span><input name="notat" placeholder="internt notat" /></label>

      <button type="submit" className="sq-knapp primar" style={{ alignSelf: 'flex-start' }}>Start måling</button>

      <p className="undertittel">
        Faste spørsmål administreres under <Link href="/puls/sporsmal">Spørsmål</Link>.
      </p>
    </form>
  )
}
