import { describe, it, expect } from 'vitest'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { tilServeren, FOR_STOR } from './rute'

// Kelsars to filer, med sine faktiske stoerrelser.
const BP26 = 26.6 * 1024 * 1024
const BP25 = 10.5 * 1024 * 1024

describe('tilServeren', () => {
  it('KANARIFUGL: en BP går til serveren uansett hvor liten den er', () => {
    // DETTE ER HELE GRUNNEN TIL AT FILA FINNES.
    //
    // BP26 (26,6 MB) traff serverveien fordi den er over 12 MB. BP25
    // (10,5 MB) gjorde det ikke, og fikk «Ukjent/ustøttet filtype» -
    // paa en fil systemet kjenner igjen uten problemer.
    expect(tilServeren({ navn: 'BP25.xlsm', storrelse: BP25, type: 'st1_bp' })).toBe(true)
    expect(tilServeren({ navn: 'BP26.xlsx', storrelse: BP26, type: 'st1_bp' })).toBe(true)
    // Og selv en absurd liten en. Regelen skal ikke hvile paa tall.
    expect(tilServeren({ navn: 'liten.xlsx', storrelse: 1024, type: 'st1_bp' })).toBe(true)
  })

  it('sender store filer til serveren før typen er kjent', () => {
    // Foerste runde: vi vet bare navn og stoerrelse. En 27 MB fil skal
    // aldri aapnes i fanen for aa finne ut hva den er.
    expect(tilServeren({ navn: 'BP26.xlsx', storrelse: BP26 })).toBe(true)
    expect(tilServeren({ navn: 'stor.xlsx', storrelse: FOR_STOR + 1 })).toBe(true)
    expect(tilServeren({ navn: 'liten.xlsx', storrelse: FOR_STOR - 1 })).toBe(false)
  })

  it('sender PDF, CSV og tekst til serveren', () => {
    // Nettleserparseren her kan bare xlsx; en CSV kveler zip-leseren.
    for (const n of ['a.pdf', 'b.csv', 'c.txt', 'D.CSV']) {
      expect(tilServeren({ navn: n, storrelse: 1000 }), n).toBe(true)
    }
  })

  it('lar de andre rapportene parses i nettleseren', () => {
    // De har hver sin parser der, og det er poenget med aa parse foer
    // opplasting: brukeren ser tallene med en gang.
    for (const t of [
      'st1_salgsstatistikk', 'st1_salesperhour_inneute',
      'st1_cashierstats', 'salgsgrid_varetrans', 'regnskap_resultat',
    ] as const) {
      expect(tilServeren({ navn: 'f.xlsx', storrelse: 5000, type: t }), t).toBe(false)
    }
  })

  it('KANARIFUGL: opplasteren bruker regelen, og har ingen egen kopi', () => {
    // En regel som finnes to steder er en regel som skiller lag. Fant
    // vi den samme if-setningen i komponenten igjen, ville denne testen
    // vaert groenn mens produktet var uendret.
    const kilde = readFileSync(
      join(process.cwd(), 'src', 'app', '(beskyttet)', 'import', 'klient-opplaster.tsx'),
      'utf8',
    )
    expect(kilde).toContain('tilServeren(')
    // Den gamle formen skal vaere borte - baade stoerrelsessjekken og
    // filnavnsregexen hoerer hjemme i `rute.ts` naa.
    expect(kilde).not.toMatch(/size > FOR_STOR/)
    expect(kilde).not.toMatch(/\\\.\(pdf\|csv\|txt\)/)
  })

  it('.xlsm er med i det filvelgeren tilbyr', () => {
    // BP25 er makroaktivert. Uten `.xlsm` i `accept` maa brukeren bytte
    // til «alle filer» for aa i det hele tatt kunne velge den - og da
    // ser det ut som systemet ikke stoetter fila.
    for (const f of ['klient-opplaster.tsx', 'opplaster.tsx']) {
      const kilde = readFileSync(
        join(process.cwd(), 'src', 'app', '(beskyttet)', 'import', f), 'utf8',
      )
      expect(kilde, f).toContain('.xlsm')
    }
  })
})

describe('en fil som alt er lastet opp er ikke en blindvei', () => {
  const les = (f: string) =>
    readFileSync(join(process.cwd(), 'src', 'app', '(beskyttet)', 'import', f), 'utf8')

  it('KANARIFUGL: duplikatsjekken sier HVILKEN jobb det gjelder', () => {
    // `return { ok: true, hoppet: true }` kastet bort id-en, og «Hoppet
    // over» ble staaende uten vei videre. Statuslista viser bare de 50
    // siste jobbene, saa en BP fra i fjor staar ikke der - og da har
    // brukeren ingen maate aa kjoere den om igjen paa.
    const h = les('handlinger.ts')
    expect(h).toMatch(/23505/)
    expect(h).toMatch(/jobbId:/)
  })

  it('KANARIFUGL: opplasteren tilbyr handlingen der brukeren staar', () => {
    const k = les('klient-opplaster.tsx')
    expect(k).toContain('behandleJobb')
    expect(k).toContain('f.jobbId')
    // Og den maa faktisk vaere en knapp, ikke bare en tekst som naevner den.
    expect(k).toMatch(/BehandleKnapp/)
  })
})
