import type { BpResultat, BpStasjon } from '@/lib/parsere/typer'

// =====================================================================
// HVA BETYR DEN NYE BP-EN FOR OSS?
//
// En BP er ikke et resultat. Den er en ramme St1 setter, og den sier tre
// ting samtidig: hva dere skal selge, hva dere får bruke, og hva St1 tar.
// Denne fila leser de tre ut av to årganger og sier hva som er endret.
//
// ---------------------------------------------------------------------
// DET SOM SKILLER ET FUNN FRA ET TALL
//
// En prosentendring er ikke et funn. Et funn er et tall NOEN KAN GJØRE
// NOE MED, eller som endrer hva de bør forvente. Derfor har hvert funn
// tre deler: hva som er målt, hva det betyr, og hvor tallet kommer fra
// slik at det kan etterprøves.
//
// Og funn uten dom er bedre enn feil dom. Et budsjett er ikke et utfall:
// en høyere kostnadsramme er mer rom, ikke et dårligere år. Derfor er
// `dom` valgfri, og satt bare der den er utvetydig.
//
//   «det er positivt om vi får høyere timepris pr time på lønn,
//    for det er det st1 gir oss» — Robert 2026-08-30
//
// Timeprisen er en RAMME, ikke en kostnad de bærer. Det gjelder hele
// lønnsblokka: flere timer og dyrere timer er begge penger inn i ramma.
//
// ---------------------------------------------------------------------
// TO ÅRGANGER ER IKKE TO LIKE FILER
//
// BP25 er St1s gamle internasjonale mal, BP26 er en ny norsk arbeidsbok.
// Målt mot Kelsars egne filer skiller de seg på fire måter som hver for
// seg kan lage et funn som ikke finnes:
//
//   varegruppenavn   «160 Kioskvarer ex smågodt» ble til «160 Kioskvarer».
//                    Nøkles det på navn, ser én gruppe ut som to — én
//                    kuttet 100 % og én splitter ny. DERFOR NØKLES DET
//                    PÅ KODE, og navnet er bare til visning.
//
//   lønnssplitten    BP25 fører all lønn på 5010. BP26 splitter i 5012
//                    timelønn og 5010 fastlønn. Lønnen leses derfor ut av
//                    KONTOPLANEN (5xxx), ikke av splittfeltene, og
//                    splitten brukes bare når begge år har den.
//
//   kontoplanen      BP25 har 18 aggregerte konti, BP26 har over femti og
//                    kaller dem alle «Kostnader». En linje-for-linje-diff
//                    ga 38 nye og 17 borte — null informasjon. Diffen
//                    kjøres bare når kontoplanene faktisk overlapper.
//
//   royaltysatsen    Den ordinære satsen lar seg IKKE regne ut av det
//                    filene sier — vaskedelen er korrigert for appens
//                    andel, og korreksjonen står ingen steder. Derfor
//                    måles royaltyen som andel av omsetningen, og
//                    endringen deles i volum og andel. Se `royaltyandel()`.
// =====================================================================

export type Alvor = 'viktig' | 'merk' | 'info'
export type Dom = 'god' | 'vond'

export type Funn = {
  id: string
  alvor: Alvor
  tittel: string
  /** Én setning: hva som er målt. */
  maalt: string
  /** Én til tre setninger: hva det betyr for driften. */
  betyr: string
  /** Utvetydig godt eller vondt. Utelatt når det avhenger av hva de gjør. */
  dom?: Dom
  /** Kroner det handler om, når det finnes ett tall som bærer funnet. */
  kroner?: number
  /** Hvor tallene kommer fra, så funnet kan etterprøves. */
  kilde: string
}

export type Varegruppe = { post: string; salg: number; varekost: number }
export type Kostnadskonto = { post: string; kr: number }

export type Aarstall = {
  ar: number
  salg: number
  varekost: number
  brutto: number
  /** All lønn, uansett om årgangen splitter den. Konti 5xxx. */
  personal: number
  /** Splitten når årgangen har den; 0 når den ikke finnes. */
  timelonn: number
  fastlonn: number
  /** Drift utenom lønn, royalty og FSA. */
  andreKostnader: number
  royalty: number
  /** Årsrammen i timer. Ikke i BP25-malen — 0 betyr «vet ikke». */
  timer: number
  /** Nøklet på varegruppekode, aldri på navn. */
  kategorier: Map<string, Varegruppe>
  /** Nøklet på kontokode. */
  konti: Map<string, Kostnadskonto>
}

