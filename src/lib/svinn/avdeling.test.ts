import { describe, expect, it } from 'vitest'
import { avdelingAv, usynligstatus, vareomradeAv } from './mot-budsjett'
import { fordelRegnskapssvinn } from './hent-budsjett'
import { velgGrunnlagPerNoekkel } from './grunnlag'

// =====================================================================
// AVDELINGEN I EN REGNSKAPSKODE — PÅ BEGGE NIVÅER
// =====================================================================
//
// `avdelingAv` ble skrevet da `regnskap_usynlig_svinn` bare hadde
// PRODUKTRADER: `12010`, fem siffer. Etter reimporten ligger grupperaden
// `120` i samme tabell, og `velgGrunnlag` foretrekker nettopp den.
//
// Målt i produksjon 2026-09-17 (`src/lib/vaskbudsjett.test.ts`), alle
// fem stasjoner, identisk:
//
//   rader: spoerring 422   etter velgGrunnlag 91   etter iAvdelingen 0
//   120->null  130->null  140->null ... 250->null
//
// `hent-budsjett.ts:142` spør `avdelingAv(kode) === avdeling` med
// `avdeling = '120'`. Null er aldri lik '120', så hver eneste rad falt
// ut. `usynligstatus` fikk tomme kart, returnerte `null`, og `/svinn`
// sitt «hele svinnet» og AI-ens `hele_svinnet` har vært tomme for hele
// 2026 — med full regnskapsdata i basen.
//
// ---------------------------------------------------------------------
// KONTRAKTEN VAR ALLEREDE `120 -> 120`
// ---------------------------------------------------------------------
//
// Dette er ikke en utvidelse. `avdelingAv` brukes to steder, begge i
// `hent-budsjett.ts`, og på linje 165 er returverdien NØKKELEN som slås
// opp mot `kastbudsjett.kode`. For en avdelingsrad er den koden `'120'`
// (`parsere/delingsfil.ts:109`). Funksjonen skulle altså gi `'120'` for
// grupperaden hele tiden; den kunne bare ikke.
//
// Kommentaren i `hent-budsjett.ts:148` skrev invarianten ned og tok
// feil: «og `avdelingAv` gir `120` for begge».
//
// ---------------------------------------------------------------------
// TO NIVÅER, IKKE «HVA SOM HELST»
// ---------------------------------------------------------------------
//
// Fire og seks siffer avvises fortsatt. En ukjent kodeform skal gi
// `null` og stoppe raden, ikke bli tolket som en avdeling — `slice(0, 3)`
// på hvilken som helst streng ville gjort `1200` til `'120'` og lagt
// fremmede rader inn i MAT i stillhet.
// =====================================================================

describe('avdelingAv — kontrakten på begge nivåer', () => {
  it('produktkoden gir avdelingen sin', () => {
    expect(avdelingAv('12010')).toBe('120')
    expect(avdelingAv('12020')).toBe('120')
    expect(avdelingAv('16015')).toBe('160')
  })

  it('GRUPPEKODEN ER avdelingen — det reimporten faktisk legger inn', () => {
    expect(avdelingAv('120')).toBe('120')
    expect(avdelingAv('130')).toBe('130')
    expect(avdelingAv('250')).toBe('250')
  })

  it('vaskavdelingene gir seg selv, paa begge nivaaer', () => {
    // Etter rettelsen gir `avdelingAv('210')` = '210'. Det er MENINGEN,
    // og det er nettopp derfor vask-kontrakten maa vaktes eksplisitt
    // lenger nede: '210' er fortsatt ikke '120'.
    expect(avdelingAv('210')).toBe('210')
    expect(avdelingAv('21010')).toBe('210')
    expect(avdelingAv('211')).toBe('211')
    expect(avdelingAv('21110')).toBe('211')
  })

  it('avviser kodeformer uten dokumentert kontrakt', () => {
    // Fire siffer er ikke et nivaa vi kjenner. `slice(0, 3)` ville gjort
    // `1200` til '120' og sluppet en fremmed rad inn i MAT.
    expect(avdelingAv('1200')).toBeNull()
    expect(avdelingAv('120100')).toBeNull()
    expect(avdelingAv('12')).toBeNull()
    expect(avdelingAv('1')).toBeNull()
  })

  it('null, tomt og ikke-siffer haandteres som foer', () => {
    expect(avdelingAv(null)).toBeNull()
    expect(avdelingAv('')).toBeNull()
    expect(avdelingAv('   ')).toBeNull()
    expect(avdelingAv('MAT')).toBeNull()
    expect(avdelingAv('12A10')).toBeNull()
    expect(avdelingAv('1A0')).toBeNull()
  })

  it('trimmer, slik den alltid har gjort', () => {
    expect(avdelingAv(' 12010 ')).toBe('120')
    expect(avdelingAv(' 120 ')).toBe('120')
  })
})

