import { readFileSync, readdirSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, it } from 'vitest'
import { velgGrunnlagPerNoekkel } from './grunnlag'
import { mankoPerStasjon, svinnPerGruppe, svinnPerStasjon } from './aggreger'

// =====================================================================
// DE NI LESERNE, HVER FOR SEG
// =====================================================================
//
// `grunnlag.test.ts` beviser REGELEN. Denne fila beviser at hver LESER
// bruker den — og at ingen av dem kan slutte å bruke den i stillhet.
//
// Fire lesere er kode og testes direkte. Tre er SQL og kan ikke kjøres
// herfra; for dem leses migrasjonen, på samme vis som
// `kurs/viewliste.test.ts`. En SQL-leser som redefineres tilbake mot
// tabellen skal gjøre denne fila rød.
// =====================================================================

const L = 'st-laguneparken'
const D = 'st-dale'

const fase1 = [
  { stasjon_id: L, periode: '2026-04-01', nivaa: 'produkt', analyseomraade: null, kode: '12010', navn: 'Baguette', salg: 1000, kast: 100, usynlig_kr: 50 },
  { stasjon_id: L, periode: '2026-04-01', nivaa: 'produkt', analyseomraade: null, kode: '12020', navn: 'Wrap', salg: 500, kast: 40, usynlig_kr: -10 },
  { stasjon_id: D, periode: '2026-04-01', nivaa: 'produkt', analyseomraade: null, kode: '16015', navn: 'KAMPANJE', salg: 0, kast: 3655.42, usynlig_kr: 0 },
]

const fase2 = [
  { stasjon_id: L, periode: '2026-04-01', nivaa: 'gruppe', analyseomraade: 'butikk', kode: '120', navn: '120 Mat', salg: 1500, kast: 140, usynlig_kr: 40 },
  ...fase1.filter((r) => r.stasjon_id === L).map((r) => ({ ...r, analyseomraade: 'butikk' })),
  { stasjon_id: L, periode: '2026-04-01', nivaa: 'produkt', analyseomraade: 'drivstoff', kode: '1490', navn: 'Diesel', salg: 900000, kast: 0, usynlig_kr: 9999 },
]

// ---------------------------------------------------------------------
// 1-3 · KODELESERNE SOM SUMMERER PER STASJON
// ---------------------------------------------------------------------

describe('leser 1 · admin-dashbord — kast og usynlig per stasjon', () => {
  it('A · før reimport: uendret', () => {
    const lp = svinnPerStasjon(fase1).find((s) => s.stasjonId === L)!
    expect([lp.kastKr, lp.usynligKr]).toEqual([140, 40])
  })
  it('B · etter reimport: gruppen eier totalen', () => {
    const lp = svinnPerStasjon(fase2).find((s) => s.stasjonId === L)!
    expect([lp.kastKr, lp.usynligKr]).toEqual([140, 40])
    expect(lp.datastatus).toBe('gruppe')
  })
  it('D · ingen dobbelttelling, og diesel er ute', () => {
    // Rå sum over fase 2 ville gitt kast 280 og usynlig 10 079.
    const raa = fase2.reduce((a, r) => ({ k: a.k + r.kast, u: a.u + r.usynlig_kr }), { k: 0, u: 0 })
    expect([raa.k, raa.u]).toEqual([280, 10079])
    const lp = svinnPerStasjon(fase2).find((s) => s.stasjonId === L)!
    expect([lp.kastKr, lp.usynligKr]).toEqual([140, 40])
  })
  it('F · tom periode gir ingen rader, ikke en nullrad', () => {
    expect(svinnPerStasjon([])).toEqual([])
  })
})

describe('leser 2 · analyse-siden — manko, overskudd og toppliste', () => {
  it('A · før reimport: uendret', () => {
    const lp = mankoPerStasjon(fase1).find((s) => s.stasjonId === L)!
    expect([lp.mankoKr, lp.overskuddKr]).toEqual([50, -10])
  })
  it('B · etter reimport: totalen fra gruppen', () => {
    const lp = mankoPerStasjon(fase2).find((s) => s.stasjonId === L)!
    expect(lp.mankoKr).toBe(40)
  })
  it('B · forklaringen navngir varen, ikke gruppen', () => {
    const lp = mankoPerStasjon(fase2).find((s) => s.stasjonId === L)!
    expect(lp.topp.map((t) => t.kode)).toEqual(['12010'])
  })
  it('C · fallback vises i datastatus', () => {
    expect(mankoPerStasjon(fase1)[0].datastatus).toBe('eldre_grunnlag')
  })
})

