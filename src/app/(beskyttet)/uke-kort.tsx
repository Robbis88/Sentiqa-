import { kr } from '@/lib/format'
import type { UkeRapport, UkeAvdeling } from '@/lib/ukerapport'

function pst(naa: number, ifjor: number): number {
  return ifjor > 0 ? ((naa - ifjor) / ifjor) * 100 : 0
}

function Metrikk({ merke, naa, ifjor }: { merke: string; naa: number; ifjor: number }) {
  const p = pst(naa, ifjor)
  const opp = p >= 0
  const diff = naa - ifjor
  return (
    <div className="uke-metrikk">
      <span className="uke-merke">{merke}</span>
      <span className="uke-stor">{kr.format(naa)}</span>
      <span className={`uke-vekst ${opp ? 'gronn' : 'rod'}`}>
        {opp ? '▲' : '▼'} {opp ? '+' : '−'}{Math.abs(p).toFixed(1)} % ({opp ? '+' : '−'}{kr.format(Math.abs(diff))})
      </span>
      <span className="uke-ifjor">I fjor: {kr.format(ifjor)}</span>
    </div>
  )
}

function AvdRad({ a }: { a: UkeAvdeling }) {
  const opp = a.vekstPst >= 0
  return (
    <li>
      <span>{a.navn}</span>
      <span className={`uke-avd-pst ${opp ? 'gronn' : 'rod'}`}>{opp ? '+' : '−'}{Math.abs(a.vekstPst).toFixed(0)} %</span>
    </li>
  )
}

export function UkeKort({ rapport: r }: { rapport: UkeRapport }) {
  const sortert = [...r.avdelinger].filter((a) => a.ifjor > 0 && a.omsetning > 0).sort((a, b) => b.vekstPst - a.vekstPst)
  const topp = sortert.slice(0, 2)
  const bunn = sortert.slice(-2).reverse().filter((a) => !topp.includes(a))

  return (
    <section className="kort uke-kort">
      <h2>Forrige uke · {r.navn}</h2>
      {/* 🤖 var den eneste merkingen av at avsnittet er maskinskrevet.
          En robot-emoji er en svak maate aa si det paa: den leses ikke
          av en skjermleser som «AI», og den forsvinner for den som har
          slaatt av emoji-fonten. Naa staar det i ord. */}
      {r.sammendrag && (
        <p className="uke-ai">
          <span className="sq-merkelapp">Sentiqas oppsummering</span> {r.sammendrag}
        </p>
      )}

      <div className="uke-tall">
        <Metrikk merke="Omsetning" naa={r.omsetning} ifjor={r.omsetningIfjor} />
        <Metrikk merke="Bruttofortjeneste" naa={r.brutto} ifjor={r.bruttoIfjor} />
      </div>

      {sortert.length > 0 && (
        <div className="uke-avd">
          <div>
            <h3 className="uke-avd-tittel gronn">Sterkest vekst</h3>
            <ul className="uke-avd-liste">{topp.map((a) => <AvdRad key={a.kode} a={a} />)}</ul>
          </div>
          {bunn.length > 0 && (
            <div>
              <h3 className="uke-avd-tittel rod">Svakest</h3>
              <ul className="uke-avd-liste">{bunn.map((a) => <AvdRad key={a.kode} a={a} />)}</ul>
            </div>
          )}
        </div>
      )}
    </section>
  )
}