describe('vareomradeAv — uendret, og det er et valg', () => {
  it('produktkoden gir vareomraadet sitt', () => {
    expect(vareomradeAv('12010')).toBe('10')
    expect(vareomradeAv('12015')).toBe('15')
  })

  it('GRUPPEKODEN har intet vareomraade, og skal gi null', () => {
    // En grupperad ER hele avdelingen. Den kan ikke noekles inn i ETT
    // vareomraade, saa `null` er riktig svar - ikke en mangel.
    // `kastbudsjett`-koden for et vareomraade er tosifret ('10'..'15',
    // `parsere/delingsfil.ts:110`), og '120' er ikke ett av dem.
    expect(vareomradeAv('120')).toBeNull()
    expect(vareomradeAv('210')).toBeNull()
  })

  it('null og soppel som foer', () => {
    expect(vareomradeAv(null)).toBeNull()
    expect(vareomradeAv('')).toBeNull()
    expect(vareomradeAv('1200')).toBeNull()
    expect(vareomradeAv('12A10')).toBeNull()
  })
})

// =====================================================================
// INTEGRASJONSVAKTEN — velgGrunnlag -> avdelingsfilter -> usynligstatus
// =====================================================================
//
// Enhetstestene over hadde alle vaert groenne mens `/svinn` sto tom.
// Regresjonen oppsto ikke i en funksjon: den oppsto mellom to som hver
// for seg var riktige. `velgGrunnlag` ble oppdatert for reimporten og
// foretrekker grupperader; `avdelingAv` ble ikke.
//
// Kjeden maales derfor paa produksjonskoden selv. `fordelRegnskapssvinn`
// er loekken fra `hentSvinnbudsjett`, flyttet ut uendret nettopp fordi
// den bare kunne naas med en database.
// =====================================================================

const P = (m: string) => `2026-${m}-01`

/** Grupperad, slik reimporten legger dem. */
const grp = (kode: string, kast: number, usynlig: number, m = '07') => ({
  stasjon_id: 'a', periode: P(m), nivaa: 'gruppe' as const,
  analyseomraade: 'butikk' as const, kode, kast, usynlig_kr: usynlig,
})

