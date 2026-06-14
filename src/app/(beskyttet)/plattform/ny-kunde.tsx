'use client'
import { useActionState } from 'react'
import { opprettKunde, type KundeTilstand } from './handlinger'

export function NyKunde() {
  const [tilstand, handling, venter] = useActionState<KundeTilstand, FormData>(opprettKunde, undefined)
  return (
    <form action={handling} className="rutine-form arr-form" style={{ flexDirection: 'column', alignItems: 'stretch', gap: '0.6rem' }}>
      <div className="arr-form">
        <input name="firma" placeholder="Firmanavn" required />
        <input name="org_nr" placeholder="Org.nr (9 siffer)" inputMode="numeric" required />
      </div>
      <div className="arr-form">
        <input name="fullt_navn" placeholder="Admin-kontaktens navn" required />
        <input name="epost" type="email" placeholder="admin@kjede.no" required style={{ flex: '1 1 14rem' }} />
      </div>
      {tilstand?.feil && <p role="alert" className="feil">{tilstand.feil}</p>}
      {tilstand?.ok && <p className="status-pip gronn" style={{ alignSelf: 'flex-start' }}>{tilstand.ok}</p>}
      <button type="submit" className="liten" disabled={venter} style={{ alignSelf: 'flex-start' }}>
        {venter ? 'Oppretter …' : 'Opprett kunde + send invitasjon'}
      </button>
    </form>
  )
}
