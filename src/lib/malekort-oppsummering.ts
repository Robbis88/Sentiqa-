import type { Malekort, MalekortResultat } from './malekort'

export function egneMaalinger(kort: Pick<Malekort, 'navn'>, resultat: MalekortResultat, egne: Set<string>): string[] {
  if (!resultat.klar) return []
  return [
    ...resultat.rader.flatMap((rad, i) => egne.has(rad.stasjonId)
      ? [`${rad.navn}: ${i + 1}. plass av ${resultat.rader.length} på «${kort.navn}»`] : []),
    ...(resultat.utenGrunnlag ?? []).flatMap((rad) => egne.has(rad.stasjonId)
      ? [`${rad.navn}: ikke målbart på «${kort.navn}» (${rad.grunn})`] : []),
  ]
}

export function maalegrunnlag(kort: Pick<Malekort, 'normalisering' | 'retning' | 'metrikk'>): string {
  const volum = ['omsetning', 'antall', 'brutto'].includes(kort.metrikk)
  const grunnlag = kort.normalisering === 'vekst_pst' ? 'Vekst mot i fjor (%)'
    : kort.normalisering === 'per_kunde' && volum ? 'Per kunde' : 'Målt verdi'
  return `${grunnlag} · ${kort.retning === 'lav' ? 'lavest' : 'høyest'} er best`
}
