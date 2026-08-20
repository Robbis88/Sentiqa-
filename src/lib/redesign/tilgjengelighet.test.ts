// @vitest-environment jsdom
import { describe, expect, test } from 'vitest'
import { createElement as h } from 'react'
import { renderToStaticMarkup } from 'react-dom/server'
import axe from 'axe-core'
// Relativ import: repoet har ingen vitest-config, og ingen annen test
// bruker @/-aliaset. Aa legge til en config for en enkelt import ville
// vaert aa flytte en avhengighet inn i byggoppsettet for ingenting.
import {
  Sidehode, Nokkeltall, Tomtilstand, Datatabell, Forklaring,
} from '../../components/ui/side'
import { Knapp } from '../../components/ui/knapp'
import { Felt, Velg } from '../../components/ui/felt'
import { Status, Signal } from '../../components/ui/status'
import { Liste, Rad } from '../../components/ui/liste'
import { Sok, Filter } from '../../components/ui/sok'

// =====================================================================
// Tilgjengelighet paa primitivene, ikke paa sidene.
//
// De fem komponentene her tegner toppen av hver eneste av de 58 sidene.
// En manglende tabell-overskrift eller en knapp uten navn i EN av dem er
// en feil paa hele systemet - og motsatt: retter du den her, er den
// rettet overalt. Det er den hoyeste dekningen per test som finnes i
// dette repoet.
//
// HVORFOR IKKE PLAYWRIGHT HER: en browsertest maa ha appen oppe, og
// appen maa ha en base. Uten et seedet testprosjekt naar den bare
// innloggingssida. Den testen hoerer hjemme, men den maaler noe annet -
// og den koster et miljo vi ikke har enda. Dette koster 200 ms.
//
// DET DENNE IKKE MAALER, og som er lett aa tro at den gjor:
//
//   KONTRAST. jsdom har ingen layout og ingen rendering, saa axe kan
//   ikke regne fargekontrast her. Regelen er slaatt eksplisitt av under
//   framfor aa la den staa paa og stille rapportere «pass» - en regel
//   som ikke kan feile er verre enn ingen regel.
//
//   TREFFOMRAADER. At .tablet .kryss er 56x56 er en CSS-regel uten DOM
//   aa maale paa. Den staar i globals.css og maa sjekkes med oyet eller
//   i en ekte nettleser.
//
//   OM TEKSTEN GIR MENING. axe ser at en knapp HAR et navn, ikke at
//   navnet er forstaaelig for en sekstenaaring paa forste arbeidsdag.
//
// Groenn her betyr «ingen kjente strukturfeil i markupen». Det er en
// ekte og billig garanti, men den er smalere enn ordet tilgjengelighet.
// =====================================================================

async function brudd(markup: string) {
  document.body.innerHTML = `<main>${markup}</main>`
  const res = await axe.run(document.body, {
    // Regler som krever hele dokumentet (landmarks, region, tittel) gir
    // falske funn naar vi maaler ETT utsnitt. De hoerer til en sidetest.
    runOnly: {
      type: 'tag',
      values: ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'],
    },
    rules: {
      region: { enabled: false },
      'page-has-heading-one': { enabled: false },
      'landmark-one-main': { enabled: false },
      // Kan ikke regnes uten layout. Se hodet: slaatt av med vilje, saa
      // den ikke rapporterer «pass» paa noe den aldri saa etter.
      'color-contrast': { enabled: false },
    },
  })
  return res.violations.map((v) => `${v.id}: ${v.help} (${v.nodes.length})`)
}

describe('tilgjengelighet paa ui-primitivene', () => {
  test('Sidehode', async () => {
    expect(await brudd(renderToStaticMarkup(
      h(Sidehode, { tittel: 'Salg', undertittel: '+7,8 % mot en vanlig tirsdag' }),
    ))).toEqual([])
  })

  test('Nokkeltall med dom', async () => {
    expect(await brudd(renderToStaticMarkup(
      h(Nokkeltall, {
        merkelapp: 'Omsetning', verdi: '34 200 kr',
        sammenlignet: '+7,8 % mot en vanlig tirsdag', retning: 'opp', bra: true,
      }),
    ))).toEqual([])
  })

  test('Tomtilstand', async () => {
    expect(await brudd(renderToStaticMarkup(
      h(Tomtilstand, {
        tittel: 'Ingen salgsdata enna',
        forklaring: 'Last opp en fil under Import, saa fylles sida.',
      }),
    ))).toEqual([])
  })

  test('Datatabell', async () => {
    expect(await brudd(renderToStaticMarkup(
      // Barna ligger i props: createElement med varargs tilfredsstiller
      // ikke en paakrevd children-prop for TypeScript.
      h(Datatabell, {
        tittel: 'Per stasjon',
        antall: 5,
        children: [
          h('thead', { key: 'h' }, h('tr', null,
            h('th', { scope: 'col' }, 'Stasjon'), h('th', { scope: 'col' }, 'Omsetning'))),
          h('tbody', { key: 'b' }, h('tr', null,
            h('td', null, '0452 Bones'), h('td', null, '34 200 kr'))),
        ],
      }),
    ))).toEqual([])
  })

  test('Forklaring', async () => {
    expect(await brudd(renderToStaticMarkup(
      h(Forklaring, {
        sporsmaal: 'Hvorfor?',
        children: h('p', null, 'Fordi medianen staar imot enkeltdager.'),
      }),
    ))).toEqual([])
  })
})

