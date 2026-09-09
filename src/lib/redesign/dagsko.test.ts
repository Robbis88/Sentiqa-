import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, test } from 'vitest'

// =====================================================================
// «123 RUTINER IGJEN» KLOKKA SJU OM MORGENEN
//
// Nettbrettets kø sto slik på Bønes 2026-09-09. Tallet var ikke galt —
// det var **riktig svar på feil spørsmål**:
//
//     const rutinestat = await beregnRutinestat(supabase, st.id, idag)
//     // Det som faktisk gjenstaar i dag
//     const rutinerIgjen = forventet - utfort
//
// `forventet` og `utfort` er PERIODENS tall, tretti dager. Kommentaren
// sa «i dag». Bønes har 67 rutiner i døgnet, så 123 er et etterslep på
// under 6 % over en måned — hun var 94 % i mål og fikk beskjed om at
// hun aldri kom dit.
//
// ---------------------------------------------------------------------
// HVORFOR DET ER VERRE ENN ET GALT TALL
//
// Et galt tall blir oppdaget. Et riktig tall på feil spørsmål ser
// troverdig ut, og det holdt i månedsvis. Kommentaren gjorde det verre:
// den BESKREV den riktige regelen ved siden av den gale koden, så en
// gjennomlesing bekreftet feilen.
//
// Samme familie som resten: `TabletIkMat` som hadde en `t()` uten å få
// noe å slå opp i, og `anonymiser` som byttet et navn uten å være en
// grense.
//
// ---------------------------------------------------------------------
// HVA DENNE MÅLER
//
// At nettbrettets kø leser DAGENS felt. Periodetallene er lederens, og
// de skal fortsatt finnes — de brukes på dashbordet — så regelen kan
// ikke være «ikke bruk forventet». Den må være «køen bruker idag*».
// =====================================================================

const ROT = process.cwd()
const OVERSIKT = join(ROT, 'src', 'app', '(beskyttet)', 'oversikt', 'page.tsx')
const STAT = join(ROT, 'src', 'lib', 'rutinestat.ts')

const oversikt = readFileSync(OVERSIKT, 'utf8')
const stat = readFileSync(STAT, 'utf8')

/** Uttrykket som setter `rutinerIgjen`, uten kommentarer. */
function koen(kilde: string): string {
  const ren = kilde.replace(/\/\*[\s\S]*?\*\//g, ' ').replace(/\/\/.*/g, '')
  const m = /const rutinerIgjen = [\s\S]{0,200}?\)\n/.exec(ren)
  return m ? m[0] : ''
}

describe('målingen ser køen', () => {
  test('KANARIFUGL: den fant uttrykket', () => {
    // Bytter sida form, blir uttrykket tomt — og «køen bruker dagens
    // tall» blir sant fordi det ikke finnes noe uttrykk.
    expect(koen(oversikt).length, 'fant ikke `const rutinerIgjen = …`')
      .toBeGreaterThan(20)
  })

  test('KANARIFUGL: regelen ville tatt den gamle koden', () => {
    const gammel = 'const rutinerIgjen = Math.max(0, (rutinestat?.forventet ?? 0)'
      + ' - (rutinestat?.utfort ?? 0))\n'
    expect(/idagForventet|idagUtfort/.test(gammel), 'den gamle brukte dagens felt?')
      .toBe(false)
  })
})

describe('nettbrettets kø teller dagen, ikke måneden', () => {
  test('rutinerIgjen bygges på idagForventet/idagUtfort', () => {
    const uttrykk = koen(oversikt)
    expect(uttrykk, 'køen leser ikke dagens felt').toMatch(/idagForventet/)
    expect(uttrykk, 'køen leser ikke dagens felt').toMatch(/idagUtfort/)
  })

  test('og IKKE på periodetallene', () => {
    const uttrykk = koen(oversikt)
    expect(
      /rutinestat\?\.forventet|rutinestat\?\.utfort/.test(uttrykk),
      '\nKøen er tilbake på periodens tall. `forventet` og `utfort` er '
      + 'tretti dager.\n\nPå Bønes ga det «123 rutiner igjen» klokka sju om '
      + 'morgenen — et etterslep på under 6 % over en måned, lest som dagens '
      + 'jobb av den som skulle gjøre den.\n\nBruk `idagForventet` og '
      + '`idagUtfort`.\n',
    ).toBe(false)
  })

  test('begge tallparene finnes, og de er ikke det samme', () => {
    // Periodetallene skal BLI staaende - dashbordet bruker dem. Regelen
    // er ikke «ikke bruk forventet», den er «koeen bruker idag*».
    for (const felt of ['forventet', 'utfort', 'idagForventet', 'idagUtfort']) {
      expect(stat, `Rutinestat mangler ${felt}`).toMatch(new RegExp(`\\b${felt}\\b`))
    }
    // Dagens tall skal regnes for seg, ikke settes lik periodens.
    expect(stat, 'idagForventet er ikke regnet ut for én dato')
      .toMatch(/const idagForv = forventetFor\(idag\)/)
  })
})
