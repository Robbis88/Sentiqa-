import { describe, expect, test } from 'vitest'
import {
  finnDuplikat, lagFilsti, lesStikkord, normaliser, sjekkFil, sok, type Anvisning,
} from './anvisningssok'

const a = (
  id: string, tittel: string, kategori: string, stikkord: string[],
): Anvisning => ({
  id, tittel, kategori, stikkord,
  innhold: null, fil_sti: `x/${id}.pdf`, dato: null, erstatter_dato: null,
})

const ARKIV: Anvisning[] = [
  a('1', 'Horn med ost og skinke', 'Påsmurt', ['horn', 'valmue', 'ost', 'skinke']),
  a('2', 'Baguette med kylling', 'Påsmurt', ['baguette', 'kylling', 'karri']),
  a('3', 'Ostesmørbrød', 'Matpakke', ['brød', 'ost']),
  a('4', 'Grovbrød', 'Bakeri', ['brød', 'grov']),
]

describe('søket', () => {
  test('ALLE ord må treffe, ikke minst ett', () => {
    // DEN VIKTIGSTE. «ost horn» skal gi hornet, ikke alt med ost ELLER
    // horn. Med «minst ett» blir søket ubrukelig saa snart arkivet
    // passerer noen titalls ark.
    const t = sok(ARKIV, 'ost horn')
    expect(t.map((x) => x.id)).toEqual(['1'])
  })

  test('finner paa stikkord som ikke staar i tittelen', () => {
    // Personalet soeker paa det de har i haanda. «valmue» staar bare i
    // stikkordene.
    expect(sok(ARKIV, 'valmue').map((x) => x.id)).toEqual(['1'])
  })

  test('finner paa kategori', () => {
    expect(sok(ARKIV, 'bakeri').map((x) => x.id)).toEqual(['4'])
  })

  test('delstreng holder — «oste» finner «Ostesmørbrød»', () => {
    expect(sok(ARKIV, 'oste').map((x) => x.id)).toEqual(['3'])
  })

  test('tom soeketekst gir HELE arkivet, ikke ingenting', () => {
    // En tom skjerm med «soek for aa begynne» tvinger den som bare vil
    // bla til aa gjette et ord foerst.
    expect(sok(ARKIV, '')).toHaveLength(4)
    expect(sok(ARKIV, '   ')).toHaveLength(4)
  })

  test('ingen treff gir tom liste, ikke hele arkivet', () => {
    // KANARIFUGL: faller filteret tilbake til «vis alt» ved bom, ser et
    // mislykket soek ut som et vellykket.
    expect(sok(ARKIV, 'pizza')).toEqual([])
  })

  test('store bokstaver og ekstra mellomrom spiller ingen rolle', () => {
    expect(sok(ARKIV, '  OST   Horn ').map((x) => x.id)).toEqual(['1'])
  })
})

describe('normalisering', () => {
  test('trimmer, senker og kollapser', () => {
    expect(normaliser('  Horn  MED   Ost ')).toBe('horn med ost')
  })
})

describe('stikkord', () => {
  test('komma, semikolon og linjeskift skiller', () => {
    expect(lesStikkord('horn, valmue; ost\nskinke')).toEqual(
      ['horn', 'valmue', 'ost', 'skinke'],
    )
  })

  test('duplikater og tomme felt forsvinner', () => {
    expect(lesStikkord('ost, OST ,, ost')).toEqual(['ost'])
  })

  test('flerordsstikkord holdes samlet', () => {
    // «revet ost» er ett stikkord. Splittet paa mellomrom ville det blitt
    // to, og «revet» alene er ubrukelig.
    expect(lesStikkord('revet ost, skinke')).toEqual(['revet ost', 'skinke'])
  })
})

describe('duplikatvarselet', () => {
  const finnes = [
    { id: '1', tittel: 'Horn med ost og skinke', original_filnavn: 'horn-ost.pdf' },
  ]

  test('samme tittel, skrevet ulikt, meldes', () => {
    const d = finnDuplikat(finnes, { tittel: '  horn MED ost og skinke ', filnavn: null })
    expect(d?.grunn).toBe('tittel')
  })

  test('samme filnavn meldes ogsaa', () => {
    const d = finnDuplikat(finnes, { tittel: 'Noe helt annet', filnavn: 'HORN-OST.PDF' })
    expect(d?.grunn).toBe('filnavn')
  })

  test('KANARIFUGL: et nytt ark meldes ikke', () => {
    // Melder denne alt, laerer folk aa klikke «last opp likevel» uten aa
    // lese - og da er advarselen borte i praksis.
    expect(finnDuplikat(finnes, { tittel: 'Baguette', filnavn: 'bag.pdf' })).toBeNull()
  })

  test('tittel veier tyngst naar begge treffer', () => {
    const d = finnDuplikat(finnes, {
      tittel: 'Horn med ost og skinke', filnavn: 'horn-ost.pdf',
    })
    expect(d?.grunn).toBe('tittel')
  })
})

describe('filsjekken', () => {
  const fil = (o: Partial<{ size: number; type: string; name: string }> = {}) => ({
    size: 1000, type: 'application/pdf', name: 'horn.pdf', ...o,
  })

  test('en vanlig pdf slipper gjennom', () => {
    expect(sjekkFil(fil())).toBeNull()
  })

  test('for stor fil sier hvor stor den er', () => {
    // «Ugyldig fil» hjelper ingen. Tallet sier hva som maa gjoeres.
    const feil = sjekkFil(fil({ size: 25 * 1024 * 1024 }))
    expect(feil).toContain('25 MB')
    expect(feil).toContain('20 MB')
  })

  test('tom fil meldes for seg', () => {
    expect(sjekkFil(fil({ size: 0 }))).toBe('Fila er tom.')
  })

  test('en riktig pdf med rar MIME-type slipper gjennom', () => {
    // Nettleseren setter `type` av endelsen og tar av og til feil.
    expect(sjekkFil(fil({ type: 'application/octet-stream' }))).toBeNull()
  })

  test('en omdoept docx slipper IKKE gjennom', () => {
    expect(sjekkFil(fil({ type: 'application/msword', name: 'horn.docx' })))
      .toBe('Bare PDF kan lastes opp.')
  })
})

describe('filstien', () => {
  test('retailer foran, generert navn bak', () => {
    // ALDRI brukerens eget filnavn: kollisjoner paa «horn.pdf»,
    // tegnsettproblemer paa aeoeaa, og stier andre kan gjette.
    expect(lagFilsti('r1', 1_700_000, 'ab12cd')).toBe('r1/1700000-ab12cd.pdf')
  })

  test('retailer er FOERSTE stisegment', () => {
    // Storage-policyen leser `(storage.foldername(name))[1]` som
    // retailer. Bytter rekkefolgen her, faller tenantgjerdet.
    expect(lagFilsti('r1', 1, 'x').split('/')[0]).toBe('r1')
  })
})
