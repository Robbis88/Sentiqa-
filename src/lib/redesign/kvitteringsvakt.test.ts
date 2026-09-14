import { describe, expect, test } from 'vitest'
import { readFileSync, readdirSync } from 'node:fs'
import { join } from 'node:path'
import { execSync } from 'node:child_process'
import { utenKommentarer } from './skrivevakt'

// =====================================================================
// En slett-knapp skal svare.
//
// Robert, 2026-08-22: «det er slette-knapper der, det er ikke noe som
// gir beskjed om at de er slettet».
//
// `skrivevakt` maaler serverhandlingen; denne maaler knappen. De to
// henger sammen: en handling som svarer med tekst hjelper ingen hvis
// skjemaet kaster svaret, og et `<form action={slettX}>` GJOER det -
// et rent skjema har ingen plass aa vise noe.
//
// FORMEN ER ENTYDIG AVGJOERBAR, og det er hele grunnen til at den
// maales: `<form action={slett...}>` eller `<form action={fjern...}>`.
// Enten gaar sletting gjennom `SlettKnapp`/`HandlingKnapp`, eller saa
// gjoer den ikke det.
//
// UNNTAKET, og det er ekte: `fjernKryss` i /rutiner er en av/paa-bryter
// som staar i en ternaer sammen med `kryssAv` og deler signatur med
// den. Krysset som forsvinner ER kvitteringen der. Unntaket staar
// navngitt under, ikke som et hull i regexen - et navngitt unntak kan
// leses og bestrides, et hull kan ikke det.
// =====================================================================

const UNNTAK = [
  // Av/paa-bryter, ikke en slett-knapp. Se /rutiner.
  'fjernKryss',
]

