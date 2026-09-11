import { describe, expect, it } from 'vitest'
import {
  nettoPerKrone,
  royaltyAv,
  royaltyForAaret,
  satsFor,
  verdiAvGevinst,
  type Satser,
} from './royalty'

// Kelsar 2026, fra BP-arket «Cluster data».
const S: Satser = { lavSats: 0.1, hoySatsVask: 0.6, pantSats: 0 }

describe('satsFor', () => {
  it('gir tre ulike satser, ikke én', () => {
    expect(satsFor('ordinaer', S)).toBe(0.1)
    expect(satsFor('vask_kasse', S)).toBe(0.6)
    expect(satsFor('pant', S)).toBe(0)
  })

  it('vask paa abonnement betaler ingen royalty', () => {
    expect(satsFor('vask_app', S)).toBe(0)
  })
})

describe('verdiAvGevinst', () => {
  // ---- REGELEN -------------------------------------------------------
  it('KANARI: en marginforbedring betaler INGEN royalty', () => {
    // Grunnlaget er omsetning. Selger du like mye og mister mindre paa
    // veien, oeker ikke omsetningen - og da oeker ikke royaltyen.
    //
    // Blir denne roed fordi noen trakk fra en sats, er svinnarbeid
    // undervurdert med den satsen i hver eneste beregning i systemet.
    expect(verdiAvGevinst({ type: 'margin', kroner: 100_000 }, S)).toBe(100_000)
    expect(royaltyAv({ type: 'margin', kroner: 100_000 }, S)).toBe(0)
  })

  it('KANARI: ikke det gamle "30 % av gevinsten"', () => {
    // 0,30 var klusterets royalty maalt mot BUTIKKMARGINEN - en
    // observasjon, ikke en regel. Brukt paa en svinngevinst ga den
    // 70 000 der svaret er 100 000.
    expect(verdiAvGevinst({ type: 'margin', kroner: 100_000 }, S)).not.toBe(70_000)
  })

  it('volumvekst betaler satsen for sin kanal', () => {
    const mat = verdiAvGevinst(
      { type: 'volum', omsetningKr: 100_000, bruttomargin: 0.489, kanal: 'ordinaer' }, S)
    expect(mat).toBeCloseTo(38_900, 0)

    const vask = verdiAvGevinst(
      { type: 'volum', omsetningKr: 100_000, bruttomargin: 0.835, kanal: 'vask_kasse' }, S)
    expect(vask).toBeCloseTo(23_500, 0)
  })

  it('KANARI: samme vask er verdt tre ganger mer i appen enn over kassa', () => {
    // Samme vare, samme margin, bare ulik kanal. Faller kanalen bort av
    // en forenkling, blir raadet "selg mer bilvask over kassa" - og det
    // er feil raad.
    const kasse = verdiAvGevinst(
      { type: 'volum', omsetningKr: 100_000, bruttomargin: 0.866, kanal: 'vask_kasse' }, S)
    const app = verdiAvGevinst(
      { type: 'volum', omsetningKr: 100_000, bruttomargin: 0.866, kanal: 'vask_app' }, S)
    expect(app / kasse).toBeGreaterThan(3)
  })

  it('mat slaar vask over kassa, motsatt av det brutto sier', () => {
    // 86,6 % brutto mot 48,9 % ser ut som at vask vinner klart. Etter
    // royalty er det omvendt, og det var feilen i handlingsplanen.
    const mat = nettoPerKrone(0.489, 'ordinaer', S)
    const vask = nettoPerKrone(0.866, 'vask_kasse', S)
    expect(mat).toBeGreaterThan(vask)
    expect(mat / vask).toBeCloseTo(1.46, 1)
  })
})

describe('royaltyForAaret — avstemt mot BP', () => {
  // Kelsar 2026, «Cluster data». Gaar opp paa oeret mot arkets egen
  // «Sum Royalty» = 10 093 457,90.
  const BP = {
    crSalg: 68_249_457.1,
    omsetningVask: 8_553_540.42,
    omsetningPant: 349_341.55,
    // Vask over kassa = total vask minus den digitale andelen. BP oppgir
    // royaltyen paa vask direkte til 4 158 800,39; delt paa 0,60 gir det
    // grunnlaget.
    vaskOverKassa: 4_158_800.39 / 0.6,
  }

  it('rekonstruerer BPs egen sum innenfor 1 %', () => {
    const beregnet = royaltyForAaret(BP, S)
    const oppgitt = 10_093_457.9
    const avvikPst = Math.abs((beregnet - oppgitt) / oppgitt) * 100
    expect(avvikPst).toBeLessThan(1)
  })

  it('KANARI: en feil sats gjoer at avstemmingen ryker', () => {
    // Uten denne maaler testen over ingenting: en avstemming som taaler
    // hva som helst er ikke en avstemming.
    const feil: Satser = { ...S, lavSats: 0.12 }
    const beregnet = royaltyForAaret(BP, feil)
    const avvikPst = Math.abs((beregnet - 10_093_457.9) / 10_093_457.9) * 100
    expect(avvikPst).toBeGreaterThan(1)
  })

  // ---- EN FELLE SOM ER VERDT AA SKRIVE NED --------------------------
  it('avstemmingen kan IKKE skille den gale modellen fra den riktige', () => {
    // «Royalty er 30 % av butikkmarginen» er den modellen systemet hadde
    // foer. Paa Kelsars miks 2026 treffer den innenfor 0,4 %:
    //
    //   33 775 958 brutto x 0,30 = 10 132 787
    //   BPs egen Sum Royalty     = 10 093 458
    //
    // Altsaa: aarsavstemmingen over ville vaert GROENN ogsaa med feil
    // modell. Den beviser at satsene er plausible, ikke at grunnlaget er
    // forstatt.
    const somMargin = 33_775_958 * 0.3
    const avvikPst = Math.abs((somMargin - 10_093_457.9) / 10_093_457.9) * 100
    expect(avvikPst).toBeLessThan(1)
  })

  it('KANARI: men modellene spriker kraftig naar MIKSEN endrer seg', () => {
    // Og det er akkurat naar det betyr noe - en anbefaling ER en endring
    // i miks. Derfor er det disse testene som er vakten, ikke
    // aarsavstemmingen.
    //
    // 100 000 kroner mer maskinvask over kassa:
    const riktig = verdiAvGevinst(
      { type: 'volum', omsetningKr: 100_000, bruttomargin: 0.866, kanal: 'vask_kasse' }, S)
    const somMargin = 100_000 * 0.866 * 0.7   // 30 % av marginen
    expect(riktig).toBeCloseTo(26_600, 0)
    expect(somMargin).toBeCloseTo(60_620, 0)
    // Den gale modellen lover mer enn det DOBBELTE.
    expect(somMargin / riktig).toBeGreaterThan(2)
  })

  it('KANARI: og de spriker paa en svinngevinst, som er den vanligste', () => {
    const riktig = verdiAvGevinst({ type: 'margin', kroner: 100_000 }, S)
    const somMargin = 100_000 * 0.7
    expect(riktig - somMargin).toBe(30_000)
  })
})
