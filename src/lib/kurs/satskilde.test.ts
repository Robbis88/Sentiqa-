// Satsen skal leses, ikke skrives inn. Og kastet skal telles én gang.
//
// =====================================================================
// TO VAKTER SOM BEGGE HAR EN EKTE FORHISTORIE
// =====================================================================
//
// 1  HARDKODET SATS. P2-rapporten hadde en `SATS`-tabell jeg selv hadde
//    skrevet, og den paret 9145 med Bønes' sats. Ingen kilde ble slått
//    opp. Produksjonskoden skal lese `kastbudsjett.kast_pst_av_salg` via
//    `stasjon_id` og `ar` — en sats i en `.ts`-fil er den samme feilen
//    med et annet omslag.
//
// 2  DOBBELTTELLING. Første P2-måling summerte både gruppe- og
//    produktrader fra svinnarket og fikk 64 037,48 for Dale i juli —
//    nøyaktig det dobbelte av 32 018,74. Det er P1-dobbelttellingen, og
//    den kom tilbake i det øyeblikket parseren ble lest direkte i stedet
//    for gjennom grunnlagsregelen.

import { readdirSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, it } from 'vitest'
import { kastdom, kasttall, type Kastmaaned, type Kastsats } from './kastvurdering'

const MAPPE = join(process.cwd(), 'src/lib/kurs')

const les = (sti: string) => readFileSync(sti, 'utf8').split('\r\n').join('\n')

/**
 * Kildekoden uten kommentarer.
 *
 * Uten dette felte vakten sin egen dokumentasjon: `kastvurdering.ts`
 * forklarer at «6,232289968 % er `0.06232289968`», og det er nettopp
 * den setningen som gjør at ingen skriver tallet inn i koden.
 *
 * Samme form som `--`-strippingen i `svinn/lesere.test.ts`: en vakt som
 * ikke kan skille kode fra kommentar, roper på forklaringen sin og blir
 * slått av.
 */
function utenKommentarer(kilde: string): string {
  return kilde.split('\n')
    .filter((l) => {
      const t = l.trimStart()
      return !(t.startsWith('//') || t.startsWith('*') || t.startsWith('/*'))
    })
    .join('\n')
}

// =====================================================================
describe('ingen hardkodet budsjettsats i produksjonskoden', () => {
  /**
   * De fem satsene, med og uten desimalskille — og i både prosent- og
   * andelsform, siden en kopi like gjerne kan skrives som 0.062… som
   * som 6.232….
   */
  const SATSER = [
    '6.232289968', '8.415231157', '8.687747639', '12.136504768', '13.592763033',
    '0.06232289968', '0.08415231157', '0.08687747639', '0.12136504768', '0.13592763033',
  ]

  const produksjonsfiler = readdirSync(MAPPE)
    .filter((f) => f.endsWith('.ts') && !f.endsWith('.test.ts'))

  it('det finnes produksjonsfiler å vokte', () => {
    // Uten denne kunne mappa vært tom og vakten grønn av ingenting.
    expect(produksjonsfiler.length).toBeGreaterThan(3)
  })

  it.each(produksjonsfiler)('%s bærer ingen av de fem satsene', (fil) => {
    const kode = utenKommentarer(les(join(MAPPE, fil)))
    const funn = SATSER.filter((s) => kode.includes(s))
    expect(funn, `hardkodet sats i ${fil}: ${funn.join(', ')}`).toEqual([])
  })

  it('satsen kommer inn som en parameter, ikke fra en konstant', () => {
    const kilde = les(join(MAPPE, 'kastvurdering.ts'))
    // Typen finnes, og beregningen tar den inn.
    expect(kilde).toContain('export type Kastsats')
    expect(kilde).toContain('sats: Kastsats')
    // Og fila navngir hvor den hører hjemme.
    expect(kilde).toContain('kastbudsjett.kast_pst_av_salg')
  })

  it('KANARI: vakten ser en injisert sats, men ikke en kommentar', () => {
    const felt = (kilde: string) =>
      SATSER.some((s) => utenKommentarer(kilde).includes(s))
    // Kode med satsen: skal felles.
    expect(felt('  const DALE = 6.232289968')).toBe(true)
    expect(felt('  { stasjon: "4185", andel: 0.06232289968 },')).toBe(true)
    // Kommentar med satsen: skal IKKE felles. Det var dette som gjorde
    // vakten roed paa sin egen dokumentasjon foerste gang.
    expect(felt('  // 6,232289968 % er 0.06232289968')).toBe(false)
    expect(felt('   * Dale ligger paa 6.232289968 prosent.')).toBe(false)
    // Og en uskyldig kodelinje: heller ikke.
    expect(felt('  const takBilag = st.length * 150')).toBe(false)
  })

  it('KANARI: strippingen fjerner ikke kode', () => {
    const kode = ['const a = 1', '// kommentar', 'const b = 2'].join('\n')
    expect(utenKommentarer(kode)).toContain('const a = 1')
    expect(utenKommentarer(kode)).toContain('const b = 2')
    expect(utenKommentarer(kode)).not.toContain('kommentar')
  })
})

