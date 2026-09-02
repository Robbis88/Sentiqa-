import type { RegnskapVarsel } from '@/lib/regnskap-varsler'

// Admin-varsler etter opplastet regnskap: «alt som ikke er bra», sortert rød→gul.
export function RegnskapVarsler(
  { varsler, aar }: { varsler: RegnskapVarsel[]; aar: string },
) {
  if (varsler.length === 0) {
    return (
      <section className="kort varsler-tom">
        <p>✅ Alt ser bra ut — ingen varsler hittil i {aar}.</p>
      </section>
    )
  }

  const rod = varsler.filter((v) => v.nivaa === 'rod').length
  const gul = varsler.length - rod

  return (
    <section className="kort varsler">
      <details open>
        <summary>
          {/* PERIODEN MAATTE STAA.
              Varslene summeres fra 1. januar til valgt periode - se
              `fra` i regnskap-varsler.ts - mens tallene OVER dem er
              maaneden. To perioder paa samme skjerm, uten et ord om
              hvilken som er hvilken.

              Robert leste 72 107 kr i kaffemanko som julitall. Julis
              egen var 8 783; resten var de seks maanedene foer. Han saa
              det fordi han kjenner tallene - en annen leser ville trodd
              at juli var en katastrofemaaned.

              At svinn summeres over aaret er RIKTIG: en enkelt maaned er
              for stoeyende for telling, og det er aarets manko som skal
              nullstilles. Det er bare periodeangivelsen som manglet. */}
          <h2>
            ⚠️ Varsler ({varsler.length})
            {' '}
            <span className="undertittel">hittil i {aar}</span>
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
