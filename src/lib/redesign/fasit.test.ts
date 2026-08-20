import { describe, expect, test } from 'vitest'
import {
  borte, borteI, lenker, lokaleBarn, naabarhet, rutenavn, rutetre, seksjoner,
  serverhandlinger,
} from './fasit'

describe('rutenavn', () => {
  test('rutegrupper er organisering, ikke URL', () => {
    expect(rutenavn('C:/p/src/app/(beskyttet)/lonn/page.tsx')).toBe('/lonn')
  })

  test('forsiden blir «/», ikke «/page.tsx»', () => {
    // Den feilen fantes: rot-sida har ingen skraastrek foran page.tsx, og
    // monsteret krevde en. Da het forsiden noe annet enn den er.
    expect(rutenavn('C:/p/src/app/page.tsx')).toBe('/')
  })

  test('dynamiske segmenter beholdes', () => {
    expect(rutenavn('C:/p/src/app/(beskyttet)/rutiner/oppsett/[id]/page.tsx'))
      .toBe('/rutiner/oppsett/[id]')
  })

  test('windows-skråstreker gir samme svar', () => {
    expect(rutenavn('C:\\p\\src\\app\\(beskyttet)\\salg\\page.tsx')).toBe('/salg')
  })
})

describe('naabarhet', () => {
  const kilde = `
    const A: Brukerrolle = 'retailer_admin'
    const B: Brukerrolle = 'butikksjef'
    const T: Brukerrolle = 'butikkbruker_tablet'
    { sti: '/salg', tekst: 'Salg', roller: [A, B] },
    { sti: '/rutiner', tekst: 'På vakt', roller: [T] },
    { sti: '/rutiner/min', tekst: 'Min sjekkliste', roller: [A, B] },
  `

  test('kortnavn løses opp til ekte rollenavn', () => {
    // «A» kan bety noe annet i morgen. Fasiten skal bære rollen.
    expect(Object.keys(naabarhet(kilde)).sort())
      .toEqual(['butikkbruker_tablet', 'butikksjef', 'retailer_admin'])
  })

  test('meny og faner slås sammen — samme form, samme svar', () => {
    expect(naabarhet(kilde)['butikksjef']).toEqual(['/rutiner/min', '/salg'])
  })

  test('en rolle ser bare sitt eget', () => {
    expect(naabarhet(kilde)['butikkbruker_tablet']).toEqual(['/rutiner'])
  })

  test('samme sti to steder telles én gang', () => {
    const dobbel = kilde + "{ sti: '/salg', tekst: 'Salg', roller: [A] },"
    expect(naabarhet(dobbel)['retailer_admin'].filter((s) => s === '/salg')).toHaveLength(1)
  })
})

describe('serverhandlinger', () => {
  const fil = (kropp: string) => `'use server'\nimport x from 'y'\n${kropp}`

  test('finner eksporterte handlinger', () => {
    expect(serverhandlinger(fil(
      'export async function lagreFrist() {}\nexport async function slettPerson() {}',
    ))).toEqual(['lagreFrist', 'slettPerson'])
  })

  test('en fil uten «use server» har ingen', () => {
    expect(serverhandlinger('export async function noe() {}')).toEqual([])
  })

  test('uekporterte hjelpefunksjoner teller ikke', () => {
    expect(serverhandlinger(fil('async function hjelper() {}'))).toEqual([])
  })
})

