import { readdirSync, readFileSync, statSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, it } from 'vitest'
import { utenKommentarer } from '@/lib/redesign/design'

// =====================================================================
// DE ÅTTE MÅTENE «MIN MÅNED» KAN BEGYNNE Å LYVE PÅ
// =====================================================================
//
// Ingen av dem gir en feilmelding. Alle ser ut som en side som virker:
//
//   1  et manglende tall blir 0
//   2  en prognose presenteres som fasit
//   3  en plan presenteres som noe som faktisk skjedde
//   4  en anslått brutto mister anslått-statusen på veien ut
//   5  flaten regner ut et motorfelt på nytt
//   6  flaten finner på sine egne innsikter forbi `vite.ts`
//   7  en uautorisert stasjon blir synlig
//   8  det oppstår en ANDRE sammenstilling av `Bildeinput`
//
// 1–4 måles på oppførselen i `okonomi/sammenstill.test.ts`, med
// fiksturer. Denne fila tar 5–8, som er STRUKTURELLE: de kan ikke prøves
// med et tall, bare med at koden ikke har formen.
//
// Hver vakt har en kanarifugl. En vakt som slutter å se, ser nøyaktig ut
// som en vakt som ikke finner noe.
// =====================================================================

const ROT = process.cwd()
const les = (...p: string[]) => readFileSync(join(ROT, ...p), 'utf8').replace(/\r\n/g, '\n')

const SIDE = les('src', 'app', '(beskyttet)', 'min-maaned', 'page.tsx')
const REISE = les('src', 'app', '(beskyttet)', 'min-maaned', 'reise.ts')

