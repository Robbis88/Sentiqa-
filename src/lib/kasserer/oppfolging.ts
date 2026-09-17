import { erSystemnummer, per100, type Kassererrad } from './rate'

// Foreløpige, synlige vurderingsgrenser – ikke en validert svindeldetektor.
export const RETURGRENSER = { bonger: 100, historiskeBonger: 1000, maaneder: 3, returer: 5, faktor: 2, prosentpoeng: 1 } as const

export function returOppfolging(rader: Kassererrad[], maaned: string) {
  const valgte = rader.filter(r => r.maned === maaned && !erSystemnummer(r.kasserer_nr))
  return valgte.map(rad => {
    const historikk = rader.filter(r => r.stasjon_id === rad.stasjon_id && r.kasserer_nr === rad.kasserer_nr && r.maned < maaned && r.bonger >= RETURGRENSER.bonger)
    const navn = new Set([rad, ...historikk].map(r => r.navn?.trim()).filter(Boolean))
    const tvetydig = navn.size > 1 || [rad, ...historikk].some(r => r.ulike_navn > 1)
    const historiskeBonger = historikk.reduce((sum, r) => sum + r.bonger, 0)
    const normal = per100(historikk.reduce((sum, r) => sum + r.retur_antall, 0), historiskeBonger)
    const rate = per100(rad.retur_antall, rad.bonger)
    const nok = rad.bonger >= RETURGRENSER.bonger && historiskeBonger >= RETURGRENSER.historiskeBonger && historikk.length >= RETURGRENSER.maaneder
    const utslag = nok && !tvetydig && rate !== null && normal !== null && rad.retur_antall >= RETURGRENSER.returer && rate >= normal * RETURGRENSER.faktor && rate - normal >= RETURGRENSER.prosentpoeng
    return { rad, rate, normal, historiskeBonger, maaneder: historikk.length, tvetydig, nok, utslag }
  })
}
