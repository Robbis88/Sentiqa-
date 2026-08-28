import { describe, it, expect } from 'vitest'
import { readdirSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { aggregerendeDaglige, sisteDefinisjon } from './salgskilde'

// =====================================================================
// LESER NOE I SQL FORTSATT `daglig_salg` NAAR DET SUMMERER?
//
// Husregelen — alt som summerer kroner eller antall skal lese
// `v_butikksalg` — har vaert kontrollert for TypeScript, aldri for SQL.
//
// `beregn_vaerprofil` og `beregn_kategori_vaerprofil` laa i det hullet.
// De filtrerte selv, paa `avdeling_kode not in ('10','250')`, og saa
// derfor riktige ut ved gjennomlesing. Baselinen mot produksjon
// 2026-08-28 viste at drivstoff har kode **1000**: filteret traff
// ingenting, og vaerprofilen laerte paa drivstoff.
//
// **Det er ikke nok aa filtrere. Filteret maa treffe.** Derfor krever
// punkt 3 under at hvert objekt som fortsatt leser `daglig_salg` ogsaa
// har navnesjekken — den armen som faktisk gjoer jobben.
// =====================================================================

const ROT = join(process.cwd(), 'supabase/migrations')
const FILER = readdirSync(ROT).filter((f) => f.endsWith('.sql')).sort()
  .map((f) => ({ fil: f, sql: readFileSync(join(ROT, f), 'utf8') }))

describe('vaerprofilene leser butikksalg', () => {
  for (const navn of ['beregn_vaerprofil', 'beregn_kategori_vaerprofil']) {
    it(`${navn} leser v_butikksalg, ikke daglig_salg`, () => {
      const d = sisteDefinisjon(FILER, navn)
      expect(d, `${navn} finnes ikke i migrasjonene`).not.toBeNull()
      expect(d!.kropp, `${navn} leser fortsatt daglig_salg direkte (${d!.fil})`)
        .not.toMatch(/from\s+public\.daglig_salg\b/i)
      expect(d!.kropp, `${navn} leser ikke v_butikksalg (${d!.fil})`)
        .toMatch(/from\s+public\.v_butikksalg\b/i)
    })
  }

  it('den doede koden 10 er borte fra begge', () => {
    // Armen som aldri traff. Staar den igjen, ser filteret bredere ut
    // enn det er — og det var nettopp den lesningen som skjulte feilen.
    for (const navn of ['beregn_vaerprofil', 'beregn_kategori_vaerprofil']) {
      expect(sisteDefinisjon(FILER, navn)!.kropp, `${navn} filtrerer fortsatt paa '10'`)
        .not.toMatch(/'10'/)
    }
  })
})

describe('hva som fortsatt summerer fra daglig_salg', () => {
  const funn = aggregerendeDaglige(FILER)

  it('er de fem fra 0084 pluss treffkontrollen', () => {
    // SKAL BARE NED. Et nytt objekt som summerer fra `daglig_salg` maa
    // enten lese `v_butikksalg` eller foeres inn her med en begrunnelse.
    expect(funn.map((f) => f.navn)).toEqual([
      'uke_avdeling_aggregat',
      'utsolgt_kandidater',
      'v_retailer_drivstofftreff',
      'v_salg_per_avdeling_dag',
      'v_salg_per_varegruppe_dag',
      'v_salg_per_varegruppe_stasjon_dag',
    ])
  })

  it('og hver av dem har et drivstoffilter som faktisk kan treffe', () => {
    // =================================================================
    // REGELEN ER SNUDD I 0152, OG DET ER POENGET.
    //
    // Før mappingen var kravet «har navnesjekken på ENERGI», fordi det
    // var det eneste filteret som beviselig traff — koden `10` fantes
    // ikke i data i det hele tatt.
    //
    // Etter 0152 er litteralen den GALE formen. Et nytt objekt skal lese
    // `retailer_koderegel`. De fem fra `0084` beholder litteralen sin
    // til noen legger dem om: de er korrekte for Kelsar i dag, men de er
    // gjeld.
    //
    // Kravet er derfor ETT av de to. Et objekt med ingen av delene
    // filtrerer ikke drivstoff i det hele tatt — og det var nøyaktig
    // dét `beregn_vaerprofil` gjorde i to år.
    // =================================================================
    for (const f of funn) {
      const d = sisteDefinisjon(FILER, f.navn)!
      expect(
        LITTERAL.test(d.kropp) || /retailer_koderegel/i.test(d.kropp),
        `${f.navn} leser daglig_salg uten å filtrere drivstoff — `
        + 'hverken navnesjekk eller retailer_koderegel',
      ).toBe(true)
    }
  })

  it('litteralgjelden står stille på fem', () => {
    // Tallet skal bare NED. Når det når null, er drivstoff definert ett
    // sted i hele basen.
    const gjeld = funn.filter((f) => LITTERAL.test(sisteDefinisjon(FILER, f.navn)!.kropp))
    expect(gjeld.length,
      `Litteralgjeld: ${gjeld.map((f) => f.navn).join(', ')}`).toBeLessThanOrEqual(5)
    expect(new Set(gjeld.map((f) => f.fil))).toEqual(new Set(['0084_uten_drivstoff.sql']))
  })
})

/** Navnesjekken fra 0084/0085 — den armen som faktisk traff. */
const LITTERAL = /upper\s*\(\s*coalesce\s*\(\s*(?:ds\.)?avdeling_navn[\s\S]{0,40}?<>\s*'ENERGI'/i

describe('mappingen er kilden, ikke litteralen', () => {
  it('v_butikksalg leser retailer_koderegel og erklæringen', () => {
    const d = sisteDefinisjon(FILER, 'v_butikksalg')
    expect(d, 'v_butikksalg finnes ikke').not.toBeNull()
    expect(d!.kropp, 'v_butikksalg leser ikke mappingen').toMatch(/retailer_koderegel/i)
    expect(d!.kropp, 'v_butikksalg joiner ikke erklæringen — da fail-closer den ikke')
      .toMatch(/retailer_kodeerklaering/i)
  })

  it('v_butikksalg har ingen litteral igjen', () => {
    // Står én av dem igjen, er drivstoff definert to steder — og de
    // skiller lag i stillhet.
    const k = sisteDefinisjon(FILER, 'v_butikksalg')!.kropp
    expect(k, "v_butikksalg filtrerer fortsatt paa 'ENERGI'").not.toMatch(/'ENERGI'/)
    expect(k, "v_butikksalg filtrerer fortsatt paa '10'").not.toMatch(/avdeling_kode[^\n]*'10'/)
  })

  it('security_invoker står i samme setning', () => {
    // `create or replace view` uten klausulen nullstiller flagget i
    // stillhet, og viewet leses da som eier — forbi RLS.
    for (const v of ['v_butikksalg', 'v_retailer_kodestatus', 'v_retailer_drivstofftreff']) {
      const d = sisteDefinisjon(FILER, v)
      expect(d, `${v} finnes ikke`).not.toBeNull()
      expect(d!.kropp, `${v} mangler security_invoker`).toMatch(/security_invoker\s*=\s*true/i)
    }
  })

  it('0152 backfiller FØR den bytter viewet', () => {
    // Rekkefølgen er sikkerhetskritisk. Bytter viewet før radene finnes,
    // ser hver kjede med salg null rader i hele produktet — `0065`-formen.
    const f = FILER.find((x) => x.fil.startsWith('0152'))!.sql
    const backfill = f.indexOf('insert into public.retailer_kodeerklaering')
    const viewbytte = f.indexOf('create or replace view public.v_butikksalg')
    expect(backfill, 'fant ikke backfillen').toBeGreaterThan(-1)
    expect(viewbytte, 'fant ikke viewbyttet').toBeGreaterThan(-1)
    expect(backfill, 'viewet byttes FØR backfillen').toBeLessThan(viewbytte)
  })
})

describe('bugfixen holdt seg innenfor', () => {
  const f0151 = FILER.find((f) => f.fil.startsWith('0151'))

  // EN KOMMENTAR ER IKKE EN SETNING. Foerste versjon av denne vakten
  // feilet paa sin egen migrasjon, fordi kommentaren DER forklarer at
  // ingen tabell har «force row level security». Uten strippingen melder
  // vakten en endring som ikke finnes — og en vakt med falske positive
  // laerer folk aa se bort fra roedt.
  const setninger = (sql: string) =>
    sql.replace(/\/\*[\s\S]*?\*\//g, ' ').replace(/--.*/g, '')

  it('0151 finnes', () => {
    expect(f0151, 'migrasjon 0151 mangler').toBeTruthy()
  })

  it('roerer ikke v_butikksalg', () => {
    expect(setninger(f0151!.sql))
      .not.toMatch(/create\s+(or\s+replace\s+)?view\s+public\.v_butikksalg/i)
  })

  it('roerer ikke policyer eller RLS', () => {
    expect(setninger(f0151!.sql))
      .not.toMatch(/create\s+policy|drop\s+policy|row\s+level\s+security/i)
  })

  it('roerer ikke tabeller eller kolonner', () => {
    expect(setninger(f0151!.sql)).not.toMatch(/alter\s+table|create\s+table|drop\s+table/i)
  })

  it('endrer kun de to funksjonene', () => {
    const opprettet = [...setninger(f0151!.sql).matchAll(
      /create\s+or\s+replace\s+function\s+public\.([a-z0-9_]+)/gi)].map((m) => m[1])
    expect(opprettet.sort()).toEqual(['beregn_kategori_vaerprofil', 'beregn_vaerprofil'])
  })
})

describe('kanarifugler', () => {
  it('parseren leser et fornuftig antall definisjoner', () => {
    // Slutter regexen aa treffe, blir lista tom — og «ingenting leser
    // daglig_salg» ser noeyaktig ut som «alt er ryddet».
    expect(sisteDefinisjon(FILER, 'v_butikksalg')).not.toBeNull()
    expect(sisteDefinisjon(FILER, 'beregn_vaerprofil')).not.toBeNull()
    expect(FILER.length).toBeGreaterThan(140)
  })

  it('SISTE definisjon vinner, ikke den foerste', () => {
    // Uten dette ville vakten vurdert 0068 i staden for 0151, og meldt
    // en feil som alt er rettet.
    const to = [
      { fil: '0001.sql', sql: 'create or replace function public.f() as $$ select sum(x) from public.daglig_salg; $$;' },
      { fil: '0002.sql', sql: 'create or replace function public.f() as $$ select sum(x) from public.v_butikksalg; $$;' },
    ]
    expect(aggregerendeDaglige(to)).toEqual([])
    expect(aggregerendeDaglige([to[0]]).map((x) => x.navn)).toEqual(['f'])
  })

  it('en KOMMENTAR om daglig_salg er ikke et treff', () => {
    expect(aggregerendeDaglige([{ fil: '0001.sql',
      sql: 'create or replace view public.v() as -- from public.daglig_salg\n select sum(x) from public.v_butikksalg;' }]))
      .toEqual([])
  })

  it('uten aggregat er det ikke et treff', () => {
    // `v_butikksalg` leser selv `daglig_salg` — det er hele poenget med
    // den. En vakt som meldte den ville vaert ubrukelig.
    expect(aggregerendeDaglige([{ fil: '0001.sql',
      sql: 'create or replace view public.v() as select * from public.daglig_salg;' }]))
      .toEqual([])
  })
})
