import { describe, expect, it } from 'vitest'
import { renderToStaticMarkup } from 'react-dom/server'
import { Arbeidsstedsblokk } from './arbeidsstedsblokk'
import type { A1Kort } from '@/lib/lonnskost/a1-kort'
import { erLeder } from '@/lib/auth/roller'
import fasit from '@/lib/redesign/fasit.json'

const BONES = 'sss-bones'

/** Bønes august 2026, slik produksjonsbeviset målte den. */
const BONES_AUGUST: A1Kort = {
  status: 'minimum',
  maaned: '2026-08',
  kroner: 143889.14,
  betalteTimer: 698.77,
  prisedeTimer: 630.77,
  forklarteTimer: 0,
  upriseteTimer: 68,
  andelPriset: 90.3,
  uprisetePersoner: [
    { ansattNr: '1004', navn: 'Stig E.E Litlehamar', timer: 68, grunn: 'ukjent_nummer' },
  ],
  innlaantKr: 4758.33,
  innlaanteNr: ['1104265', '1104270'],
  dataavvik: { dubletter: 0, avvisteVakter: 0 },
  helligdagstimer: 0,
  forbehold: ['Overtid (lønnsart 96 og 97) inngår ikke.', 'Helligdagstillegget (1410) …'],
}

const KOMPLETT: A1Kort = {
  ...BONES_AUGUST,
  status: 'komplett',
  upriseteTimer: 0,
  uprisetePersoner: [],
  prisedeTimer: 698.77,
  andelPriset: 100,
}

// `Intl` skiller tusener med HARDT mellomrom (U+00A0). Uten
// normaliseringen bommer «143 889» paa markup som inneholder
// «143\u00a0889», og testen ville vaert roed av feil grunn.
//
// Escapen staar med vilje: et LITERELT hardt mellomrom i kilden er
// usynlig, og en regex ingen kan lese er en regex ingen kan
// vedlikeholde.
//
// Merk ogsaa at husets `kr` runder til hele kroner: motoren holder
// 143 889,14, mens skjermen viser 143 889 kr.
const marker = (kort: A1Kort[]) =>
  renderToStaticMarkup(<Arbeidsstedsblokk kort={kort} stasjonId={BONES} />)
    .replace(/\u00a0/g, ' ')

describe('kildemangel viser aldri en kroneverdi', () => {
  it('mangler_register: ingen kroner, men timene er synlige', () => {
    const m = marker([{
      status: 'kildemangel', maaned: '2026-08', mangler: 'register',
      timer: 698.8, personer: 13,
    }])
    expect(m).toContain('Kan ikke beregnes')
    expect(m).toContain('698,8')
    // Et frittstaaende nullbeloep. «143 889 kr» skal ikke treffe.
    expect(m).not.toMatch(/(^|[\s>])0\s?kr/)
  })

  it('mangler_begge sier hva som mangler, ikke et tall', () => {
    const m = marker([{ status: 'kildemangel', maaned: '2026-08', mangler: 'begge' }])
    expect(m).toContain('Både arbeidstid og lønnsgrunnlag mangler')
    expect(m).not.toMatch(/\d+,\d\d\s*kr/)
  })

  it('mangler_arbeidstid', () => {
    const m = marker([{ status: 'kildemangel', maaned: '2026-08', mangler: 'arbeidstid' }])
    expect(m).toContain('Arbeidstiden fra easy@work mangler')
  })
})

