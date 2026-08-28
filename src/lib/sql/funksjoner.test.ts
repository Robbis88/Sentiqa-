import { describe, it, expect } from 'vitest'
import { readFileSync, writeFileSync, existsSync } from 'node:fs'
import { join } from 'node:path'
import { lovedeFunksjoner, genererFunksjonssjekk, lesFil } from './funksjoner'

const ROT = process.cwd()
const MIGRASJONER = join(ROT, 'supabase/migrations')
const FASIT = join(ROT, 'supabase/tests/funksjoner_finnes.sql')

const navn = lovedeFunksjoner(MIGRASJONER)

describe('funksjonene migrasjonene lover', () => {
  it('leser et fornuftig antall ut av migrasjonene', () => {
    // KANARIFUGL. Slutter parseren å treffe — en endret skrivemåte, en
    // flyttet mappe — blir lista tom, og «ingen mangler» ser nøyaktig
    // ut som «alt er på plass». Tallet er et gulv, ikke en fasit.
    expect(navn.length).toBeGreaterThan(20)
  })

  it('kjenner funksjonen som faktisk manglet i produksjon', () => {
    // 0075. Den var borte i månedsvis, og symptomet var «Ingen
    // stasjoner.» på /maaling. Forsvinner den fra lista, måler ikke
    // vakten det den ble skrevet for.
    expect(navn).toContain('malekort_stasjoner')
  })

  it('kjenner hjelperne RLS hviler på', () => {
    expect(navn).toContain('gjeldende_retailer_id')
    expect(navn).toContain('gjeldende_rolle')
    expect(navn).toContain('mine_stasjoner')
  })

  it('EN KOMMENTAR ER IKKE EN SETNING', () => {
    // Migrasjonene siterer hverandre — `0138` siterer `0112`, `0150`
    // nevner `0110`. Uten strippingen ville en funksjon som bare er
    // OMTALT blitt krevd som om den var opprettet, og vakten hadde meldt
    // et funn som ikke finnes.
    const sett = new Set<string>()
    lesFil(`
      -- create function public.bare_omtalt() -- staar i en kommentar
      /* create function public.ogsaa_omtalt() */
      create or replace function public.ekte() returns void as $$ $$;
    `, sett)
    expect([...sett]).toEqual(['ekte'])
  })

  it('respekterer drop — en fjernet funksjon kreves ikke', () => {
    // `0104` dropper og erstatter. Uten rekkefølgen ville hver bevisst
    // fjerning stått som et evig funn, og en vakt med falske positive
    // lærer folk å se bort fra rødt.
    const sett = new Set<string>()
    lesFil('create function public.a() returns void as $$ $$;', sett)
    lesFil('create function public.b() returns void as $$ $$;', sett)
    expect([...sett].sort()).toEqual(['a', 'b'])
    lesFil('drop function if exists public.a();', sett)
    expect([...sett]).toEqual(['b'])
  })

  it('drop og gjenopprett i SAMME fil lar funksjonen leve', () => {
    // Den vanligste formen i repoet. Leses drop sist, ville hver slik
    // migrasjon sett ut som en sletting.
    const sett = new Set<string>()
    lesFil(`
      drop function if exists public.puls_ins();
      create or replace function public.puls_ins() returns void as $$ $$;
    `, sett)
    expect([...sett]).toEqual(['puls_ins'])
  })
})

describe('den genererte katalogsjekken', () => {
  const generert = genererFunksjonssjekk(navn)

  it('har kanarifugl og kaster på funn', () => {
    expect(generert).toContain('VAKTEN MAALER INGENTING')
    expect(generert).toContain('raise exception')
    // Kvitteringen må være en RAD. SQL Editor viser ikke `raise notice`,
    // og en vakt ingen ser svaret fra blir ikke kjørt igjen.
    expect(generert).toContain("select 'OK'")
  })

  it('er i takt med migrasjonene', () => {
    if (process.env.OPPDATER_FUNKSJONER) {
      writeFileSync(FASIT, generert)
      return
    }
    expect(existsSync(FASIT), `${FASIT} mangler`).toBe(true)
    expect(
      readFileSync(FASIT, 'utf8').replace(/\r\n/g, '\n'),
      'Fasitfila er ikke i takt med migrasjonene. '
      + 'Kjor: OPPDATER_FUNKSJONER=1 npx vitest run src/lib/sql',
    ).toBe(generert)
  })
})
