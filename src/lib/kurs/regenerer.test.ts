// EN SMAL VEI ER BARE SMAL SÅ LENGE NOEN MÅLER BREDDEN.
//
// =====================================================================
// HVA DENNE VAKTEN FINNES FOR
// =====================================================================
//
// `regenererMaaned` skal skrive ÉN tabell — `maanedsplan` — og lese
// resten. Den påstanden står i en kommentar i `regenerer.ts`, og en
// påstand i en kommentar er ikke en grense: den blir usann i det
// øyeblikket noen legger en `.insert()` i `hent.ts` og ingenting sier
// fra.
//
// Derfor leser denne vakten KILDEFILENE i kallgrafen og feller enhver
// skriving mot en tabell som ikke er `maanedsplan`. En ny tabell i
// kjeden blir med av seg selv — det var nettopp det en håndholdt liste
// ikke ville gjort.
//
// Kanarifugl nederst: en injisert skriving MÅ felle vakten. Uten den
// måler den ingenting, og en vakt som slutter å se ser nøyaktig ut som
// en vakt som ikke finner noe.
// =====================================================================

import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, it } from 'vitest'
import { regenereringsnotat, validerMaaned, type Regenerering } from './regenerer'

const ROT = join(import.meta.dirname, '..', '..', '..')

/** Filene regenereringen faktisk kjører gjennom. */
const KALLGRAF = [
  'src/lib/kurs/regenerer.ts',
  'src/lib/kurs/hent.ts',
  'src/lib/kurs/lagre.ts',
  'src/app/(beskyttet)/maanedsplan/handlinger.ts',
]

/** Tabellene Robert har sagt at veien aldri skal endre. */
const FREDET = [
  'regnskapslinjer', 'regnskap_usynlig_svinn', 'bilagssum', 'bp_aar',
  'bp_linje', 'kastbudsjett', 'royaltysats', 'raa_filer', 'import_jobber',
  'daglig_salg', 'stasjoner', 'v_kurs_maanedstall', 'v_svinn_grunnlag',
  'v_butikksalg',
]

const les = (f: string) => readFileSync(join(ROT, f), 'utf8')

/**
 * `from('x')` etterfulgt av en skriveoperasjon.
 *
 * Vinduet er romslig og bevisst grovt: heller ett falskt funn som noen
 * må ta stilling til, enn en skriving som glir gjennom fordi den sto to
 * linjer lenger ned enn mønsteret rakk. Kommentarer strippes først —
 * `svinn.spec.ts` og `satskilde.test.ts` har begge blitt felt av sin
 * egen dokumentasjon.
 */
