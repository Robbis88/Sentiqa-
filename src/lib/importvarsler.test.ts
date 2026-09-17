import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { createClient, type SupabaseClient } from '@supabase/supabase-js'

// =====================================================================
// HVOR MANGE IMPORTVARSLER ER SAMME SAK? — READ ONLY
// =====================================================================
//
// 3C ga `import_feil` og `import_avvik` strukturell identitet. Radene som
// alt ligger der har ingen — de ble skrevet før nøkkelen fantes.
//
// DENNE FILA RYDDER IKKE. Ingen `update`, ingen `delete`. Den teller, så
// beslutningen om opprydding kan tas på tall i stedet for på anslag.
//
// ---------------------------------------------------------------------
// HVA SOM KAN BEVISES OG HVA SOM BARE MISTENKES
// ---------------------------------------------------------------------
//
// BEVIST: hvor mange rader som finnes, hvor mange strukturelt unike
// saker de utgjør, og hvor mange rader som er overskytende.
//
// Saken utledes av `import_jobber` gjennom lenken varselet SELV ville
// hatt i dag: tittelen bærer filnavnet, og `raa_filer.filnavn` kan slås
// opp. Det er en REKONSTRUKSJON, ikke en nøkkel — de gamle radene har
// ingen — og derfor står den som «kan knyttes» og «kan ikke knyttes»
// hver for seg.
//
// MISTENKT: hvor mange som skyldes «Behandle»-feilen. `kjerne.ts:210`
// dokumenterer at knappen kunne skrive `feilet` over en jobb som hadde
// gått helt fint, med meldingen «Kunne ikke laste ned fil: Object not
// found». Feilmeldingen kan telles. At raden var UNØDVENDIG kan ikke
// bevises herfra — det krever at man vet om dataene faktisk kom inn.
//
// KREVER KANARI_EPOST og KANARI_PASSORD.
// =====================================================================

const EPOST = process.env.KANARI_EPOST
const PASSORD = process.env.KANARI_PASSORD
const kjor = EPOST && PASSORD ? it : it.skip

