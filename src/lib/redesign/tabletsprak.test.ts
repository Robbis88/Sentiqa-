import { readFileSync, readdirSync, existsSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, test } from 'vitest'
import {
  TABLETMENY, NETTBRETTFLATER, FANEGRUPPER, SEKSJONER,
} from '../../app/(beskyttet)/navigasjon'

// =====================================================================
// NETTBRETTET STÅR I BUTIKKEN, OG DEN SOM HOLDER DET LESER IKKE
// NØDVENDIGVIS NORSK
//
// Hele språkvalget finnes: `TABLET_ORD` er en fast liste, `oversettMange`
// cacher mot Haiku, og `useT()` slår opp. Flagg-velgeren står i toppen.
// En bruker som velger polsk får polsk på «I dag», på Rutiner, på
// Sjekkpunkter, på Produksjon, på IK-mat måling og på Vår stasjon.
//
// Og så norsk på resten. Ikke som et valg — som et hull.
//
// Det er den verste formen et språkvalg kan ha: den som velger polsk får
// bekreftet at appen kan polsk, og møter så norsk der hun trenger det
// mest. Et halvt språkvalg er verre enn ingen, fordi det ser ut som
// hennes feil.
//
// ---------------------------------------------------------------------
// HVA DENNE MÅLER
//
// Rutene nettbrettet kan nå leses ut av `navigasjon.ts` — men av
// ROLLEN, ikke av listenavnet. `NETTBRETTFLATER` heter som om den er
// fasit og er det ikke: `/mine-opplysninger`, `/nyheter`, `/merker` og
// `/ikmat` står med rollen [T] i de andre listene, og nås fra foten
// under «Hjelp». Leste vakten bare de to «tablet»-listene, fant den to
// ruter i stedet for seks.
//
// For hver av dem: finnes det oppsett for oversetting i mappa
// (`@/lib/oversett`, `OversettProvider` eller `useT`)?
//
// Den beviser IKKE at hver streng er oversatt — det ville krevd at
// vakten forsto hvilken tekst som er brukersynlig, og en vakt som
// gjetter det ville meldt falske funn på hver kommentar. Den beviser at
// ruta har språk i det hele tatt. Det er den grove forskjellen, og det
// er den som faktisk fantes.
//
// FASITEN KAN BARE KRYMPE. En ny tablet-rute uten språk er rød med en
// gang, og en rute som får språk må strammes ut av fasiten.
//
// ---------------------------------------------------------------------
// HVA SOM STÅR IGJEN, OG HVORFOR
//
// Fem av seks er gjort. Én står igjen, og den er et valg, ikke en
// forglemmelse:
//
//   /mine-opplysninger  Personopplysningssida etter aml. § 9-2. Ordene
//                       er juridiske, og en maskinoversettelse av dem
//                       er en annen slags beslutning enn «Stemple inn»:
//                       arbeidsgiver dokumenterer at den ansatte ER
//                       informert, og da må teksten være til å stå for.
//                       Det er Roberts valg, ikke vaktens.
//
// `/ikmat` var det stygge tilfellet. `TabletIkMat` HADDE et `ord`-prop
// og en `t()` fra dagen den ble skrevet — sida sendte den bare aldri
// noe, så `t()` var identiteten. Maskineriet sto der og virket på
// ingenting, og koden så ferdig ut. En gjennomlesing ville bekreftet
// den.
// =====================================================================

const ROT = process.cwd()
const APP = join(ROT, 'src', 'app', '(beskyttet)')
const FASIT = join(ROT, 'src', 'lib', 'redesign', 'tabletsprakfasit.json')