const ROYALTY = '6312'
const FSA = '6315'

const erVask = (post: string) => /vask/i.test(post)
const erPant = (post: string) => /pant/i.test(post)
const erLonn = (kode: string) => /^5\d{3}$/.test(kode)

/** Summerer en BP-årgang til de tallene analysen trenger. */
export function summer(bp: BpResultat, butikknumre?: string[]): Aarstall {
  const med = (s: BpStasjon) => !butikknumre || butikknumre.includes(s.butikknummer)
  const stasjoner = bp.stasjoner.filter(med)

  const t: Aarstall = {
    ar: bp.ar ?? 0,
    salg: 0, varekost: 0, brutto: 0,
    personal: 0, timelonn: 0, fastlonn: 0,
    andreKostnader: 0, royalty: 0, timer: 0,
    kategorier: new Map(), konti: new Map(),
  }

  for (const s of stasjoner) {
    t.timer += s.timerAar ?? 0
    for (const m of s.maaneder) {
      t.salg += m.salgKr
      t.varekost += m.varekostKr
      t.brutto += m.bruttoKr
      t.timelonn += m.timelonnKr
      t.fastlonn += m.fastlonnKr

      for (const k of m.kategorier) {
        const v = t.kategorier.get(k.kode) ?? { post: k.post, salg: 0, varekost: 0 }
        v.salg += k.salgKr
        v.varekost += k.varekostKr
        t.kategorier.set(k.kode, v)
      }

      for (const k of m.konti) {
        if (k.kode === ROYALTY) { t.royalty += k.belopKr; continue }
        // FSA staar negativt og er ikke en driftskostnad - den er
        // avtalens utjevning. Tas den med i kostnadsramma, ser rammen
        // mindre ut enn den er.
        if (k.kode === FSA) continue

        const v = t.konti.get(k.kode) ?? { post: k.post, kr: 0 }
        v.kr += k.belopKr
        t.konti.set(k.kode, v)

        // LOENNEN LESES UT AV KONTOPLANEN, ikke av splittfeltene: BP25
        // fører alt på 5010 og har ingen splitt å lese.
        if (erLonn(k.kode)) t.personal += k.belopKr
        else t.andreKostnader += k.belopKr
      }
    }
  }

  // BP26 fører 5010/5012 både som felt og som konto. BP25 har bare
  // kontoen. Feltene brukes derfor kun til splitten, aldri til summen —
  // ellers telles BP26s lønn to ganger og BP25 ser 9 millioner billigere ut.
  if (t.personal === 0) t.personal = t.timelonn + t.fastlonn

  return t
}

const pst = (b: number, f: number) => (f === 0 ? null : (b / f - 1) * 100)
const kr = (n: number) => Math.round(n).toLocaleString('nb-NO')
// Desimalkomma, ikke punktum. `toFixed` gir punktum uansett locale.
const p1 = (x: number) =>
  (x >= 0 ? '+' : '−') + Math.abs(x).toFixed(1).replace('.', ',') + ' %'
const p2 = (x: number) => x.toFixed(2).replace('.', ',')

/** Ordinær omsetning: alt som betaler den ordinære royaltysatsen. */
export function ordinaertSalg(t: Aarstall): number {
  let sum = 0
  for (const v of t.kategorier.values()) {
    if (!erVask(v.post) && !erPant(v.post)) sum += v.salg
  }
  return sum
}

/**
 * Royaltyens andel av omsetningen. Eksakt: to tall vi leser, delt på
 * hverandre.
 *
 * ---------------------------------------------------------------------
 * HVORFOR IKKE DEN ORDINÆRE SATSEN?
 *
 * Fordi den ikke lar seg regne ut av det filene sier. Royaltyen er
 * sammensatt av tre satser — ordinært salg, vask, og pant som har null —
 * og vaskedelen er i tillegg korrigert for appens andel («Royalty vask
 * korr for andel app», BP25 `Budget`-arket). Den korreksjonen står ikke
 * i tallene vi leser.
 *
 * Førsteforsøket trakk 60 % av vaskemarginen fra og delte resten på
 * ordinært salg. Det ga 6,70 % → 9,27 % der avtalen sier 7,75 % → 10,00 %.
 * Feil i samme retning begge år, altså et systematisk fradrag som er for
 * stort — og et tall med to desimaler som ser like sikkert ut som et
 * riktig ett.
 *
 * Den blandede andelen er derimot eksakt, og den er nok til å svare på
 * spørsmålet: hva koster den nye BP-en oss? Se `royaltyEndring()`.
 *
 * Vær oppmerksom på at andelen også kan flytte seg av varemiks, siden
 * vask har en langt høyere sats enn butikk. `royaltyEndring()` skiller
 * volum fra sats, og miksen ligger inne i satsleddet.
 */
