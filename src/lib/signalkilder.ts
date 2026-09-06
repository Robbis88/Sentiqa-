import 'server-only'
import type { SupabaseClient } from '@supabase/supabase-js'
import { finnUtsolgt, type Kandidatrad } from '@/lib/utsolgt'
import type { RaaSignal, Signal } from '@/lib/signaler'

// =====================================================================
// Signalkilder som krever egne spørringer, og filteret som holder feeden
// ren. Alt som allerede hentes til forsiden bygges der; dette er de to
// som ellers ville krevd at brukeren husket at modulen fantes.
// =====================================================================

type Klient = SupabaseClient
type Stasjon = { id: string; navn: string }

/**
 * Varer som ser ut til å ha vært utsolgt. Deteksjonen finnes fra før som
 * ren funksjon (finnUtsolgt) — her kalles den bare per stasjon.
 *
 * Ett signal per stasjon, ikke ett per vare: tolv varelinjer på forsiden
 * er en rapport, ikke en sak.
 */
export async function utsolgtSignaler(
  supabase: Klient, stasjoner: Stasjon[], idag: string,
): Promise<RaaSignal[]> {
  const ut: RaaSignal[] = []
  // Én RPC per stasjon. Med fem stasjoner er det håndterbart; blir det
  // mange flere, hører dette hjemme i en nattjobb i stedet.
  for (const s of stasjoner.slice(0, 8)) {
    try {
      const { data, error } = await supabase.rpc('utsolgt_kandidater', { p_stasjon: s.id, p_dager: 35 })
      // INGEN SIGNALER OG EN FEILET MOTOR SER LIKE UT. Kastet fanges av
      // try/catch under, og det er riktig — én stasjon skal ikke velte
      // hele signalrunden. Men det skal skje SYNLIG, ikke som et signal
      // ingen savner fordi ingen visste det skulle vært der.
      if (error) throw new Error(`utsolgt_kandidater feilet for ${s.navn}: ${error.message}`)
      const hendelser = finnUtsolgt((data ?? []) as Kandidatrad[], idag, 35)
      if (hendelser.length === 0) continue
      const tapt = hendelser.reduce((a, h) => a + h.tapt_kr, 0)
      const verst = [...hendelser].sort((a, b) => b.tapt_kr - a.tapt_kr).slice(0, 3)
      ut.push({
        id: `utsolgt-${s.id}`,
        stasjonId: s.id,
        merke: 'Mulig utsolgt',
        tittel: stasjoner.length > 1
          ? `${s.navn}: ${hendelser.length} varer kan ha gått tom`
          : `${hendelser.length} varer kan ha gått tom`,
        endring: `${Math.round(tapt).toLocaleString('nb-NO')} kr`,
        detalj:
          `${verst.map((h) => h.varenavn).join(', ')}${hendelser.length > 3 ? ' m.fl.' : ''}. ` +
          'Varer som selger jevnt har hatt null salg i flere dager på rad.',
        niva: tapt >= 5000 ? 'kritisk' : 'folg',
        lenke: '/utsolgt',
        konsekvensKr: -tapt,
        dager: Math.max(...hendelser.map((h) => h.dager)),
      })
    } catch {
      // En stasjon uten nok historikk skal ikke velte forsiden.
    }
  }
  return ut
}

/**
 * Produksjonsplanen som bommer på de samme varegruppene gang på gang.
 *
 * Én dårlig dag er en dag. Samme kategori tre dager på rad betyr at planen
 * er feil, ikke dagen — og det er en helt annen samtale.
 */
export async function treffSignaler(
  supabase: Klient, stasjoner: Stasjon[], idag: string,
): Promise<RaaSignal[]> {
  const fra = new Date(`${idag}T12:00:00Z`)
  fra.setUTCDate(fra.getUTCDate() - 7)
  const { data } = await supabase
    .from('prognose_treff')
    .select('stasjon_id, kategori, dato, treff, forventet, faktisk')
    .eq('type', 'produksjonsplan')
    .neq('kategori', '*')
    .gte('dato', fra.toISOString().slice(0, 10))
    .limit(500)

  type Rad = { stasjon_id: string; kategori: string; dato: string; treff: number; forventet: number; faktisk: number }
  const rader = (data ?? []) as Rad[]
  if (rader.length === 0) return []

  // Grupper per (stasjon, kategori) og se etter vedvarende bom.
  const per = new Map<string, { stasjonId: string; kategori: string; daarlige: number; avvikKr: number }>()
  for (const r of rader) {
    if (r.treff >= 70) continue
    const n = `${r.stasjon_id}|${r.kategori}`
    const e = per.get(n) ?? { stasjonId: r.stasjon_id, kategori: r.kategori, daarlige: 0, avvikKr: 0 }
    e.daarlige++
    e.avvikKr += Math.abs(r.forventet - r.faktisk)
    per.set(n, e)
  }

  const navnFor = new Map(stasjoner.map((s) => [s.id, s.navn]))
  const ut: RaaSignal[] = []
  const perStasjon = new Map<string, { kategorier: string[]; dager: number; kr: number }>()
  for (const e of per.values()) {
    if (e.daarlige < 3) continue // én eller to dager er støy
    const g = perStasjon.get(e.stasjonId) ?? { kategorier: [], dager: 0, kr: 0 }
    g.kategorier.push(e.kategori)
    g.dager = Math.max(g.dager, e.daarlige)
    g.kr += e.avvikKr
    perStasjon.set(e.stasjonId, g)
  }

  for (const [stasjonId, g] of perStasjon) {
    const navn = navnFor.get(stasjonId)
    if (!navn) continue
    ut.push({
      id: `treff-${stasjonId}`,
      stasjonId,
      merke: 'Treffsikkerhet',
      tittel: stasjoner.length > 1
        ? `${navn}: produksjonsplanen bommer på ${g.kategorier.length} varegrupper`
        : `Produksjonsplanen bommer på ${g.kategorier.length} varegrupper`,
      endring: `${g.dager} dager på rad`,
      detalj:
        `Samme varegrupper bommer gjentatte ganger (${g.kategorier.slice(0, 4).join(', ')}). ` +
        'Når det er de samme hver gang, er det planen som er feil — ikke dagen.',
      niva: 'folg',
      lenke: '/produksjonsplan/treffsikkerhet',
      dager: g.dager,
    })
  }
  return ut
}

/**
 * Fjerner funn som er skjult manuelt og fortsatt innenfor sin frist.
 *
 * Merk at et funn som forsvinner av seg selv aldri havner her — da uteblir
 * det bare ved neste beregning. Dette gjelder kun det brukeren har sett og
 * bevisst lagt bort, og det kommer tilbake når fristen går ut.
 */
export async function filtrerLukkede(
  supabase: Klient, signaler: Signal[], idag: string,
): Promise<Signal[]> {
  if (signaler.length === 0) return signaler
  const { data } = await supabase
    .from('signal_lukket')
    .select('signal_id')
    .gte('gjelder_til', idag)
  const skjult = new Set(((data ?? []) as { signal_id: string }[]).map((r) => r.signal_id))
  return skjult.size === 0 ? signaler : signaler.filter((s) => !skjult.has(s.id))
}
