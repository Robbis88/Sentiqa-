import { describe, it, expect } from 'vitest'
import { readFileSync, existsSync, readdirSync, statSync } from 'node:fs'
import { FRIST_MIN } from '../ukebrief/klar'
import { join } from 'node:path'

// =====================================================================
// EN CRON SOM PEKER FEIL SIER INGENTING.
//
// Vercel kaller stien i `vercel.json`. Finnes ruta ikke, svarer Next med
// 404 — og en 404 fra en cron ser ut akkurat som en cron som kjørte og
// ikke hadde noe å gjøre. Ingen logg roper, ingen bruker merker det, og
// det oppdages først når noen spør hvorfor et brev aldri kom.
//
// Den motsatte veien er like stille: en cron-rute som ingen plan
// utløser. Den bygger, den svarer på kall, den ser komplett ut — og
// kjører aldri. `/api/cron/ukebrief` var nettopp det, med vilje, fram til
// 2026-09-03.
//
// Begge retninger måles her.
// =====================================================================

const ROT = process.cwd()
const CRONMAPPE = join(ROT, 'src', 'app', 'api', 'cron')

type Cron = { path: string; schedule: string }
const planer: Cron[] = JSON.parse(readFileSync(join(ROT, 'vercel.json'), 'utf8')).crons ?? []

/**
 * Cron-ruter som med vilje IKKE står i `vercel.json`.
 *
 * Skal stå tom. En rute her må ha en skrevet grunn — «vi rakk det ikke»
 * er ikke en; da hører den hjemme i planen eller i papirkurven.
 */
const UTEN_PLAN: Record<string, string> = {
  '/api/cron/ukebrief':
    'Manuell inngang. Planen peker paa -slott-1/-2/-3 fordi Vercels '
    + 'validator fra 2026-09-15 avviser flere cron-oppfoeringer med samme '
    + 'path (invalid_routes). Ruta er fortsatt DEN som baerer logikken, og '
    + 'den brukes manuelt med ?torrkjor=1 og ?uke=. Se '
    + 'src/app/api/cron/ukebrief-slott-1/route.ts.',
}

/**
 * Er dette ukebriefen — uansett hvilken inngang den kalles gjennom?
 *
 * DE TRE SLOTTENE ER ÉN JOBB. Fram til 2026-09-15 sto de som tre
 * oppfoeringer mot samme path, slik Vercel selv dokumenterer. Da
 * validatoren begynte aa avvise det, ble de tre unike stier — men det er
 * fortsatt ett brev med tre forsoek, og paastandene under maaler jobben,
 * ikke stien.
 *
 * Skrives dette om til ett slott igjen, faller de tre siste testene i
 * fila — og det er meningen.
 */
const erUkebrief = (sti: string): boolean =>
  /^\/api\/cron\/ukebrief(-slott-\d+)?$/.test(sti)

function rutefil(sti: string): string {
  return join(ROT, 'src', 'app', ...sti.split('/').filter(Boolean), 'route.ts')
}

function cronruter(): string[] {
  const ut: string[] = []
  for (const n of readdirSync(CRONMAPPE)) {
    if (!statSync(join(CRONMAPPE, n)).isDirectory()) continue
    if (existsSync(join(CRONMAPPE, n, 'route.ts'))) ut.push(`/api/cron/${n}`)
  }
  return ut
}

