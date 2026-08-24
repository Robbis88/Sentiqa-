'use client'
import { useEffect, useState, type FormEvent } from 'react'
import { lagSupabaseNettleserKlient } from '@/lib/supabase/client'

type Steg = 'laster' | 'ingen' | 'qr' | 'paa'

// TOTP-oppsett og -administrasjon. Hele syklusen kjøres på klienten mot
// Supabase MFA-API-et: enroll() gir QR + hemmelig nøkkel, og challengeAndVerify()
// verifiserer koden og løfter sesjonen til aal2 i samme steg.
export function MfaOppsett({ tvunget, rollenKrever }: { tvunget: boolean; rollenKrever: boolean }) {
  const [supabase] = useState(() => lagSupabaseNettleserKlient())
  const [steg, setSteg] = useState<Steg>('laster')
  const [factorId, setFactorId] = useState<string | null>(null)
  const [qr, setQr] = useState<string | null>(null)
  const [hemmelig, setHemmelig] = useState<string | null>(null)
  const [kode, setKode] = useState('')
  const [feil, setFeil] = useState<string | null>(null)
  const [venter, setVenter] = useState(false)

  // Finn en evt. verifisert faktor ved last.
  useEffect(() => {
    supabase.auth.mfa.listFactors().then(({ data }) => {
      const verifisert = data?.totp?.find((f) => f.status === 'verified')
      if (verifisert) {
        setFactorId(verifisert.id)
        setSteg('paa')
      } else {
        setSteg('ingen')
      }
    })
  }, [supabase])

  async function start() {
    setVenter(true)
    setFeil(null)
    const { data, error } = await supabase.auth.mfa.enroll({ factorType: 'totp' })
    setVenter(false)
    if (error || !data) {
      setFeil('Kunne ikke starte oppsett. Oppdater siden og prøv igjen.')
      return
    }
    setFactorId(data.id)
    setQr(data.totp.qr_code)
    setHemmelig(data.totp.secret)
    setSteg('qr')
  }

  async function verifiser(e: FormEvent) {
    e.preventDefault()
    if (!factorId || venter) return
    setVenter(true)
    setFeil(null)
    const { error } = await supabase.auth.mfa.challengeAndVerify({ factorId, code: kode.trim() })
    if (error) {
      setFeil('Feil eller utløpt kode. Sjekk appen og prøv igjen.')
      setKode('')
      setVenter(false)
      return
    }
    if (tvunget) {
      window.location.assign('/oversikt') // sesjonen er nå aal2 → slipper gjennom porten
      return
    }
    setQr(null)
    setHemmelig(null)
    setSteg('paa')
    setVenter(false)
  }

  async function fjern() {
    if (!factorId || venter) return
    setVenter(true)
    setFeil(null)
    const { error } = await supabase.auth.mfa.unenroll({ factorId })
    setVenter(false)
    if (error) {
      setFeil('Kunne ikke fjerne to-faktor. Prøv igjen.')
      return
    }
    setFactorId(null)
    setSteg('ingen')
  }

  if (steg === 'laster') return <p className="undertittel">Laster …</p>

  if (steg === 'paa') {
    return (
      <div className="mfa-status">
        <p className="mfa-paa">✓ To-faktor er aktivert på kontoen din.</p>
        <button type="button" className="logg-ut" onClick={fjern} disabled={venter}>
          {venter ? 'Fjerner …' : 'Fjern to-faktor'}
        </button>
        {rollenKrever && (
          <p className="undertittel" style={{ fontSize: '0.78rem', marginTop: '0.5rem' }}>
            Merk: rollen din krever to-faktor — fjerner du den, må du sette den opp på nytt ved neste innlogging.
          </p>
        )}
        {feil ? <p role="alert" className="feil">{feil}</p> : null}
      </div>
    )
  }

  if (steg === 'qr' && qr) {
    return (
      <form onSubmit={verifiser} className="skjema">
        <p className="undertittel">1. Skann QR-koden i autentiseringsappen din.</p>
        {/* qr_code er en ferdig SVG-data-URL fra Supabase */}
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src={qr} alt="QR-kode for to-faktor" className="mfa-qr" />
        {hemmelig && (
          <p className="undertittel" style={{ fontSize: '0.78rem' }}>
            Kan du ikke skanne? Skriv inn nøkkelen manuelt:<br />
            <code className="mfa-hemmelig">{hemmelig}</code>
          </p>
        )}
        <label className="felt">
          <span>2. Skriv inn engangskoden appen viser</span>
          <input
            name="kode"
            inputMode="numeric"
            autoComplete="one-time-code"
            pattern="[0-9]*"
            placeholder="123456"
            value={kode}
            onChange={(e) => setKode(e.target.value)}
            required
            autoFocus
          />
        </label>
        {feil ? <p role="alert" className="feil">{feil}</p> : null}
        <button type="submit" disabled={venter} className="primar">{venter ? 'Bekrefter …' : 'Aktiver to-faktor'}</button>
      </form>
    )
  }

  // steg === 'ingen'
  return (
    <div className="mfa-status">
      {feil ? <p role="alert" className="feil">{feil}</p> : null}
      <button type="button" onClick={start} disabled={venter}>
        {venter ? 'Starter …' : 'Sett opp to-faktor'}
      </button>
    </div>
  )
}
