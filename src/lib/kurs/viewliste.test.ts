import { describe, expect, it } from 'vitest'
import { readFileSync, readdirSync } from 'node:fs'
import { join } from 'node:path'
import {
  BUTIKKSJEF_DRIFT_BEGREP, BUTIKKSJEF_PERSONAL_BEGREP,
} from '@/lib/regnskap-tilgang'
import { SKJUL_OMS_KODER } from '@/lib/avdelinger'

// =====================================================================
// LISTENE I VIEWET OG LISTENE I KODEN SKAL VÆRE DE SAMME
// =====================================================================
//
// `0205` flyttet summeringen til basen, fordi app-laget hentet 1 563 rå
// rader med et tak på 7 200 — og PostgREST kutter på tusen uten å feile.
// Siste måned falt utenfor, og månedsplanene sto med 0 kroner på hver
// stasjon mens tallene lå i basen.
//
// Prisen er at reglene nå finnes to steder: i viewet og i koden. Det er
// den formen dette prosjektet har blitt bitt av flest ganger, og svaret
// er alltid det samme — en billig, deterministisk vakt som gjør at lista
// i praksis bare finnes ett sted.
//
// **Denne fila måler listene, ikke aritmetikken.** Aritmetikken kan ikke
// kjøres i vitest uten en base; den bevises av
// `supabase/tests/kurs_maanedstall_probe.sql`, som måler viewet mot tall
// lest rett ut av julifila.
// =====================================================================

const KATALOG = join(process.cwd(), 'supabase', 'migrations')

/**
 * SISTE definisjon av viewet, uten `--`-kommentarer.
 *
 * PEKER IKKE PÅ ET FILNAVN. Første utgave leste `0205` — og `0206`
 * redefinerte viewet en time senere. **En vakt som peker på en fil blir
 * utdatert av neste migrasjon, og den blir det i stillhet:** den
 * fortsetter å måle en gammel definisjon og melder at alt er i orden.
 *
 * Samme felle tok `begrepliste.test.ts` to ganger samme dag. Hele
 * katalogen leses, og den siste definisjonen er den som gjelder — som
 * også er regelen migrasjonene selv følger.
 */
function renSql(): string {
  let siste: string | null = null
  for (const fil of readdirSync(KATALOG).filter((n) => n.endsWith('.sql')).sort()) {
    const ren = readFileSync(join(KATALOG, fil), 'utf8')
      .replace(/\r\n/g, '\n')
      .split('\n')
      .map((l) => l.replace(/--[^\n]*$/, ''))
      .join('\n')
    const i = ren.search(/create\s+or\s+replace\s+view\s+public\.v_kurs_maanedstall/i)
    if (i >= 0) siste = ren.slice(i)
  }
  if (!siste) throw new Error('fant ingen definisjon av v_kurs_maanedstall')
  return siste
}

