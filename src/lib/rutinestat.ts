import 'server-only'
import type { SupabaseClient } from '@supabase/supabase-js'
import { rutinerForDato } from './rutineskjema'
import { hentPerDato, maaVaereHele } from './supabase/datobolker'

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
  /** Over hele perioden (30 dager som standard). Lederens tall. */
  forventet: number
  utfort: number
  prosent: number
  // =================================================================
  // I DAG ER ET ANNET TALL ENN PERIODEN, OG DE BLE BLANDET
  //
  // Nettbrettets kø sto med
  //
  //     const rutinerIgjen = forventet - utfort   // 30 DAGER
  //     // Det som faktisk gjenstaar i dag
  //
  // Kommentaren sa «i dag», koden summerte en måned. Bønes har 67
  // rutiner i døgnet, så det ble **123 rutiner igjen** på skjermen — et
  // etterslep på under 6 % over tretti dager, lest som dagens jobb.
  //
  // Det er den dyreste formen for feil tall her: det er ikke galt, det
  // er RIKTIG SVAR PÅ FEIL SPØRSMÅL. Og på et nettbrett i butikken
  // klokka sju om morgenen svarer det «du kommer aldri i mål» til noen
  // som er 94 % i mål.
  //
  // Derfor står dagens tall som sine egne felt. Periodetallene er
  // lederens, dagens er hennes.
  // =================================================================
  /** Bare i dag. Nettbrettets kø. */
  idagForventet: number
  idagUtfort: number
  toppUtforere: { navn: string; antall: number }[]
}

export async function beregnRutinestat(
  supabase: Klient,
  stasjonId: string,
  idag: string,
  periodeDager = 30,
): Promise<Rutinestat> {
  const fra90 = minusDager(idag, 89)
  // =================================================================
  // NITTI DAGER GANGER SYTTI RUTINER ER IKKE TUSEN RADER
  // =================================================================
  // Boenes har 67 rutiner i doegnet. Nitti dager gir over fem tusen
  // utfoeringer, og PostgREST kutter paa tusen UTEN aa feile. Streaken
  // ble regnet paa de foerste tusen radene den fikk - altsaa paa et
  // vilkaarlig utsnitt - og et for lavt tall ser ut som at noen har
  // sluttet aa foelge opp.
  //
  // `hentPerDato` deler perioden i bolker og deler en bolk i to hvis den
  // treffer taket. Da kan svaret ikke vaere stille avkortet.
  const [skjemaSvar, rutineSvar, ansattSvar, utf] = await Promise.all([
    supabase.from('rutineskjemaer').select('id, ukedager').eq('stasjon_id', stasjonId).eq('aktiv', true).is('slettet_tid', null).limit(1000),
    supabase.from('rutiner').select('id, skjema_id, ukedager, opprettet_dato').eq('stasjon_id', stasjonId).not('skjema_id', 'is', null).is('slettet_tid', null).limit(1000),
    supabase.from('ansatte').select('id, navn').is('slettet_tid', null).eq('stasjon_id', stasjonId).limit(1000),
    hentPerDato<{ rutine_id: string; dato: string; ansatt_id: string | null }>(
      (fra, til) => supabase
        .from('rutine_utforinger')
        .select('rutine_id, dato, ansatt_id')
        .eq('stasjon_id', stasjonId)
        .gte('dato', fra)
        .lte('dato', til),
      fra90, idag,
    ),
  ])
  const skjemaer = maaVaereHele(skjemaSvar, 'rutineskjemaene')
  const rutiner = maaVaereHele(rutineSvar, 'rutinene')
  const ansatte = maaVaereHele(ansattSvar, 'de ansatte')

  const skjemaUke = new Map<string, number[]>()
  for (const s of skjemaer as { id: string; ukedager: number[] }[]) skjemaUke.set(s.id, s.ukedager)
  const rs = (rutiner as { id: string; skjema_id: string; ukedager: number[]; opprettet_dato: string }[])
    .filter((r) => skjemaUke.has(r.skjema_id))

  const doneFor = new Map<string, Set<string>>()
  const ansattTeller = new Map<string, number>()
  const periodeFra = minusDager(idag, periodeDager - 1)
  for (const u of utf) {
    const set = doneFor.get(u.dato) ?? new Set<string>()
    set.add(u.rutine_id)
    doneFor.set(u.dato, set)
    if (u.ansatt_id && u.dato >= periodeFra) ansattTeller.set(u.ansatt_id, (ansattTeller.get(u.ansatt_id) ?? 0) + 1)
  }

  // Regelen bor i `rutineskjema.ts`. Den sto her, og ukebriefen fikk en
  // egen - daarligere - kopi som ikke kjente ukedager i det hele tatt.
  const forventetFor = (dato: string): string[] => rutinerForDato(rs, skjemaUke, dato)

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

  // I DAG, for seg. Samme regel som periodetallene, ett doegn.
  const idagForv = forventetFor(idag)
  const idagDone = doneFor.get(idag) ?? new Set<string>()
  const idagUtfort = idagForv.filter((id) => idagDone.has(id)).length

  const navnFor = new Map(((ansatte ?? []) as { id: string; navn: string }[]).map((a) => [a.id, a.navn]))
  const toppUtforere = [...ansattTeller.entries()]
    .map(([id, antall]) => ({ navn: navnFor.get(id) ?? '—', antall }))
    .sort((a, b) => b.antall - a.antall)
    .slice(0, 3)

  return {
    streak, forventet, utfort, prosent,
    idagForventet: idagForv.length, idagUtfort,
    toppUtforere,
  }
}
