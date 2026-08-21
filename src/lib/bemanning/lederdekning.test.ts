import { describe, expect, test } from 'vitest'
import {
  ARSVERK_TIMER, MANEDER, forklarDekning, forslagHelManed, normaliserTimer,
  timetall, uavklarte,
} from './lederdekning'

describe('lederdekning', () => {
  test('årsverket er det St1 faktisk trekker fra', () => {
    // KANARIFUGL FOR EN TALLENDRING I STILLHET. 1695 står i 0082 som
    // «timene St1 trekker fra for butikksjefens fastlønn». Endres den
    // her uten at noen sjekker migrasjonen, blir forslaget i skjemaet
    // et annet tall enn det basen er dokumentert med.
    expect(ARSVERK_TIMER).toBe(1695)
  })

  test('forslaget beholder desimalen', () => {
    // 141 og 141,25 er ikke samme tall når det ganges med tolv. Og et
    // avrundet forslag inviterer til et avrundet valg — halve måneder
    // er hele grunnen til at feltet finnes.
    expect(forslagHelManed(ARSVERK_TIMER)).toBe(141.25)
    expect(timetall(141.25)).toBe('141,25')
    expect(timetall(70.5)).toBe('70,5')
  })

  test('setningen sier BEGGE deler, også når de er uenige', () => {
    // DEN VIKTIGSTE AV DISSE, og den er Bjørn på Laguneparken:
    // fastlønnet leder i permisjon, men ingen timelønnet dekket ham.
    // «Ingen fastlønnet butikksjef» ALENE ville lest som en tildeling.
    expect(forklarDekning('ikke_fastlonnet', null))
      .toBe('Ingen fastlønnet butikksjef. Ingen timer lagt tilbake.')
    expect(forklarDekning('ikke_fastlonnet', 141.25))
      .toBe('Ingen fastlønnet butikksjef. Rammen er økt med 141,25 timer.')

    // Og motsatt: leder på plass, men eieren ga likevel timer — også
    // gyldig, f.eks. når hun var sykmeldt halve måneden.
    expect(forklarDekning('fastlonnet', 70.5))
      .toBe('Fastlønnet butikksjef på plass. Rammen er økt med 70,5 timer.')
    expect(forklarDekning('ukjent', null))
      .toMatch(/Ikke tatt stilling/)
  })

  test('0 og tomt er det samme, og begge er null', () => {
    // Databasen forbyr 0 ved skranke. «Ingenting» skal ha én
    // representasjon, ellers bommer `is null` på halvparten.
    expect(normaliserTimer('')).toBeNull()
    expect(normaliserTimer('0')).toBeNull()
    expect(normaliserTimer('0,0')).toBeNull()
    expect(normaliserTimer('-5')).toBeNull()
    expect(normaliserTimer('tull')).toBeNull()
  })

  test('komma og punktum leses likt, og tastefeil avvises', () => {
    expect(normaliserTimer('141,25')).toBe(141.25)
    expect(normaliserTimer('141.25')).toBe(141.25)
    expect(normaliserTimer('70,5')).toBe(70.5)
    // Et årsverk er 1695. Skriver noen det i ett månedsfelt, er det en
    // tastefeil — og den ville doblet rammen.
    expect(normaliserTimer('1695'), 'hele årsverket i én måned').toBeNull()
    expect(normaliserTimer('300')).toBe(300)
    expect(normaliserTimer('301')).toBeNull()
  })

  test('de fire tilfellene leses ulikt', () => {
    // Situasjonene Robert beskrev, i den rekkefølgen de forekommer.
    // Setningen må skille dem — det er den som står under hver måned
    // og forklarer hva raden faktisk gjør.
    const full = forklarDekning('ikke_fastlonnet', 141.25)
    const halv = forklarDekning('ikke_fastlonnet', 70.5)
    const permisjon = forklarDekning('ikke_fastlonnet', null)
    const ingenting = forklarDekning('ukjent', null)

    expect(full).toContain('141,25 timer')
    expect(halv).toContain('70,5 timer')

    // PERMISJON UTEN TILBAKEFOERING er Bjørn på Laguneparken, og det
    // tilfellet den gamle automatikken tok feil på: faktumet står,
    // ingenting gis. Sier setningen bare det første, leses den som en
    // tildeling.
    expect(permisjon).toContain('Ingen fastlønnet butikksjef')
    expect(permisjon).toContain('Ingen timer lagt tilbake')
    expect(permisjon).not.toMatch(/økt med/)

    // Alle fire skal kunne skilles fra hverandre av en leser.
    expect(new Set([full, halv, permisjon, ingenting]).size).toBe(4)
  })

  test('uavklarte måneder telles, også når ingen er fylt ut', () => {
    expect(uavklarte([], 12), 'ingenting utfylt').toBe(12)
    expect(uavklarte([{ fastlonnet: true }, { fastlonnet: false }], 12)).toBe(10)
    expect(uavklarte([{ fastlonnet: null }, { fastlonnet: true }], 12)).toBe(11)
    expect(uavklarte(Array(12).fill({ fastlonnet: true }), 12)).toBe(0)
  })

  test('tolv måneder, i rekkefølge', () => {
    expect(MANEDER).toHaveLength(12)
    expect(MANEDER[0]).toBe('Januar')
    expect(MANEDER[11]).toBe('Desember')
  })
})
