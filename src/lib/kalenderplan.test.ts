import { describe, expect, test } from 'vitest'
import { planleggKalender, type Dagsvekt, type Vindu } from './bemanning'
import { dagsprofiler, datoerIMaaned } from './dagtyper'

const vindu = (fra = 6, til = 18, min = 1): Vindu[] =>
  [1, 2, 3, 4, 5, 6, 7].map((ukedag) => ({ ukedag, fraTime: fra, tilTime: til, minBemanning: min }))
const flatProfil = (n: number) => new Map(
  [1, 2, 3, 4, 5, 6, 7].flatMap((u) => Array.from({ length: 24 }, (_, t) => [`${u}:${t}`, n] as [string, number])))

// Mai 2026 har FEM røde dager: 1. mai, Kristi himmelfart 14., Grunnlovsdagen
// 17., og pinse 24.–25. Antallet regnes ut, ikke skrives inn.
// Hva de røde timene koster ekstra i et gitt vindu — regnet, ikke skrevet.
// Mai 2026 har fem hele røde dager OG pinseaften 23., rød fra 15.
const paaslag = (fra: number, til: number) => maiVekter().reduce((sum, d) => {
  if (d.rodFraTime === null) return sum
  let n = 0
  for (let t = fra; t < til; t++) if (t >= d.rodFraTime) n++
  return sum + n
}, 0)
const maiVekter = (): Dagsvekt[] =>
  dagsprofiler(datoerIMaaned(2026, 5), []).map((p) => ({
    dato: p.dato, ukedag: p.ukedag, faktor: p.faktor, rodFraTime: p.rodFraTime,
  }))

