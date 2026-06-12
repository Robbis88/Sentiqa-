import type { RegnskapVarsel } from '@/lib/regnskap-varsler'

// Admin-varsler etter opplastet regnskap: «alt som ikke er bra», sortert rød→gul.
export function RegnskapVarsler({ varsler }: { varsler: RegnskapVarsel[] }) {
  if (varsler.length === 0) {
    return (
      <section className="kort varsler-tom">
        <p>✅ Alt ser bra ut — ingen varsler for denne perioden.</p>
      </section>
    )
  }

  const rod = varsler.filter((v) => v.nivaa === 'rod').length
  const gul = varsler.length - rod

  return (
    <section className="kort varsler">
      <details open>
        <summary>
          <h2>
            ⚠️ Varsler ({varsler.length})
            <span className="varsler-teller">
              {rod > 0 && <span className="status-pip rod">{rod} krever tiltak</span>}
              {gul > 0 && <span className="status-pip gul">{gul} følg med</span>}
            </span>
          </h2>
        </summary>
        <ul className="varsler-liste">
          {varsler.map((v, i) => (
            <li key={i} className={`varsel ${v.nivaa}`}>
              <span className="varsel-dott" aria-hidden />
              <div className="varsel-tekst">
                <span className="varsel-topp">
                  <strong>{v.tittel}</strong>
                  <span className="varsel-omfang">{v.omfang}</span>
                </span>
                <span className="varsel-detalj">{v.detalj}</span>
              </div>
            </li>
          ))}
        </ul>
      </details>
    </section>
  )
}
