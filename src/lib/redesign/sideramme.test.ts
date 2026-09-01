import { describe, it, expect } from 'vitest'
import { readFileSync, readdirSync, statSync, existsSync } from 'node:fs'
import { join, relative, dirname } from 'node:path'
import { RUTEMONSTER, SPALTE, monsterFor, MONSTRE, type Monster } from './monstre'

// =====================================================================
// SIDERAMMEN HAR TRE MÅTER Å SLUTTE Å VIRKE PÅ, OG INGEN AV DEM ROPER
//
//   1. Skallet slutter å sette `data-bredde`  → alt blir smalt i stillhet.
//   2. CSS-en mister `[data-bredde='bred']`   → alt blir smalt i stillhet.
//   3. En side wrappes uten å stå i mønster-  → siden blir smal i stillhet.
//      kartet
//
// Alle tre gir en side som ser ut som en side. Det er derfor de måles her
// og ikke overlates til øyet. Hver kontroll har en kanarifugl som sier
// hvordan man ser at den fortsatt måler.
// =====================================================================

const ROT = process.cwd()
const APP = join(ROT, 'src', 'app')
const les = (...p: string[]) => readFileSync(join(ROT, ...p), 'utf8')

function sider(rot: string): string[] {
  const ut: string[] = []
  for (const n of readdirSync(rot)) {
    const p = join(rot, n)
    if (statSync(p).isDirectory()) { ut.push(...sider(p)); continue }
    if (n === 'page.tsx') ut.push(p)
  }
  return ut
}
/**
 * All kode som utgjør en rute: `page.tsx` pluss filene den importerer
 * lokalt. Uten dette teller `/ansatte` som klasseløs fordi radene ligger
 * i `AnsattListe` i nabofila.
 */
function kodenFor(sidefil: string): string {
  const mappe = dirname(sidefil)
  const ut = [readFileSync(sidefil, 'utf8')]
  const sett = new Set([sidefil])
  const ko = [...ut]
  while (ko.length) {
    const k = ko.pop()!
    for (const x of k.matchAll(/from\s+'(\.\.?\/[^']+)'/g)) {
      for (const endelse of ['.tsx', '.ts']) {
        const p = join(mappe, x[1] + endelse)
        if (!existsSync(p) || sett.has(p)) continue
        sett.add(p)
        const t = readFileSync(p, 'utf8')
        ut.push(t)
        ko.push(t)
        break
      }
    }
  }
  return ut.join('\n')
}

const ruteFor = (p: string) =>
  ('/' + relative(APP, dirname(p)).replace(/\\/g, '/')
    .replace(/\(.*?\)\/?/g, '').replace(/\/$/, '')) || '/'