// =====================================================================
// Primitivene fra trinn 03.
//
// Dette ER komponentmiljoet. Prosjektet har ikke Storybook, og skulle
// ikke faa det for tre komponenter - men en primitiv uten et sted aa
// rendre den blir aldri sett for den staar i en side. Her rendres hver
// av dem, i hver tilstand som har egen markup, og maales.
// =====================================================================

describe('primitivene', () => {
  test('Knapp i alle fire varianter', async () => {
    for (const variant of ['primar', 'sekundaer', 'ghost', 'destruktiv'] as const) {
      expect(await brudd(renderToStaticMarkup(
        h(Knapp, { variant, children: 'Lagre' }),
      ))).toEqual([])
    }
  })

  test('Knapp med ikon beholder navnet sitt', async () => {
    expect(await brudd(renderToStaticMarkup(
      h(Knapp, {
        variant: 'primar',
        ikon: h('svg', { width: 14, height: 14, 'aria-hidden': true }),
        children: 'Ny ansatt',
      }),
    ))).toEqual([])
  })

  test('Felt med hjelpetekst', async () => {
    expect(await brudd(renderToStaticMarkup(
      h(Felt, { etikett: 'Ansattnummer', hjelp: 'Kommer fra Azets.' }),
    ))).toEqual([])
  })

  test('Felt med feil', async () => {
    expect(await brudd(renderToStaticMarkup(
      h(Felt, { etikett: 'PIN', feil: 'PIN maa vaere 4-6 siffer.' }),
    ))).toEqual([])
  })

  // Skjult etikett er et VALG. Den skal fortsatt finnes for skjermleser
  // - det er hele forskjellen paa skjult og glemt.
  test('Felt med skjult etikett har fortsatt navn', async () => {
    expect(await brudd(renderToStaticMarkup(
      h(Felt, { etikett: 'Soek etter navn', skjultEtikett: true }),
    ))).toEqual([])
  })

  test('Velg', async () => {
    expect(await brudd(renderToStaticMarkup(
      h(Velg, {
        etikett: 'Stasjon',
        children: h('option', { value: '1' }, '0452 Bones'),
      }),
    ))).toEqual([])
  })

  test('Status paa alle fire nivaa', async () => {
    for (const nivaa of ['normal', 'endring', 'handling', 'kritisk'] as const) {
      expect(await brudd(renderToStaticMarkup(
        h(Status, { nivaa, children: 'Aktiv' }),
      ))).toEqual([])
    }
  })

  test('Signal paa alle fire nivaa', async () => {
    for (const nivaa of ['informasjon', 'mulighet', 'oppmerksomhet', 'kritisk'] as const) {
      expect(await brudd(renderToStaticMarkup(
        h(Signal, {
          nivaa,
          tittel: 'Tre vakter staar uten utstempling',
          children: 'Loennsfila lages ikke for de er lukket.',
        }),
      ))).toEqual([])
    }
  })

  test('Liste med klikkbar rad', async () => {
    expect(await brudd(renderToStaticMarkup(
      h(Liste, {
        merkelapp: 'Ansatte',
        children: h(Rad, {
          href: '/ansatte/1',
          primaer: 'Kari Nordmann',
          sekundaer: '0452 Bones',
          status: h(Status, { children: 'Aktiv' }),
          metadata: '1009',
        }),
      }),
    ))).toEqual([])
  })

  test('Liste med handlinger paa raden', async () => {
    expect(await brudd(renderToStaticMarkup(
      h(Liste, {
        merkelapp: 'Ansatte',
        children: h(Rad, {
          primaer: 'Kari Nordmann',
          handlinger: h(Knapp, { variant: 'ghost', liten: true, children: 'Deaktiver' }),
        }),
      }),
    ))).toEqual([])
  })

  test('Sok', async () => {
    expect(await brudd(renderToStaticMarkup(
      h(Sok, { plassholder: 'Soek etter navn', skjulte: { stasjon: 'abc' } }),
    ))).toEqual([])
  })

  test('Filter med teller', async () => {
    expect(await brudd(renderToStaticMarkup(
      h(Filter, {
        antall: 1,
        children: h(Velg, {
          etikett: 'Status',
          skjultEtikett: true,
          children: h('option', { value: 'aktiv' }, 'Aktiv'),
        }),
      }),
    ))).toEqual([])
  })
})

describe('maalingen virker', () => {
  test('den fanger en ekte feil', async () => {
    // KANARIFUGL. Groenn over betyr bare noe hvis roedt er mulig. En
    // knapp uten tilgjengelig navn er den vanligste feilen i dette
    // repoet - avkryssingsknappene paa nettbrettet var lenge tomme
    // <button> med bare et kryss inni.
    const funn = await brudd('<button></button>')
    expect(funn.length).toBeGreaterThan(0)
  })

  test('og den er ikke bare stoy', async () => {
    expect(await brudd('<p>Helt vanlig tekst.</p>')).toEqual([])
  })
})
