import { describe, expect, test } from 'vitest'
import { lagBemanningsvarsler, type BemanningsMaaling } from './bemanningsvarsler'

// Dale i juli 2026: 1254 timer brukt mot 1084 disponible, sats 227 mot 217
// budsjettert, brutto per time 530 mot clusterets 647.
const DALE: BemanningsMaaling = {
  maned: 7,
  timerBrukt: 1254,
  timerDisponible: 1084,
  timesatsFaktisk: 226.75,
  timesatsBudsjett: 216.76,
  bruttoPrTime: 529.56,
  bruttoPrTimeCluster: 646.87,
  bruttoFaktisk: 640000,
  bruttoBudsjett: 700000,
  sykelonnNetto: 5000,
  reserveKr: 8000,
  lonnAvBrutto: 0.59,
}

const FRISK: BemanningsMaaling = {
  ...DALE,
  timerBrukt: 1000,
  timesatsFaktisk: 210,
  bruttoPrTime: 700,
  bruttoFaktisk: 700000,
  sykelonnNetto: 1000,
}

const typer = (m: BemanningsMaaling) => lagBemanningsvarsler(m).map((v) => v.type)

describe('bemanningsvarsler', () => {
  test('timeoverforbruk oversettes til vakter og kroner', () => {
    const v = lagBemanningsvarsler(DALE).find((x) => x.type === 'bemanning_timer')!
    expect(v.tittel).toContain('170 timer')
    expect(v.tekst).toContain('1254')
    expect(v.tekst).toContain('1084')
    expect(v.tekst).toContain('21 vakter')
  })

  test('sier ifra at rammen skulle vaert strammere naar bruttoen ogsaa sviktet', () => {
    const v = lagBemanningsvarsler(DALE).find((x) => x.type === 'bemanning_timer')!
    expect(v.tekst).toContain('strammere, ikke løsere')
  })

  test('naevner ikke bruttoen naar den faktisk holdt', () => {
    const v = lagBemanningsvarsler({ ...DALE, bruttoFaktisk: 720000 })
      .find((x) => x.type === 'bemanning_timer')!
    expect(v.tekst).not.toContain('strammere')
  })

  test('timesats over budsjett peker paa tillegg', () => {
    const v = lagBemanningsvarsler(DALE).find((x) => x.type === 'bemanning_timesats')
    expect(v?.tekst).toContain('tillegg')
  })

  test('reserven flagges bare naar den er brukt opp', () => {
    expect(typer(DALE)).not.toContain('bemanning_sykefravaer')
    expect(typer({ ...DALE, sykelonnNetto: 12000 })).toContain('bemanning_sykefravaer')
  })

  test('lav brutto per time forklares som plassering, ikke antall', () => {
    const v = lagBemanningsvarsler(DALE).find((x) => x.type === 'bemanning_produktivitet')!
    expect(v.tekst).toContain('feil på døgnet')
  })

  test('normal manedsstoy utloser ingenting', () => {
    // 3 % over rammen og 2 % over sats er innenfor terskelen.
    expect(typer({
      ...FRISK, timerBrukt: 1116, timesatsFaktisk: 221, bruttoPrTime: 640,
    })).toEqual([])
  })

  test('en god maaned faar kvittering, ikke stillhet', () => {
    const v = lagBemanningsvarsler(FRISK)
    expect(v).toHaveLength(1)
    expect(v[0].type).toBe('bemanning_ok')
    expect(v[0].tekst).toContain('Lønnsandel')
  })

  test('manglende ramme gir ingen timevarsel, men blokkerer ikke de andre', () => {
    const t = typer({ ...DALE, timerDisponible: null })
    expect(t).not.toContain('bemanning_timer')
    expect(t).toContain('bemanning_produktivitet')
  })
})
