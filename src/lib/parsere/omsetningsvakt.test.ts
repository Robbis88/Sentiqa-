import { describe, expect, it } from 'vitest'
import { ParserFeil } from './felles'
import { sjekkOmsetningslinje, vokteteKoder, SKJUL_OMS_KODER } from './omsetningsvakt'

// `0203` slipper inn regnskapsfiler fra før februar 2026. Kostnadssiden
// er dekket av kontoregisteret og `begrep`; omsetningssiden har sin egen
// hardkodede kodeliste, og den var aldri målt. Denne fila måler den.

describe('sjekkOmsetningslinje', () => {
  it('slipper gjennom linjene slik de står i dag', () => {
    expect(() => sjekkOmsetningslinje('10', 'Drivstoff')).not.toThrow()
    expect(() => sjekkOmsetningslinje('250', 'Pant')).not.toThrow()
    expect(() => sjekkOmsetningslinje('40', 'CR')).not.toThrow()
  })

  it('slipper gjennom en helt vanlig varegruppe', () => {
    // Vakten kjenner tre linjer, ikke hele kontoplanen. En ukjent linje
    // er ikke et funn — og en vakt som feller riktige filer blir skrudd av.
    expect(() => sjekkOmsetningslinje('120', 'Mat')).not.toThrow()
    expect(() => sjekkOmsetningslinje('210', 'Bilvask')).not.toThrow()
    expect(() => sjekkOmsetningslinje('999', 'Noe helt nytt')).not.toThrow()
  })

  it('tåler at arket skriver koden inni navnecellen', () => {
    expect(() => sjekkOmsetningslinje('10', '10 Drivstoff')).not.toThrow()
  })

  it('tåler manglende kode og tomt navn', () => {
    expect(() => sjekkOmsetningslinje(null, 'Drivstoff')).not.toThrow()
    expect(() => sjekkOmsetningslinje('10', '   ')).not.toThrow()
  })

  // ---- KANARIFUGLENE --------------------------------------------------

  it('KANARI: kjent kode med feil navn felles', () => {
    // Koden betyr noe annet enn vi tror. Da holder filteret feil linje
    // utenfor, og butikksjefens omsetning mangler en varegruppe.
    expect(() => sjekkOmsetningslinje('10', 'Kioskvarer')).toThrow(ParserFeil)
    expect(() => sjekkOmsetningslinje('10', 'Kioskvarer')).toThrow(/skal være/)
  })

  it('KANARI: drivstoff på et nytt nummer felles — den farlige veien', () => {
    // Her EKSISTERER drivstofflinja fortsatt, men på et nummer filteret
    // ikke ser etter. Uten vakten blir den stille regnet med, og
    // drivstoff er ~68 % av omsetningen: hver sammenligning blir gal, og
    // ingenting ser galt ut.
    expect(() => sjekkOmsetningslinje('12', 'Drivstoff')).toThrow(ParserFeil)
    expect(() => sjekkOmsetningslinje('12', 'Drivstoff')).toThrow(/68 %/)
    expect(() => sjekkOmsetningslinje('260', 'Pant')).toThrow(ParserFeil)
  })

  it('KANARI: vakten dekker nøyaktig kodene filteret hviler på', () => {
    // Vokser `SKJUL_OMS_KODER` uten at vakten følger med, er den nye
    // koden uvoktet — og en vakt som dekker halve lista ser nøyaktig ut
    // som en som dekker hele.
    expect(vokteteKoder()).toEqual([...SKJUL_OMS_KODER].sort())
  })

  it('KANARI: en delstreng er ikke et treff', () => {
    // «Pantemaskin» er ikke «Pant». Et delstrengstreff ville felt en
    // ekte varegruppe, og da blir vakten skrudd av — som er verre enn
    // at den ikke fantes.
    expect(() => sjekkOmsetningslinje('170', 'Pantemaskin')).not.toThrow()
    expect(() => sjekkOmsetningslinje('170', 'Drivstoffkanner')).not.toThrow()
  })
})