describe('språket', () => {
  it('«Minst» står foran beløpet ved minimum', () => {
    expect(marker([BONES_AUGUST])).toContain('Minst')
  })

  it('ordet «komplett» vises ALDRI', () => {
    // Statusen betyr komplett for MODELLEN. Overtid er utenfor.
    for (const k of [BONES_AUGUST, KOMPLETT]) {
      expect(marker([k]).toLowerCase()).not.toContain('komplett')
    }
  })

  it('ordet «minimum» vises heller ikke', () => {
    expect(marker([BONES_AUGUST]).toLowerCase()).not.toContain('minimum')
  })

  it('ingen intern enum-verdi lekker til markup', () => {
    const m = marker([BONES_AUGUST, { status: 'kildemangel', maaned: '2026-07', mangler: 'begge' }])
    for (const ord of [
      'ukjent_nummer', 'kildemangel', 'mangler_register', 'mangler_arbeidstid',
      'mangler_begge', 'motstrid', 'Vurdertrad', 'innlaantKr', 'a1_registeroppslag',
    ]) {
      expect(m, `«${ord}» lekket`).not.toContain(ord)
    }
  })
})

describe('forbeholdet står uansett status', () => {
  it('ved minimum', () => {
    expect(marker([BONES_AUGUST])).toContain('Overtid er ikke med')
  })

  it('OGSÅ ved komplett — det er hele poenget', () => {
    expect(marker([KOMPLETT])).toContain('Overtid er ikke med')
  })

  it('sier fra når 1410 ikke påvirker tallet', () => {
    expect(marker([BONES_AUGUST])).toContain('påvirker ikke tallene her')
  })
})

describe('handling før prosent', () => {
  it('rekkefølgen er beløp, mangel, dekning, innlånt', () => {
    const m = marker([BONES_AUGUST])
    const iBelop = m.indexOf('143 889')
    const iMangel = m.indexOf('mangler satsgrunnlag')
    const iDekning = m.indexOf('betalte timer priset')
    const iInnlaant = m.indexOf('sats hentet fra en annen stasjon')

    expect(iBelop).toBeGreaterThan(-1)
    expect(iMangel).toBeGreaterThan(iBelop)
    expect(iDekning).toBeGreaterThan(iMangel)
    expect(iInnlaant).toBeGreaterThan(iDekning)
  })

  it('prosenten står ALDRI før mangelen', () => {
    const m = marker([BONES_AUGUST])
    expect(m.indexOf('90,3')).toBeGreaterThan(m.indexOf('mangler satsgrunnlag'))
  })
})

describe('A2 bygges ikke nå', () => {
  it('ingen tom bokført-kolonne rendres', () => {
    const m = marker([BONES_AUGUST])
    expect(m.toLowerCase()).not.toContain('bokført')
    expect(m.toLowerCase()).not.toContain('forventet')
    // Tre kolonner: Måned, Beløp, Grunnlag. Ikke fire.
    expect((m.match(/<th>/g) ?? []).length).toBe(3)
  })
})

// =====================================================================
// REVISJONSLENKA — KONTRAKTEN, IKKE EN STATUS
//
// ERSTATTER regelen «ingen lenke når ingenting er upriset». Den var
// riktig så lenge `komplett` var sjeldent, men ble usann i det
// fastlønnsklassifiseringen kom: Bønes august ble `komplett`, og Stigs
// 68 forklarte timer ble uoppnåelige — nettopp de timene A1 BEVISST
// har valgt å ikke timeprise.
//
// Regelen er knyttet til ARBEIDET, aldri til intern status:
//
//   uprisedeMinutter > 0  ELLER  forklarteMinutter > 0  ->  lenke
//
// «Forklart» vil senere dekke flere typer arbeid systemet med vilje
// ikke priser. Er tallet reviderbart, skal brukeren kunne spørre hvilke
// timer det er.
// =====================================================================
describe('revisjonslenka følger arbeidet, ikke statusen', () => {
  const LENKE = `/lonnskost/arbeidssted?stasjon=${BONES}&amp;maned=2026-08`

  it('upriset > 0, forklart = 0 → lenke', () => {
    const k: A1Kort = { ...BONES_AUGUST, upriseteTimer: 68, forklarteTimer: 0 }
    expect(marker([k])).toContain(LENKE)
  })

  it('upriset = 0, forklart > 0 → lenke  (Bønes etter fastlønn)', () => {
    const k: A1Kort = {
      ...BONES_AUGUST, status: 'komplett',
      upriseteTimer: 0, uprisetePersoner: [], forklarteTimer: 68,
    }
    expect(marker([k])).toContain(LENKE)
  })

  it('upriset > 0, forklart > 0 → lenke', () => {
    const k: A1Kort = { ...BONES_AUGUST, upriseteTimer: 40, forklarteTimer: 28 }
    expect(marker([k])).toContain(LENKE)
  })

  it('upriset = 0, forklart = 0 → INGEN lenke', () => {
    // Alt ordinært priset. Da finnes det ingenting aa spoerre om.
    expect(marker([KOMPLETT])).not.toContain('/lonnskost/arbeidssted')
  })

  it('lenka bærer stasjon OG måned', () => {
    expect(marker([BONES_AUGUST])).toContain(LENKE)
  })

  it('regelen er IKKE knyttet til status=komplett', () => {
    // Samme status, to utfall - det er arbeidet som avgjoer.
    const medForklart: A1Kort = {
      ...KOMPLETT, forklarteTimer: 12, prisedeTimer: 686.77,
    }
    expect(marker([medForklart])).toContain(LENKE)
    expect(marker([KOMPLETT])).not.toContain('/lonnskost/arbeidssted')
  })
})