describe('seksjoner', () => {
  test('leser overskriftene, også de med uttrykk', () => {
    expect(seksjoner('<h2>Salg</h2><h2>{MND[m]} {ar}</h2>'))
      .toEqual(['Salg', '{MND[m]} {ar}'])
  })

  // KANARIFUGLENE. Disse tre er ikke pynt: de feiler den dagen skraperen
  // slutter aa se overskrifter som har flyttet inn i designsystemet. En
  // vakt som slutter aa se, ser noyaktig ut som en vakt som ikke finner
  // noe - og da er /svinn og alle sidene etter den umaalte i stillhet.
  test('overskrift i en tittel-prop telles', () => {
    expect(seksjoner('<Datatabell tittel="Mest svinn" antall={3}>'))
      .toEqual(['Mest svinn'])
  })

  test('tittel med malstreng telles', () => {
    expect(seksjoner('<Datatabell tittel={`Per stasjon · ${dato}`}>'))
      .toEqual(['Per stasjon · ${dato}'])
  })

  test('et rent uttrykk er ikke en overskrift', () => {
    // `tittel={tittel}` sier ingenting om hva som staar paa skjermen.
    // Talte vi den, ville vakten voktet et variabelnavn.
    expect(seksjoner('<Signal tittel={tittel}>')).toEqual([])
    expect(seksjoner('<Datatabell tittel={g.navn}>')).toEqual([])
  })

  test('men et uttrykk MED tekst i voktes fortsatt', () => {
    // Teksten kan endres i stillhet, og da skal vakten si fra - selv om
    // den staar inne i et kall eller en ternaer.
    expect(seksjoner("<Tomtilstand tittel={o('Ingen anvisninger')}>"))
      .toEqual(["o('Ingen anvisninger')"])
  })

  test('nostet uttrykk i malstrengen stopper den ikke', () => {
    // Dette er formen som faktisk star i /svinn. Regexen som lette etter
    // «backtick, ikke-backtick, backtick» fant den ikke i det hele tatt,
    // og en overskrift den ikke finner er en overskrift den ikke vokter.
    expect(seksjoner('<Datatabell tittel={`Mest svinn${a ? ` · ${b}` : \'\'}`}>'))
      .toEqual(['Mest svinn${a ? ` · ${b}` : \'\'}'])
  })

  test('h3 teller — Datatabell rendrer tittelen sin som h3', () => {
    expect(seksjoner('<h3>Svinn mot terskel</h3>')).toEqual(['Svinn mot terskel'])
  })

  test('sidas eget navn er ikke en seksjon', () => {
    // Uten dette unntaket ville hver migrerte side lagt sitt eget navn i
    // seksjonslista, og lista sluttet aa handle om seksjoner.
    expect(seksjoner('<Sidehode\n  tittel="Synlig svinn"\n  undertittel="x"\n/>'))
      .toEqual([])
  })

  // ---------------------------------------------------------------
  // At vakten SER de nye formene er bare halve jobben. Den andre halve
  // er at den fortsatt REAGERER. En parser som er gjort tolerant nok
  // kan ende med aa svelge et ekte tap, og da er vakten verre enn
  // ingen: den staar groenn mens en seksjon er borte fra skjermen.
  // ---------------------------------------------------------------
  test('EKTE TAP: en slettet tittel-prop meldes', () => {
    const foer = '<h2>Oversikt</h2><Datatabell tittel="Per stasjon">'
    const etter = '<h2>Oversikt</h2>'
    expect(borte(seksjoner(foer), seksjoner(etter))).toEqual(['Per stasjon'])
  })

  test('EKTE TAP: en slettet h2 meldes', () => {
    const foer = '<h2>Oversikt</h2><Datatabell tittel="Per stasjon">'
    const etter = '<Datatabell tittel="Per stasjon">'
    expect(borte(seksjoner(foer), seksjoner(etter))).toEqual(['Oversikt'])
  })

  test('EKTE TAP: aa bytte tagg mot prop er IKKE et tap', () => {
    // Det motsatte tilfellet, og grunnen til at unntaket finnes: samme
    // overskrift flyttet fra <h2> til en prop skal ikke melde tap. Ellers
    // meldte hver eneste migrerte side et tap som ikke fantes, og da
    // slutter folk aa lese meldingen - som er hvordan et ekte tap
    // slipper forbi.
    expect(borte(seksjoner('<h2>Per stasjon</h2>'),
                 seksjoner('<Datatabell tittel="Per stasjon">'))).toEqual([])
  })

  test('h2 med attributter og linjeskift', () => {
    expect(seksjoner('<h2 className="x">\n  Klar for\n  sletting\n</h2>'))
      .toEqual(['Klar for sletting'])
  })
})

