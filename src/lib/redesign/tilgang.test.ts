import { readFileSync, readdirSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, test } from 'vitest'
import { naabarhet, rutenavn } from './fasit'
import { avvisteRoller, ALLE_ROLLER, LEDERE, type Rolle } from './tilgang'

// =====================================================================
// Rollevakt: holder sidene det menyen lover?
//
// Fasiten måler hva hver rolle KAN NÅ ifølge menyen. Den sier ingenting
// om hva sida gjør når hun kommer dit. Det gjør denne.
//
// Kjøres i samme pass som resten — den leser filer og tar millisekunder.
// Det er hele grunnen til at vaktene her blir kjørt: de er gratis.
// =====================================================================

const ROT = process.cwd()
const APP = join(ROT, 'src', 'app')

function sider(mappe: string): string[] {
  const ut: string[] = []
  for (const rad of readdirSync(mappe, { withFileTypes: true })) {
    const sti = join(mappe, rad.name)
    if (rad.isDirectory()) ut.push(...sider(sti))
    else if (rad.name === 'page.tsx') ut.push(sti)
  }
  return ut
}

const kildeFor = new Map<string, string>()
for (const sti of sider(APP)) kildeFor.set(rutenavn(sti), readFileSync(sti, 'utf8'))

const meny = naabarhet(
  readFileSync(join(APP, '(beskyttet)', 'navigasjon.ts'), 'utf8'),
)

// En vakt som er groenn foerste gang, har ikke bevist noe. Disse mater
// den med kjente former og krever at den svarer riktig - saa vi vet at
// groenn betyr «sjekket», ikke «forsto ingenting».
describe('avvisteRoller leser formene', () => {
  const portner = (vilkaar: string) =>
    `const bruker = await hentInnloggetBruker()\n`
    + `if (${vilkaar}) return <p>Ingen tilgang.</p>\n`

  test('erLeder stenger nettbrett og plattform', () => {
    const s = avvisteRoller(portner('!erLeder(bruker.rolle)'))
    expect(s).toEqual({ slag: 'roller', nektede: ['butikkbruker_tablet', 'plattform_redaktor'] })
  })

  test('ulikhet slipper inn bare den ene', () => {
    const s = avvisteRoller(portner("bruker.rolle !== 'retailer_admin'"))
    expect(s.slag === 'roller' && s.nektede).toEqual(
      ['butikkbruker_tablet', 'butikksjef', 'plattform_redaktor'])
  })

  test('likhet stenger bare den ene', () => {
    const s = avvisteRoller(portner("bruker.rolle === 'plattform_redaktor'"))
    expect(s.slag === 'roller' && s.nektede).toEqual(['plattform_redaktor'])
  })

  test('en gren foran portneren teller som handtert', () => {
    // Dette er /regnskap-formen, og den falske alarmen vakten ga foerste
    // gang den kjoerte: butikksjefen faar sin egen visning FOER portneren
    // som ellers ville stengt henne ute.
    const s = avvisteRoller(
      "if (bruker.rolle === 'butikksjef') { return <RegnskapButikksjef bruker={bruker} /> }\n"
      + "if (bruker.rolle !== 'retailer_admin') { return <p>Kun eier.</p> }\n",
    )
    expect(s.slag === 'roller' && s.nektede).not.toContain('butikksjef')
  })

  test('videresending er ikke avvisning', () => {
    const s = avvisteRoller(
      "if (bruker.rolle === 'plattform_redaktor') redirect('/plattform')\n"
      + "if (!erLeder(bruker.rolle)) return <p>Nei.</p>\n",
    )
    expect(s.slag === 'roller' && s.nektede).not.toContain('plattform_redaktor')
  })

  test('tom tilstand er ikke en tilgangssjekk', () => {
    const s = avvisteRoller('if (!person) return <p>Ingen ansatte.</p>')
    expect(s).toEqual({ slag: 'roller', nektede: [] })
  })

  test('ukjent form gir beskjed i stedet for aa tie', () => {
    const s = avvisteRoller(portner("bruker.rolle.startsWith('butikk')"))
    expect(s.slag).toBe('ukjent')
  })

  test('den fanger en ekte feil', () => {
    // Bevis: en side menyen viser for butikksjef, men som bare slipper
    // inn eier. Uten dette hadde vi ikke visst at groenn betyr noe.
    const s = avvisteRoller(portner("bruker.rolle !== 'retailer_admin'"))
    expect(s.slag === 'roller' && s.nektede).toContain('butikksjef')
  })
})

