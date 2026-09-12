import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'

// =====================================================================
// TO VEIER INN, ETT ETTERARBEID
// =====================================================================
//
// Importen har to innganger, og de kjørte hver sin kode:
//
//   behandleJobbKjerne   serveren parser fila (e-postinntak, «Behandle»)
//   lagreForhandsparset  nettleseren parser, serveren lagrer
//
// Den andre er den som brukes HVER DAG — hovedfeltet på /import parser i
// nettleseren. Og den gjorde bare to av seks steg: regnskapslinjene og
// usynlig svinn.
//
// **Bilagsbufferen, månedsplanene, bemanningsvarslene og kaffevarslene
// manglet.** Målt i produksjon 2026-09-12: `bilagssum` hadde NULL rader
// etter måneder med vellykkede opplastinger, og `/maanedsplan` var tom
// etter sju importer. Ingenting feilet — koden ble aldri kalt.
//
// Det tok fem runder å finne, fordi alt så riktig ut: grønn status,
// riktig linjetall, ingen merknad.
//
// Dette er den dyreste formen dette prosjektet kjenner: **to kilder for
// samme regel, like den dagen de skrives.** Den har tatt
// `rls_vakthund`/`rls_funn`, `LONNSKONTI`/`BUTIKKSJEF_PERSONAL_KODER`,
// og `KILDER`/onboarding. Nå denne.
//
// Etterarbeidet ligger derfor i `etterRegnskap`, og denne vakten krever
// at begge veiene kaller den.
// =====================================================================

const FIL = join(process.cwd(), 'src', 'lib', 'import', 'kjerne.ts')
const kilde = readFileSync(FIL, 'utf8').replace(/\r\n/g, '\n')

/** Kroppen til en `async function` på toppnivå. */
function kropp(navn: string): string {
  const start = kilde.indexOf(`async function ${navn}(`)
  if (start < 0) throw new Error(`fant ikke ${navn} i kjerne.ts`)
  const slutt = kilde.indexOf('\n}\n', start)
  if (slutt < 0) throw new Error(`fant ikke slutten paa ${navn}`)
  return kilde.slice(start, slutt + 3)
}

/** Stegene som skal skje etter at et regnskap er lagret. */
const STEG = [
  { navn: 'bilagssummene', kall: 'lagreBilagssum' },
  { navn: 'maanedsplanene', kall: 'byggPlanerForRetailer' },
  { navn: 'utkastene', kall: 'lagreUtkast' },
  { navn: 'bemanningsvarslene', kall: 'varsleBemanning' },
  { navn: 'kaffevarslene', kall: 'varsleKaffe' },
  { navn: 'usynlig svinn', kall: 'lagreUsynligSvinn' },
] as const

describe('etterarbeidet finnes ett sted', () => {
  it('KANARI: begge funksjonene blir funnet', () => {
    // Byttes navn eller struktur, blir utsnittene tomme — og hver
    // paastand under ville vaert sann fordi det ikke er noe aa maale.
    expect(kropp('behandleJobbKjerne').length).toBeGreaterThan(2000)
    expect(kropp('lagreForhandsparset').length).toBeGreaterThan(1000)
    expect(kropp('etterRegnskap').length).toBeGreaterThan(900)
  })

  it('hvert steg finnes i etterRegnskap', () => {
    const e = kropp('etterRegnskap')
    const mangler = STEG.filter((s) => !e.includes(s.kall)).map((s) => s.navn)
    expect(
      mangler,
      `\nStegene ${mangler.join(', ')} staar ikke i etterRegnskap.\n\n`
      + 'Legges de et annet sted, gjelder de bare den ene veien inn - og '
      + 'da er vi tilbake der `bilagssum` sto paa null rader i maanedsvis '
      + 'uten at noe feilet.\n',
    ).toEqual([])
  })

  it('BEGGE veiene kaller etterRegnskap', () => {
    for (const vei of ['behandleJobbKjerne', 'lagreForhandsparset']) {
      expect(
        kropp(vei),
        `\n${vei} kaller ikke etterRegnskap.\n\n`
        + 'Da gjoer de to importveiene forskjellige ting, og forskjellen '
        + 'er usynlig: status blir groenn, linjetallet riktig, og '
        + 'merknaden tom.\n',
      ).toContain('etterRegnskap(')
    }
  })

  it('ingen av veiene gjoer et steg PAA EGEN HAAND', () => {
    // Den farlige regresjonen er ikke at kallet forsvinner - det er at
    // noen legger til et steg i den ene veien «bare for naa», og at det
    // blir staaende. Da har vi to sannheter igjen.
    //
    // `lagreUsynligSvinn` er unntaket i serverveien: den PARSER fila
    // selv, og sender resultatet inn. Parsingen hoerer til veien, ikke
    // til etterarbeidet - men LAGRINGEN skjer i `etterRegnskap`.
    for (const vei of ['behandleJobbKjerne', 'lagreForhandsparset']) {
      const k = kropp(vei)
      for (const s of STEG) {
        if (s.kall === 'lagreUsynligSvinn') continue
        expect(
          k.includes(`${s.kall}(`),
          `${vei} kaller ${s.kall} direkte - det hoerer i etterRegnskap`,
        ).toBe(false)
      }
    }
  })

  it('nettleserveien sender bilagene med i payloaden', () => {
    // Serveren har fila og kan lese bufferen selv. Nettleserveien har
    // bare det parsete resultatet, saa bufferen maa summeres i
    // nettleseren og foelge med. Uten `payload.bilag` er `bilagssum`
    // tom paa den veien - som den var.
    expect(kropp('lagreForhandsparset')).toContain('payload.bilag')
  })

  it('KANARI: steglista maaler faktisk noe', () => {
    // En tom liste ville gjort hver paastand over sann.
    expect(STEG.length).toBeGreaterThanOrEqual(6)
    expect(kropp('etterRegnskap')).toContain('lagreBilagssum')
  })
})