describe('rutetre', () => {
  // =================================================================
  // Vakten leste bare page.tsx fram til trinn 08. En side som flytter
  // innholdet sitt inn i en klientkomponent - slik /produksjonsplan har
  // gjort med hele plantabellen - saa da helt urort ut.
  //
  // Testene under bygger et lite filsystem i minnet. Det er med vilje:
  // grensetilfellene (sykler, dobbeltimport, dybde, rotgjerdet) er
  // vanskelige aa lage paa disk og lette aa lage her, og de skal maales
  // like presist som resten.
  // =================================================================

  const ROT = '/app'
  const fs = (filer: Record<string, string>) => (sti: string) => filer[sti] ?? null

  test('A - seksjon rett i page.tsx', () => {
    const filer: Record<string, string> = { '/app/r/page.tsx': '<h2>Rett i sida</h2>' }
    const tre = rutetre('/app/r/page.tsx', fs(filer), ROT)
    expect(tre).toEqual(['/app/r/page.tsx'])
    expect(tre.flatMap((f) => seksjoner(filer[f]))).toEqual(['Rett i sida'])
  })

  test('B - seksjon ett niva ned', () => {
    const filer: Record<string, string> = {
      '/app/r/page.tsx': "import { Barn } from './barn'\nexport default () => <Barn />",
      '/app/r/barn.tsx': '<h2>Fra barnet</h2>',
    }
    const tre = rutetre('/app/r/page.tsx', fs(filer), ROT)
    expect(tre).toEqual(['/app/r/page.tsx', '/app/r/barn.tsx'])
    expect(tre.flatMap((f) => seksjoner(filer[f]))).toEqual(['Fra barnet'])
  })

  test('C - seksjon to niva ned', () => {
    // Ekte monster i repoet: /oversikt -> admin-dashbord -> oppmerksomhet.
    const filer: Record<string, string> = {
      '/app/r/page.tsx': "import { Barn } from './barn'\n<Barn />",
      '/app/r/barn.tsx': "import { Barnebarn } from './barnebarn'\n<Barnebarn />",
      '/app/r/barnebarn.tsx': '<h3>To niva ned</h3>',
    }
    const tre = rutetre('/app/r/page.tsx', fs(filer), ROT)
    expect(tre).toHaveLength(3)
    expect(tre.flatMap((f) => seksjoner(filer[f]))).toEqual(['To niva ned'])
  })

  test('D - generiske primitiver folges ikke', () => {
    // `@/components/ui` er ikke relativ, og skal ikke naas i det hele
    // tatt. Gjorde den det, ville Datatabell sine egne overskrifter
    // dukket opp som en seksjon paa hver eneste side som bruker den.
    const filer: Record<string, string> = {
      '/app/r/page.tsx':
        "import { Datatabell } from '@/components/ui/side'\n"
        + "import Link from 'next/link'\n<Datatabell tittel=\"Ekte\" />",
      '/components/ui/side.tsx': '<h2>Primitivets egen overskrift</h2>',
    }
    const tre = rutetre('/app/r/page.tsx', fs(filer), ROT)
    expect(tre).toEqual(['/app/r/page.tsx'])
    expect(tre.flatMap((f) => seksjoner(filer[f]))).toEqual(['Ekte'])
  })

  test('D2 - en import som ikke RENDRES folges ikke', () => {
    // Naboen kan levere en type eller en hjelpefunksjon uten at noe av
    // UI-et hennes havner paa skjermen.
    const filer: Record<string, string> = {
      '/app/r/page.tsx': "import { Hjelp } from './hjelp'\nconst x = Hjelp()",
      '/app/r/hjelp.tsx': '<h2>Skal ikke telles</h2>',
    }
    expect(rutetre('/app/r/page.tsx', fs(filer), ROT)).toEqual(['/app/r/page.tsx'])
  })

  test('D3 - rotgjerdet holder: ../.. ut av app folges ikke', () => {
    const filer: Record<string, string> = {
      '/app/r/page.tsx': "import { Ute } from '../../ute'\n<Ute />",
      '/ute.tsx': '<h2>Utenfor app</h2>',
    }
    expect(rutetre('/app/r/page.tsx', fs(filer), ROT)).toEqual(['/app/r/page.tsx'])
  })

  test('E - samme barn rendret to steder telles en gang', () => {
    const filer: Record<string, string> = {
      '/app/r/page.tsx': "import { A } from './a'\nimport { B } from './b'\n<A /><B />",
      '/app/r/a.tsx': "import { Delt } from './delt'\n<Delt />",
      '/app/r/b.tsx': "import { Delt } from './delt'\n<Delt />",
      '/app/r/delt.tsx': '<h2>Delt seksjon</h2>',
    }
    const tre = rutetre('/app/r/page.tsx', fs(filer), ROT)
    expect(tre.filter((f) => f === '/app/r/delt.tsx')).toHaveLength(1)
    // Og seksjonen staar en gang i lista, ikke to.
    const alle = [...new Set(tre.flatMap((f) => seksjoner(filer[f])))]
    expect(alle).toEqual(['Delt seksjon'])
  })

  test('F - importsyklus terminerer', () => {
    const filer: Record<string, string> = {
      '/app/r/page.tsx': "import { A } from './a'\n<A />",
      '/app/r/a.tsx': "import { B } from './b'\n<B /><h2>A</h2>",
      '/app/r/b.tsx': "import { A } from './a'\n<A /><h2>B</h2>",
    }
    const tre = rutetre('/app/r/page.tsx', fs(filer), ROT)
    expect(tre).toHaveLength(3)
    expect([...new Set(tre.flatMap((f) => seksjoner(filer[f])))].sort()).toEqual(['A', 'B'])
  })

  test('G - EKTE TAP I ET BARN MELDES FORTSATT', () => {
    // DEN VIKTIGSTE. Utvidet leting maa ikke gjore vakten snillere:
    // slettes en seksjon fra barnet, skal den komme ut av borte().
    const foer: Record<string, string> = {
      '/app/r/page.tsx': "import { Barn } from './barn'\n<Barn /><h2>I sida</h2>",
      '/app/r/barn.tsx': '<h2>I barnet</h2>',
    }
    const etter: Record<string, string> = { ...foer, '/app/r/barn.tsx': '<p>tom</p>' }
    const samle = (f: Record<string, string>) =>
      [...new Set(rutetre('/app/r/page.tsx', fs(f), ROT).flatMap((x) => seksjoner(f[x])))].sort()

    expect(samle(foer)).toEqual(['I barnet', 'I sida'])
    expect(borte(samle(foer), samle(etter))).toEqual(['I barnet'])
  })

  test('G2 - AA FLYTTE en seksjon fra sida til barnet er IKKE et tap', () => {
    // Motstykket til G, og grunnen til at vakten maa se treet: uten det
    // ville hver eneste utflytting til en klientkomponent meldt et tap
    // som ikke fant sted - og en vakt som roper ulv slutter folk aa lese.
    const foer: Record<string, string> = { '/app/r/page.tsx': '<h2>Flyttes</h2>' }
    const etter: Record<string, string> = {
      '/app/r/page.tsx': "import { Barn } from './barn'\n<Barn />",
      '/app/r/barn.tsx': '<h2>Flyttes</h2>',
    }
    const samle = (f: Record<string, string>) =>
      [...new Set(rutetre('/app/r/page.tsx', fs(f), ROT).flatMap((x) => seksjoner(f[x])))].sort()
    expect(borte(samle(foer), samle(etter))).toEqual([])
  })

  test('dybdegrensa stopper en lang kjede', () => {
    const filer: Record<string, string> = { '/app/r/page.tsx': "import { K0 } from './k0'\n<K0 />" }
    for (let i = 0; i < 8; i++) {
      filer[`/app/r/k${i}.tsx`] = `import { K${i + 1} } from './k${i + 1}'\n<K${i + 1} /><h2>N${i}</h2>`
    }
    // maksDybde 4 fra sida: page + fire niva.
    expect(rutetre('/app/r/page.tsx', fs(filer), ROT)).toHaveLength(5)
  })
})