describe('rollevakt', () => {
  test('erLeder speiles riktig fra roller.ts', () => {
    // Hele klassifiseringen hviler paa at !erLeder(bruker.rolle) betyr
    // «alle utenom eier og butikksjef». Endres den funksjonen, skal
    // denne testen si fra foer vakten begynner aa svare feil.
    const kilde = readFileSync(join(ROT, 'src', 'lib', 'auth', 'roller.ts'), 'utf8')
    for (const rolle of LEDERE) expect(kilde).toContain(`'${rolle}'`)
    for (const rolle of ALLE_ROLLER) {
      if (LEDERE.includes(rolle)) continue
      const erNevntSomLeder = new RegExp(
        `erLeder[\\s\\S]{0,200}'${rolle}'`,
      ).test(kilde)
      expect(erNevntSomLeder, `${rolle} skal ikke telle som leder`).toBe(false)
    }
  })

  test('hver tilgangssjekk er leselig for vakten', () => {
    const uleselige: string[] = []
    for (const [rute, kilde] of kildeFor) {
      const svar = avvisteRoller(kilde)
      if (svar.slag === 'ukjent') uleselige.push(`${rute}: ${svar.tekst}`)
    }
    // Nye former er lov. De maa bare legges inn i tilgang.ts foerst, saa
    // vakten faktisk vet hva den ser paa.
    expect(uleselige, `Ukjent form paa tilgangssjekk:\n  ${uleselige.join('\n  ')}\n`
      + 'Legg formen inn i src/lib/redesign/tilgang.ts.').toEqual([])
  })

  test('menyen lover ikke tilgang sida avviser', () => {
    // Den doede lenka: punktet staar der, hun trykker, og moeter «Du har
    // ikke tilgang». Det ser ut som hennes feil, og er var.
    const brudd: string[] = []
    for (const [rolle, stier] of Object.entries(meny)) {
      for (const sti of stier) {
        const kilde = kildeFor.get(sti)
        // Ruter uten egen page.tsx (redirects, eksterne) hopper vi over.
        if (!kilde) continue
        const svar = avvisteRoller(kilde)
        if (svar.slag !== 'roller') continue
        if (svar.nektede.includes(rolle as Rolle)) {
          brudd.push(`${sti} vises for ${rolle}, men sida avviser den rollen`)
        }
      }
    }
    expect(brudd, `\n  ${brudd.join('\n  ')}\n`).toEqual([])
  })

  test('vakten ser fortsatt portnerne', () => {
    // KANARIFUGL. Foerste versjon av regexen taalte ikke parenteser i
    // vilkaaret, saa `!erLeder(bruker.rolle)` - portneren paa rundt
    // femti sider - var usynlig. Alle testene var groenne, fordi den
    // ikke fant noe aa vaere uenig med.
    //
    // En vakt som slutter aa se, ser ut som en vakt som ikke finner
    // noe. Denne skiller de to.
    const medPortner = [...kildeFor.values()]
      .map(avvisteRoller)
      .filter((v) => v.slag === 'roller' && v.nektede.length > 0).length

    expect(medPortner, 'Vakten finner nesten ingen tilgangssjekker. '
      + 'Sannsynligvis leser den ikke kilden riktig lenger.').toBeGreaterThan(40)
  })

  test('hver menyrute har en side som finnes', () => {
    // Den motsatte doede lenka: menyen peker paa noe som er slettet.
    const manglende = new Set<string>()
    for (const stier of Object.values(meny)) {
      for (const sti of stier) if (!kildeFor.has(sti)) manglende.add(sti)
    }
    expect([...manglende].sort()).toEqual([])
  })
})
