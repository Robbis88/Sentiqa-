// Trafikk-innhenting fra Statens vegvesens åpne Trafikkdata-API (GraphQL).
// To funksjoner: finn nærmeste brukbare bilteller (redaktør-oppsett), og hent
// døgnvolum for stasjoner der måling er skrudd på (nattjobb). Ren datahenting —
// kampanjeanalysen ligger i lib/kampanjeeffekt.ts.
import type { SupabaseClient } from '@supabase/supabase-js'

const API = 'https://trafikkdata-api.atlas.vegvesen.no/'

async function gql<T = unknown>(query: string): Promise<T | null> {
  try {
    const r = await fetch(API, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ query }) })
    if (!r.ok) return null
    const j = await r.json()
    if (j.errors) return null
    return j.data as T
  } catch {
    return null
  }
}

function km(a: number, b: number, c: number, d: number): number {
  const R = 6371, t = Math.PI / 180
  const dLat = (c - a) * t, dLon = (d - b) * t
  const x = Math.sin(dLat / 2) ** 2 + Math.cos(a * t) * Math.cos(c * t) * Math.sin(dLon / 2) ** 2
  return R * 2 * Math.atan2(Math.sqrt(x), Math.sqrt(1 - x))
}

export type Teller = { id: string; navn: string; vei: string | null; avstandKm: number; snittVolum: number }

type PunktSvar = { trafficRegistrationPoints: { id: string; name: string; trafficRegistrationType: string; location: { coordinates: { latLon: { lat: number; lon: number } } | null; roadReference: { shortForm: string } | null } | null }[] }

async function snittVolum(id: string): Promise<number | null> {
  const d = await gql<{ trafficData: { volume: { byDay: { edges: { node: { total: { volumeNumbers: { volume: number | null } | null } | null } }[] } } } }>(
    `{ trafficData(trafficRegistrationPointId: "${id}") { volume { byDay(from: "2026-05-01T00:00:00+02:00", to: "2026-05-06T00:00:00+02:00") { edges { node { total { volumeNumbers { volume } } } } } } } }`,
  )
  const vols = (d?.trafficData?.volume?.byDay?.edges ?? []).map((e) => e.node.total?.volumeNumbers?.volume).filter((v): v is number => v != null)
  return vols.length ? Math.round(vols.reduce((a, b) => a + b, 0) / vols.length) : null
}

/** Nærmeste bilteller (VEHICLE, ikke sykkel/gangsti) med ekte volum, til en
 *  koordinat. Brukes av redaktørens trafikk-oppsett. */
export async function finnNaermesteTeller(lat: number, lon: number): Promise<Teller | null> {
  const data = await gql<PunktSvar>(`{ trafficRegistrationPoints { id name trafficRegistrationType location { coordinates { latLon { lat lon } } roadReference { shortForm } } } }`)
  const pkt = (data?.trafficRegistrationPoints ?? [])
    .map((p) => ({ id: p.id, navn: p.name, type: p.trafficRegistrationType, lat: p.location?.coordinates?.latLon?.lat, lon: p.location?.coordinates?.latLon?.lon, vei: p.location?.roadReference?.shortForm ?? null }))
    .filter((p) => p.lat != null && p.lon != null && p.type === 'VEHICLE' && !/sykkel|gs-veg|gang/i.test(p.navn))
    .map((p) => ({ ...p, d: km(lat, lon, p.lat!, p.lon!) }))
    .sort((a, b) => a.d - b.d)
  for (const p of pkt.slice(0, 8)) {
    const sn = await snittVolum(p.id)
    if (sn != null && sn > 300) return { id: p.id, navn: p.navn, vei: p.vei, avstandKm: Math.round(p.d * 100) / 100, snittVolum: sn }
  }
  return null
}

/** Henter døgntrafikk (siste ~90 dager) for alle stasjoner med aktiv måling og
 *  upserter i trafikk-tabellen. Kalles fra nattjobben (service-role). */
export async function hentTrafikkMedKlient(supabase: SupabaseClient): Promise<{ stasjoner: number; rader: number }> {
  const { data: st } = await supabase.from('stasjoner').select('id, trafikk_punkt_id').eq('trafikk_aktiv', true).not('trafikk_punkt_id', 'is', null).is('slettet_tid', null)
  const fra = new Date(Date.now() - 90 * 86400000).toISOString().slice(0, 10)
  const til = new Date(Date.now() + 86400000).toISOString().slice(0, 10)
  let rader = 0
  for (const s of (st ?? []) as { id: string; trafikk_punkt_id: string }[]) {
    const d = await gql<{ trafficData: { volume: { byDay: { edges: { node: { from: string; total: { volumeNumbers: { volume: number | null } | null; coverage: { percentage: number | null } | null } | null } }[] } } } }>(
      `{ trafficData(trafficRegistrationPointId: "${s.trafikk_punkt_id}") { volume { byDay(from: "${fra}T00:00:00+02:00", to: "${til}T00:00:00+02:00") { edges { node { from total { volumeNumbers { volume } coverage { percentage } } } } } } } }`,
    )
    const edges = d?.trafficData?.volume?.byDay?.edges ?? []
    const upsert = edges
      .filter((e) => e.node.total?.volumeNumbers?.volume != null)
      .map((e) => ({ stasjon_id: s.id, dato: e.node.from.slice(0, 10), antall_kjoretoy: e.node.total!.volumeNumbers!.volume, dekning_pst: e.node.total?.coverage?.percentage ?? null, hentet_tid: new Date().toISOString() }))
    if (upsert.length > 0) {
      const { error } = await supabase.from('trafikk').upsert(upsert, { onConflict: 'stasjon_id,dato' })
      if (!error) rader += upsert.length
    }
  }
  return { stasjoner: (st ?? []).length, rader }
}