describe('payloaden fra nettleseren baerer bilagene', () => {
  const typer = readFileSync(
    join(process.cwd(), 'src', 'lib', 'import', 'typer.ts'), 'utf8',
  ).replace(/\r\n/g, '\n')

  it('ForhandsPayload har feltet', () => {
    expect(typer).toMatch(/bilag:\s*\{/)
  })

  it('feltet er SUMMERT, ikke raa linjer', () => {
    // Raa bilagslinjer er titusener per fil. En serverhandling har en
    // kroppsgrense paa 1 MB, og summeringen er likevel det som lagres.
    expect(typer).toContain('summer: Leverandorsum[]')
    expect(typer, 'raa Bilagslinje[] i payloaden sprenger kroppsgrensen')
      .not.toMatch(/bilag[\s\S]{0,200}Bilagslinje\[\]/)
  })

  it('summeringen ligger i den RENE parsermodulen', () => {
    // Klienten kan ikke importere fra `import/kjerne.ts` - den er
    // server-only. Laa funksjonen der, kunne nettleseren ikke kalle den,
    // og steget ville falt ut av den ene veien igjen.
    const buffer = readFileSync(
      join(process.cwd(), 'src', 'lib', 'parsere', 'bilagsbuffer.ts'), 'utf8',
    )
    expect(buffer).toContain('export function summerBilagsbuffer')
    expect(kilde, 'summerBilagsbuffer er tilbake i server-kjernen')
      .not.toContain('export function summerBilagsbuffer')
  })
})

// =====================================================================
// OG FELTENE PAA JOBBRADEN, SOM DREV FRA HVERANDRE 2026-09-12
// =====================================================================
//
// Vakten over krevde at begge veiene KALLER etterRegnskap. Den sa
// ingenting om hva de skriver paa jobbraden - og saa la jeg
// `parserversjon`, `avstemt_tid` og `avviksantall` inn i nettleserveien
// alene.
//
// Maalt i produksjon samme kveld: juli ble behandlet paa nytt gjennom
// SERVERVEIEN, svinnet kom inn riktig med 272 butikkrader og 0 avvik, og
// jobben sto likevel med `parserversjon = null`. `0211` ville avvist sin
// egen import, og aarsaken hadde vaert usynlig: status groenn, radtall
// riktig, merknad fyldig.
//
// Feltene bygges naa ett sted. Denne vakten krever at det blir slik.
// =====================================================================

describe('fullfoeringsfeltene finnes ett sted', () => {
  it('KANARI: helperen blir funnet', () => {
    // Byttes navnet, maaler paastandene under ingenting.
    expect(kilde).toContain('function fullfoeringsfelt(')
  })

  it('BEGGE veiene sprer inn fullfoeringsfelt', () => {
    for (const vei of ['behandleJobbKjerne', 'lagreForhandsparset']) {
      expect(
        kropp(vei),
        `\n${vei} bygger jobbfeltene selv.\n\n`
        + 'Et felt som skal skrives paa to steder blir glemt paa ett av '
        + 'dem. Det skjedde med `parserversjon` 2026-09-12.\n',
      ).toContain('...fullfoeringsfelt(')
    }
  })

  it('ingen av veiene skriver feltene PAA EGEN HAAND', () => {
    const felt = ['parserversjon:', 'avstemt_tid:', 'avviksantall:', 'parset_tid:']
    for (const vei of ['behandleJobbKjerne', 'lagreForhandsparset']) {
      const k = kropp(vei)
      const funnet = felt.filter((f) => k.includes(f))
      expect(
        funnet,
        `\n${vei} setter ${funnet.join(', ')} direkte.\n\n`
        + 'Da er det to kilder for samme felt igjen, like den dagen de '
        + 'skrives.\n',
      ).toEqual([])
    }
  })

  it('helperen setter alle fire feltene', () => {
    const h = kilde.slice(kilde.indexOf('function fullfoeringsfelt('))
    const slutt = h.indexOf('\n}\n')
    const kropp_h = h.slice(0, slutt)
    for (const f of ['gjelder_dato', 'antall_rader', 'parset_tid',
      'parserversjon', 'avstemt_tid', 'avviksantall']) {
      expect(kropp_h, `fullfoeringsfelt mangler ${f}`).toContain(f)
    }
  })

  it('avstemmingen avgjoer avstemt_tid, ikke et tidspunkt alene', () => {
    const h = kilde.slice(kilde.indexOf('function fullfoeringsfelt('))
    // `avstemt_tid` maa vaere betinget. Var den alltid satt, ville
    // `0211` sluppet gjennom hver jobb - porten ville vaert en attrapp.
    expect(h).toMatch(/avstemt_tid:\s*o\.avstemming \? naa : null/)
    expect(h).toMatch(/avviksantall:\s*o\.avstemming \? o\.avstemming\.avvik : null/)
  })
})