describe('kjeden: grunnlagsvalg -> avdelingsfilter -> usynligstatus', () => {
  it('GRUPPERADEN OVERLEVER et kastbudsjett paa avdeling 120', () => {
    // Regresjonen, i kjedeform. Foer rettelsen ga dette to tomme kart og
    // `usynligstatus` returnerte null - «ingen maaned er avlagt».
    const g = velgGrunnlagPerNoekkel([grp('120', 1_400, 400)], (r) => r.periode)
    const { kastRegnskap, usynligPerMaaned } = fordelRegnskapssvinn(
      g.alleRader, { avdeling: '120', paaVareomrade: false })

    expect(usynligPerMaaned.get('2026-07')).toBe(400)
    expect(kastRegnskap.get('120')?.get('2026-07')).toBe(1_400)

    const u = usynligstatus(usynligPerMaaned, kastRegnskap.get('120')!)
    expect(u, 'usynligstatus ga null — kjeden er broetet igjen').not.toBeNull()
    expect(u!.usynligKr).toBe(400)
    expect(u!.kastAvlagtKr).toBe(1_400)
    expect(u!.totaltKr).toBe(1_800)
    expect(u!.maaneder).toBe(1)
  })

  it('produktraden overlever fortsatt — nivaaene er likestilte', () => {
    const rad = { ...grp('12010', 900, 300), nivaa: 'produkt' as const }
    const g = velgGrunnlagPerNoekkel([rad], (r) => r.periode)
    const { usynligPerMaaned } = fordelRegnskapssvinn(
      g.alleRader, { avdeling: '120', paaVareomrade: false })
    expect(usynligPerMaaned.get('2026-07')).toBe(300)
  })

  it('NIVAAVALGET STAAR — grupperaden eier totalen, produktraden telles ikke med', () => {
    // Ligger begge i samme svar, ville en raa loekke lagt matkastet til
    // to ganger. Naa som BEGGE nivaaer slipper gjennom `avdelingAv`, er
    // det `velgGrunnlag` alene som hindrer dobbelttellingen.
    const g = velgGrunnlagPerNoekkel(
      [grp('120', 1_400, 400), { ...grp('12010', 1_400, 400), nivaa: 'produkt' as const }],
      (r) => r.periode)
    const { usynligPerMaaned, kastRegnskap } = fordelRegnskapssvinn(
      g.alleRader, { avdeling: '120', paaVareomrade: false })
    expect(usynligPerMaaned.get('2026-07')).toBe(400)
    expect(kastRegnskap.get('120')?.get('2026-07')).toBe(1_400)
  })

  it('uten avdelingsrad gjoeres ingen avgrensning, som foer', () => {
    const g = velgGrunnlagPerNoekkel([grp('120', 100, 10), grp('250', 200, 20)],
      (r) => r.periode)
    const { usynligPerMaaned } = fordelRegnskapssvinn(
      g.alleRader, { avdeling: null, paaVareomrade: false })
    expect(usynligPerMaaned.get('2026-07')).toBe(30)
  })

  it('en ukjent kodeform stopper raden i stedet for aa bli gjettet inn i MAT', () => {
    const g = velgGrunnlagPerNoekkel([grp('1200', 500, 50)], (r) => r.periode)
    const { usynligPerMaaned, kastRegnskap } = fordelRegnskapssvinn(
      g.alleRader, { avdeling: '120', paaVareomrade: false })
    expect(usynligPerMaaned.size).toBe(0)
    expect(kastRegnskap.size).toBe(0)
  })
})

// ---------------------------------------------------------------------
// VASK-KONTRAKTEN MAA OVERLEVE DENNE RETTELSEN
// ---------------------------------------------------------------------
//
// Etter rettelsen gir `avdelingAv('210')` = '210' i stedet for null. Det
// er meningen — men det betyr at vasken naa faar et SVAR der den foer
// fikk ingenting, og et svar kan sammenlignes feil.
//
// `'210' === '120'` er fortsatt usant, saa vask slipper ikke inn i MAT.
// Den setningen er billig aa tro paa og dyr aa ta feil om.
// ---------------------------------------------------------------------

describe('vask slipper ikke inn i MAT', () => {
  it('210 og 211 filtreres bort naar budsjettet gjelder avdeling 120', () => {
    const g = velgGrunnlagPerNoekkel(
      [grp('120', 1_400, 400), grp('210', 0, -28_622), grp('211', 0, -6_520)],
      (r) => r.periode)
    const { usynligPerMaaned } = fordelRegnskapssvinn(
      g.alleRader, { avdeling: '120', paaVareomrade: false })
    // 400, ikke 400 − 28 622 − 6 520 = −34 742.
    expect(usynligPerMaaned.get('2026-07')).toBe(400)
  })

  it('produktnivaa vask filtreres ogsaa bort', () => {
    const rader = [
      { ...grp('12010', 0, 400), nivaa: 'produkt' as const },
      { ...grp('21014', 0, -22_592), nivaa: 'produkt' as const },
    ]
    const g = velgGrunnlagPerNoekkel(rader, (r) => r.periode)
    const { usynligPerMaaned } = fordelRegnskapssvinn(
      g.alleRader, { avdeling: '120', paaVareomrade: false })
    expect(usynligPerMaaned.get('2026-07')).toBe(400)
  })

  it('KANARIFUGL — vaskraden ER med i grunnlaget, saa filteret faktisk proeves', () => {
    // Faller vaskraden ut alt i `velgGrunnlag`, beviser testene over at
    // avdelingsfilteret virker uten at det noen gang ble utfordret.
    const g = velgGrunnlagPerNoekkel(
      [grp('120', 1_400, 400), grp('210', 0, -28_622)], (r) => r.periode)
    expect(g.alleRader.some((r) => r.kode === '210')).toBe(true)
  })
})
