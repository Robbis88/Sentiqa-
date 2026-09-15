import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, it } from 'vitest'
import { utenKommentarer } from '@/lib/redesign/design'

// =====================================================================
// SAMMENSTILLEREN SKAL IKKE BLI DEN NYE ØKONOMIMOTOREN
// =====================================================================
//
// Lagdelingen sier at domenemotorene regner og at `okonomi/bilde.ts`
// velger kilde. Uten en vakt flytter aritmetikken seg dit én linje om
// gangen — og om et år er det den fila som eier tallene.
//
// ---------------------------------------------------------------------
// REGELEN ER HARD MED VILJE
// ---------------------------------------------------------------------
//
// «Ingen ØKONOMISK aritmetikk» måtte tolkes hver gang noen la til en
// linje, og en regel som må tolkes er ingen regel. Denne feller enhver
// `+`, `-`, `*` eller `/` utenfor kommentarer og strenger.
//
// Prisen er at fila ikke kan telle noe selv. Det er en villet pris:
// `Dekning` kommer ferdig inn, og en kalenderlengde er ikke
// sammenstillerens jobb.
//
// ---------------------------------------------------------------------
// DEN DEKKER J2 SAMTIDIG
// ---------------------------------------------------------------------
//
// «Svinn skal ikke trekkes fra en brutto som alt er netto» kan ikke skje
// i en fil som ikke kan subtrahere. Regnskapets bruttofortjeneste ER
// fratrukket svinn (`rom.ts`), og en `brutto - matkast` her ville
// trukket det fra to ganger.
// =====================================================================

const STI = join(process.cwd(), 'src', 'lib', 'okonomi', 'bilde.ts')
const KILDE = readFileSync(STI, 'utf8').replace(/\r\n/g, '\n')

/**
 * Kode uten kommentarer OG uten strenginnhold.
 *
 * `utenKommentarer` er streng-bevisst, men beholder innholdet — og en
 * bindestrek i en norsk setning er ikke en subtraksjon. Importstier har
 * dessuten `/` i seg.
 */
function bareKode(kilde: string): string {
  return utenKommentarer(kilde)
    .replace(/`(?:[^`\\]|\\.)*`/g, '‹streng›')
    .replace(/'(?:[^'\\\n]|\\.)*'/g, '‹streng›')
    .replace(/"(?:[^"\\\n]|\\.)*"/g, '‹streng›')
}

// Aritmetiske operatorer, med det som BARE ser saann ut tatt bort.
//
// `=>`, `<=`, `>=`, `??`, `?.` og `...` inneholder ingen av de fire.
// Kommentartegnene gjoer - og de er alt fjernet av `bareKode`. Derfor
// kan regexen vaere rett fram.
//
// (Denne forklaringen staar som linjekommentarer og ikke som JSDoc med
// vilje: en blokkommentar som NEVNER kommentartegnene avslutter seg
// selv. Den feilen tok fem minutter foerste gang.)
function aritmetikk(kode: string): string[] {
  const ut: string[] = []
  for (const [nr, linje] of kode.split('\n').entries()) {
    if (/[+\-*/]/.test(linje)) ut.push(`${nr}: ${linje.trim()}`)
  }
  return ut
}

describe('okonomi/bilde.ts regner ingenting', () => {
  it('KANARIFUGL: fila blir funnet og er ikke tom', () => {
    // Byttes navn eller sti, ville hver paastand under vaert sann fordi
    // det ikke er noe aa maale.
    expect(KILDE.length).toBeGreaterThan(2000)
    expect(KILDE).toContain('export function byggOkonomibilde')
  })

  it('inneholder ingen aritmetisk operator utenfor kommentar og streng', () => {
    const funn = aritmetikk(bareKode(KILDE))
    expect(
      funn,
      '\nSammenstilleren har begynt aa regne:\n\n  '
      + funn.join('\n  ')
      + '\n\nTrenger noe aa regnes, hoerer det i en domenemotor med egne\n'
      + 'tester - rom.ts, royalty.ts, mot-budsjett.ts, kastvurdering.ts.\n',
    ).toEqual([])
  })

  // =================================================================
  // KANARIFUGLER FOR SELVE LESEREN
  // =================================================================
  it('KANARIFUGL: leseren finner en aritmetikk som blir lagt inn', () => {
    const med = KILDE.replace(
      'const { rom, regnskap } = inn',
      'const { rom, regnskap } = inn\n  const resultat = rom.bruttoKr - 1',
    )
    expect(med).not.toBe(KILDE)
    expect(aritmetikk(bareKode(med))).not.toEqual([])
  })

  it('KANARIFUGL: en bindestrek i en NORSK SETNING er ikke en subtraksjon', () => {
    // Uten strengfjerningen ville hver forklaringstekst felt fila, og
    // vakten hadde vaert ubrukelig fra foerste dag.
    const kode = bareKode("const a = 'et tall - og en strek'\nconst b = `to - tre`\n")
    expect(aritmetikk(kode)).toEqual([])
  })

  it('KANARIFUGL: en importsti med skraastrek er ikke en divisjon', () => {
    const kode = bareKode("import { x } from '@/lib/lonnskost/rom'\n")
    expect(aritmetikk(kode)).toEqual([])
  })

  it('KANARIFUGL: en kommentar med regnestykke felles ikke', () => {
    const kode = bareKode('// brutto - royalty - lonn\nconst a = b\n')
    expect(aritmetikk(kode)).toEqual([])
  })
})

describe('sammenstilleren peker ikke oppover i lagene', () => {
  it('importerer ingen komponent og ingen flate', () => {
    // Stiene leses av RAAKILDEN. `bareKode` gjoer dem om til ‹streng›,
    // saa en sjekk paa den ville maalt sin egen erstatning.
    const stier = [...KILDE.matchAll(/from\s+'([^']+)'/g)].map((m) => m[1])
    expect(stier.length).toBeGreaterThan(0)
    for (const s of stier) {
      expect(s, `bilde.ts importerer ${s}`).not.toMatch(/^@\/components\//)
      expect(s, `bilde.ts importerer ${s}`).not.toMatch(/^@\/app\//)
    }
  })

  it('leser motorene, og skriver dem ikke om', () => {
    // `styringsavvik` er E2 sin. Blir den kopiert hit, er lagdelingen
    // borte selv om aritmetikkvakten skulle staa groenn.
    expect(KILDE).toContain("from '@/lib/lonnskost/rom'")
    expect(KILDE).toContain('styringsavvik(rom, styringskost.verdi)')
    // OG DEN MAA FAA STYRINGSKOSTEN, IKKE HELE LOENNA.
    //
    // Rommet er regnet av BP-loenn, som dekker 501+503+508+540+541.
    // `lonn.verdi` er alle ni kontiene. Sto det `lonn.verdi` her igjen,
    // ville 502/505/506/509 spist av et rom som aldri var satt av til
    // dem - 8,71 % paa Dale i juli 2026, der 34 830 kr var sykeloenn.
    expect(KILDE).not.toContain('styringsavvik(rom, lonn.verdi)')
  })
})
