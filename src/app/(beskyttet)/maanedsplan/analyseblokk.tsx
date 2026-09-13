// Mat- og svinnanalysen på plankortet.
//
// =====================================================================
// SEKS SPØRSMÅL BUTIKKSJEFEN SKAL KUNNE SVARE PÅ
// =====================================================================
//
//   1  Hvor ligger vi nå?           → talltabellen
//   2  Hva var budsjettet ved DENNE omsetningen?  → justert kastbudsjett
//   3  Er vi over eller under?      → avvik i kroner og prosentpoeng
//   4  Går vi riktig eller feil vei? → retningslinja, med perioden
//   5  Er tallet pålitelig?         → merket, og blokkeringsårsaken
//   6  Hvorfor får vi et tiltak?    → forklaringen fra beregningen
//
// ---------------------------------------------------------------------
// EN BLOKKERT ANALYSE FORSVINNER IKKE
//
// Før P2 falt matkast bare ut av `punkter` når den ikke kunne regnes, og
// kortet så komplett ut. Da tror den som leser at alt er i orden.
// Blokkert vises med årsak og måned, og rangeres aldri.
//
// ---------------------------------------------------------------------
// INGEN BEREGNING HER. Alt kommer fra `analysevisning.ts`, som leser det
// lagrede øyeblikksbildet. Komponenten formaterer ikke engang tallene.

import { matkastvisning, usynligvisning } from '@/lib/kurs/analysevisning'
import { lesMatkast, lesUsynlig } from '@/lib/kurs/snapshot'

export function Analyseblokk({ matkast, usynlig }: { matkast: unknown; usynlig: unknown }) {
  const m = matkastvisning(lesMatkast(matkast))
  const u = usynligvisning(lesUsynlig(usynlig))

  return (
    <div className="sq-analyser">
      <section className={`sq-analyse sq-analyse-${m.slag}`}>
        <header className="sq-analyse-hode">
          <h4 className="sq-analyse-tittel">Synlig matkast</h4>
          <span className={`sq-analyse-merke sq-merke-${m.slag}`}>{m.merke}</span>
        </header>

        {(m.slag === 'ikke_beregnet' || m.slag === 'blokkert') ? (
          <div className="sq-analyse-stengt">
            <p className="sq-analyse-stengt-tittel">{m.tittel}</p>
            <p className="sq-analyse-stengt-tekst">{m.tekst}</p>
            {m.slag === 'blokkert' && m.maaned && (
              <p className="sq-analyse-stengt-maaned">Gjelder måneden {m.maaned}</p>
            )}
          </div>
        ) : (
          <>
            <dl className="sq-analyse-rader">
              {m.rader.map((r) => (
                <div key={r.navn} className="sq-analyse-rad">
                  <dt>{r.navn}</dt>
                  <dd>
                    {r.verdi}
                    {r.bi && <span className="sq-analyse-bi">{r.bi}</span>}
                  </dd>
                </div>
              ))}
            </dl>
            <p className="sq-analyse-retning">{m.retning}</p>
            <p className="sq-analyse-forklaring">{m.forklaring}</p>
          </>
        )}
      </section>

      <section className={`sq-analyse sq-analyse-${u.slag}`}>
        <header className="sq-analyse-hode">
          <h4 className="sq-analyse-tittel">Uforklart matavvik</h4>
          <span className={`sq-analyse-merke sq-merke-${u.slag}`}>{u.merke}</span>
        </header>

        {(u.slag === 'ikke_beregnet' || u.slag === 'blokkert') ? (
          <div className="sq-analyse-stengt">
            <p className="sq-analyse-stengt-tittel">{u.tittel}</p>
            <p className="sq-analyse-stengt-tekst">{u.tekst}</p>
            {u.slag === 'blokkert' && u.maaned && (
              <p className="sq-analyse-stengt-maaned">Gjelder måneden {u.maaned}</p>
            )}
          </div>
        ) : (
          <>
            <p className="sq-analyse-tall">{u.verdi}</p>
            <p className={u.slag === 'usikker'
              ? 'sq-analyse-usikker' : 'sq-analyse-retning'}>
              {u.utvikling}
            </p>
            <p className="sq-analyse-forklaring">{u.forklaring}</p>
            <p className="sq-analyse-aarsaker">{u.aarsaker}</p>
          </>
        )}
      </section>
    </div>
  )
}