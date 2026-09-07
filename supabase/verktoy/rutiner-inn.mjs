// =====================================================================
// FLYTT RUTINER FRA DET ANDRE SYSTEMET INN I SENTIQA
//
//   node supabase/verktoy/rutiner-inn.mjs <eksport.sql> <uuid>=<navn> ...
//
// Eksempel:
//   node supabase/verktoy/rutiner-inn.mjs eksport.sql 6a957fb5-...=Bønes 1234abcd-...=Lone
//
// Leser eksporten slik den kommer ut av det andre systemet - `insert
// into rutine select * from json_populate_recordset(...)` - og skriver
// ferdig SQL til stdout. Ingen opprydding i fila på forhånd.
//
// ---------------------------------------------------------------------
// ALLE STASJONER I ÉN KJØRING
//
// Eksporten dumper hele basen, ikke én stasjon. Tok verktøyet én om
// gangen, ville noen kjørt det fire ganger og glemt den femte - og en
// stasjon som mangler rutiner ser ut som en stasjon uten rutiner.
//
// Hver stasjon får sin egen blokk, så en som feiler ikke velter de
// andre.
//
// ---------------------------------------------------------------------
// UKEDAGENE ER KODET ULIKT, OG BARE ÉN DAG AVSLØRER DET
//
//     dem       1=man 2=tir 3=ons 4=tor 5=fre 6=lør 7=søn   (ISO)
//     Sentiqa   0=søn 1=man 2=tir 3=ons 4=tor 5=fre 6=lør
//
// 1-6 betyr det SAMME i begge. Bare 7 er forskjellig. En rett kopiering
// ville altså virket for seks dager og stille tatt feil på søndag - og
// søndagsrutinene («Fjern alt av søndagsbakeri merking») ville aldri
// dukket opp. Det er den slags feil ingen finner, fordi den ser riktig
// ut mandag til lørdag.
//
// ---------------------------------------------------------------------
// STASJONEN SLÅS OPP PÅ NAVN, INNE I SQL-EN
//
// Deres stasjons-uuid-er finnes ikke i Sentiqa. I stedet for at noen
// skal oversette dem for hånd, resolver SQL-en stasjonen selv - og
// KASTER hvis navnet ikke treffer nøyaktig én. Rutiner på feil stasjon
// er verre enn rutiner som mangler: det siste ser man.
//
// ---------------------------------------------------------------------
// ID-ENE BEHOLDES, OG DET ER MENINGEN
//
// De er uuid-er; de kolliderer ikke med noe i Sentiqa. Å beholde dem
// gjør to ting: `skjema_id` på hver rutine peker fortsatt riktig uten at
// noe må mappes, og en ny kjøring blir en no-op i stedet for duplikater.
// Limes fila inn to ganger, skjer ingenting andre gang.
// =====================================================================

import { readFileSync } from 'node:fs'

const [, , fil, ...par] = process.argv
if (!fil || par.length === 0) {
  console.error('Bruk: node supabase/verktoy/rutiner-inn.mjs <eksport.sql> <uuid>=<navn> ...')
  process.exit(1)
}

/** Deres stasjons-uuid -> navnet stasjonen har i Sentiqa. */
const navnFor = new Map(par.map((p) => {
  const i = p.indexOf('=')
  if (i < 1) {
    console.error(`Forsto ikke «${p}». Formen er <uuid>=<navn>.`)
    process.exit(1)
  }
  return [p.slice(0, i), p.slice(i + 1)]
}))

const kilde = readFileSync(fil, 'utf8')

/**
 * TO FORMER GODTAS, og det er ikke slappheit.
 *
 * Den enkleste eksporten for et MENNESKE er ikke den samme som den et
 * dumpeverktøy spytter ut:
 *
 *   1. Rått JSON: `{"rutineskjema": [...], "rutine": [...]}`
 *      Én spørring i det gamle systemet, én celle, én fil. Dette er
 *      veien vi ber om, fordi den har færrest ledd å gjøre feil i.
 *
 *   2. Insert-eksporten med `json_populate_recordset(...)`.
 *      Formen et dumpeverktøy lager. Godtas fordi den allerede fantes,
 *      og den som har den skal slippe å hente alt på nytt.
 */
const somJson = (() => {
  try {
    const o = JSON.parse(kilde)
    return o && typeof o === 'object' && !Array.isArray(o) ? o : null
  } catch {
    return null
  }
})()