// =====================================================================
/** Den nyeste migrasjonen som definerer `v_kurs_maanedstall`. */
function sisteViewdefinisjon(): string {
  const mappe = join(process.cwd(), 'supabase/migrations')
  const siste = readdirSync(mappe).filter((f) => f.endsWith('.sql')).sort()
    .filter((f) => les(join(mappe, f)).includes('create or replace view public.v_kurs_maanedstall'))
    .pop()
  expect(siste, 'ingen migrasjon definerer v_kurs_maanedstall').toBeDefined()
  return les(join(mappe, siste as string))
}

describe('dobbelttelling gjør testen rød', () => {
  const dale = (kast: number): Kastmaaned => ({
    maaned: '2026-07-01', matsalgKr: 838292.15, matkastKr: kast,
    harSvinndata: true, datastatus: 'gruppe',
  })
  const satsDale: Kastsats =
    { stasjonId: '4185', aar: 2026, andel: 0.06232289968, nivaa: 'avdeling' }

  it('ett nivå gir 3,8195 % og gunstig avvik', () => {
    const k = kasttall(dale(32018.74), satsDale)
    expect(k.faktiskPst).toBeCloseTo(3.8195, 4)
    expect(k.gunstig).toBe(true)
  })

  it('gruppe + produkt gir det dobbelte, og dommen snur', () => {
    // 64 037,48 er nøyaktig 2 × 32 018,74 — tallet den feilaktige
    // målingen ga. En P2-modell som leser svinnrader utenom
    // `v_svinn_grunnlag` havner her.
    const dobbelt = kasttall(dale(32018.74 * 2), satsDale)
    expect(dobbelt.synligKastKr).toBeCloseTo(64037.48, 2)
    expect(dobbelt.faktiskPst).toBeCloseTo(7.6390, 4)
    expect(dobbelt.gunstig).toBe(false)
    // Og det er poenget: Dale ville fått et tiltak den ikke skal ha.
    expect(kasttall(dale(32018.74), satsDale).gunstig)
      .not.toBe(dobbelt.gunstig)
  })

  it('hele Dale-serien doblet gir tiltak i stedet for bekreftelse', () => {
    const maaneder: [string, number, number][] = [
      ['2026-01-01', 519573.61, 37861.32], ['2026-02-01', 517322.38, 35076.17],
      ['2026-03-01', 545167.87, 36961.30], ['2026-04-01', 625019.16, 40898.24],
      ['2026-05-01', 644784.51, 37144.00], ['2026-06-01', 724620.49, 32881.44],
      ['2026-07-01', 838292.15, 32018.74],
    ]
    const enkel = maaneder.map(([m, s, k]) => kasttall(
      { maaned: m, matsalgKr: s, matkastKr: k, harSvinndata: true, datastatus: 'gruppe' },
      satsDale))
    const doblet = maaneder.map(([m, s, k]) => kasttall(
      { maaned: m, matsalgKr: s, matkastKr: k * 2, harSvinndata: true, datastatus: 'gruppe' },
      satsDale))

    expect(kastdom(enkel).slag).toBe('bekreftelse')
    expect(kastdom(doblet).slag).toBe('tiltak')
    // Retningen er den SAMME i begge — dobling skalerer serien og
    // endrer ikke fortegnet på trenden. Det er nettopp derfor en
    // retningstest alene ikke ville fanget dobbelttellingen.
    expect(kastdom(enkel).kurs?.vei).toBe(kastdom(doblet).kurs?.vei)
  })

  /**
   * Uttrykket som staar RETT FOER et kolonnealias.
   *
   * Foerste utgave saa 400 tegn bakover og traff nabokolonnens
   * `case when` - groenn mens den var blind. Andre utgave klippet ved
   * forrige komma, men SQL-kommentarene inneholder komma, og siste
   * kolonne i en CTE har ikke noe komma etter aliaset.
   *
   * Denne stripper `--`-linjer foerst, og godtar alias fulgt av komma
   * ELLER linjeskift.
   */
  function utenSqlKommentarer(sql: string): string {
    const nl = String.fromCharCode(10)
    return sql.split(nl).filter((l) => !l.trimStart().startsWith('--')).join(nl)
  }

  function uttrykkFor(raa: string, alias: string): string {
    const sql = utenSqlKommentarer(raa)
    const m = new RegExp(`\\bas ${alias}\\s*(,|$)`, 'm').exec(sql)
    expect(m, `fant ikke ${alias} i viewet`).not.toBeNull()
    const foran = sql.slice(0, (m as RegExpExecArray).index)
    let dybde = 0
    let kutt = -1
    for (let k = foran.length - 1; k >= 0; k--) {
      const c = foran[k]
      if (c === ')') dybde++
      else if (c === '(') dybde--
      else if (c === ',' && dybde === 0) { kutt = k; break }
    }
    return foran.slice(kutt + 1).trim()
  }

  it('SQL: mattallene er NULL naar matgruppen ikke ble funnet', () => {
    // Kontrakten fra `0215`. `sum()` over null rader er NULL, og en
    // `coalesce(..., 0)` her ville sagt «null kroner kastet mat» om en
    // maaned der matgruppen ikke finnes i det hele tatt.
    const sql = sisteViewdefinisjon()
    for (const kolonne of ['matkast_kr', 'usynlig_mat_kr']) {
      const u = uttrykkFor(sql, kolonne)
      expect(u, `${kolonne} maa gi NULL uten matrader`).toMatch(/^case when /)
      expect(u, `${kolonne} maa avsluttes med end`).toMatch(/end$/)
      expect(u).toContain("filter (where s.kode like '12%') = 0 then null")
    }
  })

  it('SQL: usynlig_rest_kr BEHOLDER sin coalesce', () => {
    // Den er en avgrensning, ikke et oppslag: null rader utenfor mat,
    // vask og pant betyr faktisk at det ikke er noe der.
    const u = uttrykkFor(sisteViewdefinisjon(), 'usynlig_rest_kr')
    expect(u).toMatch(/^coalesce\(sum\(s\.usynlig_kr\)/)
    expect(u).not.toMatch(/^case when /)
  })

  it('KANARI: vakten ser en gjeninnfoert coalesce paa RIKTIG kolonne', () => {
    // Injeksjonen som slapp gjennom foerste utgave: `usynlig_mat_kr`
    // med coalesce, RETT ETTER en `matkast_kr` som fortsatt har sin
    // `case when`. Vinduet paa 400 tegn saa naboens `end` og godtok den.
    const skadet = [
      "    case when count(*) filter (where s.kode like '12%') = 0 then null",
      "         else coalesce(sum(s.kast) filter (where s.kode like '12%'), 0)",
      '    end                                        as matkast_kr,',
      "    coalesce(sum(s.usynlig_kr) filter (where s.kode like '12%'), 0) as usynlig_mat_kr,",
    ].join(String.fromCharCode(10))
    expect(uttrykkFor(skadet, 'matkast_kr')).toMatch(/^case when /)
    expect(uttrykkFor(skadet, 'usynlig_mat_kr')).not.toMatch(/^case when /)
  })

  it('SQL-kjeden leser ett nivå', () => {
    // `v_kurs_maanedstall` skal hente svinn fra `v_svinn_grunnlag`,
    // som velger gruppe ELLER produkt per stasjonsmåned. Vakten for
    // «siste definisjon» ligger i `svinn/lesere.test.ts`; her sjekkes
    // bare at den nyeste migrasjonen ikke har åpnet døra igjen.
    const mappe = join(process.cwd(), 'supabase/migrations')
    const siste = readdirSync(mappe).filter((f) => f.endsWith('.sql')).sort()
      .filter((f) => les(join(mappe, f)).includes('create or replace view public.v_kurs_maanedstall'))
      .pop()
    expect(siste).toBeDefined()
    const sql = les(join(mappe, siste!))
    expect(sql).toContain('from public.v_svinn_grunnlag')
    expect(sql).not.toContain('from public.regnskap_usynlig_svinn')
  })
})
