import { readFileSync, writeFileSync } from 'node:fs'

// =====================================================================
// 0125 GENERERES FRA 0116. Ikke skriv den av for hånd.
//
// 0125 er 0116 pluss én kolonne bakerst. Skrevet av for hånd ville de to
// sklidd fra hverandre første gang noen rettet en kommentar i 0116 — og
// siden hele settet kjøres om igjen fra bunn av og til, ville
// produksjonen fått den nyeste, altså 0125, med den gamle teksten.
//
//   node scripts/generer-0125.mjs
//
// `kildevakt.test.ts` kjører det samme i minnet og feller hvis
// resultatet ikke er identisk med det som ligger i git. Uten den vakten
// er «generert fra 0116» et løfte i en kommentar, ikke en egenskap.
//
// HODET TIL 0125 LIGGER I FILA SELV, mellom de to første
// `======`-linjene, og hentes derfra. Ellers ville en regenerering
// slettet forklaringen på hvorfor kolonnen finnes.
// =====================================================================

export const KILDE = 'supabase/migrations/0116_brutto_mot_budsjett.sql'
export const MAAL = 'supabase/migrations/0125_bp_brutto_fast.sql'

/** Linjene til og med den andre `======`-linja. */
export function lesHode(kilde) {
  const l = kilde.split(/\r?\n/)
  let slutt = -1
  for (let i = 1; i < l.length; i++) {
    if (l[i].startsWith('-- ======')) { slutt = i; break }
  }
  if (slutt < 0) throw new Error('fant ikke slutten paa hodet')
  return l.slice(0, slutt + 1)
}

export function generer(kilde, hode) {
  const skift = kilde.includes('\r\n') ? '\r\n' : '\n'
  const l = kilde.split(/\r?\n/)

  // 1) Ny CTE rett foer `grunn as (` — den maa ligge etter `budsjett`.
  const iGrunn = l.findIndex((r) => r === 'grunn as (')
  if (iGrunn < 0) throw new Error('fant ikke grunn-CTE')
  l.splice(iGrunn, 0, ...[
    '-- Staar budsjettmarginen paa samme tall hele aaret, eller foelger den',
    '-- aarets gang? Se hodet: flat betyr IKKE mistenkelig.',
    'fast_margin as (',
    '  select b.stasjon_id,',
    '         b.gruppe_kode,',
    "         date_trunc('year', b.maned)::date            as aar,",
    '         -- MINST SEKS MAANEDER. Én maaned er trivielt «flat», og et',
    '         -- halvt aar er nok til aa se om tallet beveger seg.',
    '         count(*) >= 6',
    '           and count(distinct round(',
    '             coalesce(b.bp_brt_avlagt, b.bp_brt_aapen)',
    '             / nullif(coalesce(b.bp_oms_avlagt, b.bp_oms_aapen), 0) * 100, 1',
    '           )) = 1                                      as fast',
    '  from budsjett b',
    "  group by b.stasjon_id, b.gruppe_kode, date_trunc('year', b.maned)",
    '),',
    '',
  ])

  // 2) Ny kolonne SIST i utvalget. `create or replace view` tillater bare
  //    at kolonner legges til paa slutten.
  const iFra = l.findIndex((r) => r === 'from med_status m')
  if (iFra < 0) throw new Error('fant ikke from-klausulen')
  let sisteKol = iFra - 1
  while (!l[sisteKol].trim()) sisteKol--
  l[sisteKol] += ','
  l.splice(sisteKol + 1, 0, ...[
    '',
    '  -- Sant naar budsjettmarginen staar paa samme tall hele aaret. Da kan',
    '  -- et avvik ikke leses som sesong. Det er ALT kolonnen sier.',
    '  coalesce(fm.fast, false)                          as bp_brutto_fast',
  ])

  // 3) Koblingen. Samme aarsbetingelse som `ytd` — uten den blandes
  //    fjoraaret inn i aarets tall.
  const iSlutt = l.findIndex(
    (r) => r.trim() === "and y.aar = date_trunc('year', m.maned)::date;",
  )
  if (iSlutt < 0) throw new Error('fant ikke ytd-koblingen')
  l[iSlutt] = l[iSlutt].replace(';', '')
  l.splice(iSlutt + 1, 0, ...[
    'left join fast_margin fm',
    '  on fm.stasjon_id = m.stasjon_id',
    ' and fm.gruppe_kode = m.gruppe_kode',
    " and fm.aar = date_trunc('year', m.maned)::date;",
  ])

  // 4) Hodet til slutt, i stedet for 0116 sitt.
  let slutt = -1
  for (let i = 1; i < l.length; i++) {
    if (l[i].startsWith('-- ======')) { slutt = i; break }
  }
  l.splice(0, slutt + 1, ...hode)

  return l.join(skift)
}

if (import.meta.filename === process.argv[1]) {
  const ut = generer(readFileSync(KILDE, 'utf8'), lesHode(readFileSync(MAAL, 'utf8')))
  writeFileSync(MAAL, ut)
  console.log('0125 regenerert fra 0116')
}
