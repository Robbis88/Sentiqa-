import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, it } from 'vitest'
import { delOppKostnad, STYRINGSKONTI, UTENFOR_BP } from './kostnadsniva'
import { easyatworkNiva } from './easyatwork'
import { BP_TIL_REGNSKAP } from './bp'
import { LONNSKONTI } from './maaned'

// Tallene under er MÅLT mot regnskapet (`190 Kelsar Bil AS 2026xx`) over
// 30 stasjonsmåneder, januar–juli 2026.

describe('kontosettene', () => {
  it('styringskontiene er UTLEDET av BP, ikke skrevet av', () => {
    // Skriver noen dem av på nytt, kan de to listene skille lag — og da
    // ville den ene stille bestemt lønnsrommet mens den andre så riktig
    // ut. Endres `BP_TIL_REGNSKAP`, skal dette følge med av seg selv.
    expect([...STYRINGSKONTI].sort()).toEqual(Object.values(BP_TIL_REGNSKAP).sort())
    expect([...STYRINGSKONTI].sort()).toEqual(['501', '503', '508', '540', '541'])
  })

  it('utenfor-BP er nøyaktig de fire som aldri budsjetteres', () => {
    // MÅLT: 502, 505, 506 og 509 står med budsjett 0 i alle 30
    // stasjonsmånedene. De måles, men budsjetteres aldri.
    expect([...UTENFOR_BP].sort()).toEqual(['502', '505', '506', '509'])
  })

  it('de to settene dekker alle ni lønnskontiene, uten overlapp', () => {
    // KANARIFUGL MOT DRIFT. Legger noen til en tiende lønnskonto i
    // `maaned.ts` uten å klassifisere den her, faller den mellom
    // stolene — den ville hverken belastet rommet eller vært synlig som
    // øvrig kostnad, og ingen av delene ville sagt fra.
    const begge = [...STYRINGSKONTI, ...UTENFOR_BP].sort()
    expect(begge).toEqual([...LONNSKONTI].sort())
    expect(new Set(begge).size).toBe(begge.length)
  })

  it('BP-kontoene kan ikke endres i stillhet', () => {
    // Endres `BP_TIL_REGNSKAP`, endres hva lønnsrommet måles mot. Det er
    // en forretningsbeslutning, ikke en refaktorering, og den skal
    // tvinge noen til å lese denne testen.
    expect(BP_TIL_REGNSKAP).toEqual({
      5010: '501', 5012: '503', 5090: '508', 5400: '540', 5401: '541',
    })
  })
})

describe('delOppKostnad', () => {
  it('holder sykelønn utenfor styringskosten', () => {
    // HOVEDVAKTEN. MÅLT på Dale juli 2026: 34 830 kr sykelønn av 35 330
    // utenfor BP. Med det gamle oppsettet spiste de av et rom som aldri
    // var satt av til dem.
    const n = delOppKostnad({ 501: 47789, 503: 140723, 508: 22815, 540: 26751, 541: 3273, 505: 34830 })
    expect(n.styringskostKr).toBe(241351)
    expect(n.ovrigLonnKr).toBe(34830)
  })

  it('lar sykelønn IKKE påvirke styringskosten i det hele tatt', () => {
    // Samme måned, ti ganger så mye sykefravær. Styringskosten skal
    // stå helt stille. Blir 505 flyttet inn i STYRINGSKONTI, blir denne
    // rød umiddelbart.
    const u = delOppKostnad({ 503: 300000, 508: 36000, 540: 47376 })
    const m = delOppKostnad({ 503: 300000, 508: 36000, 540: 47376, 505: 348300 })
    expect(m.styringskostKr).toBe(u.styringskostKr)
    expect(m.ovrigLonnKr).toBe(348300)
  })

  it('summerer ALDRI alle ni og kaller det styringskost', () => {
    // Den konkrete feilen vi retter: ni konti holdt mot et fem-konto-BP.
    const alle = { 501: 10, 502: 20, 503: 30, 505: 40, 506: 50, 508: 60, 509: 70, 540: 80, 541: 90 }
    const n = delOppKostnad(alle)
    const total = Object.values(alle).reduce((a, b) => a + b, 0)
    expect(n.styringskostKr).not.toBe(total)
    expect(n.styringskostKr).toBe(10 + 30 + 60 + 80 + 90)
    expect(n.ovrigLonnKr).toBe(20 + 40 + 50 + 70)
    expect(n.styringskostKr! + n.ovrigLonnKr!).toBe(total)
  })

  it('tar refundert sykelønn med fortegnet den har', () => {
    // 506 ligger som NEGATIV kostnad i regnskapet. Trekkes den fra i
    // stedet for å legges til, teller refusjonen dobbelt.
    expect(delOppKostnad({ 505: 34830, 506: -12000 }).ovrigLonnKr).toBe(22830)
  })
})

