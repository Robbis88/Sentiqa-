// Kampanjeeffekt: måler en kampanje mot ukene rett før. Tre effekter hver for
// seg — kampanjevarenes salg, innekunder (kom flere inn?) og fangstrate
// (innekunder ÷ biler forbi, der trafikk er målt). Ren funksjon; datahenting
// skjer i kall-laget. «Uke mot uke» = kampanjeperioden vs. like lang periode rett før.

function leggTilDager(iso: string, n: number): string {
  const d = new Date(`${iso}T12:00:00Z`); d.setUTCDate(d.getUTCDate() + n); return d.toISOString().slice(0, 10)
}
function dagerMellom(fra: string, til: string): number {
  return Math.round((new Date(`${til}T12:00:00Z`).getTime() - new Date(`${fra}T12:00:00Z`).getTime()) / 86400000) + 1
}
const pst = (ny: number, gml: number): number | null => (gml > 0 ? Math.round(((ny / gml) - 1) * 1000) / 10 : null)

export type DagSalg = { dato: string; antall: number; antallTilbud: number; omsetning: number }
export type DagKunder = { dato: string; innekunder: number }
export type DagTrafikk = { dato: string; biler: number }

export type Periode = { antall: number; antallTilbud: number; omsetning: number; innekunder: number; biler: number; harTrafikk: boolean }
export type KampanjeEffekt = {
  fraDato: string; tilDato: string; baselineFra: string; baselineTil: string; dager: number
  kampanje: Periode; baseline: Periode
  antallLoft: number | null; omsetningLoft: number | null; innekunderLoft: number | null
  trafikkEndring: number | null
  fangstrateKampanje: number | null; fangstrateBaseline: number | null; fangstrateLoft: number | null
  konklusjon: string[]
}

export function maalKampanje(opts: {
  fraDato: string; tilDato: string
  salg: DagSalg[]        // kampanjevarenes salg (alle dager i analysevinduet)
  kunder: DagKunder[]    // innekunder pr dag (sum over kampanjens stasjoner)
  trafikk: DagTrafikk[]  // biler pr dag (sum over MÅLTE stasjoner); tom = ingen trafikk
}): KampanjeEffekt {
  const { fraDato, tilDato } = opts
  const lengde = dagerMellom(fraDato, tilDato)
  const baselineTil = leggTilDager(fraDato, -1)
  const baselineFra = leggTilDager(fraDato, -lengde)
  const iKamp = (d: string) => d >= fraDato && d <= tilDato
  const iBase = (d: string) => d >= baselineFra && d <= baselineTil

  const tom = (): Periode => ({ antall: 0, antallTilbud: 0, omsetning: 0, innekunder: 0, biler: 0, harTrafikk: false })
  const k = tom(), b = tom()
  for (const r of opts.salg) { const p = iKamp(r.dato) ? k : iBase(r.dato) ? b : null; if (p) { p.antall += r.antall; p.antallTilbud += r.antallTilbud; p.omsetning += r.omsetning } }
  for (const r of opts.kunder) { const p = iKamp(r.dato) ? k : iBase(r.dato) ? b : null; if (p) p.innekunder += r.innekunder }
  for (const r of opts.trafikk) { const p = iKamp(r.dato) ? k : iBase(r.dato) ? b : null; if (p) { p.biler += r.biler; p.harTrafikk = true } }

  const harTrafikk = k.biler > 0 && b.biler > 0
  const fangstK = harTrafikk ? Math.round((k.innekunder / k.biler) * 1000) / 10 : null
  const fangstB = harTrafikk ? Math.round((b.innekunder / b.biler) * 1000) / 10 : null
  const antallLoft = pst(k.antall, b.antall)
  const omsetningLoft = pst(k.omsetning, b.omsetning)
  const innekunderLoft = pst(k.innekunder, b.innekunder)
  const trafikkEndring = harTrafikk ? pst(k.biler, b.biler) : null
  const fangstrateLoft = fangstK != null && fangstB != null && fangstB > 0 ? Math.round(((fangstK / fangstB) - 1) * 1000) / 10 : null

  const konklusjon: string[] = []
  if (antallLoft != null) konklusjon.push(`Kampanjevarene solgte ${antallLoft >= 0 ? '+' : ''}${antallLoft} % (${Math.round(b.antall)} → ${Math.round(k.antall)} stk) mot ukene før.`)
  if (harTrafikk) {
    konklusjon.push(`Trafikken forbi ${trafikkEndring! >= 0 ? 'økte' : 'falt'} ${Math.abs(trafikkEndring!)} %.`)
    if (fangstrateLoft != null) {
      if (fangstrateLoft >= 5) konklusjon.push(`Fangstraten steg fra ${fangstB} % til ${fangstK} % (+${fangstrateLoft} %) — kampanjen trakk en større andel av bilene inn. Ekte kampanjeeffekt, ikke bare mer trafikk.`)
      else if (fangstrateLoft <= -5) konklusjon.push(`Fangstraten falt fra ${fangstB} % til ${fangstK} % (${fangstrateLoft} %) — salgsøkningen skyldtes trafikk, ikke kampanjen.`)
      else konklusjon.push(`Fangstraten var nær uendret (${fangstB} % → ${fangstK} %) — kampanjen flyttet i hovedsak eksisterende kunder.`)
    }
  } else {
    konklusjon.push('Ingen trafikkdata for stasjonen(e) — kun rått salgsløft, ikke fangstrate.')
  }
  if (innekunderLoft != null) konklusjon.push(`Innekunder totalt ${innekunderLoft >= 0 ? '+' : ''}${innekunderLoft} %.`)

  return { fraDato, tilDato, baselineFra, baselineTil, dager: lengde, kampanje: k, baseline: b, antallLoft, omsetningLoft, innekunderLoft, trafikkEndring, fangstrateKampanje: fangstK, fangstrateBaseline: fangstB, fangstrateLoft, konklusjon }
}
