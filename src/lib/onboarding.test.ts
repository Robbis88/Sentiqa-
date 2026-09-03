import { describe, expect, it, test } from 'vitest'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { KILDER, OPPSETT, nesteSteg, onboardingsteg, oppsettsteg, type Kildemaaling } from './onboarding'

const m = (noekkel: string, stasjoner: number, dager: number): Kildemaaling =>
  ({ noekkel, stasjonerMedData: stasjoner, dagerDekket: dager, sisteDato: '2026-08-13' })

const alt = (stasjoner: number, dager: number) => KILDER.map((k) => m(k.noekkel, stasjoner, dager))

// «Rikelig» er ikke et tall man kan skrive ned - det er den strengeste
// terskelen i lista. Sto det 400 her, ble testene roede da timesalg gikk
// fra 365 til 730 dager, uten at noe var galt med det de maalte.
const RIKELIG = Math.max(...KILDER.map((k) => k.anbefaltDager)) + 1

// Alt på plass, UNNTATT de nøklene som nevnes.
//
// Fiksturene ramset før opp kildene de ville ha på plass, og ble derfor
// ufullstendige hver gang lista vokste: da `bp_timer` kom til, var den
// plutselig et kritisk manglende steg i en test som handlet om noe helt
// annet, og testen falt uten at noe var galt. Nevn det du vil MANGLE.
const altUnntatt = (...utelatt: string[]) =>
  KILDER.filter((k) => !utelatt.includes(k.noekkel)).map((k) => m(k.noekkel, 5, RIKELIG))

describe('onboardingsteg', () => {
  test('en ny retailer mangler alt, og får vite hvor filene hentes', () => {
    const s = onboardingsteg([], 5)
    expect(s.every((x) => x.status === 'mangler')).toBe(true)
    expect(s[0].beskjed).toContain('St1-rapport 0714')
  })

  test('tre av fem stasjoner er ikke «ok» — det ser ferdig ut uten å være det', () => {
    const s = onboardingsteg([m('timesalg', 3, 400)], 5)
    const t = s.find((x) => x.noekkel === 'timesalg')!
    expect(t.status).toBe('ufullstendig')
    expect(t.beskjed).toContain('2 av 5')
  })

  test('for få dager er «tynt», ikke «mangler»', () => {
    const s = onboardingsteg([m('timesalg', 5, 60)], 5)
    expect(s.find((x) => x.noekkel === 'timesalg')!.status).toBe('tynt')
  })

  test('kilder uten dagskrav vurderes bare på om alle stasjoner har dem', () => {
    const s = onboardingsteg([m('bemanning_maned', 5, 0)], 5)
    expect(s.find((x) => x.noekkel === 'bemanning_maned')!.status).toBe('ok')
  })

  test('alt på plass gir ok hele veien', () => {
    const s = onboardingsteg(alt(5, RIKELIG), 5)
    expect(s.every((x) => x.status === 'ok')).toBe(true)
  })
})

describe('nesteSteg', () => {
  test('peker på det kritiske før det pene', () => {
    // Stemplinger mangler helt, men salgsstatistikk er tynn — og
    // salgsstatistikken bærer alt annet.
    const s = onboardingsteg(
      [...altUnntatt('stempling', 'st1_salgsstatistikk'), m('st1_salgsstatistikk', 5, 30)], 5)
    expect(nesteSteg(s)!.noekkel).toBe('st1_salgsstatistikk')
  })

  test('helt manglende går foran tynt, når begge er kritiske', () => {
    const s = onboardingsteg(
      [...altUnntatt('timesalg', 'st1_salgsstatistikk'), m('st1_salgsstatistikk', 5, 30)], 5)
    expect(nesteSteg(s)!.noekkel).toBe('timesalg')
  })

  test('når alt er på plass er det ingen neste steg', () => {
    expect(nesteSteg(onboardingsteg(alt(5, RIKELIG), 5))).toBeNull()
  })

  test('rekkefølgen i KILDER avgjør når alt annet er likt', () => {
    const s = onboardingsteg([], 5)
    expect(nesteSteg(s)!.noekkel).toBe(KILDER.find((k) => k.kritisk)!.noekkel)
  })
})

// =====================================================================
// OPPSETTSKRAV — det som ikke er en fil.
// =====================================================================

describe('oppsettsteg', () => {
  const krav = OPPSETT[0]

  it('sier «ikke satt opp» naar ingen stasjoner har det', () => {
    const [s] = oppsettsteg([{ noekkel: krav.noekkel, stasjonerMedOppsett: 0 }], 5)
    expect(s.status).toBe('mangler')
    expect(s.hvor).toBe(krav.gjoresI)
    expect(s.slag).toBe('oppsett')
  })

  // Den viktigste tilstanden. «Tre av fem» ser ferdig ut naar man ikke
  // teller - og de to andre stasjonene faar ingenting, i stillhet.
  it('sier hvor mange stasjoner som mangler, ikke bare at noe mangler', () => {
    const [s] = oppsettsteg([{ noekkel: krav.noekkel, stasjonerMedOppsett: 3 }], 5)
    expect(s.status).toBe('ufullstendig')
    expect(s.beskjed).toContain('2 av 5')
  })

  it('er ok foerst naar alle stasjonene er dekket', () => {
    const [s] = oppsettsteg([{ noekkel: krav.noekkel, stasjonerMedOppsett: 5 }], 5)
    expect(s.status).toBe('ok')
  })

  it('behandler en maaling som mangler som null, ikke som ok', () => {
    // En kilde uten maaling er ikke «ingen problemer funnet».
    const [s] = oppsettsteg([], 5)
    expect(s.status).toBe('mangler')
  })

  it('tar oppsettskrav med i nesteSteg', () => {
    const steg = oppsettsteg([{ noekkel: krav.noekkel, stasjonerMedOppsett: 0 }], 5)
    expect(nesteSteg(steg)?.noekkel).toBe(krav.noekkel)
  })
})

describe('hvert oppsettskrav blir faktisk maalt', () => {
  // DETTE ER DEKNINGSSJEKKEN, og den er viktigere enn regnestykket over.
  // `oppsettsteg()` gaar over OPPSETT; et krav ingen MAALER faar
  // `stasjonerMedOppsett = 0` og staar evig som «mangler» - eller, verre,
  // blir lagt til uten at noen skriver maalingen, og da lyver lista.
  //
  // Vakten leser importsida, som er stedet maalingene bor.
  const side = readFileSync(
    join(process.cwd(), 'src', 'app', '(beskyttet)', 'import', 'page.tsx'), 'utf8')

  it('KANARIFUGL: vakten finner maalefunksjonen i det hele tatt', () => {
    expect(side).toContain('maalOppsett')
    expect(OPPSETT.length).toBeGreaterThan(0)
  })

  it('hver noekkel i OPPSETT settes av en maaling', () => {
    const umaalte = OPPSETT.filter((k) => !side.includes(`'${k.noekkel}'`))
    expect(umaalte.map((k) => k.noekkel),
      'oppsettskrav som ingen maaler - de vil staa som «mangler» for alltid').toEqual([])
  })

  it('maalingen leser den samme koblingen utsendingen leser', () => {
    // «Én sannhet, ikke to»: bytter noen denne mot en haandholdt hake,
    // skiller lista og modulen lag i stillhet.
    expect(side).toContain('butikksjef_stasjoner')
  })
})

