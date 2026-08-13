import { kr } from '@/lib/format'

// Ett måltall med sammenligning. Delt mellom butikksjefens og eierens
// forside, så de to flatene ser ut som samme produkt.
export function Maal({ merke, naa, ifjor }: { merke: string; naa: number; ifjor: number }) {
  const pst = ifjor > 0 ? ((naa - ifjor) / ifjor) * 100 : 0
  const opp = pst >= 0
  return (
    <div className="sq-maal">
      <span className="sq-merkelapp">{merke}</span>
      <span className="sq-verdi">{kr.format(naa)}</span>
      <span className="sq-under">
        <span className={`sq-delta ${opp ? 'opp' : 'ned'}`}>
          {opp ? '↑' : '↓'} {Math.abs(pst).toFixed(0)} %
        </span>
        <span className="sq-merkelapp">
          {opp ? '+' : '−'}{kr.format(Math.abs(naa - ifjor))} mot i fjor
        </span>
      </span>
    </div>
  )
}