describe('de to aksene', () => {
  it('datakvalitet står for seg, ikke som kroner', () => {
    const m = marker([{
      ...KOMPLETT, dataavvik: { dubletter: 1, avvisteVakter: 2 },
    }])
    expect(m).toContain('Datakvalitet')
    expect(m).toContain('1 vakt(er) registrert to ganger')
    expect(m).toContain('2 vakt(er) kunne ikke leses')
  })

  it('ingen datakvalitetslinje når det ikke er avvik', () => {
    expect(marker([BONES_AUGUST])).not.toContain('Datakvalitet')
  })
})

describe('forklart arbeid', () => {
  it('sies høyt og aldri som 0 kr', () => {
    const m = marker([{ ...BONES_AUGUST, forklarteTimer: 193.5 }])
    expect(m).toContain('193,5 timer er forklart og ikke timepriset')
    expect(m).not.toMatch(/(^|[\s>])0\s?kr/)
  })
})

describe('tom liste', () => {
  it('rendrer ingenting når stasjonen ikke har A1-måneder', () => {
    expect(marker([])).toBe('')
  })
})

describe('tilgang — serveren, ikke frontend', () => {
  it('erLeder slipper bare retailer_admin og butikksjef inn', () => {
    // Porten på begge sidene. Nettbrettet og plattformredaktøren
    // avvises av DENNE, ikke av at en komponent gjemmer noe.
    expect(erLeder('retailer_admin')).toBe(true)
    expect(erLeder('butikksjef')).toBe(true)
    expect(erLeder('butikkbruker_tablet')).toBe(false)
    expect(erLeder('plattform_redaktor')).toBe(false)
  })

  it('menyen lover ikke lønnskost til nettbrett eller redaktør', () => {
    // `naabart` er menyen. Lover den en rute siden avviser, er det en
    // løgn brukeren møter som en blindvei.
    expect(fasit.naabart.butikkbruker_tablet).not.toContain('/lonnskost')
    expect(fasit.naabart.plattform_redaktor).not.toContain('/lonnskost')
    expect(fasit.naabart.retailer_admin).toContain('/lonnskost')
    expect(fasit.naabart.butikksjef).toContain('/lonnskost')
  })

  it('drilldownruta er registrert, men ikke i menyen', () => {
    // Den nås fra en lenke i blokka. En rute som ikke står i fasiten er
    // en rute ingen ville savnet.
    expect(fasit.ruter).toContain('/lonnskost/arbeidssted')
    expect(JSON.stringify(fasit.naabart)).not.toContain('arbeidssted')
  })
})
