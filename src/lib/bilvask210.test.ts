import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { createClient, type SupabaseClient } from '@supabase/supabase-js'
import { MOTPOSTER, erMotpost, nettMotposter } from './regnskap-varsler'
import { TERSKLER } from './regnskap/terskler'

// =====================================================================
// HVORFOR 210 BILVASK IKKE BLIR ET FENOMEN
// =====================================================================
//
// Målt 2026-09-17 (`maanedsbevegelse.test.ts`), juli alene, fire av de
// åtte største bevegelsene i hele kjeden:
//
//   −28 463   9145 Varden          210 Bilvask
//   −18 587   4177 Lone            210 Bilvask
//   −18 119   9038 Laguneparken    210 Bilvask
//   −14 628   9467 Bønes           210 Bilvask
//
// Ingen av dem finnes blant de 22 fenomenene i noen av de tre målte
// månedene. Ca. 80 000 kr i bevegelse, null utslag.
//
// ---------------------------------------------------------------------
// FORKLARINGEN LÅ I KODEN, IKKE I DATA
// ---------------------------------------------------------------------
//
// `210` står i `MOTPOSTER`. Avdelingen motposterer seg selv — maskinvask
// mot maskinvask-app — så `nettMotposter` summerer den FØR den vurderes,
// og motpost-løkka har bare én arm:
//
//   if (g.kr > 0 && ...) legg(...)
//   // Netto overskudd er ikke et funn her.
//
// Et minus er normaltilstanden i en gruppe som motposterer seg selv. Den
// regelen er RIKTIG, og den er skrevet ned med begrunnelse.
//
// Og den er allerede kvittert i produksjon: kommentaren i
// `regnskap-varsler.ts` bokfører Bønes juli 2026 som
//
//   21010 MASKINVASK +7 964    21014 MASKINVASK APP −22 592   = −14 628
//
// — nøyaktig tallet bevegelseskanarifuglen leste for Bønes.
//
// ---------------------------------------------------------------------
// DET SOM LIKEVEL ER ET FUNN
// ---------------------------------------------------------------------
//
// «Minus er normalt» er en påstand om NIVÅ, og den ble avgjort mot en
// årssum. Den sier ingenting om BEVEGELSE. En gruppe som har nettet til
// −5 000 hver måned og plutselig netter −28 463 har flyttet seg, selv om
// begge tallene er «normale» på nivå.
//
// Statusmotoren tier her fordi den skal. En bevegelsesmotor ville hatt et
// annet spørsmål, og den finnes ikke.
//
// DENNE FILA BYGGER DEN IKKE. Den måler bare hva statusmotoren ser og
// hva den forkaster, side om side — så forskjellen kan leses i kroner i
// stedet for å argumenteres.
//
// INGEN TERSKEL BRUKES PÅ ET MÅNEDSTALL. Tersklene vises for å forklare
// statusmotorens valg på ÅRSSUMMEN, som er det eneste de er satt mot.
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

const MAANEDER = ['2026-05-01', '2026-06-01', '2026-07-01']
const navnPaa = (p: string) => ({ '05': 'mai', '06': 'juni', '07': 'juli' })[p.slice(5, 7)] ?? p
const kr = (n: number) => Math.round(n).toLocaleString('nb-NO')
const krTegn = (n: number) => (n >= 0 ? '+' : '−') + kr(Math.abs(n))

type Svinnrad = {
  stasjon_id: string | null
  kode: string | null
  navn: string
  salg: number | null
  usynlig_kr: number | null
  kast: number | null
}

/**
 * Prosenten, slik MOTOREN regner den.
 *
 * =====================================================================
 * `svinn_sum` RETURNERER INGEN PROSENT
 * =====================================================================
 *
 * Foerste utgave av denne fila leste `r.usynlig_pst` rett fra RPC-en.
 * Kolonnen finnes ikke der — `0161` gir `stasjon_id, kode, navn, salg,
 * usynlig_kr, kast, datastatus` — saa feltet ble `undefined`, `?? 0` tok
 * det, og HELE kolonnen sto `0.0`. Ogsaa paa en rad med −6 520 kr paa
 * 15 576 kr salg, altsaa −41,9 %.
 *
 * Det saa ikke ut som en feil. Det saa ut som et svar: «ingen av dem
 * utloeser paa prosent». En maaling som leser feil felt gir null, og
 * null ser ut som en konklusjon.
 *
 * `regnskap-varsler.ts:245` regner den selv, rett foer vurderingen:
 *
 *   usynlig_pst: s.salg ? ((s.usynlig_kr ?? 0) / s.salg) * 100 : 0
 *
 * Den ene linja er gjengitt her — ikke importert, fordi den ligger inne
 * i en `map` midt i `hentRegnskapVarsler` og ikke er eksportert. Vakta
 * under holder de to mot hverandre paa ekte rader.
 */