describe('leser 3 · fokus — svinn per varegruppe', () => {
  it('A · før reimport: produktene nøkles på gruppekoden', () => {
    const { grupper, datastatus } = svinnPerGruppe(fase1)
    expect(grupper.find((g) => g.gruppe === '120')!.kastKr).toBe(140)
    expect(datastatus).toBe('eldre_grunnlag')
  })
  it('B+D · etter reimport: gruppen, og bare én gang', () => {
    const { grupper } = svinnPerGruppe(fase2)
    expect(grupper.find((g) => g.gruppe === '120')!.kastKr).toBe(140)
    expect(grupper.find((g) => g.gruppe === '149')).toBeUndefined() // diesel
  })
  it('KANARI: gruppekoden nøkles som streng, ikke som tall', () => {
    // Her sto `Math.floor(Number(kode) / 100)`, som gir 120 for `12010`
    // men **1** for grupperaden `120`. Matgruppens egen rad havnet da i
    // en bøtte ingen leser.
    expect(Math.floor(Number('120') / 100)).toBe(1)
    expect(svinnPerGruppe(fase2).grupper.map((g) => g.gruppe)).toContain('120')
  })
  it('E · kast uten salg beholdes i gruppens total', () => {
    const { grupper } = svinnPerGruppe(fase1)
    expect(grupper.find((g) => g.gruppe === '160')!.kastKr).toBeCloseTo(3655.42, 2)
  })
})

describe('leser 4 · hent-budsjett — fasiten mot kastbudsjettet', () => {
  it('grunnlaget velges per PERIODE (stasjonen er gitt av spørringen)', () => {
    const rader = [
      { periode: '2026-03-01', nivaa: 'produkt', analyseomraade: null, kode: '12010', kast: 10, usynlig_kr: 1 },
      { periode: '2026-04-01', nivaa: 'gruppe', analyseomraade: 'butikk', kode: '120', kast: 99, usynlig_kr: 9 },
      { periode: '2026-04-01', nivaa: 'produkt', analyseomraade: 'butikk', kode: '12010', kast: 60, usynlig_kr: 5 },
    ]
    const g = velgGrunnlagPerNoekkel(rader, (r) => r.periode)
    expect(g.perNoekkel.get('2026-03-01')!.grunnlag).toBe('produkt')
    expect(g.perNoekkel.get('2026-04-01')!.grunnlag).toBe('gruppe')
    // Summen over alle radene valget landet på: 10 (mars) + 99 (april).
    expect(g.alleRader.reduce((a, r) => a + r.kast, 0)).toBe(109)
    // Rå sum ville gitt 169 — april telt to ganger.
    expect(rader.reduce((a, r) => a + r.kast, 0)).toBe(169)
  })
})

// ---------------------------------------------------------------------
// 5-7 · SQL-LESERNE. Migrasjonen leses; den kan ikke kjøres herfra.
// ---------------------------------------------------------------------

/**
 * Les en fil og NORMALISER linjeskiftene.
 *
 * CRLF-FELLA, TREDJE GANG I DETTE PROSJEKTET. Git sjekker ut `.sql` med
 * CRLF på Windows, LF i CI. Et mønster som inneholder to linjeskift på
 * rad er derfor GRØNT I CI OG RØDT LOKALT — og det motsatte kan også
 * skje. `seksjoner.test.ts` og `begrepliste.test.ts` har vært her før;
 * dette er tredje gang.
 */
function les(sti: string): string {
  return readFileSync(sti, 'utf8').split('\r\n').join('\n')
}

