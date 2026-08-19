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