function pstSomMotoren(r: { salg: number | null; usynlig_kr: number | null }): number {
  return r.salg ? ((r.usynlig_kr ?? 0) / r.salg) * 100 : 0
}

/**
 * Nøyaktig den grenen `hentRegnskapVarsler` tar for en motpostgruppe.
 *
 * GJENGITT, IKKE GJENSKAPT PÅ NYTT: `nettMotposter` og `TERSKLER`
 * importeres fra motoren. Bare `if`-en er skrevet av, og den er tre
 * linjer. Endrer noen motoren uten å endre denne, viser utskriften det
 * som et avvik mellom «motoren varslet» og «grenen sier».
 */
function motpostutfall(kr_: number, pst: number): string {
  const T = TERSKLER
  if (!(kr_ > 0)) return 'INGEN — netto overskudd, forkastet med vilje'
  if (!(kr_ >= T.mankoGul || pst >= T.mankoPstGul)) return 'INGEN — under gul grense'
  const rod = kr_ >= T.mankoRod || (pst >= T.mankoPstRod && kr_ >= T.mankoGul)
  return rod ? 'VARSEL rod' : 'VARSEL gul'
}

/**
 * Samme, for varegruppe-armen — og den har en overskuddsgren.
 *
 * ARMEN SIER HVILKEN AV DE TO BETINGELSENE SOM TRAFF. «gul (pst)» og
 * «gul (kr)» ser like ut paa flaten, men det ene er et beloep og det
 * andre er et forholdstall mot et salg som kan vaere naer null.
 */
function varegruppeutfall(kr_: number, pst: number): string {
  const T = TERSKLER
  if (kr_ > 0 && (kr_ >= T.mankoGul || pst >= T.mankoPstGul)) {
    const rod = kr_ >= T.mankoRod || (pst >= T.mankoPstRod && kr_ >= T.mankoGul)
    return `manko ${rod ? 'rod' : 'gul'}`
  }
  if (kr_ < 0) {
    // BEGGE ARMENE VISES. Returnerte vi bare den foerste som traff,
    // ville «utloest paa kroner» skjult at prosenten ogsaa gjorde det —
    // og spoersmaalet er nettopp hvilke som kommer inn UTEN kroner.
    const paaKr = -kr_ >= T.overskudd
    const paaPst = -pst >= T.overskuddPst
    if (paaKr && paaPst) return 'overskudd gul (kr OG pst)'
    if (paaKr) return 'overskudd gul (kr)'
    if (paaPst) return 'overskudd gul (KUN PST — ingen kronegrense)'
  }
  return 'INGEN'
}