export function royaltyandel(t: Aarstall): number | null {
  if (t.salg <= 0) return null
  return t.royalty / t.salg
}

export type RoyaltyEndring = {
  /** Kroner mer royalty fordi omsetningen vokser, med fjorårets andel. */
  volum: number
  /** Kroner mer royalty fordi andelen selv har flyttet seg. */
  sats: number
  /** Faktisk endring i kroner. `volum + sats` skal treffe denne. */
  totalt: number
  fjorAndel: number
  aarAndel: number
}

/**
 * Deler endringen i royalty i to: den delen som følger av at dere selger
 * mer, og den delen som følger av at St1 tar en større andel.
 *
 * Den første er prisen på vekst og er i orden. Den andre er ren kostnad,
 * og det er den Robert spør om når han spør «går vi opp i royalty?».
 */
export function royaltyEndring(fjor: Aarstall, iAar: Aarstall): RoyaltyEndring | null {
  const a = royaltyandel(fjor)
  const b = royaltyandel(iAar)
  if (a === null || b === null) return null
  return {
    volum: a * (iAar.salg - fjor.salg),
    sats: (b - a) * iAar.salg,
    totalt: iAar.royalty - fjor.royalty,
    fjorAndel: a,
    aarAndel: b,
  }
}

/** Er de to kontoplanene like nok til at en linje-for-linje-diff betyr noe? */
function kontiSammenlignbare(a: Aarstall, b: Aarstall): boolean {
  const koderA = new Set(a.konti.keys())
  const koderB = new Set(b.konti.keys())
  if (!koderA.size || !koderB.size) return false
  let felles = 0
  for (const k of koderA) if (koderB.has(k)) felles++
  return felles / Math.min(koderA.size, koderB.size) >= 0.5
}

/**
 * Funnene, i den rekkefølgen en regnskapsfører ville lest dem: det som
 * er avtalt og ikke kan påvirkes først, så rammene, så målene.
 */
