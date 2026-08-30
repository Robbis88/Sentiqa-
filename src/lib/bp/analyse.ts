import type { BpResultat, BpStasjon } from '@/lib/parsere/typer'

// =====================================================================
// HVA BETYR DEN NYE BP-EN FOR OSS?
//
// En BP er ikke et resultat. Den er en ramme St1 setter, og den sier tre
// ting samtidig: hva dere skal selge, hva dere får bruke, og hva St1 tar.
// Denne fila leser de tre ut av to årganger og sier hva som er endret.
//
// «vil du skal analysere hele BP og oppføre deg som den beste
//  regnskapsføreren» — Robert 2026-08-29
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

export type Aarstall = {
  ar: number
  salg: number
  varekost: number
  brutto: number
  timelonn: number
  fastlonn: number
  andreKostnader: number
  royalty: number
  timer: number
  /** Salg per varegruppe, summert over året. */
  kategorier: Map<string, number>
  /** Kostnad per konto, summert over året. */
  konti: Map<string, number>
}

// Royaltykonto i St1s kontoplan. Varekost og salg er ikke kostnader i
// denne sammenhengen - de er egne ledd i regnestykket.
const ROYALTY = '6312'
const FSA = '6315'
const TIMELONN = '5012'
const FASTLONN = '5010'

/** Summerer en BP-årgang til de tallene analysen trenger. */
export function summer(bp: BpResultat, butikknumre?: string[]): Aarstall {
  const med = (s: BpStasjon) => !butikknumre || butikknumre.includes(s.butikknummer)
  const stasjoner = bp.stasjoner.filter(med)

  const t: Aarstall = {
    ar: bp.ar ?? 0,
    salg: 0, varekost: 0, brutto: 0, timelonn: 0, fastlonn: 0,
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
        t.kategorier.set(k.post, (t.kategorier.get(k.post) ?? 0) + k.salgKr)
      }
      for (const k of m.konti) {
        if (k.kode === ROYALTY) { t.royalty += k.belopKr; continue }
        // FSA staar negativt og er ikke en driftskostnad - den er
        // avtalens utjevning. Tas den med i kostnadsramma, ser rammen
        // mindre ut enn den er.
        if (k.kode === FSA) continue
        if (k.kode === TIMELONN || k.kode === FASTLONN) continue
        t.konti.set(k.post, (t.konti.get(k.post) ?? 0) + k.belopKr)
        t.andreKostnader += k.belopKr
      }
    }
  }
  return t
}

const pst = (b: number, f: number) => (f === 0 ? null : (b / f - 1) * 100)
const kr = (n: number) => Math.round(n).toLocaleString('nb-NO')
// Desimalkomma, ikke punktum. `toFixed` gir punktum uansett locale.
const p1 = (x: number) =>
  (x >= 0 ? '+' : '−') + Math.abs(x).toFixed(1).replace('.', ',') + ' %'

/**
 * Royaltysatsen, lest ut av tallene.
 *
 * Den STÅR ikke som en sats noe sted vi kan lese direkte, men den lar seg
 * regne: royaltyen er en prosent av ordinært salg pluss en andel av
 * vaskemarginen. Bekreftet mot Kelsars filer på krona i begge år —
 * 10 % × 59 346 575 + 4 090 433 = 10 025 091, som er nøyaktig det fila
 * oppgir.
 *
 * Vask og pant holdes utenfor: de har egne satser (60 % og 0 %), og tas
 * de med i nevneren, blir den samlede satsen et blandingstall som ikke
 * kan sammenlignes mellom år der vaskeandelen har flyttet seg.
 */
export function royaltysats(t: Aarstall): number | null {
  let ordinaert = 0
  for (const [post, kr2] of t.kategorier) {
    if (/vask/i.test(post) || /pant/i.test(post)) continue
    ordinaert += kr2
  }
  if (ordinaert <= 0) return null
  let vaskeroyalty = 0
  for (const [post, kr2] of t.kategorier) {
    if (/vask/i.test(post)) vaskeroyalty += kr2
  }
  // Vaskeroyaltyen kjenner vi ikke direkte per aar; den delen av
  // royaltyen som IKKE forklares av ordinaert salg tilskrives vask.
  // Naar vaskeomsetningen er null, er hele royaltyen ordinaer.
  if (vaskeroyalty === 0) return t.royalty / ordinaert
  return null
}

