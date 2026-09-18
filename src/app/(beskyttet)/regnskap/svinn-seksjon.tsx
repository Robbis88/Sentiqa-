import { kr, prosent } from '@/lib/format'
import { beregnSvinnRapport, type SvinnRad } from '@/lib/regnskap/svinn-rapport'

export function SvinnSeksjon({ rader, periodeetikett, komplett = true, dekning = [], forrige = [], fjor = [] }: { rader: SvinnRad[]; periodeetikett: string; komplett?: boolean; dekning?: { kilde: string; siste_dato: string | null }[]; forrige?: SvinnRad[]; fjor?: SvinnRad[] }) {
  const rapport = beregnSvinnRapport(rader, komplett)
  const forrigeRapport = forrige.length ? beregnSvinnRapport(forrige) : null
  const fjorRapport = fjor.length ? beregnSvinnRapport(fjor) : null
  const kort = [
    ['Registrert svinn', rapport.registrert],
    ['Usynlig manko', rapport.manko],
    ['Uforklart overskudd', rapport.overskudd],
  ] as const
  const tidligere = (i: number, r: ReturnType<typeof beregnSvinnRapport> | null) => r ? [r.registrert, r.manko, r.overskudd][i].kr : null
  return <section className="kort" aria-label={`Svinn i ${periodeetikett}`}>
    <h2>Svinn i {periodeetikett}</h2>
    <p className="undertittel">Kilden er den månedlige svinnrapporten. Daglige transaksjoner inngår ikke i totalsummen.</p>
    <div className="sq-nokkelrad">
      {kort.map(([navn, k], i) => <div className="kpi" key={navn}>
        <span className="kpi-tall">{kr.format(k.kr)}</span><span className="kpi-merke">{navn}</span>
        <span className={`kpi-mot${k.status === 'fullstendig' ? '' : ' darlig'}`}>{k.prosent == null ? 'Kan ikke beregnes mot salg' : prosent.format(k.prosent / 100)}</span>
        <small>{k.status !== 'fullstendig' ? 'Manglende eller usikkert grunnlag' : `Forrige måned: ${tidligere(i, forrigeRapport) == null ? 'Ikke sammenlignbart' : kr.format(k.kr - tidligere(i, forrigeRapport)!)} · Samme måned i fjor: ${tidligere(i, fjorRapport) == null ? 'Ikke sammenlignbart' : kr.format(k.kr - tidligere(i, fjorRapport)!)}`}</small>
      </div>)}
    </div>
    {rapport.avdelinger.length === 0 ? <p className="undertittel">Manglende svinnrapport for perioden.</p> : <div className="tabell-wrap"><table className="tabell"><thead><tr><th>Avdeling</th><th>Salg</th><th>Registrert svinn</th><th>Manko</th><th>Overskudd</th><th>Samlet avvik</th><th>Status</th></tr></thead><tbody>{rapport.avdelinger.map((a) => <tr key={a.kode}><td>{a.navn} <small>({a.kode})</small></td><td>{kr.format(a.salg)}</td><td>{kr.format(a.registrert)}</td><td>{kr.format(a.manko)}</td><td>{kr.format(a.overskudd)}</td><td>{a.samlet == null ? '—' : kr.format(a.samlet)}{a.prosent == null ? '' : ` · ${prosent.format(a.prosent / 100)}`}</td><td>{a.status === 'fullstendig' ? 'Kontroller ved avvik' : 'Usikkert'}</td></tr>)}</tbody></table></div>}
    <p className="undertittel sq-finstilt">Datadekning: regnskap {dekning.find((d) => d.kilde === 'regnskapslinjer')?.siste_dato ?? 'mangler'} · salg {dekning.find((d) => d.kilde === 'st1_salgsstatistikk')?.siste_dato ?? 'mangler'} · svinnrapport {rader.length ? periodeetikett : 'mangler'} · varetellingsgrunnlag {rader.length ? 'tilgjengelig' : 'mangler'}.</p>
    <p className="undertittel sq-finstilt">Mulige forklaringer må undersøkes. Uforklart overskudd er ikke automatisk positivt, og manko er ikke bevis på tyveri.</p>
  </section>
}