/** Siste definisjon av et SQL-objekt på tvers av hele migrasjonsmappa. */
function sisteDefinisjon(monster: RegExp): { fil: string; sql: string } | null {
  const mappe = join(process.cwd(), 'supabase', 'migrations')
  let treff: { fil: string; sql: string } | null = null
  for (const f of readdirSync(mappe).filter((n) => n.endsWith('.sql')).sort()) {
    const sql = les(join(mappe, f))
    const m = monster.exec(sql)
    if (m) treff = { fil: f, sql: m[0] }
    monster.lastIndex = 0
  }
  return treff
}

describe('leser 5-7 · SQL', () => {
  // Denne formen har gått galt to ganger før: en test som peker på ÉN
  // migrasjonsfil blir stille foreldet neste gang objektet redefineres.
  // Derfor skannes hele mappa, og siste definisjon er den som gjelder.
  const tilfeller: [string, RegExp][] = [
    ['svinn_sum', /create function public\.svinn_sum[\s\S]*?\$\$;/],
    ['v_kurs_maanedstall', /create or replace view public\.v_kurs_maanedstall[\s\S]*?\n\nselect[\s\S]*?;\n\ngrant/],
    ['v_kaffe_svinn', /create or replace view public\.v_kaffe_svinn[\s\S]*?;\n\ngrant/],
  ]

  for (const [navn, monster] of tilfeller) {
    it(`${navn} leser v_svinn_grunnlag, ikke tabellen`, () => {
      const d = sisteDefinisjon(monster)
      expect(d, `fant ingen definisjon av ${navn}`).not.toBeNull()
      expect(d!.sql).toContain('v_svinn_grunnlag')
      expect(d!.sql).not.toContain('regnskap_usynlig_svinn')
    })
  }

  it('grunnlagsviewet finnes, med security_invoker og uten anon', () => {
    const sql = les(join(process.cwd(), 'supabase', 'migrations', '0210_lesere_ett_nivaa.sql'))
    expect(sql).toContain('create or replace view public.v_svinn_grunnlag')
    expect(sql).toContain('with (security_invoker = true)')
    expect(sql).toContain('revoke all on public.v_svinn_grunnlag from anon;')
    expect(sql).toContain('grant select on public.v_svinn_grunnlag to authenticated;')
  })

  it('REGELEN i SQL er den samme som i TypeScript', () => {
    const sql = les(join(process.cwd(), 'supabase', 'migrations', '0210_lesere_ett_nivaa.sql'))
    // Omraadet: butikk eller gammel rad.
    expect(sql).toContain("analyseomraade = 'butikk' or analyseomraade is null")
    // Valget: gruppe naar den finnes, ellers produkt. Aldri begge.
    expect(sql).toContain("bool_or(nivaa = 'gruppe')")
    expect(sql).toContain("(v.har_gruppe and u.nivaa = 'gruppe')")
    expect(sql).toContain("(not v.har_gruppe and (u.nivaa = 'produkt' or u.nivaa is null))")
    // Statusen foelger med ut.
    expect(sql).toContain('as datastatus')
  })

  it('KANARI: les() fjerner CRLF', () => {
    // Uten denne er hele SQL-vakten over en attrapp paa Windows: mine
    // moenstre inneholder to linjeskift paa rad, og med `\r\n` traff de
    // ingenting. Testene var GROENNE I CI og ROEDE LOKALT 2026-09-12.
    //
    // Paastanden maa gjelde begge steder, saa den sier ikke at fila HAR
    // CRLF - bare at den ikke har det etter normalisering.
    const sti = join(process.cwd(), 'supabase', 'migrations', '0210_lesere_ett_nivaa.sql')
    expect(les(sti)).not.toContain('\r')
    expect(les(sti).length).toBeLessThanOrEqual(readFileSync(sti, 'utf8').length)
    // Og moensteret som brukes over MAA finne noe i den normaliserte teksten.
    expect(les(sti)).toMatch(/\n\nselect/)
  })

  it('KANARI: grunnlagsviewet er registrert i anon-sonden', () => {
    // Supabase gir `anon` grant paa hvert nytt view. Den vakten felte
    // dette arbeidet én gang alt.
    const maal = JSON.parse(les(
      join(process.cwd(), 'supabase', 'tests', 'sonde_maal.json'))) as { views: string[] }
    expect(maal.views).toContain('v_svinn_grunnlag')
  })
})