/**
 * Funnene, i den rekkefølgen en regnskapsfører ville lest dem: det som
 * er avtalt og ikke kan påvirkes først, så rammene, så målene.
 */
export function analyser(fjor: Aarstall, iAar: Aarstall): Funn[] {
  const funn: Funn[] = []

  // ---- 1. ROYALTYSATSEN --------------------------------------------
  // Den viktigste enkeltlinja: den er avtalt, den kan ikke jobbes inn,
  // og den treffer hver eneste krone av omsetningen.
  const sf = royaltysats(fjor)
  const si = royaltysats(iAar)
  if (sf !== null && si !== null && Math.abs(si - sf) > 0.0005) {
    let ordinaert = 0
    for (const [post, x] of iAar.kategorier) {
      if (!/vask|pant/i.test(post)) ordinaert += x
    }
    const effekt = ordinaert * (si - sf)
    funn.push({
      id: 'royaltysats',
      alvor: 'viktig',
      dom: si > sf ? 'vond' : 'god',
      tittel: `Royaltysatsen er ${si > sf ? 'hevet' : 'satt ned'} fra ${(sf * 100).toFixed(2).replace('.', ',')} % til ${(si * 100).toFixed(2).replace('.', ',')} %`,
      maalt: `${(Math.abs(si - sf) * 100).toFixed(2).replace('.', ',')} prosentpoeng på ${kr(ordinaert)} kr i ordinær omsetning.`,
      betyr: si > sf
        ? `Det koster ${kr(Math.abs(effekt))} kr i året, og det er ikke noe dere kan jobbe inn — satsen treffer hver krone dere selger. Til sammenligning: hele kostnadsrammen endret seg med ${kr(Math.abs(iAar.andreKostnader + iAar.timelonn + iAar.fastlonn - (fjor.andreKostnader + fjor.timelonn + fjor.fastlonn)))} kr.`
        : `Det gir ${kr(Math.abs(effekt))} kr mer å sitte igjen med i året, uten at dere trenger å gjøre noe annerledes.`,
      kroner: effekt,
      kilde: 'royalty delt på ordinær omsetning, vask og pant holdt utenfor',
    })
  }

  // ---- 2. LØNNSRAMMEN ----------------------------------------------
  // Timer og timepris er BEGGE penger St1 legger inn. En hoyere timepris
  // er ikke en dyrere time dere betaler - det er mer per time i ramma.
  if (fjor.timer > 0 && iAar.timer > 0) {
    const dt = pst(iAar.timer, fjor.timer)!
    const kf = fjor.timelonn / fjor.timer
    const ki = iAar.timelonn / iAar.timer
    const dk = pst(ki, kf)!
    funn.push({
      id: 'timeramme',
      alvor: Math.abs(dt) >= 2 || Math.abs(dk) >= 2 ? 'viktig' : 'info',
      dom: dt >= 0 && dk >= 0 ? 'god' : dt < 0 && dk < 0 ? 'vond' : undefined,
      tittel: `Lønnsrammen ${iAar.timelonn >= fjor.timelonn ? 'øker' : 'faller'} ${p1(pst(iAar.timelonn, fjor.timelonn)!)}`,
      maalt: `${p1(dt)} timer (${kr(iAar.timer - fjor.timer)} t) og ${p1(dk)} i timepris (${kr(ki - kf)} kr).`,
      betyr: dt >= 0 && dk >= 0
        ? `Begge deler er ramme dere har fått: flere timer å bemanne med, og mer per time. De to ganger hverandre — ${(1 + dt / 100).toFixed(3)} × ${(1 + dk / 100).toFixed(3)} — så veksten i kroner er ikke det samme som vekst i bemanning.`
        : dt < 0
        ? `Færre timer å bemanne med. Sjekk om stengte timer per døgn er endret i delingsfila — det er den største enkeltposten i timeberegningen.`
        : `Timeprisen faller, så hver time gir mindre å rekruttere for. Timetallet alene sier da for lite om hva dere faktisk kan bemanne.`,
      kroner: iAar.timelonn - fjor.timelonn,
      kilde: 'timebudsjett og konto 5012 timelønn',
    })
  }

  // ---- 3. VOKSER KOSTNADENE RASKERE ENN SALGET? --------------------
  // Klassisk marginklem. Den sier ikke at noe er galt, men den sier hva
  // aaret krever: enten mer volum, eller mindre forbruk enn ramma.
  const ds = pst(iAar.salg, fjor.salg)
  const kostF = fjor.andreKostnader + fjor.timelonn + fjor.fastlonn
  const kostI = iAar.andreKostnader + iAar.timelonn + iAar.fastlonn
  const dkost = pst(kostI, kostF)
  if (ds !== null && dkost !== null) {
    const klem = dkost - ds
    funn.push({
      id: 'marginklem',
      alvor: Math.abs(klem) >= 1.5 ? 'viktig' : 'info',
      tittel: klem > 0
        ? `Kostnadsrammen vokser ${klem.toFixed(1).replace('.', ',')} prosentpoeng raskere enn salgsmålet`
        : `Salgsmålet vokser ${Math.abs(klem).toFixed(1).replace('.', ',')} prosentpoeng raskere enn kostnadsrammen`,
      maalt: `Salg ${p1(ds)}, kostnader ${p1(dkost)}.`,
      betyr: klem > 0
        ? `Rammen er romsligere, men marginen skal bære mer. Treffer dere salgsmålet nøyaktig og bruker hele rammen, sitter dere igjen med mindre enn i fjor.`
        : `Rammen er strammere enn salgsmålet. Treffer dere begge, går marginen opp — men det forutsetter at kostnadene faktisk holdes innenfor.`,
      kilde: 'CR-salg mot sum lønn og andre driftskostnader',
    })
  }

  // ---- 4. HVOR LIGGER VEKSTEN, OG HVA KUTTES? ----------------------
  const kat: { post: string; f: number; i: number; d: number }[] = []
  for (const post of new Set([...fjor.kategorier.keys(), ...iAar.kategorier.keys()])) {
    const f = fjor.kategorier.get(post) ?? 0
    const i = iAar.kategorier.get(post) ?? 0
    kat.push({ post, f, i, d: i - f })
  }
  const vekst = kat.filter((k) => k.d > 0).reduce((a, k) => a + k.d, 0)
  const topp = kat.filter((k) => k.d > 0).sort((a, b) => b.d - a.d).slice(0, 3)
  if (vekst > 0 && topp.length) {
    const andel = topp.reduce((a, k) => a + k.d, 0) / vekst * 100
    funn.push({
      id: 'vekstkonsentrasjon',
      alvor: andel >= 70 ? 'merk' : 'info',
      tittel: `${Math.round(andel)} % av salgsveksten ligger i ${topp.length} varegrupper`,
      maalt: topp.map((k) => `${k.post} ${p1(pst(k.i, k.f) ?? 0)}`).join(', ') + '.',
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

  // ---- 5. STRUKTURENDRINGER I KONTOPLANEN --------------------------
  // Det som forsvinner er lettest aa overse, og ofte det viktigste.
  const nye = [...iAar.konti.keys()].filter((k) => !fjor.konti.has(k))
  const borte = [...fjor.konti.keys()].filter((k) => !iAar.konti.has(k))
  if (nye.length || borte.length) {
    funn.push({
      id: 'kontoplan',
      alvor: 'merk',
      tittel: `Kontoplanen er endret: ${nye.length} nye, ${borte.length} borte`,
      maalt: [
        nye.length ? `Nye: ${nye.slice(0, 4).join(', ')}` : '',
        borte.length ? `Borte: ${borte.slice(0, 4).join(', ')}` : '',
      ].filter(Boolean).join('. ') + '.',
      betyr: `En linje som forsvinner mellom to år er lett å overse. Sjekk om kostnaden er borte, eller om den bare har flyttet til en annen konto — det siste er langt vanligere.`,
      kilde: 'kostnadskonti i de to årgangene',
    })
  }

  return funn
}