/** Kode uten kommentarer og uten strenginnhold. Som `bildevakt.test.ts`. */
function bareKode(kilde: string): string {
  return utenKommentarer(kilde)
    .replace(/`(?:[^`\\]|\\.)*`/g, '‹streng›')
    .replace(/'(?:[^'\\\n]|\\.)*'/g, '‹streng›')
    .replace(/"(?:[^"\\\n]|\\.)*"/g, '‹streng›')
}

describe('KANARIFUGL: filene finnes og er ikke tomme', () => {
  it('siden og reisen blir lest', () => {
    // Byttes en sti, ville hver påstand under vært sann fordi det ikke
    // er noe å måle.
    expect(SIDE.length).toBeGreaterThan(3000)
    expect(SIDE).toContain('export default async function MinMaanedSide')
    expect(REISE).toContain('export function reisen')
  })
})

// =====================================================================
// 8. ÉN SAMMENSTILLING AV `Bildeinput`
// =====================================================================
describe('det finnes bare ÉN sammenstilling av Bildeinput', () => {
  /** Hver `.ts`/`.tsx` under `src/`, uten tester. */
  function kildefiler(mappe: string, ut: string[] = []): string[] {
    for (const navn of readdirSync(mappe)) {
      const sti = join(mappe, navn)
      if (statSync(sti).isDirectory()) { kildefiler(sti, ut); continue }
      if (!/\.tsx?$/.test(navn)) continue
      if (/\.test\.tsx?$/.test(navn)) continue
      ut.push(sti)
    }
    return ut
  }

  const ALLE = kildefiler(join(ROT, 'src'))

  it('KANARIFUGL: filsøket finner et rimelig antall filer', () => {
    expect(ALLE.length).toBeGreaterThan(200)
  })

  it('bare bilde.ts og sammenstill.ts nevner byggOkonomibilde', () => {
    // =================================================================
    // EN ANDRE SAMMENSTILLING ER EN ANDRE SANNHET
    // =================================================================
    //
    // `bilde.ts` løste det for kildemerkingen: ett sted bestemmer når et
    // tall er fasit. Men INNGANGEN til den — hvilken måned, hvilke uker
    // som er ventet, om regnskapet skal leses — sto i /lonnskost, og
    // neste flate måtte kopiere den eller finne på sin egen.
    //
    // To sammenstillinger ville ikke gitt en feil. De ville gitt to
    // riktige sider som svarte forskjellig på samme spørsmål, og det
    // ville vist seg først når noen sammenlignet dem i et møte.
    // KALLET, IKKE OMTALEN. Sju filer NEVNER `byggOkonomibilde` i en
    // kommentar — de forklarer nettopp hvorfor de IKKE gjør dette selv.
    // Uten `bareKode` ville vakten felt hver av dem, og den første som
    // skulle rette noe ville slått den av.
    //
    // KALLET *ELLER* IMPORTEN. En fil som bare importerer og gir
    // funksjonen videre, kaller den ikke selv — men den lar en tredje
    // fil gjøre det uten å stå på denne lista. Vakten ville pekt på
    // mellomleddet og sett forbi den som faktisk bygger bildet.
    const funn = ALLE
      .filter((f) => !/okonomi[\\/](bilde|sammenstill)\.ts$/.test(f))
      .filter((f) => {
        const k = bareKode(readFileSync(f, 'utf8'))
        return k.includes('byggOkonomibilde(')
          || /import[^\n;]*\bbyggOkonomibilde\b/.test(k)
      })
      .map((f) => f.slice(ROT.length + 1))

    expect(
      funn,
      '\nDisse filene kaller byggOkonomibilde utenom sammenstillingen:\n\n  '
      + funn.join('\n  ')
      + '\n\nBruk `hentBildegrunnlag` + `byggMaanedsbilde` i stedet. To\n'
      + 'sammenstillinger er to meninger om naar et tall er fasit.\n',
    ).toEqual([])
  })

  it('bare sammenstill.ts konstruerer en Bildeinput', () => {
    const funn = ALLE
      .filter((f) => !/okonomi[\\/](bilde|sammenstill)\.ts$/.test(f))
      .filter((f) => /:\s*Bildeinput\b|satisfies Bildeinput\b/.test(readFileSync(f, 'utf8')))
      .map((f) => f.slice(ROT.length + 1))
    expect(funn).toEqual([])
  })

  it('/lonnskost og /min-maaned bruker DEN SAMME inngangen', () => {
    const lonnskost = les('src', 'app', '(beskyttet)', 'lonnskost', 'page.tsx')
    for (const kilde of [lonnskost, SIDE]) {
      expect(kilde).toContain('hentBildegrunnlag(')
      expect(kilde).toContain('standardmaaned(')
    }
  })
})

// =====================================================================
// 5. FLATEN REGNER IKKE UT ET MOTORFELT PÅ NYTT
// =====================================================================
describe('siden regner ingen kroner selv', () => {
  // Hvert `kr.format(...)`-kall, med argumentet sitt.
  //
  // GRAADIG MED VILJE. `[^\n]*?` stoppet paa foerste `)` og leste
  // `Math.round(avvik.kroner` som hele argumentet - altsaa et argument
  // som ALDRI kunne matche den lovlige formen, og en vakt som alltid
  // feller er like ubrukelig som en som aldri gjoer det. En for vid
  // fangst gjoer vakten strengere; en for smal gjoer den blind.
  const kroneformateringer = (kilde: string) =>
    [...kilde.matchAll(/kr\.format\((.*)\)/g)].map((m) => m[1])

  it('KANARIFUGL: det finnes kroneformateringer å måle', () => {
    expect(kroneformateringer(SIDE).length).toBeGreaterThan(0)
  })

  it('hvert kronetall kommer rett fra et motorfelt', () => {
    // `Math.round` er avrunding for VISNING, ikke en beregning: tallet er
    // det samme, det skrives bare uten ører. Alt annet — en sum, en
    // differanse, en andel — ville vært flaten som fant på et tall.
    const lovlig = /^Math\.round\((?:felt\.verdi|avvik\.kroner)\)$/
    for (const arg of kroneformateringer(SIDE)) {
      expect(arg.trim(), `kr.format(${arg}) regner noe siden ikke skal regne`)
        .toMatch(lovlig)
    }
  })

  it('KANARIFUGL: leseren ser en utregning som blir lagt inn', () => {
    const med = SIDE.replace(
      'kr.format(Math.round(avvik.kroner))',
      'kr.format(Math.round(bilde.lonnsrom.verdi - bilde.styringskost.verdi))',
    )
    expect(med).not.toBe(SIDE)
    const lovlig = /^Math\.round\((?:felt\.verdi|avvik\.kroner)\)$/
    expect(kroneformateringer(med).some((a) => !lovlig.test(a.trim()))).toBe(true)
  })

  it('reise.ts inneholder ingen aritmetikk i det hele tatt', () => {
    // Stripa skal LESE tre felt, ikke regne en terskel. En prosentgrense
    // her ville vært en ny sannhetsregel om hvor sikkert noe er — og det
    // er `bilde.ts` sin, ikke en UI-modul sin.
    const funn = bareKode(REISE).split('\n')
      .map((l, i) => [i, l] as const)
      .filter(([, l]) => /[+\-*/]/.test(l))
      .map(([i, l]) => `${i}: ${l.trim()}`)
    expect(funn, `\nreise.ts har begynt aa regne:\n\n  ${funn.join('\n  ')}\n`).toEqual([])
  })
})

// =====================================================================
// 2, 3, 4. HVERT TALL BÆRER KILDEN SIN UT
// =====================================================================
describe('ingen krone vises uten kildemerket sitt', () => {
  it('siden har like mange kildemerker som kroneformateringer', () => {
    // =================================================================
    // LOV 3: KILDEN FØLGER MED UT
    // =================================================================
    //
    // Et tall uten merke leses som et tall man kan stole på. Det er
    // nøyaktig feilen kildemerkingen ble bygget for: en anslått
    // bruttofortjeneste og en avlagt ser like ut på skjermen.
    //
    // Tabellradene bærer merket gjennom `Tallrad` (én `kr.format`, ett
    // `<Kildemerke`). Hovedtallene og styringsavviket er skrevet her, og
    // må holde samme forhold.
    const kroner = [...SIDE.matchAll(/kr\.format\(/g)].length
    const merker = [...SIDE.matchAll(/<Kildemerke\s/g)].length
    expect(merker, 'et kronetall paa siden mangler kildemerket sitt').toBe(kroner)
  })

  it('et manglende tall blir en tankestrek, ikke null kroner', () => {
    // `verdi === null ? '—' : kr.format(...)`. Uten det ville et hull i
    // dataene stått som «0 kr» — en rolig, riktig-utseende løgn.
    expect(SIDE).toContain("felt.verdi === null ? '—'")
    expect(SIDE).toContain("avvik.kroner === null ? '—'")
  })

  it('styringsavviket bærer AVVIKSFELTETS kilde, ikke rommets', () => {
    // Lov 2: den svakeste av rommets og lønnas. Sto `bilde.lonnsrom.kilde`
    // her, ville et avvik regnet av et easy@work-anslag stått som fasit
    // fordi bruttoen var avlagt.
    expect(SIDE).toContain('kilde={bilde.styringsavvik.kilde}')
    expect(SIDE).not.toContain('kilde={bilde.lonnsrom.kilde}')
  })

  it('reisen leser de feltene siden faktisk viser', () => {
    // Bygges lista to ganger, kan stripa si «prognose» om et felt
    // tabellen ikke viser — eller tie om ett den viser.
    expect(SIDE).toContain('reisen(bilde, rader.map((r) => r.felt))')
  })
})

// =====================================================================
// 6. `vite.ts` BLIR IKKE OMGÅTT
// =====================================================================
describe('innsiktene er vite.ts sine', () => {
  it('siden kaller ikke hvaBoerJegViteNaa selv', () => {
    // Den bruker `<HvaBoerJegVite>`, som kaller den. Kalte siden den
    // direkte, kunne den filtrert, sortert eller lagt til en beskjed —
    // og da hadde vi to meninger om hva som haster.
    expect(bareKode(SIDE)).not.toContain('hvaBoerJegViteNaa')
    expect(SIDE).toContain('<HvaBoerJegVite bilde={bilde} />')
  })

  it('siden importerer ikke vite.ts', () => {
    expect(SIDE).not.toContain("from '@/lib/okonomi/vite'")
  })

  it('handlingene er månedsplanens, ikke sidas egne', () => {
    // `Planlesing` er komponenten butikksjefen leser planen med paa
    // /min-plan. To flater som tegner det samme hver for seg er to
    // sannheter, og forskjellen viser seg foerst i et moete.
    expect(SIDE).toContain('<Planlesing')
    // BARE SLUPPET OG SENDT. Et utkast er eierens forslag til seg selv;
    // ser butikksjefen det, er godkjenningen meningsloes.
    //
    // HELE KALLET, IKKE DELSTRENGEN. Her sto `toContain("'sluppet',
    // 'sendt'")`, og en injeksjon som la til `'utkast'` kom GROENN
    // tilbake - delstrengen sto der fortsatt. Samme form som en
    // komponentsjekk paa `<TabletSkall` som ogsaa matchet `<TabletSkallX`.
    expect(SIDE).toContain(".in('status', ['sluppet', 'sendt'])")
  })
})

