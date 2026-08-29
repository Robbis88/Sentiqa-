import { describe, it, expect } from 'vitest'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { erPrognosedag } from './forventet'

// =====================================================================
// EN PROGNOSE FOR EN DAG SOM HAR VAERT, ER IKKE EN PROGNOSE
//
// `lagSalgsprognose` bruker vaervarselet for maaldagen og trenden de
// siste fire ukene foer siste salgsdag. Kalles den for en dag som ligger
// bakover, regner den med tall fra ETTER dagen den skal forutsi.
//
// Tallet ville sett helt rimelig ut. Det er hele problemet: et
// etterpaaklokt anslag som ser ut som en prognose er verre enn en tom
// kolonne, fordi ingen kan se forskjell.
//
//   «vi trenger bare forventet for dagen etterpaa, saa ikke det loves
//    mere enn vi kan» - Robert 2026-08-29
// =====================================================================

describe('erPrognosedag', () => {
  it('er sann bare for kalenderens i morgen', () => {
    expect(erPrognosedag('2026-08-30', '2026-08-29')).toBe(true)
  })

  it('KANARIFUGL: er usann for i dag og for alt bakover', () => {
    // Blir denne sann for en dag som har vaert, faar den dagen et
    // «forventet» bygget paa sin egen fasit.
    expect(erPrognosedag('2026-08-29', '2026-08-29')).toBe(false)
    expect(erPrognosedag('2026-08-28', '2026-08-29')).toBe(false)
    expect(erPrognosedag('2026-08-01', '2026-08-29')).toBe(false)
  })

  it('KANARIFUGL: er usann for overmorgen og lenger fram', () => {
    // Vaervarselet finnes ikke ni dager fram, og trenden sier ingenting
    // om en dag saa langt borte.
    expect(erPrognosedag('2026-08-31', '2026-08-29')).toBe(false)
    expect(erPrognosedag('2026-09-05', '2026-08-29')).toBe(false)
  })

  it('KANARIFUGL: maalt fra I DAG, ikke fra siste salgsdag', () => {
    // Importen ligger to dager bak: siste salgsdag 27., i dag 29.
    // Regnes prognosedagen fra salgsdataene, ville sida tilbudt en
    // «prognose» for den 28. - en dag som alt er forbi - og /salg og
    // /salgsprognose ville svart for hver sin dag.
    expect(erPrognosedag('2026-08-28', '2026-08-29')).toBe(false)
    expect(erPrognosedag('2026-08-30', '2026-08-29')).toBe(true)
  })

  it('krysser maanedsskiftet riktig', () => {
    expect(erPrognosedag('2026-09-01', '2026-08-31')).toBe(true)
    expect(erPrognosedag('2026-03-01', '2026-02-28')).toBe(true)
    // 2028 er skuddaar: dagen etter 28. februar er den 29., ikke 1. mars.
    expect(erPrognosedag('2028-03-01', '2028-02-28')).toBe(false)
    expect(erPrognosedag('2028-02-29', '2028-02-28')).toBe(true)
  })
})

// =====================================================================
// ÉN KILDE, TO SIDER
//
// /salg og /salgsprognose skal vise SAMME tall for samme dag. Skrives
// regnestykket to steder, skiller de lag i stillhet - og da har
// produktet to sannheter om i morgen.
// =====================================================================

describe('prognosen regnes ett sted', () => {
  const les = (sti: string) => readFileSync(join(process.cwd(), sti), 'utf8')
  const utenKommentarer = (k: string) =>
    k.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/.*$/gm, '')

  it('/salg kaller hentForventet og ikke lagSalgsprognose selv', () => {
    const kilde = utenKommentarer(les('src/app/(beskyttet)/salg/page.tsx'))
    expect(kilde).toContain('hentForventet')
    expect(
      kilde,
      '/salg skal ikke bygge prognosen selv — da kan den skille lag med /salgsprognose',
    ).not.toContain('lagSalgsprognose')
  })

  it('KANARIFUGL: monsteret ville sett et direkte kall', () => {
    expect(utenKommentarer('const p = lagSalgsprognose({ maalDato })')).toContain('lagSalgsprognose')
  })

  it('kalibreringen er med, ikke bare raatallet', () => {
    // Uten `hentKalibrering` her ville /salg vist raa prognose og
    // /salgsprognose den kalibrerte - samme dag, to tall.
    const kilde = les('src/lib/salg/forventet.ts')
    expect(kilde).toContain('hentKalibrering')
  })
})