export function analyser(fjor: Aarstall, iAar: Aarstall): Funn[] {
  const funn: Funn[] = []
  const kostF = fjor.personal + fjor.andreKostnader
  const kostI = iAar.personal + iAar.andreKostnader

  // ---- 1. ROYALTYEN --------------------------------------------------
  // Den viktigste enkeltlinja: den er avtalt, den kan ikke jobbes inn,
  // og den treffer hver eneste krone av omsetningen.
  const roy = royaltyEndring(fjor, iAar)
  if (roy && Math.abs(roy.sats) > 1000) {
    const opp = roy.sats > 0
    funn.push({
      id: 'royalty',
      alvor: 'viktig',
      dom: opp ? 'vond' : 'god',
      tittel: `Royaltyandelen ${opp ? 'stiger' : 'faller'} fra ${p2(roy.fjorAndel * 100)} % til ${p2(roy.aarAndel * 100)} % av omsetningen`,
      maalt: `Royalty ${kr(fjor.royalty)} → ${kr(iAar.royalty)} kr. Av økningen skyldes ${kr(roy.volum)} kr at dere selger mer, og ${kr(roy.sats)} kr at andelen selv har flyttet seg.`,
      betyr: opp
        ? `De ${kr(roy.sats)} kronene er ren kostnad — de kommer ikke av at dere gjør noe annerledes, og de kan ikke jobbes inn. Til sammenligning endret hele kostnadsrammen seg med ${kr(kostI - kostF)} kr.`
        : `De ${kr(Math.abs(roy.sats))} kronene er penger dere beholder uten å gjøre noe annerledes.`,
      kroner: roy.sats,
      kilde: 'royalty delt på CR-salg, endringen delt i volum og andel',
    })
  }

  // ---- 2. LØNNSRAMMEN ----------------------------------------------
  // Timer og timepris er BEGGE penger St1 legger inn. En hoyere timepris
  // er ikke en dyrere time dere betaler - det er mer per time i ramma.
  const dLonn = pst(iAar.personal, fjor.personal)
  if (dLonn !== null) {
    const harTimer = fjor.timer > 0 && iAar.timer > 0
    const dt = harTimer ? pst(iAar.timer, fjor.timer)! : null
    const kf = harTimer ? fjor.personal / fjor.timer : 0
    const ki = harTimer ? iAar.personal / iAar.timer : 0
    const dk = harTimer ? pst(ki, kf)! : null
    funn.push({
      id: 'lonnsramme',
      alvor: Math.abs(dLonn) >= 2 ? 'viktig' : 'info',
      dom: dt !== null && dk !== null
        ? (dt >= 0 && dk >= 0 ? 'god' : dt < 0 && dk < 0 ? 'vond' : undefined)
        : (dLonn >= 0 ? 'god' : 'vond'),
      tittel: `Lønnsrammen ${dLonn >= 0 ? 'øker' : 'faller'} ${p1(dLonn)}`,
      maalt: dt !== null && dk !== null
        ? `${p1(dt)} timer (${kr(iAar.timer - fjor.timer)} t) og ${p1(dk)} i kroner per time (${kr(ki - kf)} kr).`
        : `${kr(iAar.personal - fjor.personal)} kr. Timerammen står ikke i begge årganger, så kroner per time kan ikke leses.`,
      betyr: dt !== null && dk !== null && dt >= 0 && dk >= 0
        ? `Begge deler er ramme dere har fått: flere timer å bemanne med, og mer per time. De to ganger hverandre — ${(1 + dt / 100).toFixed(3)} × ${(1 + dk / 100).toFixed(3)} — så vekst i kroner er ikke det samme som vekst i bemanning.`
        : dt !== null && dt < 0
        ? `Færre timer å bemanne med. Sjekk om stengte timer per døgn er endret i delingsfila — det er den største enkeltposten i timeberegningen.`
        : `Rammen sier hvor mye lønn budsjettet bærer. Uten timetallet ved siden av kan den ikke skilles i «flere folk» og «dyrere folk», og det er den forskjellen som avgjør om bemanningen faktisk økte.`,
      kroner: iAar.personal - fjor.personal,
      kilde: harTimer ? 'konti 5xxx og timebudsjettet' : 'konti 5xxx',
    })
  }

  // ---- 3. VOKSER KOSTNADENE RASKERE ENN SALGET? --------------------
  const ds = pst(iAar.salg, fjor.salg)
  const dkost = pst(kostI, kostF)
  if (ds !== null && dkost !== null) {
    const klem = dkost - ds
    funn.push({
      id: 'marginklem',
      alvor: Math.abs(klem) >= 1.5 ? 'viktig' : 'info',
      tittel: klem > 0
        ? `Kostnadsrammen vokser ${p2(klem).replace(',00', '')} prosentpoeng raskere enn salgsmålet`
        : `Salgsmålet vokser ${p2(Math.abs(klem)).replace(',00', '')} prosentpoeng raskere enn kostnadsrammen`,
      maalt: `Salg ${p1(ds)}, kostnader ${p1(dkost)} (${kr(kostF)} → ${kr(kostI)} kr).`,
      betyr: klem > 0
        ? `Rammen er romsligere, men marginen skal bære mer. Treffer dere salgsmålet nøyaktig og bruker hele rammen, sitter dere igjen med mindre enn i fjor.`
        : `Rammen er strammere enn salgsmålet. Treffer dere begge, går marginen opp — men det forutsetter at kostnadene faktisk holdes innenfor.`,
      kilde: 'CR-salg mot sum lønn og andre driftskostnader',
    })
  }

  // ---- 4. HVOR LIGGER VEKSTEN, OG HVA KUTTES? ----------------------
  // NØKLET PÅ KODE. Navnene endrer seg mellom årganger.
  const kat: { kode: string; post: string; f: number; i: number; d: number }[] = []
  for (const kode of new Set([...fjor.kategorier.keys(), ...iAar.kategorier.keys()])) {
    const a = fjor.kategorier.get(kode)
    const b = iAar.kategorier.get(kode)
    kat.push({
      kode, post: b?.post ?? a?.post ?? kode,
      f: a?.salg ?? 0, i: b?.salg ?? 0, d: (b?.salg ?? 0) - (a?.salg ?? 0),
    })
  }
  const vekst = kat.filter((k) => k.d > 0).reduce((a, k) => a + k.d, 0)
  const topp = kat.filter((k) => k.d > 0).sort((a, b) => b.d - a.d).slice(0, 3)
  if (vekst > 0 && topp.length) {
    const andel = topp.reduce((a, k) => a + k.d, 0) / vekst * 100
    funn.push({
      id: 'vekstkonsentrasjon',
      alvor: andel >= 70 ? 'merk' : 'info',
      tittel: `${Math.round(andel)} % av salgsveksten ligger i ${topp.length} ${topp.length === 1 ? 'varegruppe' : 'varegrupper'}`,
      maalt: topp.map((k) => `${k.post} ${k.f > 0 ? p1(pst(k.i, k.f)!) : 'ny'} (${kr(k.d)} kr)`).join(', ') + '.',
      betyr: andel >= 70
        ? `Veksten er konsentrert. Bommer dere på disse, bommer dere på hele året — og de er verdt å følge tettere enn resten.`
        : `Veksten er spredt over flere varegrupper, så et bomskudd på én av dem velter ikke året.`,
      kroner: topp.reduce((a, k) => a + k.d, 0),
      kilde: 'salg per varegruppe, budsjett mot budsjett',
    })
  }
  const kuttet = kat.filter((k) => k.f > 0 && k.d < 0 && Math.abs(k.d) / k.f > 0.05)
    .sort((a, b) => a.d - b.d)
  if (kuttet.length) {
    funn.push({
      id: 'kuttede-grupper',
      alvor: 'merk',
      tittel: `${kuttet.length} ${kuttet.length === 1 ? 'varegruppe' : 'varegrupper'} er budsjettert ned`,
      maalt: kuttet.slice(0, 4).map((k) => `${k.post} ${p1(pst(k.i, k.f)!)}`).join(', ') + '.',
      betyr: `St1 forventer nedgang her. Er det ikke det dere ser i butikken, er budsjettet satt for lavt — og da blir avviket positivt uten at noe er gjort bedre.`,
      kroner: kuttet.reduce((a, k) => a + k.d, 0),
      kilde: 'salg per varegruppe, kutt over 5 %',
    })
  }

  // ---- 5. KONTOPLANEN ----------------------------------------------
  // En linje-for-linje-diff er bare informasjon når de to årgangene
  // fører kostnadene på samme måte. Gjør de ikke det, er «38 nye og 17
  // borte» ikke et funn — det er to ulike maler som ser ut som en endring.
  if (kontiSammenlignbare(fjor, iAar)) {
    const nye = [...iAar.konti].filter(([k]) => !fjor.konti.has(k))
    const borte = [...fjor.konti].filter(([k]) => !iAar.konti.has(k))
    if (nye.length || borte.length) {
      funn.push({
        id: 'kontoplan',
        alvor: 'merk',
        tittel: `Kontoplanen er endret: ${nye.length} nye, ${borte.length} borte`,
        maalt: [
          nye.length ? `Nye: ${nye.slice(0, 4).map(([, v]) => v.post).join(', ')}` : '',
          borte.length ? `Borte: ${borte.slice(0, 4).map(([, v]) => v.post).join(', ')}` : '',
        ].filter(Boolean).join('. ') + '.',
        betyr: `En linje som forsvinner mellom to år er lett å overse. Sjekk om kostnaden er borte, eller om den bare har flyttet til en annen konto — det siste er langt vanligere.`,
        kilde: 'kostnadskonti i de to årgangene',
      })
    }
  } else if (fjor.konti.size && iAar.konti.size) {
    funn.push({
      id: 'kontoplan-omlagt',
      alvor: 'info',
      tittel: `Kontoplanen er lagt om: ${fjor.konti.size} konti i ${fjor.ar}, ${iAar.konti.size} i ${iAar.ar}`,
      maalt: `Under halvparten av kontoene finnes i begge årganger.`,
      betyr: `De to budsjettene fører kostnadene på hver sin måte, så en linje-for-linje-sammenligning ville vist forskjeller som bare er ulik oppdeling. Totalene og lønnsrammen kan sammenlignes; enkeltkonti kan det ikke.`,
      kilde: 'kontokoder i de to årgangene',
    })
  }

  return funn
}