describe('en ukjent kostnad er ikke null', () => {
  it('gir null styringskost når fastlønna er ukjent', () => {
    // 501 ligger INNE i BP-nivået. Var den 0 her, ville styringskosten
    // vært for lav og rommet sett romsligere ut enn det er. På Bønes er
    // lederens fastlønn 27 % av lønnskosten.
    const n = delOppKostnad({ 503: 140723, 508: 22815, 540: 26751 }, ['501'])
    expect(n.styringskostKr).toBeNull()
    expect(n.ukjenteKonti).toEqual(['501'])
  })

  it('skiller en konto som mangler fra en som er ukjent', () => {
    // Et regnskap uten linje for 509 betyr null kroner bonus. Det er
    // noe helt annet enn at vi ikke vet hva bonusen var.
    const utenLinje = delOppKostnad({ 503: 100, 508: 12, 540: 15 })
    const ukjent = delOppKostnad({ 503: 100, 508: 12, 540: 15 }, ['509'])
    expect(utenLinje.ovrigLonnKr).toBe(0)
    expect(ukjent.ovrigLonnKr).toBeNull()
  })

  it('lar en ukjent øvrig-konto være styringskosten i fred', () => {
    // 509 er utenfor BP. At vi ikke kjenner den, skal ikke hindre oss i
    // å måle rommet — ellers ville ingen åpen måned hatt et avvik.
    const n = delOppKostnad({ 503: 100, 508: 12, 540: 15 }, ['509'])
    expect(n.styringskostKr).toBe(127)
    expect(n.ovrigLonnKr).toBeNull()
  })

  it('kaster på en konto ingen har klassifisert', () => {
    expect(() => delOppKostnad({ 590: 7530 })).toThrow(/verken styringskost eller utenfor BP/)
    expect(() => delOppKostnad({ 503: 100 }, ['590'])).toThrow(/ikke en lønnskonto/)
  })
})

// =====================================================================
// MOT EKTE REGNSKAP
//
// De tre kontrollmånedene, lest av regnskapsfilene. Hopper over når de
// ikke finnes — men sier fra, for en måling som slutter å måle ser
// nøyaktig ut som en som treffer.
// =====================================================================
const DL = join(process.env.USERPROFILE ?? process.env.HOME ?? '', 'Downloads')
const finnes = (f: string) => { try { readFileSync(join(DL, f)); return true } catch { return false } }
const HAR = finnes('190 Kelsar Bil AS 202607-202607.xlsx')

