import { readFileSync, readdirSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, it } from 'vitest'

// =====================================================================
// EN RAPPORTTYPE KODEN BRUKER MÅ FINNES I ENUM-EN
//
// `import_jobber.rapporttype` er en Postgres-enum. Legger man til en ny
// `Rapporttype` i TypeScript uten en `alter type ... add value`, feiler
// hver opplasting av den filtypen med
//
//     invalid input value for enum rapporttype: "..."
//
// og det skjer FØRST i produksjon, på en ekte fil, etter at parseren,
// testene, CI og en merge alle har vært grønne.
//
// ---------------------------------------------------------------------
// DETTE HAR SKJEDD TO GANGER
//
//   0093   `st1_salesperhour_inneute` og `salgsgrid_varetrans` — begge
//          hadde vært i bruk lenge. Køveien satte typen med en UPDATE
//          hvis feil aldri ble sjekket, så jobben gikk videre med
//          rapporttype 'ukjent' og dataene landet. Nettleserveien
//          kastet. Samme fil, to veier, én virket.
//
//   0189   `easyatwork_lonnsgrunnlag`. 0093 sto der med advarselen
//          skrevet ut, og den ble gjentatt likevel.
//
// Andre gang er ikke uflaks. Det er en regel som ikke ble til en vakt.
// Denne testen er den vakten: den leser TypeScript-unionen og
// migrasjonene, og krever at hver verdi står begge steder.
//
// Den kan ikke se om migrasjonen faktisk er KJØRT mot produksjon — det
// vet bare basen. Men den fanger den formen feilen faktisk har hatt
// begge gangene: at fila aldri ble skrevet.
// =====================================================================

const ROT = join(__dirname, '..', '..', '..')
const MIGRASJONER = join(ROT, 'supabase', 'migrations')

/** Verdiene i `Rapporttype`-unionen i `typer.ts`. */
function iKoden(): string[] {
  const kilde = readFileSync(join(__dirname, 'typer.ts'), 'utf8')
  // INGEN `\n\n` HER. Repoet sjekkes ut med CRLF på Windows, og en regex
  // som krever `\n\n` treffer aldri der — grønn i CI, rød hos Robert.
  // Unionen leses derfor som «ett eller flere `| 'x'`-ledd», som er
  // uavhengig av linjeskift helt og holdent.
  const m = /export type Rapporttype =((?:\s*\|\s*'[^']+')+)/.exec(kilde)
  if (!m) throw new Error('Fant ikke Rapporttype-unionen i typer.ts.')
  return [...m[1].matchAll(/'([^']+)'/g)].map((x) => x[1])
}

/** Verdiene enum-en har fått i migrasjonene, `create` og `add value`. */
function iMigrasjonene(): Set<string> {
  const ut = new Set<string>()
  for (const fil of readdirSync(MIGRASJONER).filter((f) => f.endsWith('.sql'))) {
    const sql = readFileSync(join(MIGRASJONER, fil), 'utf8')

    // `create type public.rapporttype as enum ( ... )`
    // Fram til `);`, ikke til første `)`. Verdiene i `0002` har
    // kommentarer med parentes i — «-- daglig, produktnivå (§6)» — og en
    // ikke-grisk `\)` stopper der. Da leste vakten to verdier av seks og
    // så ut som den virket.
    const skapt = /create type public\.rapporttype as enum\s*\(([\s\S]*?)\)\s*;/i.exec(sql)
    if (skapt) for (const v of skapt[1].matchAll(/'([^']+)'/g)) ut.add(v[1])

    // `alter type public.rapporttype add value [if not exists] 'x'`
    for (const v of sql.matchAll(
      /alter type public\.rapporttype\s+add value(?:\s+if not exists)?\s+'([^']+)'/gi,
    )) ut.add(v[1])

    // `alter type public.rapporttype rename value 'a' to 'b'`
    for (const v of sql.matchAll(
      /alter type public\.rapporttype\s+rename value\s+'([^']+)'\s+to\s+'([^']+)'/gi,
    )) { ut.delete(v[1]); ut.add(v[2]) }
  }
  return ut
}

describe('rapporttype-enumen', () => {
  it('har en verdi for hver Rapporttype koden kan sette', () => {
    const enumen = iMigrasjonene()
    const mangler = iKoden().filter((t) => !enumen.has(t))
    expect(
      mangler,
      'Disse rapporttypene finnes i TypeScript, men ikke i Postgres-enumen. '
      + 'Hver opplasting av dem vil feile med «invalid input value for enum '
      + 'rapporttype». Skriv en migrasjon med `alter type public.rapporttype '
      + 'add value if not exists \'…\'` — og den må kjøres ALENE, fordi '
      + 'Postgres nekter å bruke en ny enum-verdi i samme transaksjon '
      + `(55P04):\n  ${mangler.join('\n  ')}`,
    ).toEqual([])
  })

  // ===================================================================
  // KANARIFUGLEN
  //
  // Vakten er verdiløs hvis den leser tom. En regex som slutter å treffe
  // — `typer.ts` omskrevet, `create type` på én linje — ville gitt to
  // tomme mengder og en grønn test. Det er nøyaktig formen «en vakt som
  // slutter å se»: den ser ut som en vakt som ikke finner noe.
  // ===================================================================
  it('leser faktisk begge sidene', () => {
    const koden = iKoden()
    const enumen = iMigrasjonene()
    expect(koden.length).toBeGreaterThanOrEqual(10)
    expect(koden).toContain('ukjent')
    expect(koden).toContain('easyatwork_lonnsgrunnlag')
    // `0002` skaper typen, seks senere migrasjoner utvider den.
    expect(enumen.size).toBeGreaterThanOrEqual(10)
    expect(enumen).toContain('st1_salgsstatistikk')
  })

  it('følger et omdøpt navn, i stedet for å kreve det gamle', () => {
    // `0006` døpte om 'visma_resultat' til 'regnskap_resultat'. Uten den
    // regelen ville vakten meldt 'regnskap_resultat' som manglende, og
    // en falsk rød er like ille som en falsk grønn — den lærer folk å
    // legge inn unntak.
    const enumen = iMigrasjonene()
    expect(enumen).toContain('regnskap_resultat')
    expect(enumen).not.toContain('visma_resultat')
  })

  it('sier fra om en type som bare finnes i koden', () => {
    // Injisert regresjon: beviser at påstanden over faktisk feller noe.
    const enumen = iMigrasjonene()
    const paafunn = ['ukjent', 'st1_ny_rapport_som_ikke_finnes']
      .filter((t) => !enumen.has(t))
    expect(paafunn).toEqual(['st1_ny_rapport_som_ikke_finnes'])
  })
})
