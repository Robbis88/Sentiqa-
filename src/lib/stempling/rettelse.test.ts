import { describe, it, expect } from 'vitest'
import {
  vurderLukking, vurderAnnullering, iNorskTid, MIN_BEGRUNNELSE,
} from './rettelse'

const NAA = new Date('2026-08-19T18:00:00Z')
const GRUNN = 'glemte å stemple ut'

describe('vurderLukking', () => {
  it('godtar en vanlig lukking', () => {
    expect(vurderLukking({
      inn: '2026-08-19T05:00:00Z', ut: '2026-08-19T13:00:00Z', begrunnelse: GRUNN,
    }, NAA)).toEqual([])
  })

  it('krever et tidspunkt', () => {
    expect(vurderLukking({
      inn: '2026-08-19T05:00:00Z', ut: '', begrunnelse: GRUNN,
    }, NAA)).toContain('mangler_tid')
  })

  it('avviser en utstempling før innstemplingen', () => {
    expect(vurderLukking({
      inn: '2026-08-19T13:00:00Z', ut: '2026-08-19T05:00:00Z', begrunnelse: GRUNN,
    }, NAA)).toContain('for_tidlig')
  })

  it('avviser samme tidspunkt som innstemplingen', () => {
    expect(vurderLukking({
      inn: '2026-08-19T05:00:00Z', ut: '2026-08-19T05:00:00Z', begrunnelse: GRUNN,
    }, NAA)).toContain('for_tidlig')
  })

  it('avviser et tidspunkt fram i tid', () => {
    expect(vurderLukking({
      inn: '2026-08-19T05:00:00Z', ut: '2026-08-19T20:00:00Z', begrunnelse: GRUNN,
    }, NAA)).toContain('i_framtiden')
  })

  // Klokka paa nettbrettet og paa serveren er ikke synkrone paa
  // sekundet, og et avvist «naa» ville vaert uforstaaelig.
  it('tåler et halvt minutt over «nå»', () => {
    expect(vurderLukking({
      inn: '2026-08-19T05:00:00Z', ut: '2026-08-19T18:00:30Z', begrunnelse: GRUNN,
    }, NAA)).toEqual([])
  })

  // Nesten alltid feil dag, ikke en ekte lang vakt: over 16 timer er
  // uansett ikke lovlig.
  it('avviser en vakt på over 16 timer', () => {
    expect(vurderLukking({
      inn: '2026-08-18T20:00:00Z', ut: '2026-08-19T17:00:00Z', begrunnelse: GRUNN,
    }, NAA)).toContain('for_lang')
  })

  it('krever begrunnelse', () => {
    expect(vurderLukking({
      inn: '2026-08-19T05:00:00Z', ut: '2026-08-19T13:00:00Z', begrunnelse: '   ',
    }, NAA)).toContain('mangler_begrunnelse')
  })

  it('avviser en begrunnelse som er for kort til å bety noe', () => {
    expect(vurderLukking({
      inn: '2026-08-19T05:00:00Z', ut: '2026-08-19T13:00:00Z', begrunnelse: 'ok',
    }, NAA)).toContain('kort_begrunnelse')
    expect('ok'.length).toBeLessThan(MIN_BEGRUNNELSE)
  })

  // Butikksjefen skal ikke maatte trykke fire ganger for aa faa vite
  // fire ting.
  it('melder alle feilene på én gang', () => {
    const feil = vurderLukking({
      inn: '2026-08-19T13:00:00Z', ut: '2026-08-19T05:00:00Z', begrunnelse: '',
    }, NAA)
    expect(feil).toContain('for_tidlig')
    expect(feil).toContain('mangler_begrunnelse')
  })
})

describe('vurderAnnullering', () => {
  it('godtar en begrunnelse', () => {
    expect(vurderAnnullering('stemplet inn ved en feil')).toEqual([])
  })

  it('krever begrunnelse', () => {
    expect(vurderAnnullering('  ')).toEqual(['mangler_begrunnelse'])
  })
})

describe('iNorskTid', () => {
  // Uten sonen ville dette blitt tolket i serverens sone - som paa
  // Vercel er UTC, altsaa to timer feil om sommeren.
  it('regner sommertid riktig', () => {
    expect(iNorskTid('2026-08-19', '22:00')).toBe('2026-08-19T20:00:00.000Z')
  })

  it('regner vintertid riktig', () => {
    expect(iNorskTid('2026-01-15', '22:00')).toBe('2026-01-15T21:00:00.000Z')
  })

  it('treffer riktig også dagen sonen skifter', () => {
    // 25. oktober 2026 stilles klokka tilbake kl. 03:00 norsk tid.
    expect(iNorskTid('2026-10-25', '12:00')).toBe('2026-10-25T11:00:00.000Z')
  })

  it('avviser noe som ikke er dato og klokkeslett', () => {
    expect(iNorskTid('19.08.2026', '22:00')).toBeNull()
    expect(iNorskTid('2026-08-19', '22')).toBeNull()
  })
})
