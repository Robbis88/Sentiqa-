import { describe, expect, it } from 'vitest'
import { byggEasyatwork as bygg, fraLinjer, SATSER } from './easyatwork'
import type { Lonnsartlinje } from '@/lib/parsere/lonnsart'

const byggEasyatwork = (l: Lonnsartlinje[]) => bygg(fraLinjer(l))

const L = (
  lonnsart: string, timer: number, belopKr: number, dato = '2026-08-03', tekst?: string,
): Lonnsartlinje => ({
  ansattNr: '1', ansattNavn: 'A B', dato, lonnsart,
  lonnsartTekst: tekst ?? `${lonnsart} art`, timer, belopKr, lokasjon: 'St1 - Dale',
})

describe('byggEasyatwork', () => {
  it('legger hver lønnsart på sin konto', () => {
    const [m] = byggEasyatwork([
      L('2', 10, 2000), L('12', 5, 1000), L('1429', 3, 36), L('97', 1, 200),
    ])
    // TILLEGG OG OVERTID LIGGER I 503, ikke i 502. Malt mot Dale 2026 er
    // 502 noeyaktig 500 kroner hver maaned - fast mobildekning, ikke
    // kveld og helg. De variable tilleggene foerer St1 inne i 503.
    expect(m.perKonto).toEqual({ '503': 2236, '505': 1000 })
    expect(m.kontantKr).toBe(3236)
  })

  // TILLEGGENE BÆRER DE SAMME TIMENE EN GANG TIL. Et kveldstillegg er
  // ikke en ekstra time, det er en dyrere time. Summerte vi alle artene,
  // ga Dale august 1 907,81 timer der de arbeidede var 1 264,73 — og en
  // snittsats som var 35 % for lav.
  it('teller timer bare på lønnsart 2', () => {
    const [m] = byggEasyatwork([L('2', 8, 1600), L('1429', 3, 36), L('1430', 2, 44)])
    expect(m.timer).toBe(8)
  })

  // PENSJONEN ER UTENFOR LOENNSKOSTEN, og det er ikke en detalj: den laa
  // inne til 2026-09-07 og gjorde tallet usammenlignbart med regnskapet.
  // St1 foerer OTP som 5945 under konto 590, som /lonnskost holder
  // utenfor med vilje. Malt paa Dale juli var pensjonen 7 609 der - den
  // skjulte en del av gapet ved aa blaase opp anslaget.
  it('holder pensjonen utenfor lønnskosten, men regner den ut', () => {
    const [m] = byggEasyatwork([L('2', 10, 100000)])
    expect(m.feriepengerKr).toBe(12000)
    expect(m.pensjonKr).toBe(2000)
    // 14,1 % av (100 000 + 12 000). Konti 540 og 541 er nettopp de to.
    expect(m.agaKr).toBe(15792)
    expect(m.lonnskostKr).toBe(127792)
    // Kanarifugl: legger noen pensjonen tilbake i summen, blir dette 130 074.
    expect(m.lonnskostKr).not.toBe(130074)
  })

  // FASIT FRA DEN EKTE FILA: Dale, august 2026, 400 linjer. Bare
  // aggregater — lønn per navngitt person hører ikke hjemme i et repo.
  it('treffer Dale august 2026', () => {
    const [m] = byggEasyatwork([
      L('2', 1264.73, 247137.42),
      L('12', 75, 14651.88),
      L('1429', 162.78, 18647.67, '2026-08-03', '1429 samlet tillegg og overtid'),
    ])
    expect(m.kontantKr).toBe(280436.97)
    expect(m.timer).toBe(1264.73)
    expect(m.perKonto['503']).toBe(265785.09) // timelønn + tillegg
    expect(m.perKonto['505']).toBe(14651.88)
    expect(m.perKonto['502']).toBeUndefined()
    expect(m.feriepengerKr).toBe(33652.44)
    expect(m.pensjonKr).toBe(5608.74)
    expect(m.agaKr).toBe(44286.61)
    expect(m.lonnskostKr).toBe(358376.01)
    expect(m.ukjenteArter).toEqual([])
  })

  // KANARIFUGL. Fristelsen er «alt som ikke er 2 eller 12 er tillegg» —
  // den ville lagt en fastlønnsart rett i 502 og gjort et hull til et
  // tall. Slutter kartet å rapportere ukjente, feiler denne.
  it('rapporterer en ukjent lønnsart i stedet for å bøtte den', () => {
    const [m] = byggEasyatwork([L('2', 10, 2000), L('1', 160, 52500, '2026-08-03', '1 Fastlønn')])
    expect(m.ukjenteArter).toEqual(['1 Fastlønn'])
    expect(m.kontantKr).toBe(2000)
    expect(m.perKonto['502']).toBeUndefined()
  })

  // JULI 2026, DALE - MALINGEN SOM FORKLARTE HELE GAPET.
  //
  // Timene stemmer paa 0,10 av 1 527,66 mot St1s eget noekkeltall, saa
  // eksporten mangler ingen vakt. Differansen mot regnskapet (441 172)
  // er 28 998 kroner, og den er dekomponert til siste krone:
  //
  //   sykeloenn som ikke er i eksporten   28 896   langtidssykmeldt stempler ikke
  //   fast mobildekning (502)                500   ikke en arbeidet time
  //   timeloenn+tillegg, easy@work hoeyere  -398   vakt over maanedsskiftet
  //
  // Fasiten her er kontantloenna og timene. Bommer de, er det parseren
  // eller kontokartet som har flyttet seg - ikke virkeligheten.
  it('treffer Dale juli 2026', () => {
    const [m] = byggEasyatwork([
      L('2', 1527.56, 297990.47, '2026-07-15'),
      L('12', 35.50, 5933.88, '2026-07-15'),
      L('96', 0.96, 137.28, '2026-07-15'),
      L('1429', 552.39, 11977.40, '2026-07-15', '1429 samlet tillegg'),
    ])
    expect(m.timer).toBe(1527.56)
    expect(m.kontantKr).toBe(316039.03)
    expect(m.perKonto['505']).toBe(5933.88)
    expect(m.lonnskostKr).toBeCloseTo(403872.6, 1)
  })

  it('deler på måned, nyeste først', () => {
    const m = byggEasyatwork([L('2', 1, 100, '2026-07-31'), L('2', 1, 200, '2026-08-01')])
    expect(m.map((x) => x.maaned)).toEqual(['2026-08', '2026-07'])
    expect(m[0].kontantKr).toBe(200)
  })

  it('satsene står ett sted', () => {
    expect(SATSER).toEqual({ feriepengerPst: 12, pensjonPst: 2, agaPst: 14.1 })
  })
})
