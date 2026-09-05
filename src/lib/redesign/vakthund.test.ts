import { readFileSync, readdirSync, writeFileSync, existsSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, test } from 'vitest'
import {
  borte, borteI, lenker, naabarhet, rutenavn, rutetre, seksjoner, serverhandlinger,
  uregistrert, uregistrertI,
  type Fasit,
} from './fasit'
import { MONSTRE, RUTEMONSTER, TABLETRUTER } from './monstre'
import { FLYTTEDE_SEKSJONER, OMSKREVNE_SEKSJONER } from './flyttet'
import { utenKommentarer } from './design'

// =====================================================================
// Vakthund for redesignet.
//
// «Ingen funksjoner skal forsvinne» er hovedkravet i bestillingen, og
// et løfte er ikke en garanti. Denne leser kildekoden, bygger fasit paa
// nytt, og feiler hvis noe er borte.
//
// Den forbyr ikke endring. Skal noe faktisk fjernes eller slaas sammen,
// oppdaterer du fasiten med vilje:
//
//     OPPDATER_FASIT=1 npx vitest run src/lib/redesign
//
// Da viser git nøyaktig hva som ble gitt slipp paa. Forskjellen paa aa
// FLYTTE noe og aa MISTE det, er om noen skrev det ned.
// =====================================================================

const ROT = process.cwd()
const APP = join(ROT, 'src', 'app')
const FASIT = join(ROT, 'src', 'lib', 'redesign', 'fasit.json')

function filer(mappe: string, treff: (n: string) => boolean): string[] {
  const ut: string[] = []
  for (const rad of readdirSync(mappe, { withFileTypes: true })) {
    const sti = join(mappe, rad.name)
    if (rad.isDirectory()) ut.push(...filer(sti, treff))
    else if (treff(rad.name)) ut.push(sti)
  }
  return ut
}

function byggFasit(): Fasit {
  const sider = filer(APP, (n) => n === 'page.tsx')
  const ruter = sider.map(rutenavn).sort()

  // EN LESING PER FIL. Komponenter deles mellom ruter - `oppmerksomhet`
  // rendres av begge dashbordene - og uten hurtigbufferen leses de om
  // igjen for hver rute som naar dem.
  const buffer = new Map<string, string | null>()
  const les = (sti: string): string | null => {
    if (!buffer.has(sti)) {
      try { buffer.set(sti, readFileSync(sti, 'utf8')) }
      catch { buffer.set(sti, null) }
    }
    return buffer.get(sti) ?? null
  }

  const seksjonKart: Record<string, string[]> = {}
  const lenkeKart: Record<string, string[]> = {}
  for (const sti of sider) {
    const rute = rutenavn(sti)

    // SEKSJONENE LESES AV HELE RUTENS UI-TRE, ikke bare page.tsx.
    // /produksjonsplan har hele plantabellen i en klientkomponent; den
    // var usynlig for vakten fram til trinn 08.
    const treet = rutetre(sti, les, APP)
    const s = [...new Set(treet.flatMap((f) => seksjoner(les(f) ?? '')))].sort()

    // LENKENE LESES FORTSATT BARE AV page.tsx. Det er ikke glemt: en
    // delt komponent tar med seg lenkene sine til hver rute som rendrer
    // den, og navigasjonsveiene ut av en side ville da blitt en liste
    // over alt appskallet og dashbordkortene peker paa. Skal de
    // utvides, er det en egen vurdering med egen begrunnelse.
    const l = lenker(les(sti) ?? '')

    if (s.length > 0) seksjonKart[rute] = s
    if (l.length > 0) lenkeKart[rute] = l
  }

  // Serverhandlinger samles per MAPPE, ikke per side: de ligger i egne
  // filer og deles ofte av flere sider under samme omraade.
  const handlingKart: Record<string, string[]> = {}
  for (const sti of filer(APP, (n) => n.endsWith('.ts') && !n.includes('.test.'))) {
    const funksjoner = serverhandlinger(readFileSync(sti, 'utf8'))
    if (funksjoner.length === 0) continue
    const omraade = rutenavn(sti.replace(/[^\\/]+$/, 'page.tsx'))
    handlingKart[omraade] = [...(handlingKart[omraade] ?? []), ...funksjoner].sort()
  }

  return {
    ruter,
    naabart: naabarhet(readFileSync(join(APP, '(beskyttet)', 'navigasjon.ts'), 'utf8')),
    handlinger: handlingKart,
    seksjoner: seksjonKart,
    lenker: lenkeKart,
  }
}