// ALLE navigasjonslistene, ikke bare de to som heter «tablet».
//
// Foerste utgave leste `TABLETMENY` + `NETTBRETTFLATER` og fant to ruter
// uten spraak. Men `NETTBRETTFLATER` er ikke fasit for hva nettbrettet
// naar - `/mine-opplysninger`, `/nyheter`, `/merker` og `/ikmat` staar
// med rollen [T] andre steder i fila, og naas fra foten under «Hjelp».
//
// Det er samme feil som vakthunden hadde: en liste som HETER fasit, og
// en virkelighet som er stoerre. Rollen er fasit, ikke listenavnet.
const TABLETRUTER = [...new Set(
  [
    ...TABLETMENY,
    ...NETTBRETTFLATER,
    ...FANEGRUPPER.flatMap((g) => g.faner),
    ...SEKSJONER.flatMap((s) => s.punkter),
  ]
    .filter((p) => p.roller.includes('butikkbruker_tablet'))
    .map((p) => p.sti),
)].sort()

/** Har ruta oppsett for oversetting i det hele tatt? */
function harSprak(rute: string): boolean {
  const mappe = join(APP, rute.replace(/^\//, ''))
  if (!existsSync(mappe)) return false
  for (const navn of readdirSync(mappe)) {
    if (!navn.endsWith('.tsx') || navn.includes('.test.')) continue
    const kilde = readFileSync(join(mappe, navn), 'utf8')
    if (/@\/lib\/oversett|OversettProvider|useT\b/.test(kilde)) return true
  }
  return false
}

const uten = TABLETRUTER.filter((r) => !harSprak(r)).sort()

describe('målingen ser nettbrettet', () => {
  test('KANARIFUGL: lista over tablet-ruter er ikke tom', () => {
    // Bytter `navigasjon.ts` form, blir lista tom — og «ingen rute
    // mangler språk» blir sant fordi ingen rute finnes.
    expect(TABLETRUTER.length, 'fant nesten ingen tablet-ruter').toBeGreaterThan(10)
    expect(TABLETRUTER).toContain('/rutiner')
  })

  test('KANARIFUGL: den finner språk der språk finnes', () => {
    // `/rutiner` og `/sjekkpunkt` ER oversatt. Slutter lesingen å treffe
    // — feil mappe, endret importnavn — ville HVER rute havnet i lista,
    // og fasiten hadde sett ut som et mye større problem enn det er.
    expect(harSprak('/sjekkpunkt'), '/sjekkpunkt er oversatt').toBe(true)
    expect(harSprak('/produksjonsplan'), '/produksjonsplan er oversatt').toBe(true)
  })

  test('KANARIFUGL: en rute uten språk blir sett', () => {
    expect(harSprak('/finnes-ikke-i-det-hele-tatt')).toBe(false)
  })
})

describe('tablet-språkvakten', () => {
  test('ingen NY tablet-rute uten språk', () => {
    if (process.env.OPPDATER_FASIT === '1') {
      writeFileSync(FASIT, `${JSON.stringify({ utenSprak: uten }, null, 2)}\n`)
      return
    }
    const fasit = JSON.parse(readFileSync(FASIT, 'utf8')) as { utenSprak: string[] }
    const nye = uten.filter((r) => !fasit.utenSprak.includes(r))

    expect(
      nye,
      `\nDisse tablet-rutene har ingen oversetting:\n${nye.map((r) => `  ${r}`).join('\n')}\n\n`
      + 'Nettbrettet har en flagg-velger, og den som velger polsk faar '
      + 'polsk paa halve appen og norsk paa resten. Det ser ut som hennes '
      + 'feil, ikke som et hull.\n\n'
      + 'Hent `oversettTabletOrd(sprak)` i page.tsx og send strengene '
      + 'gjennom `t()` - se /vaar-stasjon for moensteret. Faste fraser '
      + 'foeres inn i `src/lib/tabletord.ts`.\n',
    ).toEqual([])
  })

  test('fasiten kan bare krympe', () => {
    if (process.env.OPPDATER_FASIT === '1') return
    const fasit = JSON.parse(readFileSync(FASIT, 'utf8')) as { utenSprak: string[] }
    const ryddet = fasit.utenSprak.filter((r) => !uten.includes(r))
    expect(
      ryddet,
      `\n${ryddet.join(', ')} har faatt spraak - bra. Stram fasiten:\n`
      + '  OPPDATER_FASIT=1 npx vitest run src/lib/redesign\n\n'
      + 'Uten strammingen kan den falle ut igjen uten at noe blir roedt.',
    ).toEqual([])
  })
})