describe('lokaleBarn', () => {
  test('bare relative stier', () => {
    expect(lokaleBarn("import { A } from './a'\n<A />")).toEqual(['./a'])
    expect(lokaleBarn("import { A } from '@/components/ui/a'\n<A />")).toEqual([])
    expect(lokaleBarn("import A from 'next/link'\n<A />")).toEqual([])
  })

  test('type-importer teller ikke', () => {
    expect(lokaleBarn("import type { Gruppe } from './g'\n<Gruppe />")).toEqual([])
    // Men en blandet import der komponenten rendres, gjor det.
    expect(lokaleBarn("import { PlanTabell, type Gruppe } from './p'\n<PlanTabell />"))
      .toEqual(['./p'])
  })

  test('smaa forbokstaver er ikke komponenter', () => {
    expect(lokaleBarn("import { hentAlt } from './h'\n<hentAlt />")).toEqual([])
  })
})

describe('lenker', () => {
  test('interne sider, ikke utsiden', () => {
    expect(lenker('<a href="/lonn">x</a><a href="https://vg.no">y</a>'))
      .toEqual(['/lonn'])
  })

  test('malstrenger med uttrykk fanges', () => {
    expect(lenker('<Link href={`/kontrakt/${id}`}>x</Link>'))
      .toEqual(['/kontrakt/${id}'])
  })

  test('spørrestrengen strippes — den er ikke en egen side', () => {
    expect(lenker('<a href="/lonn?stasjon=1">x</a><a href="/lonn?ar=2026">y</a>'))
      .toEqual(['/lonn'])
  })
})

describe('borte', () => {
  test('rekkefølge er likegyldig', () => {
    expect(borte(['a', 'b'], ['b', 'a'])).toEqual([])
  })

  test('nye ting er ikke et tap', () => {
    expect(borte(['a'], ['a', 'b'])).toEqual([])
  })

  test('sier hva som mangler', () => {
    expect(borte(['a', 'b', 'c'], ['b'])).toEqual(['a', 'c'])
  })

  test('borteI melder bare nøkler som mistet noe', () => {
    expect(borteI(
      { '/x': ['a', 'b'], '/y': ['c'] },
      { '/x': ['a'], '/y': ['c', 'd'] },
    )).toEqual({ '/x': ['b'] })
  })

  test('en nøkkel som forsvant helt, teller som tap', () => {
    expect(borteI({ '/x': ['a'] }, {})).toEqual({ '/x': ['a'] })
  })
})