const SKJEMA = /<form\s+action=\{(?:\w+ \? )?((?:slett|fjern)[A-ZÆØÅ]\w*)/g

/**
 * Alle .tsx-filer, OGSAA de som ikke er sjekket inn ennaa.
 *
 * `git ls-files` alene ser bare sporede filer. En ny side er usporet
 * helt til den committes - saa vakten var groenn lokalt og roed i CI,
 * paa nøyaktig den koden som nettopp ble skrevet. Det er verste
 * tidspunkt aa faa vite det paa: etter at man trodde man var ferdig.
 */
function sider(): { fil: string; kilde: string }[] {
  const sporede = execSync('git ls-files "src/**/*.tsx"', { encoding: 'utf8' })
  const nye = execSync(
    'git ls-files --others --exclude-standard "src/**/*.tsx"',
    { encoding: 'utf8' },
  )
  return [...new Set(`${sporede}\n${nye}`.split('\n').filter(Boolean))]
    .map((fil) => ({ fil, kilde: utenKommentarer(readFileSync(fil, 'utf8')) }))
}

describe('maalingen forstaar det den ser', () => {
  test('kjenner igjen et rent slette-skjema', () => {
    const funn = [...'<form action={slettLenke}>'.matchAll(SKJEMA)]
    expect(funn).toHaveLength(1)
    expect(funn[0][1]).toBe('slettLenke')
  })

  test('KANARIFUGL: den ser faktisk filene', () => {
    // Peker stien feil, blir lista tom og vakten groenn uten aa ha lest
    // en eneste side.
    const s = sider()
    expect(s.length, 'fant nesten ingen .tsx-filer').toBeGreaterThan(40)
    expect(
      s.filter((x) => /<SlettKnapp/.test(x.kilde)).length,
      'fant ingen SlettKnapp - da maaler ikke denne vakten noe',
    ).toBeGreaterThan(15)
  })

  test('KANARIFUGL: flerlinje-JSX leses som ett element', () => {
    // Denne feilet foer rettelsen, paa kode som var helt riktig.
    const flerlinje = [
      '<SlettKnapp',
      '  hva={rad.tittel}',
      '  handling={slett}',
      '  id={rad.id}',
      '/>',
    ].join('\n')
    const treff = [...flerlinje.matchAll(/<SlettKnapp\b[^>]*>/g)]
    expect(treff, 'elementet skal finnes').toHaveLength(1)
    expect(/\shva=\{/.test(treff[0][0]), 'hva skal sees').toBe(true)
  })

  test('KANARIFUGL: et skjema som ikke sletter telles ikke', () => {
    // Halve appen er `<form action={lagreX}>`. Traff regexen dem, ville
    // vakten vaert roed fra foerste dag og dermed ubrukelig.
    expect([...'<form action={lagreVindu}>'.matchAll(SKJEMA)]).toHaveLength(0)
  })
})

describe('kvitteringsvakten', () => {
  test('ingen sletting gaar gjennom et rent skjema', () => {
    const funn: string[] = []
    for (const { fil, kilde } of sider()) {
      for (const m of kilde.matchAll(SKJEMA)) {
        if (UNNTAK.includes(m[1])) continue
        funn.push(`  ${fil}  ${m[1]}`)
      }
    }

    expect(funn, '\nDisse sletter gjennom et rent <form>, som ikke kan vise '
      + `et svar:\n${funn.join('\n')}\n\n`
      + 'Bruk <SlettKnapp handling={...} id={...} hva={...} /> i stedet. '
      + 'Handlingen tar da (tilstand, formData) og svarer med tekst via '
      + '`kvitter` i src/lib/kvittering.ts.\n')
      .toEqual([])
  })

  test('hver slett-knapp i en liste har sitt eget navn', () => {
    // TJUE KNAPPER SOM ALLE HETER «Slett» er tjue like knapper for en
    // skjermleser. Samme feil som de tolv identiske maanedsvelgerne paa
    // bemanningssida: riktig paa skjermen, ubrukelig uten den.
    //
    // LESER HELE ELEMENTET, ikke linja. Foerste utgave sjekket
    // `hva=` paa samme linje som `<SlettKnapp`, og meldte derfor to
    // KORREKTE knapper som skrev propene sine over flere linjer. En
    // vakt som melder falske funn paa kode som virker, er den
    // sikreste maaten aa laere folk aa ignorere den paa.
    const uten: string[] = []
    for (const { fil, kilde } of sider()) {
      for (const m of kilde.matchAll(/<SlettKnapp\b[^>]*>/g)) {
        if (!/\shva=\{/.test(m[0])) {
          uten.push(`  ${fil}: ${m[0].replace(/\s+/g, ' ').slice(0, 80)}`)
        }
      }
    }
    expect(uten, `\nDisse slett-knappene mangler \`hva\`, og faar dermed `
      + `ingen aria-label:\n${uten.join('\n')}\n\n`
      + 'Sett hva={x.navn} eller det som skiller raden fra naboen.\n')
      .toEqual([])
  })
})

// =====================================================================
// KVITTERINGEN SKAL IKKE VAERE GISSEL FOR EN REVALIDERING
//
// `useActionState` holder `venter` sann gjennom HELE overgangen. Kalles
// `revalidatePath` inne i serverhandlingen, blir ruteroppdateringen en
// del av den overgangen - og kvitteringen vises foerst naar hele sida
// har tegnet seg om.
//
// MAALT, IKKE ANTATT. Playwright-sporet fra en roed CI-kjoring
// 2026-08-29 (PR #113, `vaktidentitet.spec.ts`):
//
//   0,7 s   POST /stempling      200 paa 190 ms
//   1,2 s   siste aktivitet
//   ...     29 sekunder stille
//   30,6 s  GET /stempling?_rsc  200 paa 108 ms
//   45 s    knappen staar fortsatt «Registrerer …»
//
// Serveren gjorde jobben paa 190 ms. Klienten viste det aldri.
//
// Den 29 sekunder lange stillheten er ressursmangel paa CI-maskinen, og
// den er IKKE fjernet. Det som er fjernet er koblingen som gjorde den om
// til en feil - og den koblingen rammer mennesket ogsaa: hun ser
// «Registrerer …» paa en stempling som alt ER registrert, og det er
// nettopp da hun trykker en gang til. Et dobbelttrykk lager
// `dobbel_inn`-avviket butikksjefen maa rydde.
//
// Rekkefolgen skal vaere: kvittering foerst, liste etterpaa.
// =====================================================================

describe('kvitteringen kommer foer revalideringen', () => {
  const les = (sti: string) => utenKommentarer(readFileSync(sti, 'utf8'))

  test('stemplingshandlingen revaliderer ikke selv', () => {
    expect(
      les('src/app/(beskyttet)/stempling/handlinger.ts'),
      'revalidatePath her gjor kvitteringen til gissel for ruteroppdateringen',
    ).not.toContain('revalidatePath')
  })

  test('skjemaet oppdaterer lista ETTER at svaret er kommet', () => {
    // Uten dette staar «Inne naa» og henger igjen paa forrige tall, og
    // hun ser ikke seg selv dukke opp i lista.
    const kilde = les('src/app/(beskyttet)/stempling/skjema.tsx')
    expect(kilde).toContain('router.refresh()')
    expect(kilde, 'refreshen skal staa i effekten som ser et vellykket svar')
      .toMatch(/svar\?\.ok[\s\S]{0,400}router\.refresh\(\)/)
  })

  test('KANARIFUGL: maalingen ser et revalidatePath naar det staar der', () => {
    // Slutter dette aa treffe, blir paastanden over groenn uansett hva
    // handlingen gjor.
    expect(utenKommentarer("import { revalidatePath } from 'next/cache'\nrevalidatePath('/x')"))
      .toContain('revalidatePath')
  })

  test('KANARIFUGL: kommentarstrippen skjuler ikke et ekte kall', () => {
    // Tar den for mye, leser vakten en tom fil - og en vakt som ikke ser
    // ser ut som en som ikke finner noe.
    expect(utenKommentarer("// revalidatePath('/x')\nrevalidatePath('/y')"))
      .toContain("revalidatePath('/y')")
    expect(utenKommentarer("// revalidatePath('/x')\nconst a = 1")).not.toContain('/x')
  })
})

// =====================================================================
// INGEN SERVERHANDLING SKAL REVALIDERE SIN EGEN RUTE
//
// Regelen, ikke listen. Seksten sider hadde koblingen da den ble
// oppdaget; en syttende ville arvet den i stillhet hvis vakten bare
// nevnte de seksten ved navn.
//
// `useActionState` holder `venter` sann gjennom hele overgangen, og en
// revalidering av EGEN rute gjor ruteroppdateringen til en del av den.
// Kvitteringen blir da gissel for at siden skal tegne seg om — maalt til
// 45 sekunder paa /stempling der serveren svarte paa 190 ms.
//
// `revalidatePath` for ANDRE ruter er fortsatt riktig: `router.refresh()`
// i `useKvittering` naar bare siden du staar paa.
// =====================================================================

/**
 * Navngitte unntak, ikke hull i maalingen.
 *
 * Et hull kan ingen se; et navngitt unntak kan leses og bestrides.
 */
const EGENRUTE_UNNTAK: Record<string, string> = {
  // `revalidatePath('/', 'layout')` friskner opp ALLE datasider etter en
  // import - salg, dekning, oversikt. `router.refresh()` naar bare den
  // ene siden, saa den kan ikke erstatte dette.
  //
  // Prisen er at kvitteringen paa /import fortsatt venter paa
  // oppdateringen. Det er akseptabelt her og bare her: en import tar tid
  // uansett, og den trykkes én gang, ikke av folk med hansker som har
  // det travelt.
  '/import': 'revalidatePath(\'/\', \'layout\') maa treffe alle datasider',

  // FUNNET DA VAKTEN FIKK SYNET TILBAKE (se blokka under). /plattform
  // bruker den delte `HandlingKnapp`, saa ruta ble aldri vurdert - og
  // egenrevalideringen har ligget der i main.
  //
  // MIDLERTIDIG, OG BARE DENNE. Den rettes i en egen PR sammen med
  // resten av kvitteringsflyten paa plattformflatene; aa rette den her
  // ville gjort en PR om maanedsplanen til en revisjon av noe annet.
  // Maanedsplanens tre handlinger er rettet, fordi de er flyten vi skal
  // bruke naa.
  // ---------------------------------------------------------------
  // FUNNET DA VAKTEN FIKK SYNET TILBAKE
  // ---------------------------------------------------------------
  //
  // Sju ruter, alle med den delte `HandlingKnapp`. Vakten kunne ikke se
  // dem: den krevde en krok i rutas EGEN katalog, og knappen eier
  // `useActionState` selv. De har ligget slik i main.
  //
  // De er MIDLERTIDIGE unntak, ikke godtatt oppfoersel. Rettelsen er
  // den samme overalt - `oppfrisk` paa knappen, egen rute ut av
  // handlingen - men den hoerer hjemme i en PR om kvitteringsflyten,
  // ikke i en PR om maanedsplanen.
  //
  // MAANEDSPLANENS TRE HANDLINGER STAAR IKKE HER. De er rettet, fordi
  // de er flyten som skal brukes naa: bygg -> kontroller -> slipp.
  '/anvisninger': 'MIDLERTIDIG: rettes i egen PR om kvitteringsflyten',
  '/konkurranser': 'MIDLERTIDIG: rettes i egen PR om kvitteringsflyten',
  '/lonnskost': 'MIDLERTIDIG: rettes i egen PR om kvitteringsflyten',
  '/oppgaver': 'MIDLERTIDIG: rettes i egen PR om kvitteringsflyten',
  '/plattform': 'MIDLERTIDIG: rettes i egen PR om kvitteringsflyten',
  '/redaktor': 'MIDLERTIDIG: rettes i egen PR om kvitteringsflyten',
  '/sjekkpunkt': 'MIDLERTIDIG: rettes i egen PR om kvitteringsflyten',
}

/**
 * Delte komponenter som EIER kvitteringstilstanden selv.
 *
 * Utledet av kilden, ikke skrevet ned: en ny komponent i
 * `src/components/ui` som tar en av krokene blir med uten at noen må
 * huske det.
 */
export function delteMedTilstand(): string[] {
  const mappe = join('src', 'components', 'ui')
  const ut: string[] = []
  for (const f of readdirSync(mappe)) {
    if (!f.endsWith('.tsx')) continue
    const k = readFileSync(join(mappe, f), 'utf8')
    if (!/useActionState|useKvittering|useTransition/.test(k)) continue
    for (const m of k.matchAll(/export function (\w+)/g)) ut.push(m[1])
  }
  return ut
}

const DELTE_MED_TILSTAND = delteMedTilstand()

function ruterMedEgenrevalidering(): { rute: string; katalog: string }[] {
  const ut: { rute: string; katalog: string }[] = []
  const gaa = (katalog: string) => {
    for (const oppf of readdirSync(katalog, { withFileTypes: true })) {
      const sti = join(katalog, oppf.name)
      if (oppf.isDirectory()) { gaa(sti); continue }
      // ALLE `'use server'`-FILER, ikke bare `handlinger.ts`.
      //
      // Foerste utgave saa bare paa `handlinger.ts`, og /lonn har
      // serverhandlinger i `rettelser.ts` og `overgang.ts` ogsaa. Tre
      // egen-rute-revalideringer laa der og ble ikke sett - av en vakt
      // som var gronn.
      if (!oppf.name.endsWith('.ts') || oppf.name.endsWith('.d.ts')) continue
      if (!readFileSync(sti, 'utf8').startsWith("'use server'")) continue

      const rute = '/' + katalog.replace(/\\/g, '/').split('/').slice(2)
        .filter((d) => !d.startsWith('(')).join('/')
      const kode = utenKommentarer(readFileSync(sti, 'utf8'))
      // TRE FORMER, IKKE TO.
      //
      // Bade `'/rute'` og en mal som `` `/rute/${id}` `` - den siste er
      // ogsaa egen rute naar skjemaet bor paa undersiden.
      //
      // OG `oppfrisk: ['/rute']`, som gaar gjennom `kvitter()` i
      // `src/lib/kvittering.ts` og ender i noeyaktig samme
      // `revalidatePath`. `slippPlan` og `avvisPlan` sto slik, og vakten
      // saa dem ikke: den lette bare etter det direkte kallet.
      const egen = kode.includes(`revalidatePath('${rute}')`)
        || kode.includes(`revalidatePath(\`${rute}/`)
        || new RegExp(`oppfrisk:\\s*\\[[^\\]]*'${rute}'`).test(kode)
      if (!egen) continue

      // BEGGE KROKENE TELLER, og det er ikke pynt.
      //
      // Foerste utgave saa bare etter `useActionState`. Da jeg hadde
      // byttet alle seksten til `useKvittering`, kunne vakten aldri slaa
      // ut igjen - den sto gronn med en ekte regresjon lagt inn med
      // vilje.
      //
      // Men aa droppe betingelsen HELT er ogsaa feil: 23 ruter bruker
      // rene skjemaer uten kvitteringstilstand, og der ER revalideringen
      // tilbakemeldingen. Tas den bort, oppdateres ingenting.
      //
      // Det som gjor koblingen skadelig er at en klient holder paa
      // ventetilstand og svar TVERS OVER overgangen. Det er nettopp det
      // begge disse krokene gjor.
      // TRE KROKER, IKKE TO. `useTransition` sto ikke her, og det var et
      // ekte hull: `/analyse` holdt ventetilstanden gjennom en
      // AI-analyse som kunne ta minutter, mens handlingen revaliderte
      // sin egen rute. Vakten var GROENN hele tiden - den saa aldri
      // ruta, fordi knappen brukte den tredje kroken.
      //
      // `start()` pakker den asynkrone handlingen paa noeyaktig samme
      // maate som de to andre: `venter` er sann til overgangen er over,
      // og revalideringen er en del av overgangen.
      // FIRE KROKER — OG DEN FJERDE ER EN KOMPONENT, IKKE EN KROK.
      //
      // Vakten krevde at en `.tsx` i SAMME katalog inneholdt en av de
      // tre krokene. Men den vanligste formen i dette huset er den
      // DELTE `HandlingKnapp`, som eier `useActionState` selv — og da
      // var `harTilstand` usann, og ruta ble aldri vurdert.
      //
      // /maanedsplan og /plattform laa slik. Vakten var grønn mens to
      // ruter hadde nettopp den koblingen den finnes for å hindre, og
      // e2e-testen på /maanedsplan sto og ventet i tjue sekunder.
      //
      // REGELEN, IKKE LISTEN: de delte komponentene leses ut av
      // `src/components/ui`, så en ny av samme slag blir med av seg
      // selv. Det var nettopp det en håndholdt liste ikke ville gjort.
      const harTilstand = readdirSync(katalog)
        .filter((f) => f.endsWith('.tsx'))
        .some((f) => {
          const k = readFileSync(join(katalog, f), 'utf8')
          return k.includes('useActionState') || k.includes('useKvittering')
            || k.includes('useTransition')
            || DELTE_MED_TILSTAND.some((navn) => k.includes(`<${navn}`))
        })
      if (harTilstand) ut.push({ rute, katalog })
    }
  }
  gaa('src/app')
  return ut
}

describe('vakten ser det den skal se', () => {
  test('KANARIFUGL: den delte knappen er funnet i src/components/ui', () => {
    // Uten den er `DELTE_MED_TILSTAND` tom, og utvidelsen over maaler
    // ingenting - i stillhet, akkurat som foer.
    expect(DELTE_MED_TILSTAND).toContain('HandlingKnapp')
  })

  test('KANARIFUGL: `oppfrisk`-formen gjenkjennes', () => {
    const m = new RegExp(`oppfrisk:\\s*\\[[^\\]]*'/maanedsplan'`)
    expect(m.test("oppfrisk: ['/maanedsplan']")).toBe(true)
    expect(m.test("oppfrisk: ['/min-plan']")).toBe(false)
  })

  // KOMMENTARENE STRIPPES FOERST, og det er ikke en detalj.
  //
  // Vakten leste fila raa. Da felte den enhver kommentar som SITERTE
  // `revalidatePath('/maanedsplan')` - for eksempel en blokk som
  // forklarer hvorfor kallet ble fjernet. En vakt som ikke taaler at
  // koden beskrives, laerer folk aa skrive om prosaen i stedet for aa
  // rette koden, og da maaler den til slutt ingenting.
  //
  // `utenKommentarer` brukes allerede av resten av fila. Her manglet den.
  test('maanedsplanens tre handlinger revaliderer IKKE egen rute', () => {
    // Flyten vi skal bruke naa: bygg -> kontroller -> slipp -> avvis.
    const kode = utenKommentarer(readFileSync(
      join('src', 'app', '(beskyttet)', 'maanedsplan', 'handlinger.ts'), 'utf8'))
    expect(kode).not.toContain("revalidatePath('/maanedsplan')")
    expect(kode).not.toMatch(/oppfrisk:\s*\[[^\]]*'\/maanedsplan'/)
  })

  test('KANARIFUGL: stripping skjuler ikke et ekte kall', () => {
    // Uten denne ville `utenKommentarer` kunnet strippe for mye - og en
    // vakt som ser bort fra koden er verre enn en som ser for mye.
    const kode = utenKommentarer(
      "// revalidatePath('/maanedsplan') er fjernet\n"
      + "revalidatePath('/maanedsplan')\n",
    )
    expect(kode).toContain("revalidatePath('/maanedsplan')")
    expect(kode).not.toContain('er fjernet')
  })
})

describe('ingen serverhandling revaliderer sin egen rute', () => {
  const funn = ruterMedEgenrevalidering().filter((f) => !(f.rute in EGENRUTE_UNNTAK))

  test('ingen ruter utenfor unntakslisten', () => {
    expect(
      funn.map((f) => f.rute),
      'Kvitteringen blir gissel for ruteroppdateringen. Bruk `useKvittering` '
      + 'fra @/components/ui/kvittering og ta revalideringen av egen rute ut '
      + 'av serverhandlingen.',
    ).toEqual([])
  })

  test('KANARIFUGL: maalingen finner faktisk noe naar unntaket tas bort', () => {
    // Uten dette ville en tom liste betydd bade «alt er ryddet» og
    // «maalingen ser ingenting», og de to ser like ut.
    const alle = ruterMedEgenrevalidering().map((f) => f.rute)
    expect(alle, 'unntaket /import skal fortsatt bli SETT av maalingen')
      .toContain('/import')
  })

  test('KANARIFUGL: hvert unntak peker paa en rute som finnes', () => {
    // Et unntak for en rute som er slettet er et hull som ser ut som en
    // begrunnelse.
    const alle = ruterMedEgenrevalidering().map((f) => f.rute)
    for (const rute of Object.keys(EGENRUTE_UNNTAK)) {
      expect(alle, `unntaket ${rute} gjelder ingenting lenger — fjern det`)
        .toContain(rute)
    }
  })
})
