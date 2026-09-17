import { describe, expect, it } from 'vitest'
import { FANEGRUPPER, SEKSJONER, type Punkt } from '@/app/(beskyttet)/navigasjon'
import type { Brukerrolle } from '@/lib/auth/typer'

// =====================================================================
// ÉN INNGANG PER GRUPPE, IKKE ÉN PER SIDE
// =====================================================================
//
// `navigasjon.ts` har alltid sagt det:
//
//   «Sider som ligger i en fanegruppe står med gruppens FØRSTE fane som
//    menypunkt. De andre nås som faner — ikke som egne linjer i menyen.»
//
// Ingenting håndhevet det. Målt 2026-09-16 brøt «Salg» regelen: `/salg`,
// `/timesalg` og `/salgsprognose` sto som tre menylinjer OG som tre faner
// i samme gruppe — seks innganger til tre sider.
//
// Det er ikke en skjønnhetsfeil. En butikksjef som ser tre linjer antar
// tre svar, og bruker tid på å finne ut hvilken som har hennes. Det er
// nøyaktig den kunnskapen produktet skal spare henne for.
//
// ---------------------------------------------------------------------
// PER ROLLE, IKKE GLOBALT
// ---------------------------------------------------------------------
//
// «Rutiner» har `/rutiner` for nettbrettet og `/rutiner/min` for
// lederne. Begge står i menyen, og det er riktig: de er hver sin rolles
// FØRSTE synlige fane i gruppen. Regelen må derfor stilles per rolle,
// ellers ville den felt en riktig meny.
//
// ---------------------------------------------------------------------
// DENNE VAKTEN FJERNER INGEN TILGANG
// ---------------------------------------------------------------------
//
// `naabarhet()` i `fasit.ts` leser BÅDE `SEKSJONER` og `FANEGRUPPER` med
// samme uttrykk. En rute som flyttes fra menyen til en fanegruppe blir
// stående i `naabart`, og vakthundens «ingen mistet tilgang» holder uten
// at fasiten regenereres. Vakten her sier hvor inngangen skal stå —
// aldri om ruta finnes.
// =====================================================================

const ROLLER: Brukerrolle[] = [
  'retailer_admin', 'butikksjef', 'butikkbruker_tablet', 'plattform_redaktor',
]

/** Menyens ruter for én rolle, i menyens egen rekkefølge. */
function menystier(rolle: Brukerrolle): string[] {
  return SEKSJONER.flatMap((s) => s.punkter)
    .filter((p) => p.roller.includes(rolle))
    .map((p) => p.sti)
}

/** Fanene i en gruppe som rollen faktisk ser. */
const mineFaner = (faner: Punkt[], rolle: Brukerrolle) =>
  faner.filter((f) => f.roller.includes(rolle))

describe('KANARIFUGL: det finnes en navigasjon å måle', () => {
  it('gruppene og menyen er ikke tomme', () => {
    // Byttes et eksportnavn, ville hver påstand under vært sann fordi
    // det ikke er noe å måle.
    expect(FANEGRUPPER.length).toBeGreaterThan(5)
    expect(menystier('butikksjef').length).toBeGreaterThan(20)
    expect(menystier('retailer_admin').length).toBeGreaterThan(20)
  })
})

