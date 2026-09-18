'use client'
import { useState } from 'react'

export function Tilbudsforesporsel() {
  const [status, setStatus] = useState<string | null>(null)
  const [sender, setSender] = useState(false)
  async function send(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault(); setSender(true); setStatus(null)
    const data = Object.fromEntries(new FormData(e.currentTarget).entries())
    const svar = await fetch('/api/tilbud', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(data) })
    const json = await svar.json()
    setSender(false); setStatus(json.ok ? 'Takk! Vi har mottatt forespørselen og tar kontakt med et tilpasset tilbud.' : (json.feil ?? 'Noe gikk galt. Prøv igjen.'))
    if (json.ok) e.currentTarget.reset()
  }
  if (status?.startsWith('Takk')) return <section className="kort"><h1>Tilbudsforespørsel</h1><p role="status">{status}</p></section>
  return <section className="kort" style={{ maxWidth: 720, margin: '0 auto' }}>
    <h1>Be om tilbud</h1>
    <p>Pris tilpasses antall stasjoner og ledertilganger.</p>
    <form onSubmit={send} className="sq-skjema">
      <label className="felt"><span>Virksomhet</span><input name="virksomhet" required /></label>
      <label className="felt"><span>Organisasjonsnummer (valgfritt)</span><input name="org_nr" inputMode="numeric" pattern="[0-9]{9}" /></label>
      <label className="felt"><span>Kontaktperson</span><input name="kontaktperson" required /></label>
      <label className="felt"><span>E-post</span><input name="epost" type="email" required /></label>
      <label className="felt"><span>Telefon</span><input name="telefon" type="tel" required /></label>
      <div className="sq-grid-2">
        <label className="felt"><span>Antall stasjoner</span><input name="antall_stasjoner" type="number" min="1" required /></label>
        <label className="felt"><span>Retailer-/hovedbrukere</span><input name="retailer_limit" type="number" min="0" defaultValue="1" required /></label>
        <label className="felt"><span>Butikksjefbrukere</span><input name="butikksjef_limit" type="number" min="0" defaultValue="0" required /></label>
        <label className="felt"><span>Stasjoner med tablet/drift</span><input name="tablet_station_limit" type="number" min="0" defaultValue="0" required /></label>
      </div>
      <label className="felt"><span>Ønsket oppstart</span><input name="onsket_oppstart" type="date" /></label>
      <label className="felt"><span>Fortell kort hva dere ønsker hjelp med</span><textarea name="kommentar" rows={4} /></label>
      <input name="website" tabIndex={-1} autoComplete="off" aria-hidden="true" style={{ position: 'absolute', left: '-10000px' }} />
      <p className="undertittel">En butikksjef kan ha tilgang til flere stasjoner. En stasjon trenger ikke en egen butikksjefbruker. Medarbeidere på tablet regnes ikke som egne betalte brukere.</p>
      <label className="felt-avkrysning"><input name="samtykke" type="checkbox" required /><span>Jeg samtykker til at Sentiqa kan kontakte meg om denne forespørselen.</span></label>
      {status && <p role="alert" className="feil">{status}</p>}
      <button className="sq-knapp primar" type="submit" disabled={sender}>{sender ? 'Sender …' : 'Send tilbudsforespørsel'}</button>
    </form>
  </section>
}