describe('Sideramme: bredden kommer fra mønsteret', () => {
  it('hvert mønster har en bredde, og bare de to som finnes i CSS-en', () => {
    // Typen `Record<Monster, Bredde>` sikrer at ingen glemmes. Denne
    // kontrollen sikrer det motsatte: at ingen verdi er oppfunnet som
    // CSS-en ikke kjenner — `data-bredde="middels"` ville gitt smal side
    // uten et eneste varsel.
    const kjente = new Set(['smal', 'bred'])
    for (const m of Object.keys(MONSTRE) as Monster[]) {
      expect(SPALTE[m], `mønsteret «${m}» mangler bredde`).toBeDefined()
      expect(kjente, `«${m}» har bredde «${SPALTE[m]}» som CSS-en ikke kjenner`)
        .toContain(SPALTE[m])
    }
  })

  it('KANARIFUGL: skallet setter data-bredde på .innhold', () => {
    // Forsvinner attributtet, faller `--sq-spalte` til standarden og HELE
    // systemet blir 880 px. Ingen test ville ellers merket det — sidene
    // rendrer like fint, bare feil.
    const skall = les('src', 'app', '(beskyttet)', 'appskall.tsx')
    expect(skall, 'appskall.tsx setter ikke lenger data-bredde på .innhold')
      .toMatch(/className="innhold"[^>]*data-bredde=\{bredde\}/)

    const layout = les('src', 'app', '(beskyttet)', 'layout.tsx')
    expect(layout, 'layouten utleder ikke lenger bredden av mønsteret')
      .toMatch(/monsterFor\(/)
    expect(layout, 'layouten leser ikke lenger SPALTE').toMatch(/SPALTE\[/)
  })

  it('KANARIFUGL: CSS-en har både standarden og unntaket', () => {
    // Mister `[data-bredde='bred']`, blir analysesidene 880 px brede med
    // tabeller som ikke får plass — og attributtet står der fortsatt, så
    // det ser riktig ut i DOM-en.
    const css = les('src', 'components', 'ui', 'ui.css')
    expect(css, 'standardbredden --sq-spalte mangler')
      .toMatch(/\.innhold\s*\{\s*--sq-spalte:/)
    expect(css, 'unntaket [data-bredde=\'bred\'] mangler')
      .toMatch(/\.innhold\[data-bredde='bred'\]\s*\{\s*--sq-spalte:\s*none/)
    expect(css, '.sq-sideramme leser ikke --sq-spalte')
      .toMatch(/\.sq-sideramme\s*\{[^}]*max-width:\s*var\(--sq-spalte\)/)
  })

  it('KANARIFUGL: rammens regler er scopet til .innhold', () => {
    // EN EKTE REGRESJON JEG SELV LAGDE I BØLGE 2.
    //
    // 13 sider forgrener på `butikkbruker_tablet` og rendrer da i
    // TabletSkall, som ikke har `.innhold`. /anvisninger er en av dem og
    // ble migrert — så nettbrettet fikk `display: flex` med 1,5 rem
    // mellomrom det ikke hadde før. Maksbredden forsvant av seg selv
    // (`var(--sq-spalte)` er udefinert der), men flex og gap gjorde ikke
    // det. En stille layoutendring i et skall ingen test dekket.
    //
    // Scopet til `.innhold` er rammen inert utenfor desktopskallet.
    // Fjerner noen scopet, lekker desktopgeometri inn på nettbrettet
    // igjen — og siden nettbrettsidene fortsatt rendrer, ville ingenting
    // sagt fra.
    // Kommentarene MÅ strippes først. Første utgave av denne kontrollen
    // krevde `}` eller filstart foran selektoren — og regelen står etter
    // en blokk-kommentar. Den var blind i samme øyeblikk den ble skrevet,
    // og kanarifuglen viste det med en gang.
    const css = les('src', 'components', 'ui', 'ui.css').replace(/\/\*[\s\S]*?\*\//g, '')
    const uscopet = [...css.matchAll(/([^{}]+)\{[^{}]*\}/g)]
      .map((m) => m[1].trim().replace(/\s+/g, ' '))
      .filter((sel) => /(^|[\s,])\.sq-sideramme\b/.test(sel))
      .filter((sel) => sel.split(',').some((s) => !s.trim().startsWith('.innhold')))
    expect(uscopet, `disse gjelder også i TabletSkall: ${uscopet.join(' | ')}`)
      .toEqual([])
  })

  it('den smale spalta er NØYAKTIG den gamle kortbredden', () => {
    // DETTE ERSTATTER EN NETTLESERTEST SOM MÅLTE FEIL TING.
    //
    // Piloten sammenlignet hver migrert side mot en urørt søsterside for
    // å vise at bredden ikke endret seg. Den feilet to ganger — ikke
    // fordi kontrakten var gal, men fordi baselinen beveget seg:
    // /persondata gir 1316 px for butikksjefen (hun ser ingen `.kort`
    // der i det hele tatt) og 880 for eieren. Testen sammenlignet altså
    // mot et tall som avhenger av hvem som ser, og hvilke data som
    // finnes.
    //
    // Påstanden «vi endret ikke det som allerede var riktig» hører
    // hjemme her, i katalogen, der den er deterministisk: den nye
    // standardbredden må være det SAMME tallet som den gamle regelen
    // ga. Endrer noen den ene uten den andre, sier denne fra — og
    // nettleseren beviser deretter at rammen faktisk treffer tallet.
    const ui = les('src', 'components', 'ui', 'ui.css')
    const globals = les('src', 'app', 'globals.css')

    const ny = /\.innhold\s*\{\s*--sq-spalte:\s*([^;]+);/.exec(ui)?.[1]?.trim()
    const gammel = /\.innhold \.kort\s*\{[^}]*max-width:\s*([^;]+);/.exec(globals)?.[1]?.trim()

    expect(ny, 'fant ikke standardbredden --sq-spalte').toBeDefined()
    expect(gammel, 'fant ikke den gamle .innhold .kort-bredden').toBeDefined()
    expect(ny, `--sq-spalte er ${ny}, men den gamle kortbredden er ${gammel}`)
      .toBe(gammel)
  })

  it('hver side som bruker rammen står i mønsterkartet', () => {
    // Uten mønster får siden `smal` av sikkerhetsgrunner. Det er trygt,
    // men det er ikke en beslutning — og en analysesidesom havner der
    // ville blitt smal uten at noen valgte det.
    const uten: string[] = []
    for (const p of sider(APP)) {
      if (!/\bSideramme\b/.test(readFileSync(p, 'utf8'))) continue
      const r = ruteFor(p)
      if (!RUTEMONSTER[r]) uten.push(r)
    }
    expect(uten, `bruker Sideramme uten å stå i RUTEMONSTER: ${uten.join(', ')}`)
      .toEqual([])
  })

  it('en migrert side har ingen returvei UTENFOR rammen', () => {
    // FUNNET AV CI, IKKE AV MEG.
    //
    // /kampanjer har tre returveier: avvist rolle, «mangler
    // service-nøkkel», og den ekte sida. Migreringen tok bare den siste,
    // fordi de to andre er skrevet på én linje — `return <>…</>` — og
    // ikke på formen `return (` + linjeskift + `<>`.
    //
    // I CI finnes ingen service-nøkkel, så det var nettopp den glemte
    // grenen nettleseren fikk. Sida rendret helt fint. Den sto bare
    // utenfor kontrakten, og ingenting sa fra før målingen fant null
    // rammer.
    //
    // En side som er migrert skal ikke ha igjen et nakent fragment som
    // returverdi. Da er en tilstand av sida uten bredde.
    const synder: string[] = []
    for (const p of sider(APP)) {
      const k = readFileSync(p, 'utf8')
      if (!/\bSideramme\b/.test(k)) continue
      const lin = k.split(/\r?\n/)
      const start = lin.findIndex((l) => l.startsWith('export default'))
      if (start < 0) continue
      for (let i = start; i < lin.length; i++) {
        const enLinje = /^\s*return\s*<>/.test(lin[i])
        const flere = /^\s*return \($/.test(lin[i]) && lin[i + 1]?.trim() === '<>'
        if (!enLinje && !flere) continue
        // ET ANNET SKALL ER IKKE ET HULL I DETTE.
        //
        // 13 sider forgrener på `butikkbruker_tablet` og rendrer da i
        // TabletSkall, som ikke har `.innhold`. /produksjonsplan gjør det
        // midt i samme komponent. Den returen SKAL være naken — en
        // Sideramme der ville vært desktopgeometri i feil skall.
        // Markøren er nettbrettets eget formspråk: `tablet-`-klasser og
        // `<Tablet…>`-komponenter.
        const blokk = lin.slice(i, i + 30).join('\n')
        if (/className="tablet-|<Tablet[A-Z]/.test(blokk)) continue
        synder.push(`${ruteFor(p)}:${i + 1}`)
      }
    }
    expect(synder, `returnerer et nakent fragment i stedet for Sideramme: ${synder.join(', ')}`)
      .toEqual([])
  })

  it('rammen står aldri der bare et tabellelement kan stå', () => {
    // ENDA EN FEIL MIGRATOREN MIN GJORDE, OG SOM tsc GODTOK.
    //
    // /bemanning har en kalender bygget av nøstede `.map()`-kall, og inni
    // en av dem sto `if (!c) return <td …>—</td>`. Heuristikken min for
    // «tidlig retur» så bare `return <småbokstav`, ikke hvor dypt den lå,
    // og pakket den i en Sideramme. Det gir en `<div>` inni en `<tr>` —
    // ugyldig markup som ville brutt kalenderen. JSX-typene sier ingenting
    // om hvilke elementer som kan være barn av hvilke, så tsc var grønn.
    //
    // En ramme er sidas ytterste beholder. Står den rundt et `<td>`, er
    // den ikke det, og noe har gått galt i migreringen.
    const forbudt = /<Sideramme>\s*<(td|tr|th|tbody|thead|tfoot|caption|li|option|dt|dd)\b/
    const synder: string[] = []
    for (const p of sider(APP)) {
      const k = readFileSync(p, 'utf8')
      if (!/\bSideramme\b/.test(k)) continue
      k.split(/\r?\n/).forEach((l, i) => {
        if (forbudt.test(l)) synder.push(`${ruteFor(p)}:${i + 1}`)
      })
    }
    expect(synder, `Sideramme rundt et element som bare hører hjemme i en `
      + `tabell eller liste: ${synder.join(', ')}`).toEqual([])
  })

  it('ingen migrert side setter sin egen bredde', () => {
    // Poenget med rammen er at bredden har én eier. En side som legger på
    // `max-width` selv har tatt den tilbake, og da er vi der vi startet.
    const synder: string[] = []
    for (const p of sider(APP)) {
      const k = readFileSync(p, 'utf8')
      if (!/\bSideramme\b/.test(k)) continue
      if (/max-?[Ww]idth/.test(k)) synder.push(ruteFor(p))
    }
    expect(synder, `setter egen bredde inni Sideramme: ${synder.join(', ')}`).toEqual([])
  })
})

describe('monsterFor', () => {
  it('finner mønsteret for hver rute i kartet', () => {
    for (const rute of Object.keys(RUTEMONSTER)) {
      expect(monsterFor(rute), `fant ikke mønster for ${rute}`).toBe(RUTEMONSTER[rute])
    }
  })

  it('KANARIFUGL: en ekte id treffer den dynamiske ruta', () => {
    // Nettleseren ber om `/kontrakt/9f2c-…`, kartet har `/kontrakt/[id]`.
    // Uten oversettelsen faller HVER detaljside tilbake til standarden —
    // og siden detalj ER smal, ville feilen vært usynlig i dag og dukket
    // opp første gang et detaljmønster ble bredt.
    expect(monsterFor('/kontrakt/9f2c-4a1b-8e7d')).toBe('detalj')
    expect(monsterFor('/puls/42')).toBe('detalj')
    expect(monsterFor('/rutiner/oppsett/abc')).toBe('detalj')
    // Og den skal ikke finne på noe: /kontrakt/[id] må ikke gjøre
    // /kontrakt/a/b til en detaljside.
    expect(monsterFor('/finnes-ikke')).toBeNull()
  })

  it('tåler etterslepende skråstrek', () => {
    expect(monsterFor('/salg/')).toBe(RUTEMONSTER['/salg'])
  })
})

// =====================================================================
// VAKT 1 — RAMMEN SKAL IKKE KUNNE FÅ EN BREDDEPARAMETER
//
// Målt, ikke antatt: jeg ga `Sideramme` en `bredde`-parameter og kjørte
// hele vaktsettet. Alt var grønt. Kontrakten «tar ingen breddeparameter»
// levde bare i en kommentar, og en kommentar stopper ingen.
//
// Trenger vi senere en ny layoutform, skal den uttrykkes i `Monster` og
// `SPALTE` — der alle sider av samme sort får den samtidig — ikke som en
// luke én side kan smette gjennom.
// =====================================================================

describe('Sideramme-signaturen', () => {
  const kilde = () => les('src', 'components', 'ui', 'sideramme.tsx')

  it('tar bare children — ingen bredde, variant, style eller className', () => {
    const k = kilde()

    // Propsene, slik de faktisk står i signaturen.
    const sig = /export function Sideramme\(\s*\{([^}]*)\}\s*:\s*\{([^}]*)\}/.exec(k)
    expect(sig, 'fant ikke signaturen — er komponenten skrevet om?').not.toBeNull()

    const navn = sig![1].split(',').map((s) => s.trim().split(/[:=]/)[0].trim()).filter(Boolean)
    expect(navn, `Sideramme tar ${navn.join(', ')} — den skal bare ta children`)
      .toEqual(['children'])

    const felter = sig![2].split(';').map((s) => s.trim().split(':')[0].trim()).filter(Boolean)
    expect(felter, `props-typen har ${felter.join(', ')} — bare children er tillatt`)
      .toEqual(['children'])
  })

  it('setter ingen style og ingen beregnet className', () => {
    // En `style`-prop er den korteste veien tilbake til lokal bredde, og
    // en `className` bygget av en variabel er den nest korteste.
    const k = kilde()
    expect(k, 'Sideramme setter style — da eier den ikke lenger bredden alene')
      .not.toMatch(/style=/)
    expect(k, 'className skal være strengen "sq-sideramme", ikke noe beregnet')
      .toMatch(/className="sq-sideramme"/)
    expect(k, 'className er bygget av et uttrykk').not.toMatch(/className=\{/)
  })
})

// =====================================================================
// VAKT 2 — INGEN LOKAL KLASSE SKAL TA SPALTEBREDDEN TILBAKE
//
// Vakt 1 lukker parameteren. Denne lukker omveien: en egen klasse i
// globals.css/ui.css med `width: 600px; margin-inline: auto`. Sidefila
// inneholder da ingen breddeord i det hele tatt, så en tekstsjekk på
// `page.tsx` ser ingenting. Målt: den slapp gjennom hele vaktsettet.
//
// Vakten er smal med vilje — den er ingen generell CSS-linter:
//
//   · bare klasser som faktisk brukes av MIGRERTE sider
//   · bare regler der klassen lengst til høyre er en av dem, altså der
//     regelen styrer et element på sida vår
//   · bare erklæringer som BEGRENSER en spalte. `width: 100%` fyller
//     den, `max-width: 62ch` er et lesemål for tekst, `min-width: 0` er
//     flex-fiksen. Ingen av dem tar bredden.
//
// Det som står igjen er en fast lengde eller `margin-inline: auto`, og
// hver slik regel må stå i `BREDDEUNNTAK` med en skrevet begrunnelse.
//
// ---------------------------------------------------------------------
// KJENT BEGRENSNING — BEVISST AKSEPTERT, IKKE OVERSETT
//
// DENNE VAKTEN LESER CSS. DEN LESER IKKE INLINE-STILER.
//
// En migrert side kan i prinsippet skrive
//
//     <div style={{ inlineSize: 600 }}>…</div>
//
// og komme unna med det. Vakt 2 ser den ikke, fordi det ikke finnes noen
// CSS-regel å lese. Det eneste som står i veien er design-skrallen i
// `design.ts`, og den forbyr bare at det TOTALE antallet inline-stiler
// vokser — så den som samtidig fjerner en inline-stil et annet sted,
// slipper gjennom uten et eneste rødt lys.
//
// Dette er en bevisst beslutning, ikke en forglemmelse: den som skal dit
// må aktivt ofre en annen inline-stil, og det er ikke noe man gjør ved
// et uhell. Kostnaden ved å tette det — å parse JSX-uttrykk framfor CSS —
// er høyere enn risikoen.
//
// Men les ikke denne fila som et bevis på at alle lokale breddeveier er
// fysisk umulige. To av tre er stengt:
//
//     breddeparameter på Sideramme   STENGT   (vakt 1)
//     lokal CSS-klasse med bredde    STENGT   (vakt 2)
//     inline style med bredde        ÅPEN     (denne merknaden)
//
// Skal den tettes senere, hører den hjemme i design-skrallen som en egen
// teller for breddesettende inline-stiler — ikke som enda en regex her.
// =====================================================================

/** Regler som setter en fast bredde, og hvorfor de får lov. */
const BREDDEUNNTAK: Record<string, string> = {
  '.innhold .kort':
    'Den gamle mekanismen. Nøytralisert inne i rammen av '
    + '`.innhold .sq-sideramme > .kort { max-width: none }`. Forsvinner '
    + 'når siste rute er migrert.',
  '.logg-inn .kort':
    'Innloggingskortet. Krever `.logg-inn` som forfar, og den finnes '
    + 'ikke på en innlogget side.',
  '.malekort-rad-2 .felt':
    'Et felt i målekortraden, ikke en spalte.',
  '.stepper.liten input':
    'Tallfeltet i en stepper. Komponentmål.',
  '.stepper.liten button':
    'Knappen i en stepper. Komponentmål.',
  '.skjema-form':
    'Lesbar skjemabredde. Et skjema på 1600 px er uleselig — dette er '
    + 'et mål for innholdet, ikke for sida.',
  '.sq-skjema':
    'Samme: bemanningsskjemaets egen lesbare bredde.',
  // --- Kom fram i bølge 3, alle komponentmål i /bemanning og
  //     /produksjonsplan. Ingen av dem er en spalte.
  '.stepper button':
    'Pluss/minus-knappen i en teller. Trykkflate, ikke spalte.',
  '.stepper input':
    'Tallfeltet mellom dem. Bredt nok til fire siffer.',
  '.varsel-dott':
    '9 px prikk som sier «her er noe nytt». Et ikon.',
  '.tablet-melding-merke':
    'Merkelapp på nettbrettet. Minstebredde så korte ord ikke gir en '
    + 'trykkflate på to bokstaver.',
  '.pp-regel-inn input':
    'Tallfelt i produksjonsregelen.',
  '.pp-gruppe-regel input':
    'Samme, per varegruppe.',
  '.sq-ukedager input':
    '18 px avkrysningsboks per ukedag.',
  '.bem-kalender th:first-child, .bem-kalender td:first-child':
    'Klokkeslettkolonnen i bemanningskalenderen. `table-layout: fixed` '
    + 'krever at den er satt — uten den fordeles bredden likt og '
    + '«07:00» havner på to linjer.',
  '.stilling-rad input':
    'Antallsfelt per stilling.',
  // --- Kom fram i bølge 4 (/analyse, /plattform). Komponentmål.
  '.stasjonsvelger select':
    'Nedtrekkslista med stasjonsnavn. 15 rem så «Laguneparken» ikke '
    + 'klippes — et innholdsmål for kontrollen, ikke for sida.',
  '.spinner':
    'Lastesirkelen. `0.9em` følger tekststørrelsen den står i.',
  '.laster-side .spinner':
    'Samme sirkel, større når den er sidas eneste innhold.',
  '.sq-skjult':
    'Teksten som bare skjermlesere skal ha. 1 px er hele poenget — den '
    + 'skal ut av synsfeltet uten å forsvinne fra tilgjengelighetstreet.',
  '.sq-smalt-felt':
    'Et bevisst smalt tallfelt — navnet sier det. Komponentmål. '
    + 'Forutsagt av baselinen før /merker ble migrert, og dukket opp der.',
  '.rutine-form input[type="text"], .rutine-form input:not([type])':
    'Minstebredde på skjemafelt så de ikke kollapser i en flex-rad. '
    + 'Komponentmål. Kom fram da /kampanjer ble migrert.',
  '.rutine-form select':
    'Samme skjema, samme grunn — en nedtrekksliste som er 3 rem bred er '
    + 'ubrukelig.',
  '.ansattnr-form input':
    'Ansattnummerfeltet. Et tallfelt bredt nok til fire siffer — et '
    + 'komponentmål, ikke en spalte. Kom fram da /ansatte ble migrert, '
    + 'som er nøyaktig når vakten skal spørre.',
}

describe('lokalt breddeansvar', () => {
  /** CSS-en uten kommentarer — ellers treffer vakten sin egen prosa. */
  const rens = (s: string) => s.replace(/\/\*[\s\S]*?\*\//g, '')
  const css = () =>
    rens(les('src', 'app', 'globals.css')) + '\n' + rens(les('src', 'components', 'ui', 'ui.css'))

  /** Erklæringer som BEGRENSER en spalte, ikke fyller eller måler tekst. */
  function spaltebredde(kropp: string): string[] {
    const ut: string[] = []
    const re = /(max-width|min-width|width|inline-size|margin-inline)\s*:\s*([^;]+)/g
    for (const m of kropp.matchAll(re)) {
      const prop = m[1]
      const verdi = m[2].trim()
      if (/^(100%|auto|none|0|inherit|unset)$/.test(verdi)) continue
      if (prop === 'margin-inline') {
        if (/auto/.test(verdi)) ut.push(`${prop}: ${verdi}`)
        continue
      }
      if (/\dch\b/.test(verdi)) continue
      ut.push(`${prop}: ${verdi}`)
    }
    return ut
  }

  /** Klassene de migrerte sidene faktisk bruker, inkl. lokale barnefiler. */
  function klasserIMigrerte(): Set<string> {
    const ut = new Set<string>()
    for (const p of sider(APP)) {
      if (!/\bSideramme\b/.test(readFileSync(p, 'utf8'))) continue
      for (const m of kodenFor(p).matchAll(/className="([^"{]*)"/g)) {
        for (const c of m[1].split(/\s+/)) if (c) ut.add(c)
      }
    }
    return ut
  }

  it('KANARIFUGL: vakten finner de kjente reglene', () => {
    // Uten dette ville «ingen funn» også vært svaret hvis parseren var
    // ødelagt — og en vakt som slutter å se ser ut som en som ikke
    // finner noe. `.innhold .kort` er den eldste breddereglen i
    // systemet; ser vakten ikke den, ser den ingenting.
    const funnet = funn().map((f) => f.sel)
    expect(funnet, 'vakten finner ikke .innhold .kort — da måler den ingenting')
      .toContain('.innhold .kort')
    expect(funnet.length).toBeGreaterThanOrEqual(3)
  })

  function funn() {
    const klasser = klasserIMigrerte()
    const ut: { sel: string; props: string[] }[] = []
    for (const m of css().matchAll(/([^{}]+)\{([^{}]*)\}/g)) {
      const sel = m[1].trim().replace(/\s+/g, ' ')
      const props = spaltebredde(m[2])
      if (!props.length) continue
      const iSel = [...sel.matchAll(/\.([a-zA-Z][\w-]*)/g)].map((x) => x[1])
      if (!iSel.length) continue
      if (!klasser.has(iSel[iSel.length - 1])) continue
      ut.push({ sel, props })
    }
    return ut
  }

  it('ingen udokumentert regel setter spaltebredde på en migrert side', () => {
    const ukjente = funn()
      .filter((f) => !(f.sel in BREDDEUNNTAK))
      .map((f) => `${f.sel}  →  ${f.props.join('; ')}`)
    expect(
      ukjente,
      'En klasse på en migrert side setter sin egen bredde. Bredden skal '
      + 'komme fra mønsteret (SPALTE). Er dette et komponentmål og ikke en '
      + 'spalte, før det inn i BREDDEUNNTAK med en begrunnelse:\n  '
      + ukjente.join('\n  '),
    ).toEqual([])
  })

  it('BREDDEUNNTAK inneholder ingen døde oppføringer', () => {
    // Et unntak som ikke lenger treffer noe er en løgn om systemet, og
    // det neste blir lettere å legge til.
    const levende = new Set(funn().map((f) => f.sel))
    const doede = Object.keys(BREDDEUNNTAK).filter((s) => !levende.has(s))
    expect(doede, `unntak som ikke treffer noen regel lenger: ${doede.join(', ')}`)
      .toEqual([])
  })
})