function env(navn: string): string {
  const fil = readFileSync('.env.local', 'utf8')
  const l = fil.split(/\r?\n/).find((x) => x.startsWith(`${navn}=`))
  if (!l) throw new Error(`${navn} mangler i .env.local`)
  return l.slice(navn.length + 1).trim().replace(/^["']|["']$/g, '')
}

type Varsel = {
  id: string; type: string; tittel: string; tekst: string | null
  noekkel: string | null; lest: boolean; stasjon_id: string | null
  opprettet_tid: string
}

/** «Import feilet: <filnavn>» → filnavnet. Rekonstruksjon, ikke noekkel. */
function filnavnFra(tittel: string): string | null {
  const m = /^Import feilet:\s*(.+)$/.exec(tittel.trim())
  return m ? m[1].trim() : null
}

describe('IMPORTVARSLER — hvor mange rader, hvor mange saker', () => {
  kjor('teller uten aa roere noe', async () => {
    const supabase = createClient(
      env('NEXT_PUBLIC_SUPABASE_URL'), env('NEXT_PUBLIC_SUPABASE_ANON_KEY'),
    ) as SupabaseClient
    const { error } = await supabase.auth.signInWithPassword({
      email: EPOST!, password: PASSORD!,
    })
    if (error) throw new Error(`Innlogging feilet: ${error.message}`)

    const { data: vdata, error: vfeil } = await supabase
      .from('varsler')
      .select('id, type, tittel, tekst, noekkel, lest, stasjon_id, opprettet_tid')
      .in('type', ['import_feil', 'import_avvik'])
      .is('slettet_tid', null)
      .order('opprettet_tid', { ascending: true })
      .limit(2000)
      .overrideTypes<Varsel[]>()
    if (vfeil) throw new Error(`varsler: ${vfeil.message}`)
    const varsler = vdata ?? []

    const L: string[] = ['', '  IMPORTVARSLER — PRODUKSJON, READ ONLY', '']
    L.push(`  rader i alt: ${varsler.length}`
      + (varsler.length >= 2000 ? '   <- TAKET ER NAADD, tallene under er avkortet' : ''))
    // En avkortet spoerring ser ut som en liten kjede. Se
    // `sentiqa-avkortet-nevner`.
    expect(varsler.length, 'radtaket er naadd — tallene ville vaert avkortet').toBeLessThan(2000)

    const feil = varsler.filter((v) => v.type === 'import_feil')
    const avvik = varsler.filter((v) => v.type === 'import_avvik')
    L.push(`    import_feil ${feil.length}   import_avvik ${avvik.length}`)
    L.push(`    uleste ${varsler.filter((v) => !v.lest).length}   `
      + `med noekkel fra foer ${varsler.filter((v) => v.noekkel).length}`)

    // =================================================================
    // 1 import_feil — STRUKTURELL SAK VIA import_jobber
    // =================================================================
    // =================================================================
    // HELE JOBBTABELLEN, SIDE FOR SIDE
    // =================================================================
    //
    // Foerste utgave leste `.limit(1000)` og traff noeyaktig 1000. Da er
    // `filerMedNavn` bygget paa et avkortet sett, og «kan knyttes
    // entydig» blir en paastand om data vi ikke har sett: et filnavn som
    // ser unikt ut blant de nyeste tusen, kan dekke flere filer lenger
    // bak. Tallene saa riktige ut og var provisoriske.
    //
    // Se `sentiqa-avkortet-nevner`: PostgREST kutter uten aa feile.
    type Jobb = {
      id: string; raa_fil_id: string; status: string; feilmelding: string | null
      opprettet_tid: string; raa_filer: { filnavn: string } | null
    }
    const SIDE = 1000
    const jobber: Jobb[] = []
    for (let fra = 0; ; fra += SIDE) {
      const { data, error: jfeil } = await supabase
        .from('import_jobber')
        .select('id, raa_fil_id, status, feilmelding, opprettet_tid, raa_filer(filnavn)')
        .order('opprettet_tid', { ascending: false })
        .range(fra, fra + SIDE - 1)
        .overrideTypes<Jobb[]>()
      if (jfeil) throw new Error(`import_jobber: ${jfeil.message}`)
      const side = data ?? []
      jobber.push(...side)
      if (side.length < SIDE) break
      // Rimelighetsgrense, saa en feil i pagineringen ikke loeper evig.
      if (jobber.length > 100_000) throw new Error('import_jobber: uventet mange rader')
    }
    L.push('')
    L.push(`  import_jobber lest: ${jobber.length} (HELE tabellen, paginert)   `
      + `feilet ${jobber.filter((j) => j.status === 'feilet').length}`)

    // Filnavn -> hvilke raa_filer det finnes. FLERE er det interessante
    // tilfellet: da er navnet IKKE en identitet, og en tekstbasert
    // deduplisering ville slaatt sammen to ulike filer.
    const filerMedNavn = new Map<string, Set<string>>()
    for (const j of jobber) {
      const n = j.raa_filer?.filnavn
      if (!n) continue
      const s = filerMedNavn.get(n) ?? new Set<string>()
      s.add(j.raa_fil_id)
      filerMedNavn.set(n, s)
    }
    const navnMedFlereFiler = [...filerMedNavn].filter(([, s]) => s.size > 1)
    L.push(`  filnavn som dekker MER ENN ÉN raa_fil: ${navnMedFlereFiler.length}`)
    for (const [n, s] of navnMedFlereFiler.slice(0, 10)) {
      L.push(`    «${n}» -> ${s.size} ulike filer`)
    }
    if (navnMedFlereFiler.length > 0) {
      L.push('    -> tekstbasert deduplisering ville slaatt disse sammen. Noekkelen gjoer det ikke.')
    }

    const knyttet = new Map<string, Varsel[]>() // raa_fil_id -> varsler
    const uknyttede: Varsel[] = []
    for (const v of feil) {
      const navn = filnavnFra(v.tittel)
      const filer = navn ? filerMedNavn.get(navn) : undefined
      // BARE ENTYDIGE KNYTNINGER TELLES. Dekker navnet flere filer, kan
      // vi ikke vite hvilken raden gjaldt — og en gjetning her ville
      // vaert nettopp den tekstmatchingen noekkelen skal erstatte.
      if (!filer || filer.size !== 1) { uknyttede.push(v); continue }
      const id = [...filer][0]
      knyttet.set(id, [...(knyttet.get(id) ?? []), v])
    }

    L.push('')
    L.push('  import_feil — RADER MOT SAKER')
    L.push(`    kan knyttes entydig til én fil: ${[...knyttet.values()].flat().length} rader`)
    L.push(`    strukturelt unike saker:        ${knyttet.size}`)
    L.push(`    overskytende rader:             ${[...knyttet.values()].flat().length - knyttet.size}`)
    L.push(`    kan IKKE knyttes:               ${uknyttede.length} rader`)
    const storst = [...knyttet.entries()].sort((a, b) => b[1].length - a[1].length)[0]
    if (storst) {
      L.push(`    stoerste sak: ${storst[1].length} rader — «${storst[1][0].tittel}»`)
    }

    // =================================================================
    // 1b ER SAKEN FORTSATT ET PROBLEM?
    // =================================================================
    //
    // 4 jobber staar som `feilet`, men 25 varsler ligger der fra 12
    // filer. Varselet overlever jobbstatusen: `settFeil` skriver
    // varselet ÉN gang og setter status, men en senere vellykket kjoering
    // paa samme fil endrer bare statusen - varselet blir liggende ulest.
    //
    // DET BETYR AT EN SAK KAN VAERE LOEST UTEN AT FLATEN VET DET, og en
    // Attention-flate som melder «12 importsaker» ville ropt om
    // problemer som ikke finnes lenger.
    //
    // Her maales det: for hver sak, STATUSEN PAA SISTE JOBB for den
    // fila. Det er en observasjon om jobben, ikke en paastand om at
    // dataene kom inn - se «MISTENKT» nederst for forskjellen.
    const sisteJobb = new Map<string, Jobb>()
    for (const j of jobber) {
      // `jobber` er sortert nyest foerst, saa foerste treff er siste jobb.
      if (!sisteJobb.has(j.raa_fil_id)) sisteJobb.set(j.raa_fil_id, j)
    }
    const perStatus = new Map<string, number>()
    const radersPerStatus = new Map<string, number>()
    for (const [filId, rader] of knyttet) {
      const st = sisteJobb.get(filId)?.status ?? '(ingen jobb funnet)'
      perStatus.set(st, (perStatus.get(st) ?? 0) + 1)
      radersPerStatus.set(st, (radersPerStatus.get(st) ?? 0) + rader.length)
    }
    L.push('')
    L.push('  SAKENS TILSTAND — status paa SISTE jobb for samme fil')
    for (const [st, n] of [...perStatus].sort((a2, b2) => b2[1] - a2[1])) {
      L.push(`    ${st.padEnd(14)} ${String(n).padStart(3)} saker   `
        + `${String(radersPerStatus.get(st) ?? 0).padStart(3)} varselrader`)
    }
    const fortsattFeilet = perStatus.get('feilet') ?? 0
    L.push(`    -> ${knyttet.size - fortsattFeilet} av ${knyttet.size} saker har en siste jobb`)
    L.push('       som IKKE staar som feilet. Varslene deres ligger der likevel.')

    // =================================================================
    // 2 import_avvik — SAKEN ER STASJON + DATO
    // =================================================================
    const avvikSak = new Map<string, Varsel[]>()
    for (const v of avvik) {
      const d = /(\d{4}-\d{2}-\d{2})/.exec(v.tittel)?.[1] ?? 'ukjent'
      const n = `${v.stasjon_id ?? 'kjede'}|${d}`
      avvikSak.set(n, [...(avvikSak.get(n) ?? []), v])
    }
    L.push('')
    L.push('  import_avvik — RADER MOT SAKER (stasjon + dato)')
    L.push(`    rader ${avvik.length}   saker ${avvikSak.size}   `
      + `overskytende ${avvik.length - avvikSak.size}`)
    const stAvvik = [...avvikSak.entries()].sort((a, b) => b[1].length - a[1].length)[0]
    if (stAvvik) L.push(`    stoerste sak: ${stAvvik[1].length} rader — «${stAvvik[1][0].tittel}»`)

    // =================================================================
    // 3 MISTENKT — «Behandle»-feilen
    // =================================================================
    //
    // KAN TELLES: hvor mange rader som baerer meldingen. KAN IKKE
    // BEVISES HERFRA: om raden var unoedvendig. Det krever aa vite om
    // dataene faktisk kom inn, og det staar ikke i varselet.
    const OBJEKT = /object not found/i
    const mistenkt = feil.filter((v) => OBJEKT.test(v.tekst ?? ''))
    L.push('')
    L.push('  MISTENKT — dokumentert i kjerne.ts:210')
    L.push(`    rader med «Object not found» i teksten: ${mistenkt.length}`)
    L.push('    Om disse var unoedvendige KAN IKKE avgjoeres her: varselet sier')
    L.push('    ingenting om hvorvidt dataene likevel kom inn.')
    for (const v of mistenkt.slice(0, 5)) {
      L.push(`      ${v.opprettet_tid.slice(0, 10)}  «${v.tittel}»`)
    }

    L.push('')
    L.push('  Ingen rad er endret. Ingen rad er slettet.')
    L.push('')
    console.log(L.join('\n'))

    // Kanarifugl: finnes det ingen importvarsler i det hele tatt, maaler
    // fila ingenting — og en tom utskrift ville sett ut som «ryddig».
    expect(
      varsler.length,
      'ingen importvarsler funnet — maalte denne fila noe?',
    ).toBeGreaterThan(0)
  }, 120_000)
})
