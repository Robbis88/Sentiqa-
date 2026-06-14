// iCal-import: henter .ics-kalendere (kalender_kilder) og lager arrangement-
// FORSLAG (status='forslag') i nattjobben. Lederen bekrefter og setter faktor —
// vi løfter aldri en plan på noe lederen ikke har godkjent. Re-import rører
// aldri eksisterende rader (ignoreDuplicates), så bekreftelser/forkastinger står.
import type { SupabaseClient } from '@supabase/supabase-js'

export type IcalHendelse = { uid: string; dato: string; tittel: string }

function avesc(s: string): string {
  return s.replace(/\\n/gi, ' ').replace(/\\,/g, ',').replace(/\\;/g, ';').replace(/\\\\/g, '\\').trim()
}

/** Parser VEVENT-blokker til {uid, dato (YYYY-MM-DD), tittel}. Håndterer
 *  linjebretting (RFC 5545) og DATE/DATE-TIME i DTSTART. Gjentakelser (RRULE)
 *  utvides ikke i v1 — diskrete hendelser (kampoppsett o.l.) dekker behovet. */
export function parseICal(tekst: string): IcalHendelse[] {
  const utbrettet = tekst.replace(/\r?\n[ \t]/g, '') // foldede fortsettelseslinjer
  const linjer = utbrettet.split(/\r?\n/)
  const ut: IcalHendelse[] = []
  let cur: { uid?: string; dato?: string; tittel?: string } | null = null
  for (const l of linjer) {
    if (l === 'BEGIN:VEVENT') { cur = {}; continue }
    if (l === 'END:VEVENT') {
      if (cur?.dato) ut.push({ uid: cur.uid || `${cur.dato}:${cur.tittel ?? ''}`, dato: cur.dato, tittel: cur.tittel || 'Hendelse' })
      cur = null; continue
    }
    if (!cur) continue
    const idx = l.indexOf(':')
    if (idx < 0) continue
    const felt = l.slice(0, idx).split(';')[0].toUpperCase()
    const verdi = l.slice(idx + 1)
    if (felt === 'UID') cur.uid = verdi.trim()
    else if (felt === 'SUMMARY') cur.tittel = avesc(verdi).slice(0, 120)
    else if (felt === 'DTSTART') {
      const m = verdi.match(/(\d{4})(\d{2})(\d{2})/)
      if (m) cur.dato = `${m[1]}-${m[2]}-${m[3]}`
    }
  }
  return ut
}

/** Henter alle aktive kalender-kilder (alle kjeder) og lager forslag for
 *  hendelser fra i dag og `dagerFram` fram. Kalles fra nattjobben (service-role).
 *  Returnerer antall kilder og forslag for logging. */
export async function importerAlleKalenderKilder(
  supabase: SupabaseClient,
  dagerFram = 60,
): Promise<{ kilder: number; forslag: number }> {
  const { data: kilder } = await supabase
    .from('kalender_kilder')
    .select('id, retailer_id, stasjon_id, navn, ical_url, standard_faktor')
    .eq('aktiv', true).is('slettet_tid', null)

  const idag = new Date().toISOString().slice(0, 10)
  const grense = new Date(Date.now() + dagerFram * 86400000).toISOString().slice(0, 10)
  let antall = 0

  for (const k of (kilder ?? []) as { id: string; retailer_id: string; stasjon_id: string | null; navn: string; ical_url: string; standard_faktor: number }[]) {
    try {
      const res = await fetch(k.ical_url, { headers: { accept: 'text/calendar' } })
      if (!res.ok) continue
      const hendelser = parseICal(await res.text()).filter((e) => e.dato >= idag && e.dato <= grense)
      for (const e of hendelser) {
        const navn = k.navn ? `${k.navn}: ${e.tittel}` : e.tittel
        const { error } = await supabase.from('arrangementer').upsert(
          { retailer_id: k.retailer_id, stasjon_id: k.stasjon_id, dato: e.dato, navn, faktor: k.standard_faktor, kilde_id: k.id, ekstern_uid: e.uid, status: 'forslag' },
          { onConflict: 'kilde_id,ekstern_uid', ignoreDuplicates: true },
        )
        if (!error) antall++
      }
    } catch {
      // én kilde skal ikke velte resten
    }
  }
  return { kilder: kilder?.length ?? 0, forslag: antall }
}
