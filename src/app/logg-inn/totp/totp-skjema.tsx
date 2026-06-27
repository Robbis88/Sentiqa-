'use client'
import { useEffect, useState, type FormEvent } from 'react'
import { lagSupabaseNettleserKlient } from '@/lib/supabase/client'

// Steg-opp til AAL2: brukeren har allerede skrevet passord (aal1) og har en
// verifisert TOTP-faktor. Vi henter faktor-id, lar dem skrive engangskoden, og
// challengeAndVerify løfter sesjonen til aal2 (cookies oppdateres av ssr-klienten).
export function TotpSkjema({ retur }: { retur?: string }) {
  const [supabase] = useState(() => lagSupabaseNettleserKlient())
  const [factorId, setFactorId] = useState<string | null>(null)
  const [kode, setKode] = useState('')
  const [feil, setFeil] = useState<string | null>(null)
  const [venter, setVenter] = useState(false)

  useEffect(() => {
    supabase.auth.mfa.listFactors().then(({ data }) => {
      const f = data?.totp?.find((x) => x.status === 'verified') ?? data?.totp?.[0]
      if (f) setFactorId(f.id)
      else setFeil('Fant ingen registrert autentiseringsapp. Logg inn på nytt.')
    })
  }, [supabase])

  async function send(e: FormEvent) {
    e.preventDefault()
    if (!factorId || venter) return
    setVenter(true)
    setFeil(null)
    const { error } = await supabase.auth.mfa.challengeAndVerify({ factorId, code: kode.trim() })
    if (error) {
      setFeil('Feil eller utløpt kode. Prøv igjen.')
      setKode('')
      setVenter(false)
      return
    }
    const mål = retur && retur.startsWith('/') && !retur.startsWith('//') ? retur : '/oversikt'
    window.location.assign(mål) // full navigasjon → server leser fersk aal2-sesjon
  }

  return (
    <form onSubmit={send} className="skjema">
      <label className="felt">
        <span>Engangskode</span>
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

      <button type="submit" disabled={venter || !factorId}>
        {venter ? 'Bekrefter …' : 'Bekreft'}
      </button>
    </form>
  )
}
