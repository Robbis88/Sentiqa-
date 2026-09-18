import { expect, it } from 'vitest'
import type { SupabaseClient } from '@supabase/supabase-js'
import { beregnMalekort, type Malekort } from './malekort'
import { readFileSync } from 'node:fs'

const kort: Malekort = { id: 'kort', navn: 'Salg', metrikk: 'omsetning', normalisering: 'per_kunde', periode: 'uke', retning: 'hoy', krev_fullstendig_periode: true, anonymiser: false }
const stasjoner = [{ id: 'a', navn: 'A' }, { id: 'b', navn: 'B' }]
function klient(dekning: (fra: string) => object[], feil = false) {
  const perioder: string[] = []
  const supabase = {
    from: () => ({ select: () => ({ order: () => ({ limit: () => ({ maybeSingle: async () => ({ data: { dato: '2026-09-13' }, error: null }) }) }) }) }),
    rpc: async (navn: string, args: { p_fra: string; p_malekort?: string }) => {
      if (navn === 'malekort_salgsdekning') {
        expect(args.p_malekort).toBe('kort')
        perioder.push(args.p_fra)
        return { data: dekning(args.p_fra), error: feil ? { message: 'timeout' } : null }
      }
      return { data: [], error: null }
    },
  } as unknown as SupabaseClient
  return { supabase, perioder }
}
it('en komplett butikk skjuler ikke en manglende dag hos en annen', async () => {
  const { supabase, perioder } = klient(fra => [{ stasjon_id: 'a', dager: 7 }, { stasjon_id: 'b', dager: fra === '2026-09-07' ? 6 : 7 }])
  const r = await beregnMalekort(supabase, kort, stasjoner)
  expect(perioder).toEqual(['2026-09-07', '2026-08-31'])
  expect(r.klar && r.etikett).toBe('Uke 31.8.–6.9.')
})
it('manglende butikkdekning stopper rangeringen', async () => {
  const { supabase } = klient(() => [{ stasjon_id: 'a', dager: 7 }])
  expect(await beregnMalekort(supabase, kort, stasjoner)).toEqual({ klar: false, grunn: 'Venter på fullstendige tall for perioden.' })
})
it('ikke-deltakende butikker påvirker ikke valgt periode', async () => {
  const { supabase, perioder } = klient(() => [{ stasjon_id: 'a', dager: 7 }, { stasjon_id: 'b', dager: 1 }])
  expect((await beregnMalekort(supabase, kort, stasjoner.slice(0, 1))).klar).toBe(true)
  expect(perioder).toHaveLength(1)
})
it('queryfeil er ikke venting på import', async () => {
  const { supabase } = klient(() => [], true)
  await expect(beregnMalekort(supabase, kort, stasjoner)).rejects.toThrow('malekort_salgsdekning feilet: timeout')
})
it('SQL binder dekning til stasjon, retailer og synlig målekort', () => {
  const sql = readFileSync('supabase/migrations/0225_malekort_stasjonsdekning.sql', 'utf8')
  expect(sql).toContain('from public.v_butikksalg ds')
  expect(sql).toContain('group by ds.stasjon_id')
  expect(sql).toContain('count(distinct ds.dato)')
  expect(sql).toContain('m.id = p_malekort and m.retailer_id = ds.retailer_id')
  expect(sql).toContain('m.vis_butikksjef')
  expect(sql).toContain('m.vis_tablet')
  expect(sql).toContain('from public, anon')
})