/** Begrepene i hvert `begrep = any (array[...])`-uttrykk. */
function begrepslister(): string[][] {
  const blokker = [...renSql().matchAll(/begrep\s*=\s*any\s*\(\s*array\[([\s\S]*?)\]/gi)]
  if (blokker.length === 0) throw new Error('fant ingen begrep-lister i 0205')
  return blokker.map((m) => [...m[1].matchAll(/'([a-z_]+)'/g)].map((x) => x[1]))
}

describe('begrepslistene i viewet', () => {
  it('KANARI: uttrekket finner alle fire listene', () => {
    // To for personal (regnskap + budsjett) og to for drift. Finner den
    // færre, er en av dem uvoktet — og «listene er like» ville vært sant
    // fordi den ikke ble sett.
    expect(begrepslister().length, 'fant ikke fire begrep-lister').toBe(4)
  })

  it('personallistene er identiske med BUTIKKSJEF_PERSONAL_BEGREP', () => {
    const personal = begrepslister().filter((l) => l.includes('faste_lonninger'))
    expect(personal.length, 'fant ikke begge personallistene').toBe(2)
    for (const l of personal) {
      expect([...l].sort()).toEqual([...BUTIKKSJEF_PERSONAL_BEGREP].sort())
    }
  })

  it('driftslistene er identiske med BUTIKKSJEF_DRIFT_BEGREP', () => {
    const drift = begrepslister().filter((l) => l.includes('renhold'))
    expect(drift.length, 'fant ikke begge driftslistene').toBe(2)
    for (const l of drift) {
      expect([...l].sort()).toEqual([...BUTIKKSJEF_DRIFT_BEGREP].sort())
    }
  })

  it('KANARI: «634» er ikke lenger utelatt i stillhet', () => {
    // `DRIFT_KODER` i hent.ts hadde åtte koder der tilgangsgrensen har
    // ni: `634 Rep & vedlikehold` manglet, uten at noe sted sa hvorfor.
    // At den på vaskestasjonene stort sett er WashTec — altså en FØLGE —
    // avgjøres per leverandør i `bilagssum`, og er et annet spørsmål enn
    // om kostnaden er butikksjefens.
    for (const l of begrepslister().filter((x) => x.includes('renhold'))) {
      expect(l).toContain('rep_vedlikehold')
    }
  })

  it('KANARI: den sammenslaatte renholdslinja er med', () => {
    // 627 fra før februar 2026. Uten den ville januar sett ut som en
    // måned uten renholdskostnad — og en kostnad som mangler ser ut som
    // en kostnad som er null.
    for (const l of begrepslister().filter((x) => x.includes('renhold'))) {
      expect(l).toContain('renhold_og_renovasjon')
    }
  })

  it('KANARI: royalty, FSA og leie er IKKE i driftslistene', () => {
    // Kjedeavgifter og faste avtaler. Havner de i «påvirkbare
    // driftskostnader», ber planen butikksjefen om noe hun ikke rår over.
    for (const l of begrepslister().filter((x) => x.includes('renhold'))) {
      for (const forbudt of ['royalty', 'fsa', 'leie_driftsmidler', 'telefon', 'forsikringer']) {
        expect(l, `${forbudt} er med i paavirkbar drift`).not.toContain(forbudt)
      }
    }
  })
})

describe('omsetningsfilteret i viewet', () => {
  const sql = renSql()

  it('holder hver kode i SKJUL_OMS_KODER utenfor', () => {
    // Drivstoff (10) er ~68 % av omsetningen og betjener seg selv på
    // pumpa. «40 CR» er St1s egen total og dobbelteller mot avdelingene.
    // Pant er gjennomstrømning. Se AGENTS.md.
    const iSql = new Set(
      [...sql.matchAll(/not in \(([^)]*)\)/g)]
        .flatMap((m) => [...m[1].matchAll(/'(\d+)'/g)].map((x) => x[1])),
    )
    const mangler = [...SKJUL_OMS_KODER].filter((k) => !iSql.has(k)).sort()
    expect(
      mangler,
      `\nKodene ${mangler.join(', ')} staar i SKJUL_OMS_KODER, men holdes ikke `
      + 'utenfor i viewet.\n\nTelles drivstoff med, blir «omsetning mot '
      + 'budsjett» et tall om pumpetrafikk - og bemanningen maalt mot noe '
      + 'butikksjefen ikke roerer. Det ga «+216 % vekst som ikke fantes» i '
      + 'april 2026.\n',
    ).toEqual([])
  })

  it('KANARI: kodeuttrekket ville sett en manglende kode', () => {
    const prove = "where kode not in ('10', '40')"
    const funnet = [...prove.matchAll(/not in \(([^)]*)\)/g)]
      .flatMap((m) => [...m[1].matchAll(/'(\d+)'/g)].map((x) => x[1]))
    expect(funnet).toEqual(['10', '40'])
    expect(funnet).not.toContain('250')
  })

  it('en linje uten kode telles ikke', () => {
    // «Omsetning totalt» og liknende rollups har ingen kode, og ville
    // dobbeltelt mot avdelingene.
    expect(sql).toMatch(/kode is not null/)
  })

  it('vask og pant holdes utenfor «usynlig paa resten»', () => {
    // Bilvask (21xxx) er strukturelt negativ - app-omsetningen boekfoeres
    // som overskudd - og ville dratt hele tallet i pluss. Pluss er manko,
    // minus er overskudd.
    expect(sql, 'vask er ikke holdt utenfor').toMatch(/not like '21%'/)
    expect(sql, 'pant er ikke holdt utenfor').toMatch(/not like '250%'/)
    expect(sql, 'mat er ikke skilt ut').toMatch(/like '12%'/)
  })
})

describe('viewet er trygt', () => {
  const sql = renSql()

  it('leser som den som spoer, ikke som eieren', () => {
    // Uten `security_invoker` leser viewet forbi RLS - og `create or
    // replace view` uten klausulen nullstiller flagget i stillhet.
    expect(sql).toMatch(/security_invoker\s*=\s*true/)
  })

  it('anon har ingen tilgang', () => {
    // `anon` er rollen bak den offentlige noekkelen i hver sidelast, og
    // Supabase-standarden grant'er hver ny view til den.
    expect(sql).toMatch(/revoke all on public\.v_kurs_maanedstall from anon/)
    expect(sql).toMatch(/grant select on public\.v_kurs_maanedstall to authenticated/)
  })

  it('regnskapet avgjør om måneden finnes', () => {
    // `full outer join` lot en måned med SVINN men uten stasjonsregnskap
    // komme med, med omsetning 0 og resultat 0. Desember 2025 var
    // nøyaktig det: 9 kostnadslinjer, alle på klyngenivå.
    //
    // En null i en trendserie er et datapunkt. Et hull som later som det
    // er en null blir regnet med — og det var det Robert så som «+0 på
    // 8 måneder».
    expect(sql, 'viewet bruker fortsatt full outer join')
      .not.toMatch(/full\s+outer\s+join/i)
    expect(sql, 'svinnet driver fortsatt raden').toMatch(/left join svinn/i)
  })

  it('klyngeradene er utelatt', () => {
    // Klyngearket har `stasjon_id = null` og er kjedetotalen. Kom den med,
    // ville hver stasjons tall blitt summert med hele kjedens.
    expect(sql).toMatch(/stasjon_id is not null/)
  })
})