describe('210 Bilvask — hva statusmotoren ser og hva den forkaster', () => {
  kjor('YTD og maaneden alene, per stasjon', async () => {
    const supabase = createClient(
      env('NEXT_PUBLIC_SUPABASE_URL'), env('NEXT_PUBLIC_SUPABASE_ANON_KEY'),
    ) as SupabaseClient
    const { error } = await supabase.auth.signInWithPassword({
      email: EPOST!, password: PASSORD!,
    })
    if (error) throw new Error(`Innlogging feilet: ${error.message}`)

    const { data: srader } = await supabase
      .from('stasjoner').select('id, navn, butikknummer')
      .is('slettet_tid', null).order('butikknummer').limit(200)
    const stasjoner = (srader ?? []) as { id: string; navn: string; butikknummer: string }[]
    const navnFor = new Map(stasjoner.map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))
    expect(stasjoner.length).toBeGreaterThan(0)

    const aar = MAANEDER[0].slice(0, 4)
    const svinn = async (fra: string, til: string) => {
      const { data, error: e } = await supabase.rpc('svinn_sum', { p_fra: fra, p_til: til })
      if (e) throw new Error(`svinn_sum(${fra},${til}): ${e.message}`)
      return (data ?? []) as Svinnrad[]
    }

    const L: string[] = ['', '  210 BILVASK — STATUSMOTORENS BLINDSONE', '']

    // =================================================================
    // 1 REGELEN, LEST UT AV MOTOREN
    // =================================================================
    L.push('  MOTPOSTREGELEN (lest fra regnskap-varsler.ts, ikke gjentatt)')
    for (const [avd, navn] of Object.entries(MOTPOSTER)) {
      L.push(`    avdeling ${avd}  «${navn}»`)
    }
    L.push(`    erMotpost('210') = ${erMotpost('210')}   erMotpost('211') = ${erMotpost('211')}`)
    L.push('    motpostloekka har BARE arm for g.kr > 0. Netto overskudd forkastes.')
    L.push(`    tersklene (mot AARSSUMMEN): manko rod ${kr(TERSKLER.mankoRod)} / `
      + `gul ${kr(TERSKLER.mankoGul)} / pst ${TERSKLER.mankoPstRod} % / ${TERSKLER.mankoPstGul} %`)

    // Kanarifugl: faller 210 ut av MOTPOSTER, maaler resten av fila noe
    // annet enn det den sier at den maaler.
    expect(erMotpost('210'), '210 er ikke lenger en motpostavdeling — hele denne fila maaler da feil ting').toBe(true)

    // =================================================================
    // 2 YTD OG MAANED, PER STASJON, FOR HVER MOTPOSTAVDELING
    // =================================================================
    const ytd = new Map<string, Svinnrad[]>()
    const mnd = new Map<string, Svinnrad[]>()
    for (const p of MAANEDER) {
      ytd.set(p, await svinn(`${aar}-01-01`, p))
      mnd.set(p, await svinn(p, p))
    }

    for (const avd of Object.keys(MOTPOSTER)) {
      L.push('')
      L.push(`  AVDELING ${avd} «${MOTPOSTER[avd]}» — netto per stasjon`)
      L.push('    stasjon                  maaned   YTD netto     maaneden      statusmotorens utfall')
      for (const s of stasjoner) {
        for (const p of MAANEDER) {
          const gY = nettMotposter(ytd.get(p) ?? []).find(
            (g) => g.stasjonId === s.id && g.avdeling === avd)
          const gM = nettMotposter(mnd.get(p) ?? []).find(
            (g) => g.stasjonId === s.id && g.avdeling === avd)
          if (!gY && !gM) continue
          L.push(
            `    ${(navnFor.get(s.id) ?? '').padEnd(22)}  ${navnPaa(p).padEnd(6)} `
            + `${(gY ? krTegn(gY.kr) : '—').padStart(11)}  `
            + `${(gM ? krTegn(gM.kr) : '—').padStart(11)}   `
            + (gY ? motpostutfall(gY.kr, gY.pst) : '—'),
          )
        }
      }
    }

    // =================================================================
    // 3 KONTRASTEN: 211 SELVVASK ER IKKE MOTPOST
    // =================================================================
    //
    // 211 ligger rett ved siden av 210 i kodeverket og BLIR et fenomen
    // (4/5 gul, usynlig_overskudd, alle tre maanedene). Forskjellen er
    // ikke stoerrelsen paa tallet — det er om avdelingen staar i
    // MOTPOSTER.
    //
    // NEVNEREN SKAL STAA VED SIDEN AV PROSENTEN. Overskuddsarmen er
    //
    //   krV < 0 && (-krV >= T.overskudd || -pstV >= T.overskuddPst)
    //
    // — et ELLER uten kronegulv paa prosentarmen. Maalt YTD: Lone −97 kr,
    // Boenes −522, Varden −784. Ingen av dem naar 5 000, saa de kan bare
    // ha utloest paa prosent. Er salget da ogsaa naer null, er «4 av 5
    // stasjoner» bygget paa en nevner som ikke taaler en prosent.
    //
    // FILA AVGJOER IKKE OM DET ER FEIL. Den setter salget ved siden av,
    // saa spoersmaalet kan stilles paa tall.
    L.push('')
    L.push('  KONTRAST — 211 Selvvask (ikke motpost, gaar gjennom varegruppe-armen)')
    L.push('    stasjon                  maaned   YTD usynlig   YTD salg      pst      utfall')
    for (const s of stasjoner) {
      for (const p of MAANEDER) {
        const rY = (ytd.get(p) ?? []).find(
          (r) => r.stasjon_id === s.id && (r.kode ?? '').startsWith('211'))
        if (!rY) continue
        const krV = rY.usynlig_kr ?? 0
        const pstV = pstSomMotoren(rY)
        L.push(
          `    ${(navnFor.get(s.id) ?? '').padEnd(22)}  ${navnPaa(p).padEnd(6)} `
          + `${krTegn(krV).padStart(11)}  `
          + `${kr(rY.salg ?? 0).padStart(11)}  `
          + `${pstV.toFixed(1).padStart(7)}  `
          + varegruppeutfall(krV, pstV),
        )
      }
    }

    // KANARIFUGLEN FOR PROSENTKOLONNEN. Foerste utgave leste et felt som
    // ikke finnes og fikk 0,0 paa hver rad — en maaling som saa ut som
    // et svar. Er HVER pst null igjen, maaler kolonnen ingenting, og da
    // skal fila si fra i stedet for aa rapportere «ingen paa prosent».
    const allePst = stasjoner.flatMap((s) => MAANEDER.flatMap((p) => {
      const r = (ytd.get(p) ?? []).find(
        (x) => x.stasjon_id === s.id && (x.kode ?? '').startsWith('211'))
      return r ? [pstSomMotoren(r)] : []
    }))
    expect(
      allePst.some((x) => x !== 0),
      'hver prosent er 0 — leser kolonnen i det hele tatt noe?',
    ).toBe(true)

    // =================================================================
    // 3b SALGET BAK MOTPOSTGRUPPENE — «+0» er ikke en verdi
    // =================================================================
    //
    // Dale sto +0 paa baade 210 og 211 i alle tre maaneder mens de fire
    // andre laa paa −118k til −259k. Null usynlig med salg er noe helt
    // annet enn null usynlig uten salg: det foerste er en stasjon uten
    // avvik, det andre er en stasjon uten data.
    L.push('')
    L.push('  SALGET BAK AVDELING 210 — YTD, for aa skille «ingen avvik» fra «ingen data»')
    L.push('    stasjon                  maaned   YTD salg      YTD usynlig')
    for (const s of stasjoner) {
      for (const p of MAANEDER) {
        const rader = (ytd.get(p) ?? []).filter(
          (r) => r.stasjon_id === s.id && (r.kode ?? '').slice(0, 3) === '210')
        if (rader.length === 0) continue
        const salg = rader.reduce((n, r) => n + (r.salg ?? 0), 0)
        const usyn = rader.reduce((n, r) => n + (r.usynlig_kr ?? 0), 0)
        L.push(
          `    ${(navnFor.get(s.id) ?? '').padEnd(22)}  ${navnPaa(p).padEnd(6)} `
          + `${kr(salg).padStart(11)}  ${krTegn(usyn).padStart(13)}`,
        )
      }
    }

    // =================================================================
    // 4 HVOR MYE BEVEGELSE FORKASTES, SAMLET
    // =================================================================
    //
    // ABSOLUTTVERDI, OG DET ER MED VILJE. Spoersmaalet er ikke «hva er
    // nettoen» — det er «hvor mye beveget seg uten aa naa flaten».
    // Fortegnet er allerede vist per stasjon over.
    L.push('')
    L.push('  FORKASTET BEVEGELSE — |maanedens netto| der utfallet er INGEN')
    for (const p of MAANEDER) {
      let sum = 0
      let n = 0
      for (const avd of Object.keys(MOTPOSTER)) {
        for (const g of nettMotposter(mnd.get(p) ?? [])) {
          if (g.avdeling !== avd) continue
          const gY = nettMotposter(ytd.get(p) ?? []).find(
            (x) => x.stasjonId === g.stasjonId && x.avdeling === avd)
          if (!gY || motpostutfall(gY.kr, gY.pst).startsWith('INGEN')) {
            sum += Math.abs(g.kr)
            n++
          }
        }
      }
      L.push(`    ${navnPaa(p).padEnd(6)} ${kr(sum).padStart(9)} kr fordelt paa ${n} (stasjon, avdeling)`)
    }

    L.push('')
    L.push('  Regelen er riktig for TILSTAND. Den er taus om BEVEGELSE.')
    L.push('  Ingen terskel er brukt paa et maanedstall i denne fila.')
    L.push('')
    console.log(L.join('\n'))

    // Selvvakt: finner vi ingen motpostgrupper i det hele tatt, har
    // utskriften over ingenting aa si — og en tom tabell ser ut som
    // «ingen bevegelse».
    const funnet = MAANEDER.reduce(
      (n, p) => n + nettMotposter(ytd.get(p) ?? []).length, 0)
    expect(funnet, 'ingen motpostgrupper funnet — maalte denne fila noe?').toBeGreaterThan(0)
  }, 120_000)
})