const naa = byggFasit()

if (process.env.OPPDATER_FASIT) {
  writeFileSync(FASIT, `${JSON.stringify(naa, null, 2)}\n`, 'utf8')
}

const fasit: Fasit | null = existsSync(FASIT)
  ? JSON.parse(readFileSync(FASIT, 'utf8')) as Fasit
  : null

const hjelp = 'Er dette meningen, kjør: OPPDATER_FASIT=1 npx vitest run src/lib/redesign '
  + '— og la diffen i git vise hva som ble gitt slipp på.'

describe('funksjonsbevaring', () => {
  test('fasiten finnes', () => {
    expect(fasit, 'Fasit mangler. Lag den med OPPDATER_FASIT=1.').not.toBeNull()
  })

  // --- HARDT: dette skal aldri forsvinne i stillhet ---

  test('ingen rute er borte', () => {
    expect(borte(fasit!.ruter, naa.ruter), `Ruter borte. ${hjelp}`).toEqual([])
  })

  test('ingen rolle har mistet tilgang til en side', () => {
    // Maalt paa NAABARHET, ikke paa menylinjer: aa flytte en side fra
    // menyen til en fane er en omorganisering, aa ta den ut av begge er
    // et tap. En fasit som teller menylinjer ville ropt paa det forste
    // og vaert blind for forskjellen.
    expect(borteI(fasit!.naabart, naa.naabart), `Noen mistet tilgang. ${hjelp}`)
      .toEqual({})
  })

  test('ingen serverhandling er borte', () => {
    // En knapp kan flyttes til et sidepanel uten tap. Blir handlingen
    // bak den borte, er en evne borte.
    expect(borteI(fasit!.handlinger, naa.handlinger), `Handlinger borte. ${hjelp}`)
      .toEqual({})
  })

  // --- HARDT DEN ANDRE VEIEN: et tillegg skal skrives ned ---
  //
  // ET VERN SOM BARE GJELDER DET NOEN HUSKET Å FØRE OPP, GJELDER IKKE.
  //
  // De tre testene over feller det som FORSVINNER. Fram til 2026-09-05
  // sa ingen fra om det motsatte, og da hadde det samlet seg opp: en hel
  // rute (`/ukebrief`) med to serverhandlinger, pluss `endreStasjoner`,
  // `settSkiftFraSats`, `settOpplaeringsmerke` og `lagreNotat` — alle
  // uregistrerte, alle helt i orden.
  //
  // Ingen av dem var en feil. Feilen var at de kunne slettes igjen uten
  // at noe ble rødt: en rute som ikke står i fasiten, er en rute ingen
  // ville savnet. Vernet slo altså inn først når noen husket på det.
  //
  // Prisen for å lukke det er én kommando ved hver ny rute, rolle eller
  // serverhandling. Det er billigere enn å finne ut at vakten aldri
  // gjaldt den ene tingen man trengte den til.
  //
  // BARE DE TRE HARDE. Seksjoner og lenker måles fortsatt mykt: de
  // endres i hver eneste UI-endring, og en rød CI på hver overskrift
  // ville lært folk å regenerere i blinde — og da hadde `borte`-testene
  // sluttet å bety noe også.

  test('ingen rute er uregistrert', () => {
    expect(uregistrert(fasit!.ruter, naa.ruter), `Nye ruter mangler i fasiten. ${hjelp}`)
      .toEqual([])
  })

  test('ingen ny rolletilgang er uregistrert', () => {
    // Å GI tilgang er like mye en endring som å ta den. En rolle som
    // stille fikk en side, sto uten et eneste spor av at noen valgte det.
    expect(uregistrertI(fasit!.naabart, naa.naabart), `Ny tilgang mangler i fasiten. ${hjelp}`)
      .toEqual({})
  })

  test('ingen serverhandling er uregistrert', () => {
    expect(
      uregistrertI(fasit!.handlinger, naa.handlinger),
      `Nye handlinger mangler i fasiten. ${hjelp}`,
    ).toEqual({})
  })

  // KANARIFUGL FOR RETNINGEN SELV.
  //
  // De tre testene over er grønne både når de virker og når de har
  // sluttet å se — det er hele problemet med en vakt. Denne beviser at
  // sammenligningen faktisk peker den nye veien, ved å legge inn noe som
  // ikke står i fasiten og kreve at det kommer ut.
  //
  // Blir `uregistrert` en dag skrevet om til `borte`, blir denne rød og
  // ikke de andre.
  //
  // HELT SYNTETISKE INNDATA, med vilje. Leste den `naa` og `fasit`,
  // ville den blitt rød hver gang noen la til noe uten å regenerere —
  // altså av samme grunn som testene over — og da beviste den ingenting
  // om retningen. Den skal si én ting: at sammenligningen peker riktig
  // vei.
  test('KANARIFUGL: retningen fanger et tillegg som ikke er ført opp', () => {
    expect(uregistrert(['/a'], ['/a', '/b'])).toEqual(['/b'])
    expect(uregistrertI({ '/x': ['en'] }, { '/x': ['en', 'to'] })).toEqual({ '/x': ['to'] })

    // Og den skal IKKE forveksles med `borte`: et tap er ikke et tillegg.
    expect(uregistrert(['/a', '/b'], ['/a'])).toEqual([])
    expect(uregistrertI({ '/x': ['en', 'to'] }, { '/x': ['en'] })).toEqual({})
  })

  // --- MYKT: skal endres, men ikke umerket ---

  // -------------------------------------------------------------------
  // Flytting er ikke tap — men det må bevises, ikke påstås.
  // -------------------------------------------------------------------

  /**
   * Hele UI-treet for en rute, som én streng, UTEN kommentarer.
   *
   * Kommentarene må vekk, ellers leser vakten sin egen dokumentasjon som
   * kode. Første utgave felte `/oversikt` for å «rendre VekstKort
   * fortsatt» — treffet lå i en kommentar i tablet-hero.tsx som forklarte
   * hvorfor komponenten var flyttet vekk. En vakt som ikke skiller kode
   * fra prosa, straffer den som skriver ned hvorfor.
   */
  function kildeForRute(rute: string): string {
    const sti = filer(APP, (n) => n === 'page.tsx').find((f) => rutenavn(f) === rute)
    if (!sti) return ''
    const buffer = new Map<string, string | null>()
    const les = (p: string) => {
      if (!buffer.has(p)) {
        try { buffer.set(p, readFileSync(p, 'utf8')) } catch { buffer.set(p, null) }
      }
      return buffer.get(p) ?? null
    }
    return rutetre(sti, les, APP).map((f) => utenKommentarer(les(f) ?? '')).join('\n')
  }

  test('flyttede seksjoner er flyttet, ikke tapt', () => {
    // FEM KRAV PER RAD. Erklæringen i flyttet.ts er en påstand; dette er
    // forsøket på å motbevise den. Holder ikke ett av kravene, feller
    // vakten HER — på erklæringen — i stedet for å la den dekke over noe.
    const brudd: string[] = []
    const tabletRuter = new Set(naa.naabart['butikkbruker_tablet'] ?? [])

    for (const f of FLYTTEDE_SEKSJONER) {
      const merke = `${f.seksjon} (${f.fra} → ${f.til})`

      // 1. Borte fra der den sto. Ellers er ingenting flyttet, og
      //    erklæringen skjuler en dublett i stedet for en flytting.
      if ((naa.seksjoner[f.fra] ?? []).includes(f.seksjon)) {
        brudd.push(`${merke}: står fortsatt på ${f.fra} — dette er ikke en flytting`)
      }

      // 2. Finnes der den skal være. Dette er hele forskjellen på flyttet
      //    og slettet.
      if (!(naa.seksjoner[f.til] ?? []).includes(f.seksjon)) {
        brudd.push(`${merke}: finnes ikke på ${f.til} — da er den TAPT, ikke flyttet`)
      }

      // 3. Samme capability. Komponenten som bar seksjonen skal ha fulgt
      //    med — ikke blitt skrevet om til noe som ligner.
      const tilKilde = kildeForRute(f.til)
      if (!tilKilde.includes(f.komponent)) {
        brudd.push(`${merke}: ${f.til} rendrer ikke ${f.komponent} — capabilityen fulgte ikke med`)
      }
      if (kildeForRute(f.fra).includes(f.komponent)) {
        brudd.push(`${merke}: ${f.fra} rendrer fortsatt ${f.komponent}`)
      }

      // 4. Samme rolle. Den som så seksjonen før, skal se den nå.
      //    Nettbrettet er den eneste rollen som når begge rutene.
      if (!tabletRuter.has(f.fra) || !tabletRuter.has(f.til)) {
        brudd.push(`${merke}: nettbrettet når ikke begge rutene — rollen fulgte ikke med`)
      }

      // 5. Navigerbar. En flate ingen kommer til, er ikke en flytting —
      //    det er en gjemmeleik. Dette er den lumske av de fem.
      //
      //    LEST AV HELE TREET, ikke av `naa.lenker`. Det kartet leser
      //    bare page.tsx, med god grunn (se byggFasit): en delt komponent
      //    ville dratt appskallets lenker inn på hver eneste rute. Men
      //    nettbrettets vei til «Vår stasjon» ligger nettopp i en
      //    komponent — tablet-hjem.tsx — og et krav som bare så page.tsx
      //    ville felt en lenke som står der og virker.
      if (!kildeForRute(f.naaddFra).includes(`"${f.til}"`)) {
        brudd.push(`${merke}: ${f.naaddFra} lenker ikke til ${f.til} — ingen kommer dit`)
      }
    }

    expect(brudd, `\n  ${brudd.join('\n  ')}\n`).toEqual([])
  })

  test('omskrevne seksjoner står på samme rute', () => {
    // Strengere enn en flytting: her har ingenting flyttet seg, bare
    // uttrykket vakten leser navnet ut av. Da må BEGGE navnene høre til
    // samme rute — det gamle borte, det nye på plass.
    const brudd: string[] = []
    for (const o of OMSKREVNE_SEKSJONER) {
      const paaRuta = naa.seksjoner[o.rute] ?? []
      if (paaRuta.includes(o.fra)) {
        brudd.push(`${o.fra}: står fortsatt på ${o.rute} — ingenting er skrevet om`)
      }
      if (!paaRuta.includes(o.til)) {
        brudd.push(`${o.fra} → ${o.til}: ${o.til} finnes ikke på ${o.rute} — dette er et tap`)
      }
    }
    expect(brudd, `\n  ${brudd.join('\n  ')}\n`).toEqual([])
  })

  test('ingen seksjon er borte uten at det er erklært', () => {
    // ERKLÆRINGEN ER IKKE ET FRITAK, og det er verdt å si tydelig.
    //
    // Fasiten under er oppdatert med flyttingen, så denne testen er like
    // streng som før — den krever fortsatt at INGENTING er borte. Det
    // `flyttet.ts` gjør, er å holde de fem kravene i live etterpå: at
    // seksjonene faktisk står på `/vaar-stasjon`, med samme komponent,
    // for samme rolle, lenket fra «I dag». Faller én av dem, feller
    // testen over — ikke denne.
    //
    // Alternativet var å la fasiten stå uoppdatert og trekke fra det
    // erklærte her. Da hadde fasiten løyet om hvor seksjonene er, og
    // fratrekket kunne vokst stille. En erklæring som beviser noe er
    // bedre enn en som unntar noe.
    expect(borteI(fasit!.seksjoner, naa.seksjoner), `Seksjoner borte. ${hjelp}`)
      .toEqual({})
  })

  test('erklaeringene i flyttet.ts peker paa ruter som finnes', () => {
    // KANARIFUGL FOR ERKLÆRINGEN SELV.
    //
    // Bevisene over er bare verdt noe hvis de faktisk kjører. En rad som
    // peker på en rute som ikke finnes, gir tomme seksjonslister på begge
    // sider — og da er alle fem kravene trivielt oppfylt uten at noe er
    // sjekket. Det er den stilleste måten en vakt kan slutte å se på.
    const finnes = new Set(naa.ruter)
    const doede: string[] = []
    for (const f of FLYTTEDE_SEKSJONER) {
      for (const [felt, rute] of [['fra', f.fra], ['til', f.til], ['naaddFra', f.naaddFra]]) {
        if (!finnes.has(rute)) doede.push(`${f.seksjon}: ${felt} = ${rute} finnes ikke`)
      }
      if ((naa.seksjoner[f.til] ?? []).length === 0) {
        doede.push(`${f.seksjon}: ${f.til} har ingen seksjoner i det hele tatt`)
      }
    }
    for (const o of OMSKREVNE_SEKSJONER) {
      if (!finnes.has(o.rute)) doede.push(`${o.fra}: rute = ${o.rute} finnes ikke`)
    }
    expect(doede, `Erklæringer som ikke måler noe:\n  ${doede.join('\n  ')}\n`).toEqual([])
    expect(FLYTTEDE_SEKSJONER.length + OMSKREVNE_SEKSJONER.length,
      'Lista er tom — da kjører de fem kravene på ingenting.').toBeGreaterThan(0)
  })

  test('ingen navigasjonsvei er borte uten at det er erklært', () => {
    // Den lumske varianten: alt finnes, men ingen kommer seg dit.
    expect(borteI(fasit!.lenker, naa.lenker), `Lenker borte. ${hjelp}`).toEqual({})
  })

  // --- Klassifiseringen ---

  test('hver rute har et mønster', () => {
    // Uten dette blir hver side lost for seg, og systemet ender som 68
    // sider bygget paa 68 tidspunkt - det vi proever aa komme oss vekk
    // fra. Legger noen til en side uten aa ta stilling til hva slags
    // side det er, stopper det her.
    const uten = naa.ruter.filter((r) => !(r in RUTEMONSTER))
    expect(uten, 'Ruter uten mønster. Velg ett i src/lib/redesign/monstre.ts.')
      .toEqual([])
  })

  test('ingen mønster peker på en rute som ikke finnes', () => {
    const finnes = new Set(naa.ruter)
    expect(Object.keys(RUTEMONSTER).filter((r) => !finnes.has(r))).toEqual([])
  })

  test('hvert mønster har en spesifikasjon', () => {
    for (const m of new Set(Object.values(RUTEMONSTER))) {
      expect(MONSTRE[m], m).toBeDefined()
      expect(MONSTRE[m].nivaa1.length, `nivaa1 for ${m}`).toBeGreaterThan(10)
      expect(MONSTRE[m].fella.length, `fella for ${m}`).toBeGreaterThan(20)
    }
  })

  test('nettbrettrutene finnes og deler rute med desktop', () => {
    const finnes = new Set(naa.ruter)
    for (const r of TABLETRUTER) expect(finnes.has(r), r).toBe(true)
  })

  // --- At vakthunden faktisk maaler noe ---

  test('den ser hele systemet — ellers er den grønn av feil grunn', () => {
    expect(naa.ruter.length).toBeGreaterThan(60)
    expect(Object.keys(naa.naabart).length).toBeGreaterThan(3)
    expect(naa.naabart['butikksjef'].length).toBeGreaterThan(25)
    expect(Object.keys(naa.handlinger).length).toBeGreaterThan(20)
  })
})