/** Henter JSON-en ut av `json_populate_recordset(null::<tabell>, E'...'::json)`. */
function hentRader(tabell) {
  if (somJson) return somJson[tabell] ?? []
  const m = kilde.match(
    new RegExp(`json_populate_recordset\\(\\s*null::${tabell}\\s*,\\s*(E?)'([\\s\\S]*?)'::json\\s*\\)`),
  )
  if (!m) return []
  const [, eStreng, raa] = m
  // `''` er SQL-escapet apostrof. I en E-streng er `\\` dessuten en
  // escapet backslash - og de vi bryr oss om er JSON-escapene `\r\n`
  // inne i notisfeltene.
  let tekst = raa.replace(/''/g, "'")
  if (eStreng) tekst = tekst.replace(/\\\\/g, '\\')
  return JSON.parse(tekst)
}

/** Søndag er 7 hos dem og 0 hos oss. Resten er like. */
const ukedager = (dager) =>
  [...new Set((dager ?? []).map((d) => (d === 7 ? 0 : d)))].sort((a, b) => a - b)

/** SQL-streng, eller `null`. */
const s = (v) =>
  (v === null || v === undefined || v === '' ? 'null' : `'${String(v).replace(/'/g, "''")}'`)

/**
 * IK-mat er ikke en vanlig rutine i Sentiqa.
 *
 * `ikmat_frekvens = 'daglig'` gjør rutinen til et kort som LENKER til
 * måle-arket og hakes av når alle enhetene er målt. Importeres den som
 * ren tekst, får stasjonen en avkryssingsboks der målingen skulle vært.
 */
const erIkmat = (navn) => /ik-?\s*mat/i.test(navn)

const klokke = (t) => (t ?? '').slice(0, 5) // "04:00:00" -> "04:00"

const skjemaer = hentRader('rutineskjema')
const rutiner = hentRader('rutine')

if (skjemaer.length === 0 && rutiner.length === 0) {
  console.error(`Fant verken rutineskjema eller rutine i ${fil}.`)
  process.exit(1)
}

// Rutinen kjenner bare skjemaet sitt; stasjonen henger på skjemaet.
const stasjonFor = new Map(skjemaer.map((k) => [k.id, k.stasjon_id]))

const ut = []
const rapport = []

ut.push('-- Rutiner flyttet inn fra det andre systemet.')
ut.push('--')
ut.push('-- Sondag er 7 hos dem og 0 hos oss; resten av ukedagene er like.')
ut.push('-- Id-ene er beholdt, saa en ny kjoering er en no-op.')
ut.push('-- IK-mat-rutiner er satt til `ikmat_frekvens = daglig`, saa de lenker')
ut.push('-- til maale-arket i stedet for aa bli en avkryssingsboks.')
ut.push('')