describe('cron-stiene i vercel.json', () => {
  it('KANARIFUGL: vakten finner planene og rutene i det hele tatt', () => {
    // Uten dette ville «ingen avvik» også vært svaret hvis fila ikke ble
    // lest, eller mappa var tom — og en vakt som slutter å se ser ut som
    // en vakt som ikke finner noe.
    expect(planer.length).toBeGreaterThanOrEqual(4)
    expect(cronruter().length).toBeGreaterThanOrEqual(4)
    expect(planer.map((p) => p.path)).toContain('/api/cron/natt')
  })

  it('hver plan peker på en rute som finnes', () => {
    const doede = planer.filter((p) => !existsSync(rutefil(p.path))).map((p) => p.path)
    expect(doede, `plan uten rute (gir 404 i stillhet): ${doede.join(', ')}`).toEqual([])
  })

  it('hver cron-rute har en plan som utløser den', () => {
    const planlagte = new Set(planer.map((p) => p.path))
    const uten = cronruter().filter((r) => !planlagte.has(r) && !(r in UTEN_PLAN))
    expect(uten, `cron-rute som aldri kjører: ${uten.join(', ')}`).toEqual([])
  })

  it('hver plan har et gyldig uttrykk med fem felt', () => {
    for (const p of planer) {
      expect(p.schedule.trim().split(/\s+/), `${p.path} har ugyldig schedule «${p.schedule}»`)
        .toHaveLength(5)
    }
  })

  // Tidspunktet er ikke tilfeldig, og en endring av det skal være et valg.
  // Nattjobben (03:00 UTC) henter gårsdagens salgsfil og regner ukerapport;
  // kjørte briefen før den, ville søndagen manglet i hver eneste uke.
  it('ukebriefen går mandag, og etter nattjobben', () => {
    const brief = planer.filter((p) => erUkebrief(p.path))
    expect(brief.length, 'ukebriefen har ingen plan').toBeGreaterThan(0)
    const natt = Number(planer.find((p) => p.path === '/api/cron/natt')!.schedule.split(/\s+/)[1])
    for (const b of brief) {
      const [, time, , , ukedag] = b.schedule.split(/\s+/)
      expect(ukedag, `«${b.schedule}» går ikke mandag`).toBe('1')
      expect(Number(time), `«${b.schedule}» går før nattjobben`).toBeGreaterThan(natt)
    }
  })

  // EN STILLE FEILMAATE. Briefen VENTER naar soendagens salgsfil ikke er
  // kommet, og sender foerst naar fristen i `klar.ts` er naadd. Finnes det
  // ingen kjoering etter fristen, blir det aldri sendt i en uke der fila
  // er sen - og ingen ser at brevet uteble.
  //
  // Regnet i VINTERTID (UTC+1), som er det minste paalegget. En kjoering
  // som naar fristen om sommeren, men ikke om vinteren, ville virket i
  // september og sviktet i november.
  it('en kjoering ligger etter fristen, ogsaa i vintertid', () => {
    const timer = planer
      .filter((p) => erUkebrief(p.path))
      .map((p) => Number(p.schedule.split(/\s+/)[1]))
    const senesteOslo = Math.max(...timer) + 1
    expect(senesteOslo * 60,
      `siste kjoering er ${Math.max(...timer)}:00 UTC = ${senesteOslo}:00 om vinteren, `
      + `men fristen er ${FRIST_MIN / 60}:00. Da sendes aldri en uke med sen salgsfil.`)
      .toBeGreaterThanOrEqual(FRIST_MIN)
  })

  it('flere kjoeringer, saa en uke med sen fil faar et nytt forsoek', () => {
    // Duplikatsperren gjoer gjentakelse trygg; det var dét den var til for.
    const antall = planer.filter((p) => erUkebrief(p.path)).length
    expect(antall, 'én kjoering gir ingen mulighet til aa vente paa fila').toBeGreaterThanOrEqual(2)
  })

  // ===================================================================
  // SLOTTENE BAERER INGEN EGEN LOGIKK, OG DET MAA MAALES
  // ===================================================================
  //
  // De tre slott-rutene finnes bare for aa gi Vercels validator unike
  // stier. Faar én av dem sin egen kropp - en kopiert sjekk, et eget
  // filter paa mottakere - har vi to utsendingsregler som skiller lag i
  // stillhet, og den ene sender brev ingen har vurdert.
  //
  // Uten denne testen ville en uthulet slott-rute vaert usynlig: den
  // bygger, den svarer 200, og den gjoer ingenting. Samme form som en
  // jobb som returnerer vellykket uten aa ha gjort jobben.
  //
  // Paastanden er streng med vilje: UTENOM kommentarer skal fila vaere
  // NOEYAKTIG re-eksporten. Da finnes det ikke plass til logikk.
  // ===================================================================
  it('hver slott-rute er kun en re-eksport av den ekte handleren', () => {
    const slott = cronruter().filter((r) => /-slott-\d+$/.test(r))

    // KANARIFUGL: finnes det ingen slott-ruter, maaler testen ingenting
    // og ville staatt groenn gjennom hele omgaaelsen.
    expect(slott.length, 'ingen slott-ruter funnet - maaler denne testen noe?')
      .toBeGreaterThanOrEqual(2)

    for (const r of slott) {
      const kode = readFileSync(rutefil(r), 'utf8')
        .split('\n')
        .filter((l) => !/^\s*\/\//.test(l) && l.trim() !== '')
        .join('\n')
        .trim()
      expect(kode, `${r} har egen logikk - den skal bare re-eksportere`)
        .toBe("export { GET, maxDuration } from '../ukebrief/route'")
    }
  })
})
