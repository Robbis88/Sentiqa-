import { describe, expect, test } from 'vitest'
import { readFileSync, readdirSync } from 'node:fs'
import { join } from 'node:path'
import {
  aggregerendeDaglige, filtrererDrivstoff, sisteDefinisjon,
} from '../sql/salgskilde'

// =====================================================================
// Ingen VISNING skal summere kroner med drivstoff i.
//
// AGENTS.md, siden april 2026: «alt som summerer kroner eller antall
// skal lese `v_butikksalg`.» Drivstoff er ~68 % av omsetningen, det
// betjener seg selv på pumpa, og det drukner alt annet på datoer der
// det er med.
//
// DA DET SIST VAR UFILTRERT ET STED, viste ukerapportens forside
// +216 % vekst som ikke fantes: årets uke MED drivstoff mot fjorårets
// UTEN. `0084`/`0085` ryddet opp — men `v_salg_per_stasjon_dag` fra
// `0004` kom aldri med, og den mater /salg, nettbrettets vekstkort,
// butikksjef-dashbordet og AI-verktøyet.
//
// ---------------------------------------------------------------------
// DEN HADDE SIN EGEN PARSER, OG DEN SÅ TRE TING FEIL
//
// Fram til 2026-09-08 leste denne fila migrasjonene med sine egne
// regexer, ved siden av `src/lib/sql/salgskilde.ts`. To lesninger av
// samme regel, og de hadde skilt lag:
//
//  1. **Aliaset.** `summererPenger` krevde `sum(omsetning_eks_mva`.
//     `v_retailer_drivstofftreff` skriver `sum(d.omsetning_eks_mva)` —
//     og var dermed usynlig. Det gjelder hver eneste visning som gir
//     tabellen et alias, altså de fleste.
//  2. **Kommentarene.** Kroppen ble prøvd rå, så en kommentar som
//     NEVNTE `ENERGI` talte som filter.
//  3. **Koden `10`.** Den krevde `avdeling_kode <> '10'`. Baselinen
//     2026-08-28 viste at drivstoff har kode `1000` hos Kelsar; `10`
//     finnes ikke i data. Vakten krevde altså den ene armen som ikke
//     kan treffe, og etter `0152` er `retailer_koderegel` den riktige.
//
// Nå går begge gjennom `salgskilde.ts`. Det er ikke bare mindre kode:
// to lesninger av samme regel er to steder å ta feil, og den ene av
// dem er alltid den ingen ser på.
//
// Denne fila er den VISNINGS-halvparten — `salgskilde.test.ts` dekker
// funksjoner og selve mappingen.
// =====================================================================

const KATALOG = join(process.cwd(), 'supabase', 'migrations')
const FILER = readdirSync(KATALOG).filter((f) => f.endsWith('.sql')).sort()
  .map((f) => ({ fil: f, sql: readFileSync(join(KATALOG, f), 'utf8') }))

describe('målingen forstår det den ser', () => {
  test('den ser faktisk migrasjonene', () => {
    // Peker stien feil, blir lista tom og vakten grønn uten å ha lest
    // en eneste visning.
    expect(FILER.length, `fant nesten ingen migrasjoner i ${KATALOG}`)
      .toBeGreaterThan(140)
    expect(sisteDefinisjon(FILER, 'v_butikksalg'), 'v_butikksalg skal finnes')
      .not.toBeNull()
    expect(sisteDefinisjon(FILER, 'v_salg_per_stasjon_dag')).not.toBeNull()
  })

  test('KANARIFUGL: et aliasert sum-kall er fortsatt et sum-kall', () => {
    // Den gamle vakten krevde `sum(omsetning_eks_mva`. Hver visning som
    // gir tabellen et alias — `sum(d.omsetning_eks_mva)` — var usynlig
    // for den, og det er den vanligste skrivemåten i dette repoet.
    const alias = [{
      fil: '0001.sql',
      sql: 'create or replace view public.v() as '
        + 'select sum(d.omsetning_eks_mva) from public.daglig_salg d;',
    }]
    expect(aggregerendeDaglige(alias).map((f) => f.navn)).toEqual(['v'])
  })

  test('KANARIFUGL: en kommentar om ENERGI filtrerer ingenting', () => {
    expect(filtrererDrivstoff("-- vi holder ENERGI utenfor her\nselect 1"))
      .toBe(false)
    expect(filtrererDrivstoff("/* avdeling_navn <> 'ENERGI' */ select 1"))
      .toBe(false)
  })

  test('KANARIFUGL: koden 10 alene er ikke et filter', () => {
    // Armen som aldri traff. Drivstoff har kode 1000 hos Kelsar, og
    // hvilken kode en kjede bruker er retailer-data uansett.
    expect(filtrererDrivstoff("where avdeling_kode <> '10'")).toBe(false)
    expect(filtrererDrivstoff("where avdeling_kode not in ('10', '250')"))
      .toBe(false)
  })

  test('kjenner igjen begge de lovlige måtene', () => {
    expect(filtrererDrivstoff(
      "where upper(coalesce(ds.avdeling_navn, '')) <> 'ENERGI'",
    ), 'navnesjekken fra 0084').toBe(true)
    expect(filtrererDrivstoff(
      "where exists (select 1 from public.retailer_koderegel r ...)",
    ), 'mappingen fra 0152').toBe(true)
    expect(filtrererDrivstoff(
      "where upper(coalesce(avdeling_navn, '')) <> 'ENERGI'",
    ), 'navnesjekken uten alias').toBe(true)
  })
})

describe('drivstoffvakten', () => {
  const visninger = aggregerendeDaglige(FILER).filter((f) => f.slag === 'view')

  test('KANARIFUGL: det FINNES visninger å vurdere', () => {
    // Uten denne er «ingen visning summerer med drivstoff i» sant fordi
    // vakten ikke fant en eneste visning å se på.
    expect(visninger.length, 'fant ingen aggregerende visninger over daglig_salg')
      .toBeGreaterThan(0)
  })

  test('hver visning som summerer fra daglig_salg filtrerer drivstoff', () => {
    const funn = visninger
      .filter((v) => !filtrererDrivstoff(sisteDefinisjon(FILER, v.navn)!.kropp))
      .map((v) => `  ${v.navn}  (${v.fil})`)

    expect(funn, '\nDisse visningene summerer kroner rett fra daglig_salg, '
      + `altsaa MED drivstoff:\n${funn.join('\n')}\n\n`
      + 'Drivstoff er ~68 % av omsetningen og drukner alt annet. Les '
      + '`public.v_butikksalg` i stedet, eller les `retailer_koderegel` '
      + 'som `0152` gjor.\n')
      .toEqual([])
  })
})