// =====================================================================
// 7. INGEN UAUTORISERT STASJON
// =====================================================================
describe('tilgangen er serverens, ikke skjermens', () => {
  it('rolleporten står før den første spørringen', () => {
    const port = SIDE.indexOf('erLeder(bruker.rolle)')
    const forste = SIDE.indexOf('supabase\n') >= 0
      ? Math.min(...[SIDE.indexOf('.from('), SIDE.indexOf('supabase.from(')].filter((i) => i > 0))
      : SIDE.indexOf('.from(')
    expect(port, 'rolleporten mangler').toBeGreaterThan(0)
    expect(port, 'rolleporten maa staa foer foerste spoerring').toBeLessThan(forste)
  })

  it('nettbrettet og plattformredaktøren slipper ikke inn', () => {
    // `erLeder` er eier + butikksjef. Rollelista bor i auth/roller.ts —
    // siden skriver ikke sin egen.
    expect(SIDE).toContain("from '@/lib/auth/roller'")
    expect(SIDE).not.toMatch(/rolle\s*===\s*'butikkbruker_tablet'/)
    expect(SIDE).not.toMatch(/rolle\s*===\s*'plattform_redaktor'/)
  })

  it('spørringene filtrerer på den valgte stasjonen, i basen', () => {
    // INNSNEVRING, ALDRI UTVIDELSE. RLS gir butikksjefen sine egne
    // stasjoner og eieren kjeden; valget her er et filter inne i det.
    // Sto filteret i JavaScript etterpaa, ville RLS vaert eneste lag —
    // og en frontendfiltrering er ingen sikkerhetsmekanisme.
    expect(SIDE).toContain(".eq('stasjon_id', valgtStasjon!)")
    expect(SIDE).toContain('hentBildegrunnlag(supabase, valgtStasjon!, FRA)')
  })

  it('en ukjent stasjon i URL-en gir tomtilstand, ikke en annen stasjons tall', () => {
    // `stasjonFraUrl` gir `undefined` for en id brukeren ikke naar, og
    // `husketStasjon` faller tilbake. `erStasjon` er porten som hindrer
    // at et fallback-valg ser ut som det brukeren ba om.
    expect(SIDE).toContain('const erStasjon = valgtStasjon != null && navnFor.has(valgtStasjon)')
    expect(SIDE).toContain('if (!erStasjon)')
  })

  it('en feilet spørring blir en feiltilstand, ikke en tom måned', () => {
    // `data ?? []` ville gjort en avvist eller feilet spoerring til
    // «ingen tall ennaa» — en rolig beskjed om at maaneden ikke er
    // begynt, mens sannheten er at spoerringen ikke naadde fram.
    expect(SIDE).toContain('<Feiltilstand')
    expect(SIDE).toContain('maaVaereHele(plansvar')
  })
})