for (const [uuid, navn] of navnFor) {
  const mine = skjemaer.filter((k) => k.stasjon_id === uuid)
  const mineRutiner = rutiner.filter((r) => stasjonFor.get(r.skjema_id) === uuid)

  if (mine.length === 0 && mineRutiner.length === 0) {
    // EN TOM STASJON SKAL SIES FRA OM, ikke hoppes stille over. Er uuid-en
    // skrevet feil, ser resultatet ellers ut som «denne stasjonen hadde
    // ingen rutiner».
    rapport.push(`  ${navn}: INGENTING funnet for ${uuid} - er uuid-en riktig?`)
    continue
  }

  const sondag = mineRutiner.filter((r) => (r.aktive_ukedager ?? []).includes(7))
  const ikmat = mineRutiner.filter((r) => erIkmat(r.navn))
  rapport.push(
    `  ${navn}: ${mine.length} skjema, ${mineRutiner.length} rutiner`
    + ` (${sondag.length} sondag, ${ikmat.length} IK-mat)`,
  )
  for (const r of ikmat) rapport.push(`      IK-mat -> daglig: ${r.navn}`)

  ut.push(`-- ---------------------------------------------------------------`)
  ut.push(`-- ${navn}: ${mine.length} skjema, ${mineRutiner.length} rutiner`)
  ut.push(`-- ---------------------------------------------------------------`)
  ut.push('do $$')
  ut.push('declare')
  ut.push('  v_stasjon uuid;')
  ut.push('  v_retailer uuid;')
  ut.push('  v_antall int;')
  ut.push('begin')
  ut.push('  select count(*) into v_antall from public.stasjoner')
  ut.push(`  where navn ilike ${s(`%${navn}%`)} and slettet_tid is null;`)
  ut.push('')
  ut.push('  -- STOPP HELLER ENN AA GJETTE. Treffer navnet ingen eller FLERE')
  ut.push('  -- stasjoner, skal ingenting skrives. Rutiner paa feil stasjon er')
  ut.push('  -- verre enn rutiner som mangler: det siste ser man.')
  ut.push('  if v_antall <> 1 then')
  ut.push(`    raise exception 'Fant % stasjoner for %, ventet 1', v_antall, ${s(navn)};`)
  ut.push('  end if;')
  ut.push('')
  ut.push('  select id, retailer_id into v_stasjon, v_retailer')
  ut.push('  from public.stasjoner')
  ut.push(`  where navn ilike ${s(`%${navn}%`)} and slettet_tid is null;`)
  ut.push('')

  for (const k of mine) {
    ut.push('  insert into public.rutineskjemaer')
    ut.push('    (id, retailer_id, stasjon_id, vakttype, tid_start, tid_slutt, ukedager, aktiv)')
    ut.push(`  select ${s(k.id)}, v_retailer, v_stasjon, ${s(k.vakttype)},`)
    ut.push(`         ${s(klokke(k.aktiv_fra_tid))}, ${s(klokke(k.aktiv_til_tid))},`)
    ut.push(`         '{${ukedager(k.aktiv_ukedager).join(',')}}'::int[], true`)
    ut.push(`  where not exists (select 1 from public.rutineskjemaer where id = ${s(k.id)});`)
    ut.push('')
  }

  for (const r of mineRutiner) {
    ut.push('  insert into public.rutiner')
    ut.push('    (id, retailer_id, stasjon_id, skjema_id, tittel, beskrivelse,')
    ut.push('     paakrevd_bilde, sortering, ukedager, ikmat_frekvens)')
    ut.push(`  select ${s(r.id)}, v_retailer, v_stasjon, ${s(r.skjema_id)},`)
    ut.push(`         ${s(r.navn)}, ${s(r.notis)},`)
    ut.push(`         ${r.krever_bilde ? 'true' : 'false'}, ${r.rekkefolge ?? 0},`)
    ut.push(`         '{${ukedager(r.aktive_ukedager).join(',')}}'::int[], ${erIkmat(r.navn) ? "'daglig'" : 'null'}`)
    ut.push(`  where not exists (select 1 from public.rutiner where id = ${s(r.id)});`)
    ut.push('')
  }

  ut.push('end $$;')
  ut.push('')
}

// Stasjoner i eksporten som ingen ba om. Uten dette ville en glemt
// stasjon vaert usynlig - og «alle skal over» er nettopp den setningen
// som gjoer at ingen teller etterpaa.
const bedt = new Set(navnFor.keys())
const glemt = [...new Set(skjemaer.map((k) => k.stasjon_id))].filter((id) => !bedt.has(id))

ut.push('-- Kvittering.')
ut.push('select s.navn,')
ut.push('       count(distinct k.id) as skjemaer,')
ut.push('       count(distinct r.id) as rutiner,')
ut.push('       count(distinct r.id) filter (where r.ikmat_frekvens is not null) as ikmat')
ut.push('from public.stasjoner s')
ut.push('left join public.rutineskjemaer k on k.stasjon_id = s.id and k.slettet_tid is null')
ut.push('left join public.rutiner r        on r.stasjon_id = s.id and r.slettet_tid is null')
ut.push('where s.slettet_tid is null')
ut.push('group by s.navn order by s.navn;')

console.log(ut.join('\n'))

// Oppsummering til stderr, saa den ikke havner i SQL-en.
console.error(`\nLest ${skjemaer.length} skjema og ${rutiner.length} rutiner fra ${fil}.\n`)
for (const l of rapport) console.error(l)
if (glemt.length > 0) {
  console.error(`\nADVARSEL: ${glemt.length} stasjon(er) i eksporten er IKKE bedt om:`)
  for (const id of glemt) {
    const n = skjemaer.filter((k) => k.stasjon_id === id).length
    const rn = rutiner.filter((r) => stasjonFor.get(r.skjema_id) === id).length
    console.error(`  ${id}  (${n} skjema, ${rn} rutiner)`)
  }
  console.error('Legg dem til som <uuid>=<navn> om de ogsaa skal over.')
}
console.error('\nOversettelsene er utelatt med vilje - Sentiqa oversetter selv ved behov.')