describe('én menylinje per fanegruppe, per rolle', () => {
  it('menylinja er gruppens første synlige fane', () => {
    const brudd: string[] = []
    for (const rolle of ROLLER) {
      const meny = new Set(menystier(rolle))
      for (const g of FANEGRUPPER) {
        const mine = mineFaner(g.faner, rolle)
        if (mine.length === 0) continue
        const iMeny = mine.map((f) => f.sti).filter((s) => meny.has(s))
        if (iMeny.length === 0) continue // gruppen nås et annet sted
        if (iMeny.length > 1 || iMeny[0] !== mine[0].sti) {
          brudd.push(
            `${rolle} · ${g.tittel}: menyen har [${iMeny.join(', ')}],`
            + ` første synlige fane er ${mine[0].sti}`,
          )
        }
      }
    }
    expect(
      brudd,
      '\nFlere innganger til samme fanegruppe:\n\n  '
      + brudd.join('\n  ')
      + '\n\nLa gruppens FØRSTE fane staa i menyen og fjern de andre\n'
      + 'derfra. De naas som faner, og `naabarhet()` teller dem - ingen\n'
      + 'mister tilgang.\n',
    ).toEqual([])
  })

  it('KANARIFUGL: vakten ser en ekstra menylinje som blir lagt inn', () => {
    // Uten dette kunne regelen over vaert skrevet slik at den aldri kan
    // feile, og en vakt som ikke kan feile ser ut som en som ikke finner
    // noe. Her settes bruddet opp for haand, paa data - ikke paa fila.
    const rolle: Brukerrolle = 'butikksjef'
    const g = FANEGRUPPER.find((x) => mineFaner(x.faner, rolle).length > 1)!
    const mine = mineFaner(g.faner, rolle)
    const meny = new Set([mine[0].sti, mine[1].sti])
    const iMeny = mine.map((f) => f.sti).filter((s) => meny.has(s))
    expect(iMeny.length).toBeGreaterThan(1)
  })

  it('ingen rute staar to ganger i menyen for samme rolle', () => {
    for (const rolle of ROLLER) {
      const stier = menystier(rolle)
      const doble = stier.filter((s, i) => stier.indexOf(s) !== i)
      expect(doble, `${rolle} har ruta to ganger i menyen: ${doble.join(', ')}`).toEqual([])
    }
  })

  it('samme rute kan ha ULIKT NAVN for ulike roller', () => {
    // `/oversikt` tegner butikksjefens egen stasjon og eierens
    // portefoelje - to sider bak samme URL, slik `TAALER_AGGREGAT` alt
    // sier. Derfor to menyoppfoeringer med hvert sitt ord. Testen over
    // maaler PER ROLLE nettopp for at dette skal vaere lovlig.
    const alle = SEKSJONER.flatMap((s) => s.punkter).filter((p) => p.sti === '/oversikt')
    expect(alle.length).toBeGreaterThan(1)
    const roller = alle.flatMap((p) => p.roller)
    expect(new Set(roller).size, 'to oppfoeringer for samme rolle er en dublett')
      .toBe(roller.length)
  })
})

describe('Butikken min: tre tidshorisonter, én inngang', () => {
  const gruppe = FANEGRUPPER.find((g) => g.tittel === 'Butikken min')

  it('gruppen finnes og har de tre rutene', () => {
    expect(gruppe, 'fanegruppen «Butikken min» mangler').toBeDefined()
    expect(gruppe!.faner.map((f) => f.sti))
      .toEqual(['/oversikt', '/min-maaned', '/min-plan'])
  })

  it('«I dag» staar foerst - det er der noe haster', () => {
    // Rekkefoelgen er den man leser dem i. En maanedsflate foerst ville
    // gjort en periode til startpunktet, og det som haster i dag til noe
    // man maa klikke seg til.
    expect(gruppe!.faner[0].tekst).toBe('I dag')
  })

  it('bare /oversikt staar i menyen - ikke maaneden og ikke planen', () => {
    for (const rolle of ['retailer_admin', 'butikksjef'] as Brukerrolle[]) {
      const meny = menystier(rolle)
      expect(meny, `${rolle} mangler inngangen til Butikken min`).toContain('/oversikt')
      expect(meny, `${rolle}: /min-maaned er en fane, ikke en menylinje`)
        .not.toContain('/min-maaned')
      expect(meny, `${rolle}: /min-plan er en fane, ikke en menylinje`)
        .not.toContain('/min-plan')
    }
  })

  it('nettbrettet faar ingen av de tre fanene', () => {
    // `/oversikt` er nettbrettets «I dag» og ligger i TABLETMENY. Fanene
    // her er ledernes, og `Fanerad` rendres uansett bare i `Appskall` -
    // nettbrettet har sitt eget skall. Rollelista er det andre laget.
    for (const f of gruppe!.faner) {
      expect(f.roller, `${f.sti} er aapnet for nettbrettet`)
        .not.toContain('butikkbruker_tablet')
    }
  })
})