describe('mot regnskapet', () => {
  it('regnskapsfilene finnes', () => {
    if (!HAR) console.warn('\n  HOPPET OVER: regnskapsfilene mangler. Kontrollmånedene ble IKKE målt.\n')
    expect(true).toBe(true)
  })

  // 30 SEKUNDER, IKKE FEM. Tre Excel-arbeidsbøker parses her, og under
  // full suite rakk den ikke standardgrensen — testen var grønn alene og
  // rød sammen med de andre. En test som avhenger av maskinlast måler
  // maskinen, ikke koden.
  it.runIf(HAR)('de tre kontrollmånedene deler seg som målt', { timeout: 30_000 }, async () => {
    const { parseRegnskapStasjoner } = await import('@/lib/parsere/regnskap')
    const fasit = [
      ['202607', 'ST1 Bønes', 1612, 0.67],
      ['202605', 'ST1 Dale', 16048, 3.97],
      ['202607', 'ST1 Dale', 35330, 8.71],
    ] as const

    for (const [mnd, ark, utenforKr, utenforPst] of fasit) {
      const stasjoner = await parseRegnskapStasjoner(
        readFileSync(join(DL, `190 Kelsar Bil AS ${mnd}-${mnd}.xlsx`)),
      )
      const s = stasjoner.find((x) => x.navn === ark)!

      // UAVHENGIG VEI TIL SAMME TALL.
      //
      // Denne summeringen bruker HVERKEN `LONNSKONTI` eller
      // `delOppKostnad`. Kontokodene står som literaler her. Gjorde den
      // ikke det, ville testen bare holdt modellen mot seg selv: flyttet
      // noen 505 fra den ene lista til den andre, ville begge sider
      // flyttet seg i takt og testen blitt grønn på en feil.
      let uavhengigUtenfor = 0
      let uavhengigStyring = 0
      for (const l of s.linjer) {
        if (!l.kode) continue
        if (['502', '505', '506', '509'].includes(l.kode)) uavhengigUtenfor += l.regnskap ?? 0
        if (['501', '503', '508', '540', '541'].includes(l.kode)) uavhengigStyring += l.regnskap ?? 0
      }
      expect(Math.round(uavhengigUtenfor), `${ark} ${mnd} — uavhengig sum`).toBe(utenforKr)
      expect(100 * uavhengigUtenfor / uavhengigStyring, `${ark} ${mnd}`)
        .toBeCloseTo(utenforPst, 1)

      // OG produksjonskoden skal komme fram til det samme.
      const perKonto: Record<string, number> = {}
      for (const l of s.linjer) {
        if (!l.kode || !LONNSKONTI.includes(l.kode as never)) continue
        perKonto[l.kode] = (perKonto[l.kode] ?? 0) + (l.regnskap ?? 0)
      }
      const n = delOppKostnad(perKonto)
      expect(Math.round(n.ovrigLonnKr!), `${ark} ${mnd} — produksjon`).toBe(utenforKr)
      expect(Math.round(n.styringskostKr!), `${ark} ${mnd}`).toBe(Math.round(uavhengigStyring))
    }
  })
})

// =====================================================================
// DEN ÅPNE MÅNEDEN
//
// Viktigere enn historikken: en avlagt måned har alle ni kontiene fra
// regnskapet. En åpen måned har bare easy@work, og der mangler 501 helt.
// =====================================================================
describe('åpen måned', () => {
  const ea = (fastlonnKilde: 'regnskap' | 'oppgitt' | 'baaret' | null, fastlonnKr = 0) => ({
    maaned: '2026-09',
    timer: 650,
    perKonto: fastlonnKr > 0
      ? { 503: 140723, 505: 1113, 501: fastlonnKr }
      : { 503: 140723, 505: 1113 },
    kontantKr: 141836 + fastlonnKr,
    feriepengerKr: 22815,
    pensjonKr: 2837,
    agaKr: 26751,
    lonnskostKr: 191402,
    ukjenteArter: [],
    sykelonnFraMaaned: '2026-08',
    fastlonnKr,
    fastlonnFraMaaned: null,
    fastlonnKilde,
  })

  it('kan IKKE gi et komplett lønnsrom når fastlønna er ukjent', () => {
    // 503 er kjent, 501 er ikke, og 501 ligger inne i BP-nivået.
    // Ville `?? 0` fått stå, ble styringskosten ~47 000 for lav — og
    // rommet like mye for stort. Kunstig grønt, den farlige retningen.
    const n = easyatworkNiva(ea(null) as never)
    expect(n.styringskostKr).toBeNull()
    expect(n.ukjenteKonti).toContain('501')
  })

  it('regner når alle styringsrelevante ledd faktisk er kjent', () => {
    // MOTKONTROLLEN. En vakt som alltid sier «vet ikke» er like ubrukelig
    // som en som alltid sier 0.
    const n = easyatworkNiva(ea('regnskap', 47789) as never)
    expect(n.styringskostKr).toBe(47789 + 140723 + 22815 + 26751)
    expect(n.ukjenteKonti).not.toContain('501')
  })

  it('godtar en oppgitt eller båret fastlønn', () => {
    for (const kilde of ['oppgitt', 'baaret'] as const) {
      expect(easyatworkNiva(ea(kilde, 47789) as never).styringskostKr).not.toBeNull()
    }
  })

  it('lar sykelønna være ukjent uten å stoppe styringskosten', () => {
    // 505 er KJENT fra eksporten, men 502/506/509 er det aldri. De er
    // utenfor BP, så de skal ikke hindre oss i å måle rommet.
    const n = easyatworkNiva(ea('regnskap', 47789) as never)
    expect(n.styringskostKr).not.toBeNull()
    expect(n.ovrigLonnKr).toBeNull()
    expect(n.ukjenteKonti).toEqual(['502', '506', '509'])
  })
})
