import { readFileSync, readdirSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, test } from 'vitest'
import { TAALER_AGGREGAT } from '../stasjonsvalg'
import { RUTEMONSTER } from './monstre'
import { rutenavn } from './fasit'
import { utenKommentarer } from './design'

// =====================================================================
// Aggregat-kapabiliteten skal finnes ÉN gang.
//
// Feilen i trinn 09 var to stasjonskontekster på samme skjerm. Den
// samme feilen kan gjenoppstå i en annen form: at «tåler denne sida
// aggregat?» besvares både i rutetabellen OG inne i sida. Sier tabellen
// «krever én» mens sida summerer - eller motsatt - er appskallet og
// siden uenige igjen, bare et hakk dypere.
//
// REGELEN: en side spør `tillatAlleFor(<sin egen rute>, rolle, antall)`.
// Den har ikke lov til å ha en mening selv. Da FINNES det ikke to steder
// å være uenige.
//
// Vakten leser kildekoden fordi det er den eneste måten å se at ingen
// har skrevet `true` for hånd «bare her, bare denne ene gangen».
// =====================================================================

const APP = join(process.cwd(), 'src', 'app')

function tsxFiler(mappe: string): string[] {
  const ut: string[] = []
  for (const rad of readdirSync(mappe, { withFileTypes: true })) {
    const sti = join(mappe, rad.name)
    if (rad.isDirectory()) ut.push(...tsxFiler(sti))
    else if (rad.name.endsWith('.tsx') && !rad.name.includes('.test.')) ut.push(sti)
  }
  return ut
}

/** Ruta en fil hører til - også når fila ikke selv er en `page.tsx`. */
function rutenFor(sti: string): string {
  return rutenavn(sti.replace(/[^\\/]+$/, 'page.tsx'))
}

const filer = tsxFiler(APP).map((sti) => ({
  sti,
  rute: rutenFor(sti),
  kilde: utenKommentarer(readFileSync(sti, 'utf8')),
}))

const medOppslag = filer.filter((f) => f.kilde.includes('husketStasjon('))

describe('aggregat-kapabilitet har én fasit', () => {
  test('KANARIFUGL - vakten finner faktisk sidene som spor', () => {
    // Slutter maalingen aa treffe - fordi funksjonen bytter navn, eller
    // fordi sidene begynner aa spore paa en annen maate - ser den ut som
    // en vakt uten funn. Tallet skal aldri bli null.
    expect(medOppslag.length).toBeGreaterThanOrEqual(8)
  })

  test('ingen side bestemmer selv om den taaler aggregat', () => {
    const syndere: string[] = []
    for (const { sti, kilde } of medOppslag) {
      // Tredje argument til husketStasjon er `tillatAlle`. Star det en
      // bokstavelig true/false der, har sida en egen mening - og da kan
      // den avvike fra tabellen appskallet leser.
      for (const m of kilde.matchAll(/husketStasjon\(([\s\S]{0,400}?)\n\s*\)/g)) {
        const argumenter = m[1]
        if (/,\s*(true|false)\s*,?\s*$/m.test(argumenter)) {
          syndere.push(`${sti.replace(process.cwd(), '.')}: bokstavelig true/false`)
        }
      }
    }
    expect(
      syndere,
      'En side som skriver `true` her sier at den taaler aggregat, uten at '
      + 'rutetabellen vet om det. Appskallet leser tabellen - da er de to '
      + 'uenige, og brukeren ser en stasjon i toppen og noe annet under. '
      + 'Bruk tillatAlleFor(<ruta>, rolle, antall).',
    ).toEqual([])
  })

  test('en side spor om SIN EGEN rute, ikke naboens', () => {
    const syndere: string[] = []
    for (const { sti, rute, kilde } of filer) {
      for (const m of kilde.matchAll(/tillatAlleFor\(\s*'([^']+)'/g)) {
        if (m[1] !== rute) {
          syndere.push(`${sti.replace(process.cwd(), '.')} spor om «${m[1]}», men er «${rute}»`)
        }
      }
    }
    expect(
      syndere,
      'En side som spor om en annen rutes kapabilitet faar et svar som '
      + 'gjelder en annen skjerm.',
    ).toEqual([])
  })

  test('hver rute i tabellen finnes faktisk', () => {
    // En skrivefeil her er stille: ruta faar bare aldri aggregat, og
    // ingen oppdager at tabellen aldri traff.
    const ukjente = Object.keys(TAALER_AGGREGAT).filter((r) => !(r in RUTEMONSTER))
    expect(ukjente, 'Rute i TAALER_AGGREGAT finnes ikke i rutekartet').toEqual([])
  })

  test('rollebegrensningene navngir ekte roller', () => {
    const ROLLER = new Set([
      'retailer_admin', 'butikksjef', 'butikkbruker_tablet', 'plattform_redaktor',
    ])
    const ukjente: string[] = []
    for (const [rute, regel] of Object.entries(TAALER_AGGREGAT)) {
      if (regel === true) continue
      for (const r of regel) if (!ROLLER.has(r)) ukjente.push(`${rute}: «${r}»`)
    }
    expect(ukjente, 'Ukjent rolle i TAALER_AGGREGAT - regelen vil aldri slaa til').toEqual([])
  })

  test('sidene som IKKE spor, har heller ingen egen stasjonsvelger', () => {
    // Den opprinnelige feilen, som en maaling: en synlig velger som
    // navigerer paa stasjon, i en fil som ikke gaar gjennom kontrakten.
    //
    // Skjemafelt (`name="stasjon_id"` i en <form action={...}>) er noe
    // annet - det er hvilken stasjon objektet man oppretter gjelder, og
    // hoerer ikke hjemme her.
    const syndere: string[] = []
    for (const { sti, kilde } of filer) {
      if (kilde.includes('husketStasjon(')) continue
      if (/<select[^>]*name="butikknummer"/.test(kilde)) {
        syndere.push(`${sti.replace(process.cwd(), '.')}: velger paa butikknummer`)
      }
    }
    expect(
      syndere,
      'En stasjonsvelger utenfor kontrakten er en ny dobbel kontekst.',
    ).toEqual([])
  })
})