export function skrivinger(kilde: string): { tabell: string; op: string }[] {
  const uten = kilde
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .replace(/^[ \t]*\/\/.*$/gm, '')
  const ut: { tabell: string; op: string }[] = []
  // LOOKAHEAD, IKKE EN FANGST.
  //
  // Foerste utgave skrev `\.from\(...\)([\s\S]{0,400})`. Med `g` KONSUMERER
  // matchen de 400 tegnene, saa `lastIndex` hopper forbi neste `.from(`
  // - og i `hent.ts`, der fire spoerringer staar rett etter hverandre i
  // samme `Promise.all`, var tre av fire usynlige.
  //
  // Kanarifuglen felte den paa foerste kjoering. Uten den hadde vakten
  // vaert groenn og blind, og det er den farligste tilstanden en vakt
  // kan ha.
  const m = /\.from\(\s*['"]([a-z_0-9]+)['"]\s*\)(?=([\s\S]{0,400}))/g
  for (const treff of uten.matchAll(m)) {
    const etter = treff[2]
    // Stopp ved neste `.from(` — da hører resten til en annen spørring.
    const vindu = etter.split('.from(')[0]
    const op = vindu.match(/\.(insert|update|upsert|delete)\s*\(/)
    if (op) ut.push({ tabell: treff[1], op: op[1] })
  }
  return ut
}

// =====================================================================
describe('veien skriver ÉN tabell', () => {
  const alle = KALLGRAF.flatMap((f) =>
    skrivinger(les(f)).map((s) => ({ ...s, fil: f })))

  it('BYGGEVEIEN skriver ikke direkte i det hele tatt', () => {
    // Etter `0217` gaar all planskriving gjennom
    // `skriv_maanedsplan_utkast`. Et `.from(x).upsert(...)` i disse tre
    // filene ville vaert en vei UTENOM laasen i basen - nettopp det
    // racet vi lukket.
    const bygg = alle.filter((s) => s.fil.startsWith('src/lib/kurs/'))
    expect(bygg, `skriver direkte: ${bygg.map((a) => `${a.tabell}.${a.op} i ${a.fil}`).join(', ')}`)
      .toHaveLength(0)
  })

  it('og ingen fil i grafen skriver en ANNEN tabell enn maanedsplan', () => {
    // `handlinger.ts` har `slippPlan` og `avvisPlan`, som oppdaterer
    // status paa maanedsplan. De hoerer ikke til byggeveien, men de er i
    // fila - og de skal fortsatt ikke kunne roere noe annet.
    const andre = alle.filter((s) => s.tabell !== 'maanedsplan')
    expect(andre, `skriver mot ${andre.map((a) => `${a.tabell} (${a.op}, ${a.fil})`).join(', ')}`)
      .toHaveLength(0)
  })

  it('KANARIFUGL: skriveren i basen kalles, og bare den', () => {
    // Uten denne maaler testen over ingenting: en fil som ikke skriver
    // noe som helst ville ogsaa bestaatt.
    const kall = KALLGRAF.flatMap((f) =>
      [...les(f).matchAll(/\.rpc\(\s*['"]([a-z_0-9]+)['"]/g)].map((m) => m[1]))
    expect(kall).toContain('skriv_maanedsplan_utkast')
    expect(new Set(kall).size, `flere rpc-er: ${[...new Set(kall)].join(', ')}`).toBe(1)
  })

  it('ingen av de fredede tabellene skrives', () => {
    for (const t of FREDET) {
      expect(alle.filter((s) => s.tabell === t), `${t} skrives`).toHaveLength(0)
    }
  })

  it('KANARIFUGL: en injisert skriving feller vakten', () => {
    const ekte = les('src/lib/kurs/hent.ts')
    const skadet = ekte.replace(
      ".from('royaltysats')",
      ".from('royaltysats').update({ lav_sats: 0 })",
    )
    expect(skadet, 'injeksjonen traff ikke').not.toBe(ekte)
    const funn = skrivinger(skadet)
    expect(funn.some((s) => s.tabell === 'royaltysats' && s.op === 'update')).toBe(true)
  })
})

// =====================================================================
describe('ingen tjenestenøkkel', () => {
  // Adminnøkkelen ser forbi RLS. Brukes den her, er rollesjekken i
  // handlingen den ENESTE grensen — og en glemt sjekk ville skrevet i en
  // annen kjede. Eierens egen økt har `maanedsplan_ny` (0202) og
  // `maanedsplan_slipp` (0200), og RLS blir da den andre låsen.
  it('ingen fil i kallgrafen henter adminklienten', () => {
    for (const f of KALLGRAF) {
      expect(les(f), `${f} bruker adminnøkkelen`).not.toMatch(/lagSupabaseAdminKlient/)
    }
  })

  it('KANARIFUGL: mønsteret ville sett den', () => {
    expect('const s = lagSupabaseAdminKlient()').toMatch(/lagSupabaseAdminKlient/)
  })
})

// =====================================================================
describe('validerMaaned', () => {
  const NAA = new Date('2026-09-13T00:00:00Z')

  it('godtar første i måneden', () => {
    expect(validerMaaned('2026-07-01', NAA)).toBe('2026-07-01')
    expect(validerMaaned('2024-01-01', NAA)).toBe('2024-01-01')
    // Inneværende måned er lov.
    expect(validerMaaned('2026-09-01', NAA)).toBe('2026-09-01')
  })

  const nei = (navn: string, v: unknown) =>
    it(`avviser ${navn}`, () => expect(validerMaaned(v, NAA)).toBeNull())

  nei('en dato midt i måneden', '2026-07-15')
  nei('måned uten ledende null', '2026-7-01')
  nei('måned 13', '2026-13-01')
  nei('måned 00', '2026-00-01')
  nei('framtid', '2026-10-01')
  nei('før regnskapsmodellen', '2023-12-01')
  nei('tom streng', '')
  nei('null', null)
  nei('undefined', undefined)
  nei('et tall', 202607)
  nei('et objekt', { maaned: '2026-07-01' })
  nei('en liste', ['2026-07-01'])
  // Formen er forankret i begge ender, så ingenting kan henges på.
  nei('etterhengt SQL', "2026-07-01'; drop table maanedsplan;--")
  nei('etterhengt tekst', '2026-07-01x')
  nei('forankret foran', 'x2026-07-01')
  nei('linjeskift etter', '2026-07-01\n2026-06-01')
  nei('mellomrom', ' 2026-07-01')
})

// =====================================================================
describe('kvitteringen sier hva som IKKE ble gjort', () => {
  const grunn = (o: Partial<Regenerering> = {}): Regenerering => ({
    maaned: '2026-07-01', skrevet: 5, laast: [], hoppet: [], ...o,
  })

  it('teller det som ble skrevet', () => {
    expect(regenereringsnotat(grunn())).toContain('Bygget 5 utkast for 2026-07')
  })

  it('NAVNGIR en låst stasjon', () => {
    const t = regenereringsnotat(grunn({ skrevet: 4, laast: ['St1 Dale'] }))
    expect(t).toContain('St1 Dale')
    expect(t).toContain('allerede avgjort')
  })

  it('NAVNGIR en stasjon uten tall for måneden', () => {
    const t = regenereringsnotat(grunn({
      skrevet: 4,
      hoppet: [{ stasjon: 'St1 Lone', grunn: 'Siste måned med tall er 2026-06, ikke 2026-07.' }],
    }))
    expect(t).toContain('St1 Lone')
    expect(t).toContain('2026-06')
  })

  it('sier fra når ingenting ble skrevet', () => {
    expect(regenereringsnotat(grunn({ skrevet: 0 })))
      .toContain('Ingen utkast ble skrevet')
  })
})
