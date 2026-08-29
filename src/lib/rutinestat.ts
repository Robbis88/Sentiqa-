import 'server-only'
import type { SupabaseClient } from '@supabase/supabase-js'

// Statistikk for rutineskjema: streak + periode-prosent + topputførere.
// «Forventet» pr dato = rutiner hvis skjema- OG rutine-ukedager dekker dagens
// ukedag, og som fantes den datoen. Tomme dager bryter ikke streaken.
type Klient = SupabaseClient

function wd(dato: string): number {
  return new Date(`${dato}T12:00:00Z`).getUTCDay()
}
function minusDager(dato: string, n: number): string {
  const d = new Date(`${dato}T12:00:00Z`)
  d.setUTCDate(d.getUTCDate() - n)
  return d.toISOString().slice(0, 10)
}

export type Rutinestat = {
  streak: number
  forventet: number
  utfort: number
  prosent: number
  toppUtforere: { navn: string; antall: number }[]
}

export async function beregnRutinestat(
  supabase: Klient,
  stasjonId: string,
  idag: string,
  periodeDager = 30,
): Promise<Rutinestat> {
  const fra90 = minusDager(idag, 89)
  const [{ data: skjemaer }, { data: rutiner }, { data: ansatte }, { data: utf }] = await Promise.all([
    supabase.from('rutineskjemaer').select('id, ukedager').eq('stasjon_id', stasjonId).eq('aktiv', true).is('slettet_tid', null),
    supabase.from('rutiner').select('id, skjema_id, ukedager, opprettet_dato').eq('stasjon_id', stasjonId).not('skjema_id', 'is', null).is('slettet_tid', null),
    supabase.from('ansatte').select('id, navn').is('slettet_tid', null).eq('stasjon_id', stasjonId),
    supabase.from('rutine_utforinger').select('rutine_id, dato, ansatt_id').eq('stasjon_id', stasjonId).gte('dato', fra90).lte('dato', idag),
  ])

  const skjemaUke = new Map<string, number[]>()
  for (const s of (skjemaer ?? []) as { id: string; ukedager: number[] }[]) skjemaUke.set(s.id, s.ukedager)
  const rs = ((rutiner ?? []) as { id: string; skjema_id: string; ukedager: number[]; opprettet_dato: string }[])
    .filter((r) => skjemaUke.has(r.skjema_id))

  const doneFor = new Map<string, Set<string>>()
  const ansattTeller = new Map<string, number>()
  const periodeFra = minusDager(idag, periodeDager - 1)
  for (const u of (utf ?? []) as { rutine_id: string; dato: string; ansatt_id: string | null }[]) {
    const set = doneFor.get(u.dato) ?? new Set<string>()
    set.add(u.rutine_id)
    doneFor.set(u.dato, set)
    if (u.ansatt_id && u.dato >= periodeFra) ansattTeller.set(u.ansatt_id, (ansattTeller.get(u.ansatt_id) ?? 0) + 1)
  }

  const forventetFor = (dato: string): string[] => {
    const d = wd(dato)
    const ids: string[] = []
    for (const r of rs) {
      const su = skjemaUke.get(r.skjema_id)!
      const skjemaOk = su.length === 0 || su.includes(d)
      const rutineOk = r.ukedager.length === 0 || r.ukedager.includes(d)
      if (skjemaOk && rutineOk && r.opprettet_dato <= dato) ids.push(r.id)
    }
    return ids
  }

  // Streak: i dag teller bare ved 100 %, men bryter ikke om den ikke er ferdig ennå.
  let streak = 0
  for (let i = 0; i < 90; i++) {
    const dato = minusDager(idag, i)
    const forv = forventetFor(dato)
    if (forv.length === 0) continue
    const done = doneFor.get(dato) ?? new Set<string>()
    const alle = forv.every((id) => done.has(id))
    if (alle) streak++
    else if (i === 0) continue
    else break
  }

  // Periode-prosent
  let forventet = 0
  let utfort = 0
  for (let i = 0; i < periodeDager; i++) {
    const dato = minusDager(idag, i)
    const forv = forventetFor(dato)
    if (forv.length === 0) continue
    forventet += forv.length
    const done = doneFor.get(dato) ?? new Set<string>()
    utfort += forv.filter((id) => done.has(id)).length
  }
  const prosent = forventet > 0 ? Math.round((utfort / forventet) * 100) : 0

  const navnFor = new Map(((ansatte ?? []) as { id: string; navn: string }[]).map((a) => [a.id, a.navn]))
  const toppUtforere = [...ansattTeller.entries()]
    .map(([id, antall]) => ({ navn: navnFor.get(id) ?? '—', antall }))
    .sort((a, b) => b.antall - a.antall)
    .slice(0, 3)

  return { streak, forventet, utfort, prosent, toppUtforere }
}
