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
// sa «i dag». Bønes har 55 rutiner i døgnet, så 123 er et etterslep på
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
// OG DØGNET VAR IKKE SVARET HELLER
//
// Første rettelse gjorde køen til dagens tall. Men 36 av Bønes' 55 er
// morgen og 19 er kveld, og den som står på morgenvakt kan ikke gjøre
// kveldens. «55 igjen» klokka sju er sant og likevel en beskjed om at
// hun ligger etter noe hun ikke rår over.
//
// Køen teller VAKTA. Regelen bor i `tablet/skiftkoe.ts` — samme sted
// `/rutiner` henter den fra, for skrev hjemskjermen sin egen kopi ville
// kortet og sida sagt to ulike tall om samme jobb.
//
// ---------------------------------------------------------------------
// HVA DENNE MÅLER
//
// At nettbrettets kø leser VAKTAS felt. Både periodetallene og dagens
// skal fortsatt finnes — dashbordet bruker de første — så regelen kan
// ikke være «ikke bruk forventet». Den må være «køen bruker vakt*».
// =====================================================================

const ROT = process.cwd()
const OVERSIKT = join(ROT, 'src', 'app', '(beskyttet)', 'oversikt', 'page.tsx')
const STAT = join(ROT, 'src', 'lib', 'rutinestat.ts')

const oversikt = readFileSync(OVERSIKT, 'utf8')
const stat = readFileSync(STAT, 'utf8')

/**
 * Uttrykket som setter `rutinerIgjen`, uten kommentarer.
 *
 * `\r?\n` OG IKKE `\n`. Første utgave sluttet på `\)\n`, og på Windows
 * står det `)\r\n` — så mønsteret kunne aldri matche der. Den var grønn
 * i CI (Linux) og rød på maskinen til den som skrev den, som er den
 * verste kombinasjonen: feilen dukker opp hos én person, etter at
 * porten har sagt ja.
 *
 * Det er andre gang samme felle i dette repoet. Kanarifuglen under
 * fanget den — det er hele grunnen til at den står der.
 */
function koen(kilde: string): string {
  const ren = kilde.replace(/\/\*[\s\S]*?\*\//g, ' ').replace(/\/\/.*/g, '')
  const m = /const rutinerIgjen = [\s\S]{0,200}?\)\r?\n/.exec(ren)
  return m ? m[0] : ''
}

describe('målingen ser køen', () => {
  test('KANARIFUGL: den fant uttrykket', () => {
    // Bytter sida form, blir uttrykket tomt — og «køen bruker vaktas
    // tall» blir sant fordi det ikke finnes noe uttrykk.
    expect(koen(oversikt).length, 'fant ikke `const rutinerIgjen = …`')
      .toBeGreaterThan(20)
  })

  test('KANARIFUGL: regelen ville tatt den gamle koden', () => {
    const gammel = 'const rutinerIgjen = Math.max(0, (rutinestat?.forventet ?? 0)'
      + ' - (rutinestat?.utfort ?? 0))\n'
    // Den gamle brukte HVERKEN vaktas eller dagens felt. Slutter det å
    // være sant, har noen skrevet om historien, og assertionen over
    // måler ikke lenger den feilen den ble skrevet for.
    expect(/vaktForventet|vaktUtfort|idagForventet/.test(gammel)).toBe(false)
  })
})

describe('nettbrettets kø teller vakta, ikke døgnet og ikke måneden', () => {
  test('rutinerIgjen bygges på vaktForventet/vaktUtfort', () => {
    const uttrykk = koen(oversikt)
    expect(uttrykk, 'køen leser ikke vaktas felt').toMatch(/vaktForventet/)
    expect(uttrykk, 'køen leser ikke vaktas felt').toMatch(/vaktUtfort/)
  })

  test('og IKKE på periodetallene', () => {
    const uttrykk = koen(oversikt)
    expect(
      /rutinestat\?\.forventet|rutinestat\?\.utfort|rutinestat\?\.idag/.test(uttrykk),
      '\nKøen er tilbake på periodens tall. `forventet` og `utfort` er '
      + 'tretti dager.\n\nPå Bønes ga det «123 rutiner igjen» klokka sju om '
      + 'morgenen — et etterslep på under 6 % over en måned, lest som dagens '
      + 'jobb av den som skulle gjøre den.\n\nDøgnet er heller ikke svaret: '
      + '36 av Bønes’ 55 er morgen og 19 er kveld, og den som står på '
      + 'morgenvakt kan ikke gjøre kveldens.\n\nBruk `vaktForventet` og '
      + '`vaktUtfort` — regelen bor i `tablet/skiftkoe.ts`, samme sted '
      + '`/rutiner` bruker.\n',
    ).toBe(false)
  })

  test('begge tallparene finnes, og de er ikke det samme', () => {
    // Periodetallene skal BLI staaende - dashbordet bruker dem. Regelen
    // er ikke «ikke bruk forventet», den er «koeen bruker vakt*».
    for (const felt of [
      'forventet', 'utfort', 'idagForventet', 'idagUtfort',
      'vaktForventet', 'vaktUtfort',
    ]) {
      expect(stat, `Rutinestat mangler ${felt}`).toMatch(new RegExp(`\\b${felt}\\b`))
    }
    // Dagens tall skal regnes for seg, ikke settes lik periodens.
    expect(stat, 'idagForventet er ikke regnet ut for én dato')
      .toMatch(/const idagForv = forventetFor\(idag\)/)
    // Og vakta skal komme fra den DELTE regelen, ikke fra en kopi.
    expect(stat, 'rutinestat regner skiftkøen selv i stedet for å bruke skiftkoe.ts')
      .toMatch(/from '\.\/tablet\/skiftkoe'/)
  })
})
