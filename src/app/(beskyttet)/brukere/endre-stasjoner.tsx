'use client'
import { useKvittering } from '@/components/ui/kvittering'
import { endreStasjoner, type BrukerTilstand } from './handlinger'

// =====================================================================
// Endrer hvilke stasjoner én butikksjef når.
//
// Avkryssingene starter der brukeren står i dag — ikke tomme. Et skjema
// som åpner blankt ser ut som «hun har ingen stasjoner», og den som bare
// skulle legge til én, fjerner da alle de andre uten å ha ment det.
// =====================================================================

export function EndreStasjoner({
  profilId, navn, stasjoner, valgte,
}: {
  profilId: string
  navn: string
  stasjoner: { id: string; navn: string }[]
  valgte: string[]
}) {
  const [tilstand, handling, venter] = useKvittering<BrukerTilstand, FormData>(endreStasjoner, undefined)
  const na = new Set(valgte)

  return (
    <form action={handling} className="skjema">
      <input type="hidden" name="profil_id" value={profilId} />
      <fieldset className="felt">
        <span>Stasjoner {navn} når</span>
        <div className="stasjon-valg">
          {stasjoner.map((s) => (
            <label className="avkryss" key={s.id}>
              <input type="checkbox" name="stasjon_ids" value={s.id} defaultChecked={na.has(s.id)} /> {s.navn}
            </label>
          ))}
        </div>
      </fieldset>

      {tilstand?.ok ? <p className="ok" role="status">Tilgangene er lagret.</p> : null}
      {tilstand?.feil ? <p className="feil" role="alert">{tilstand.feil}</p> : null}
      <button type="submit" disabled={venter} className="primar">{venter ? 'Lagrer …' : 'Lagre tilganger'}</button>
    </form>
  )
}
