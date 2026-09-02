import { describe, expect, test } from 'vitest'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'

// =====================================================================
// SATSEN ER ET SPOR, IKKE EN BESLUTNING
//
// Timesatsen peker entydig paa skiftordningen - ingen sats i tariffarket
// finnes i begge kolonnene. Men ordningen er AVTALEFESTET (§ 2.7.1.1:
// enighet med tillitsvalgte, skiftplan fire uker i forveien), og feltet
// bestemmer overtidsgrensen.
//
// Utledet automatisk ville en feilfoert timesats avgjort naar overtid
// slaar inn - og feilen ville forsterket seg selv i stedet for aa bli
// oppdaget. Derfor en handling lederen utloeser.
//
// LESER KILDEN. Handlingen er 'use server' og drar inn env-modulen.
// =====================================================================

const les = (...d: string[]) =>
  readFileSync(join(process.cwd(), ...d), 'utf8')
    .split('\n').filter((l) => !l.trim().startsWith('//') && !l.trim().startsWith('*')).join('\n')

const kode = les('src', 'app', '(beskyttet)', 'lonn', 'handlinger.ts')
const knapp = les('src', 'app', '(beskyttet)', 'lonn', 'skift-knapp.tsx')

describe('settSkiftFraSats', () => {
  test('KANARIFUGL: kilden lar seg lese, og kommentarene er strippet', () => {
    expect(kode).toContain('export async function settSkiftFraSats')
    expect(kode, 'kommentarene ble ikke fjernet').not.toContain('SATSEN ER ET SPOR')
  })

  test('roerer ALDRI et felt noen har satt', () => {
    // En motsigelse - feltet sier ordinaer, satsen sier to skift - er
    // nettopp det et menneske maa avgjoere. Aa overskrive den ville gjort
    // en loennsfoering til fasit over en avtale.
    expect(kode).toMatch(/slag === 'motsier'/)
    expect(kode).toMatch(/hoppet\+\+/)
    expect(kode, 'setter ogsaa der feltet motsier satsen')
      .not.toMatch(/skal\.push[\s\S]{0,80}motsier/)
  })

  test('bare lederen', () => {
    expect(kode).toMatch(/if \(!erLeder\(bruker\.rolle\)\) return \{ ok: false/)
  })

  test('feilen fra basen svelges ikke', () => {
    expect(kode).toMatch(/if \(error\) return \{ ok: false/)
    expect(kode).toMatch(/if \(se\) return \{ ok: false/)
  })

  test('KANARIFUGL: null endringer kvitteres ikke som «lagret»', () => {
    // «Lagret» paa null endringer ser ut som en handling som virket -
    // samme feil som `bekreftLest` hadde, rettet i #150.
    expect(knapp).toMatch(/r\.endret === 0/)
    // `\r?\n`, ikke `\n`. Fila sjekkes ut med CRLF paa Windows, saa tegnet
    // etter `)` er `\r` - regexen fant null treff, `svar` ble tom streng,
    // og testen var evig roed lokalt og groenn i CI. Ingenting galt med
    // koden den vokter. En vakt som bare virker paa ett operativsystem
    // maaler operativsystemet.
    const svar = [...knapp.matchAll(/setMelding\([\s\S]*?\)\r?\n/g)].join(' ')
    expect(svar).toMatch(/Ingen aa sette|Ingen å sette/)
  })

  test('knappen forsvinner naar det ikke er noe aa gjoere', () => {
    // En knapp som alltid staar der, og som ikke gjoer noe naar man
    // trykker, laerer folk at knapper ikke betyr noe.
    expect(knapp).toMatch(/if \(antall === 0\) return null/)
  })

  test('oppdateringen skjer etter svaret, ikke i handlingen', () => {
    // `kvitteringsvakt.test.ts`: revalidering av egen rute gjoer
    // kvitteringen til gissel for ruteroppdateringen.
    expect(knapp).toContain('router.refresh()')
    expect(kode, 'handlingen revaliderer sin egen rute').not.toContain('revalidatePath')
  })
})
