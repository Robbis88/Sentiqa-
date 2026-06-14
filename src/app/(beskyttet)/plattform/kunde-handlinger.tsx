'use client'

// Liten skjema-knapp som ber om bekreftelse før en server-handling kjøres.
// Brukes til deaktiver/slett/send-på-nytt i plattform-konsollen.
export function BekreftKnapp({
  action, id, epost, etikett, klasse, sporsmaal,
}: {
  action: (formData: FormData) => Promise<void>
  id?: string
  epost?: string
  etikett: string
  klasse?: string
  sporsmaal?: string
}) {
  return (
    <form
      action={action}
      onSubmit={(e) => { if (sporsmaal && !window.confirm(sporsmaal)) e.preventDefault() }}
      style={{ display: 'inline' }}
    >
      {id ? <input type="hidden" name="id" value={id} /> : null}
      {epost ? <input type="hidden" name="epost" value={epost} /> : null}
      <button type="submit" className={klasse ?? 'liten'}>{etikett}</button>
    </form>
  )
}