describe('planleggKalender', () => {
  test('en rød dag koster dobbelt av rammen', () => {
    const p = planleggKalender({
      disponibleTimer: 10000, dager: maiVekter(), vinduer: vindu(6, 18, 1),
      krav: [], fasteVakter: [], profil: new Map(),
    })
    // 12 timer x 31 dager = 372 persontimer i gulvet. De røde teller to.
    expect(p.bundneTimer).toBe(12 * 31 + paaslag(6, 18))
    expect(p.rodtPaaslag).toBe(paaslag(6, 18))
    // Fem hele dager (12 t hver) pluss tre timer 15–18 på pinseaften.
    expect(p.rodtPaaslag).toBe(5 * 12 + 3)
  })

  test('paaslaget er ikke smaatteri — det er nesten en uke i mai', () => {
    const p = planleggKalender({
      disponibleTimer: 10000, dager: maiVekter(), vinduer: vindu(5, 24, 1),
      krav: [], fasteVakter: [], profil: new Map(),
    })
    // Fem røde dager x 19 timer = 95 timer ekstra, uten at noen har
    // bestemt seg for å bruke dem.
    expect(p.rodtPaaslag).toBe(paaslag(5, 24))
    // Fem hele dager x 19 timer, pluss ni timer 15–24 på pinseaften.
    expect(p.rodtPaaslag).toBe(5 * 19 + 9)
  })

  test('ekstravakter legges heller på en vanlig dag enn en rød', () => {
    // Like mange kunder overalt. Da skal de frie timene gå dit de er
    // billigst — en rød time må gi dobbelt igjen for å være verdt det.
    const p = planleggKalender({
      disponibleTimer: 12 * 31 + paaslag(6, 18) + 6, // gulv + rødt påslag + én vakt
      dager: maiVekter(), vinduer: vindu(6, 18, 1),
      krav: [], fasteVakter: [], profil: flatProfil(10),
    })
    const paaRod = p.timer.filter((t) => t.kostnad === 2 && t.ekstra > 0)
    expect(paaRod).toHaveLength(0)
  })

  test('en dag med kraftig utfart får ekstra selv om den er rød', () => {
    const dager = maiVekter().map((d) =>
      d.dato === '2026-05-17' ? { ...d, faktor: 3 } : d)
    const p = planleggKalender({
      disponibleTimer: 12 * 31 + paaslag(6, 18) + 12,
      dager, vinduer: vindu(6, 18, 1), krav: [], fasteVakter: [], profil: flatProfil(10),
    })
    expect(p.timer.filter((t) => t.dato === '2026-05-17' && t.ekstra > 0).length)
      .toBeGreaterThanOrEqual(5)
  })

  test('butikksjefens ferie henter timer — den dekker ikke lenger gulvet', () => {
    const felles = {
      disponibleTimer: 10000, dager: maiVekter(), vinduer: vindu(6, 18, 1),
      krav: [], profil: new Map<string, number>(),
      fasteVakter: [1, 2, 3, 4, 5].map((ukedag) => ({ ukedag, fraTime: 8, tilTime: 16, navn: 'Stig' })),
    }
    const paaJobb = planleggKalender(felles)
    const iFerie = planleggKalender({
      ...felles,
      fravaer: [{ navn: 'Stig', fraDato: '2026-05-01', tilDato: '2026-05-31' }],
    })
    expect(iFerie.bundneTimer).toBeGreaterThan(paaJobb.bundneTimer)
    expect(iFerie.fasteTimer).toBe(0)
    // Ferien er ikke gratis: de timene Stig dekket må nå kjøpes.
    expect(iFerie.bundneTimer - paaJobb.bundneTimer).toBeGreaterThanOrEqual(paaJobb.fasteTimer)
  })

  test('en ferie midt i måneden treffer bare de dagene', () => {
    const felles = {
      disponibleTimer: 10000, dager: maiVekter(), vinduer: vindu(6, 18, 1),
      krav: [], profil: new Map<string, number>(),
      fasteVakter: [1, 2, 3, 4, 5].map((ukedag) => ({ ukedag, fraTime: 8, tilTime: 16, navn: 'Stig' })),
    }
    const hel = planleggKalender({ ...felles, fravaer: [{ navn: 'Stig', fraDato: '2026-05-01', tilDato: '2026-05-31' }] })
    const halv = planleggKalender({ ...felles, fravaer: [{ navn: 'Stig', fraDato: '2026-05-01', tilDato: '2026-05-15' }] })
    const ingen = planleggKalender(felles)
    expect(halv.bundneTimer).toBeGreaterThan(ingen.bundneTimer)
    expect(halv.bundneTimer).toBeLessThan(hel.bundneTimer)
  })

  test('taket fra historikken gjelder også her', () => {
    const tak = new Map([...Array(24).keys()].flatMap((t) =>
      [1, 2, 3, 4, 5, 6, 7].map((u) => [`${u}:${t}`, 1] as [string, number])))
    const p = planleggKalender({
      disponibleTimer: 100000, dager: maiVekter(), vinduer: vindu(6, 18, 1),
      krav: [], fasteVakter: [], profil: flatProfil(50), tak,
    })
    expect(p.timer.every((t) => t.sum <= 1)).toBe(true)
    expect(p.brukteTimer).toBe(0)
  })

  test('flagger at rammen ikke holder når gulvet pluss rødt sprenger den', () => {
    const p = planleggKalender({
      disponibleTimer: 12 * 31, // dekker gulvet, men ikke det røde påslaget
      dager: maiVekter(), vinduer: vindu(6, 18, 1),
      krav: [], fasteVakter: [], profil: new Map(),
    })
    expect(p.gjennomforbar).toBe(false)
    expect(p.underskudd).toBe(paaslag(6, 18))
  })

  test('bruker aldri mer enn rammen', () => {
    const p = planleggKalender({
      disponibleTimer: 500, dager: maiVekter(), vinduer: vindu(6, 18, 1),
      krav: [], fasteVakter: [], profil: flatProfil(20),
    })
    expect(p.bundneTimer + p.brukteTimer).toBeLessThanOrEqual(500)
  })
})
