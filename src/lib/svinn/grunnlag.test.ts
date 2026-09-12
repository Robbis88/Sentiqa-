import { describe, expect, it } from 'vitest'
import {
  ARKTYPE, AARSAK_ELDRE_FORMAT, kastprosent, periodestatus, samlet, serieStart,
  velgGrunnlag, velgGrunnlagPerNoekkel,
} from './grunnlag'
import { mankoPerStasjon, svinnPerGruppe, svinnPerStasjon } from './aggreger'

// =====================================================================
// SEKS BEVIS, EN FOR HVER TILSTAND LESERNE KAN MØTE
// =====================================================================
//
// Alle tall er målt, ikke oppfunnet:
//
//   FASE 1   produksjonsbasen 12.09: 588 rader, alle `nivaa='produkt'`,
//            `analyseomraade` = null (0208 etterfylte ikke området)
//   FASE 2   etter reimport: 78 grupperader + butikkprodukter per fil,
//            pluss 19 drivstoff og 1 ukjent som skal holdes ute
//   KAMPANJE Laguneparken april, `16015 KAMPANJE`: salg 0, usynlig 0,
//            kast 3 655,42 — raden den gamle parseren kastet
// =====================================================================

const L = '9038-laguneparken'
const D = '4185-dale'

// FASE 1: slik produksjonsbasen ser ut NÅ.
const fase1 = [
  { stasjon_id: L, periode: '2026-04-01', nivaa: 'produkt', analyseomraade: null, kode: '12010', navn: 'Baguette', salg: 1000, kast: 100, usynlig_kr: 50, usynlig_pst: 5 },
  { stasjon_id: L, periode: '2026-04-01', nivaa: 'produkt', analyseomraade: null, kode: '12020', navn: 'Wrap', salg: 500, kast: 40, usynlig_kr: -10, usynlig_pst: -2 },
  { stasjon_id: D, periode: '2026-04-01', nivaa: 'produkt', analyseomraade: null, kode: '13010', navn: 'Kaffe', salg: 800, kast: 0, usynlig_kr: 200, usynlig_pst: 25 },
]

// FASE 2: samme stasjonsmåned etter reimport. Grupperaden eier totalen,
// og produktradene summerer til den.
const fase2 = [
  { stasjon_id: L, periode: '2026-04-01', nivaa: 'gruppe', analyseomraade: 'butikk', kode: '120', navn: '120 Mat', salg: 1500, kast: 140, usynlig_kr: 40, usynlig_pst: 2.7 },
  { stasjon_id: L, periode: '2026-04-01', nivaa: 'produkt', analyseomraade: 'butikk', kode: '12010', navn: 'Baguette', salg: 1000, kast: 100, usynlig_kr: 50, usynlig_pst: 5 },
  { stasjon_id: L, periode: '2026-04-01', nivaa: 'produkt', analyseomraade: 'butikk', kode: '12020', navn: 'Wrap', salg: 500, kast: 40, usynlig_kr: -10, usynlig_pst: -2 },
  // Skal ALDRI inn i butikkanalysen, uansett fase:
  { stasjon_id: L, periode: '2026-04-01', nivaa: 'produkt', analyseomraade: 'drivstoff', kode: '1490', navn: 'Diesel', salg: 900000, kast: 0, usynlig_kr: 9999, usynlig_pst: 1 },
  { stasjon_id: L, periode: '2026-04-01', nivaa: 'produkt', analyseomraade: 'ukjent', kode: '99910', navn: 'UKJENT', salg: 72, kast: 0, usynlig_kr: -45, usynlig_pst: -62 },
]

const kampanje = {
  stasjon_id: L, periode: '2026-04-01', nivaa: 'produkt', analyseomraade: 'butikk',
  kode: '16015', navn: '16015 KAMPANJE', salg: 0, kast: 3655.42, usynlig_kr: 0, usynlig_pst: 0,
}

describe('A · før reimport gir dagens data uendrede tall', () => {
  it('summerer produktradene, som før', () => {
    const per = svinnPerStasjon(fase1)
    const lp = per.find((s) => s.stasjonId === L)!
    // Hånd­regnet på dagens rader: 100 + 40 kast, 50 − 10 usynlig.
    expect(lp.kastKr).toBe(140)
    expect(lp.usynligKr).toBe(40)
    expect(lp.datastatus).toBe('eldre_grunnlag')
  })

  it('KANARI: fase 1 må IKKE bli utilgjengelig', () => {
    // Filtrerte leserne bare på `nivaa = 'gruppe'`, ble hver måned tom
    // til den var reimportert. Det er fella som tømte månedsplanene.
    for (const s of svinnPerStasjon(fase1)) {
      expect(s.datastatus).not.toBe('utilgjengelig')
      expect(s.kastKr + Math.abs(s.usynligKr)).toBeGreaterThan(0)
    }
  })
})

describe('B · etter reimport eier grupperaden totalen', () => {
  it('leser gruppe, ikke produkt', () => {
    const valg = velgGrunnlag(fase2)
    expect(valg.grunnlag).toBe('gruppe')
    expect(valg.rader).toHaveLength(1)
    expect(valg.rader[0].kode).toBe('120')
  })

  it('totalen er gruppens tall', () => {
    const lp = svinnPerStasjon(fase2).find((s) => s.stasjonId === L)!
    expect(lp.kastKr).toBe(140)   // gruppens kast, ikke 140 + 140
    expect(lp.usynligKr).toBe(40)
    expect(lp.datastatus).toBe('gruppe')
  })

  it('drivstoff og ukjent holdes ute i begge faser', () => {
    const lp = svinnPerStasjon(fase2).find((s) => s.stasjonId === L)!
    // Diesel har 9 999 i usynlig. Slapp den inn, ville tallet blitt 10 039.
    expect(lp.usynligKr).toBe(40)
    const barePrudukt = svinnPerStasjon(fase2.filter((r) => r.nivaa !== 'gruppe'))
    expect(barePrudukt.find((s) => s.stasjonId === L)!.usynligKr).toBe(40)
  })
})

describe('C · mangler grupperaden, brukes eldre grunnlag', () => {
  it('faller tilbake og sier det', () => {
    const blandet = [...fase2.filter((r) => r.nivaa !== 'gruppe'), ...fase1.filter((r) => r.stasjon_id === D)]
    const per = svinnPerStasjon(blandet)
    expect(per.find((s) => s.stasjonId === L)!.datastatus).toBe('eldre_grunnlag')
    expect(per.find((s) => s.stasjonId === D)!.datastatus).toBe('eldre_grunnlag')
  })

  it('to stasjoner i ULIK fase regnes hver på sitt grunnlag', () => {
    // Laguneparken er reimportert, Dale er ikke. Ett felles valg ville
    // regnet den ene på feil nivå.
    const blandet = [...fase2, ...fase1.filter((r) => r.stasjon_id === D)]
    const per = svinnPerStasjon(blandet)
    expect(per.find((s) => s.stasjonId === L)!.datastatus).toBe('gruppe')
    expect(per.find((s) => s.stasjonId === D)!.datastatus).toBe('eldre_grunnlag')
    expect(per.find((s) => s.stasjonId === D)!.usynligKr).toBe(200)
  })

  it('KANARI: fallbacken skal strammes, ikke bli permanent', () => {
    // Den dagen alle perioder er reimportert, skal en manglende
    // grupperad være et FUNN. Denne testen holder statusen synlig slik
    // at «eldre_grunnlag» ikke kan forsvinne i stillhet.
    const valg = velgGrunnlag(fase1)
    expect(valg.datastatus).toBe('eldre_grunnlag')
    expect(valg.aarsak).toMatch(/ingen grupperad/i)
  })
})

describe('D · både gruppe og produkt: ingen dobbelttelling', () => {
  it('gruppen vinner, produktene legges ikke til', () => {
    const { grupper, datastatus } = svinnPerGruppe(fase2)
    const mat = grupper.find((g) => g.gruppe === '120')!
    expect(mat.kastKr).toBe(140)      // ikke 280
    expect(mat.usynligKr).toBe(40)    // ikke 80
    expect(datastatus).toBe('gruppe')
  })

  it('KANARI: summen av alle rader ville vært det dobbelte', () => {
    // Beviset på at regelen gjør noe. Uten nivåvalget:
    const naivt = fase2
      .filter((r) => r.analyseomraade === 'butikk')
      .reduce((a, r) => a + (r.kast ?? 0), 0)
    expect(naivt).toBe(280)
    const riktig = svinnPerGruppe(fase2).grupper.reduce((a, g) => a + g.kastKr, 0)
    expect(riktig).toBe(140)
  })

  it('produktnivået er fortsatt tilgjengelig som forklaring', () => {
    const lp = mankoPerStasjon(fase2).find((s) => s.stasjonId === L)!
    // Totalen fra gruppen …
    expect(lp.mankoKr).toBe(40)
    // … men topplista navngir VAREN, ikke «120 Mat».
    expect(lp.topp.map((t) => t.kode)).toEqual(['12010'])
    expect(lp.topp.map((t) => t.kode)).not.toContain('120')
  })
})

describe('E · kast uten salg: beløpet beholdes, prosenten finnes ikke', () => {
  it('REGRESJON: 16015 KAMPANJE, Laguneparken april 2026', () => {
    // Målt i produksjon. Den gamle parseren kastet raden fordi salg og
    // usynlig var null, og 3 655,42 kroner i kast forsvant fra basen.
    const p = kastprosent(kampanje.kast, kampanje.salg)
    expect(p.pst).toBeNull()
    expect(p.status).toBe('ikke_beregnbar')
    expect(p.tekst).toBe('Kast registrert uten registrert salg i samme periode.')
  })

  it('beløpet inngår i gruppens totale kast', () => {
    const medKampanje = [...fase2.filter((r) => r.nivaa !== 'gruppe'), kampanje]
    const { grupper } = svinnPerGruppe(medKampanje)
    // 16015 hører til gruppe 160, ikke 120 — og beløpet er med.
    expect(grupper.find((g) => g.gruppe === '160')!.kastKr).toBeCloseTo(3655.42, 2)
    expect(grupper.find((g) => g.gruppe === '120')!.kastKr).toBe(140)
  })

  it('KANARI: prosenten blir ikke 0, og ikke uendelig', () => {
    const p = kastprosent(3655.42, 0)
    expect(p.pst).not.toBe(0)
    expect(p.pst).not.toBe(Infinity)
    expect(Number.isFinite(p.pst as number)).toBe(false)
    // «Ingen kast» skal aldri stå på en rad med kast.
    expect(p.tekst).not.toMatch(/ingen kast/i)
  })

  it('null salg OG null kast er en annen sak, og sies annerledes', () => {
    const p = kastprosent(0, 0)
    expect(p.status).toBe('ikke_beregnbar')
    expect(p.tekst).toBe('Ingen salg og ingen kast registrert i perioden.')
  })

  it('vanlig rad regner som før', () => {
    expect(kastprosent(100, 1000)).toEqual({ pst: 10, status: 'ok', tekst: '' })
  })
})

describe('F · desember 2025 blokkeres, og viser ikke 0', () => {
  it('ingen rader gir utilgjengelig med årsak', () => {
    const s = periodestatus('2025-12-01', [], 'teoretisk_kr')
    expect(s.datastatus).toBe('utilgjengelig')
    expect(s.aarsak).toBe(AARSAK_ELDRE_FORMAT)
  })

  it('rader uten teoretisk BF blokkeres også', () => {
    // Fase 1-radene finnes, men har ingen teoretisk_kr — kolonnen kom i
    // 0208 og etterfylles ikke.
    const s = periodestatus('2026-01-01', [{ teoretisk_kr: null }], 'teoretisk_kr')
    expect(s.datastatus).toBe('utilgjengelig')
    expect(s.aarsak).toMatch(/teoretisk_kr/)
  })

  it('serien starter i januar, ikke i desember', () => {
    const statuser = [
      periodestatus('2025-12-01', [], 'teoretisk_kr'),
      periodestatus('2026-01-01', [{ teoretisk_kr: 1 }], 'teoretisk_kr'),
      periodestatus('2026-02-01', [{ teoretisk_kr: 1 }], 'teoretisk_kr'),
    ]
    expect(serieStart(statuser)).toBe('2026-01-01')
  })

  it('KANARI: en blokkert periode skal ikke bli et nullpunkt', () => {
    const s = periodestatus('2025-12-01', [], 'kast')
    // Det ville vært lett å returnere 0 her. Da blir «ingen data» til
    // «ingenting ble kastet», og retningen ut av desember er oppdiktet.
    expect(s.datastatus).toBe('utilgjengelig')
    expect(svinnPerStasjon([])).toEqual([])
  })
})

describe('regelen selv', () => {
  it('tom liste er utilgjengelig, ikke tom sum', () => {
    const valg = velgGrunnlag([])
    expect(valg.datastatus).toBe('utilgjengelig')
    expect(valg.grunnlag).toBeNull()
  })

  it('KANARI: «ProdGr3» er arkets navn og treffer ingen rad i basen', () => {
    // Robert skrev regelen som `nivaa = 'ProdGr3'`. Basen lagrer
    // normalisert, og 0208 har check (nivaa in ('gruppe','produkt')).
    // Et filter på arkets navn ville truffet null rader I STILLHET.
    expect(ARKTYPE.gruppe).toBe('ProdGr3')
    expect(ARKTYPE.produkt).toBe('Prod')
    expect(fase2.some((r) => r.nivaa === ARKTYPE.gruppe)).toBe(false)
    expect(velgGrunnlag(fase2.filter((r) => r.nivaa === 'ProdGr3')).datastatus).toBe('utilgjengelig')
  })

  it('den svakeste statusen vinner i en samlet sum', () => {
    expect(samlet([
      { grunnlag: 'gruppe', datastatus: 'gruppe', aarsak: '', rader: [] },
      { grunnlag: 'produkt', datastatus: 'eldre_grunnlag', aarsak: '', rader: [] },
    ])).toBe('eldre_grunnlag')
    expect(samlet([
      { grunnlag: 'gruppe', datastatus: 'gruppe', aarsak: '', rader: [] },
      { grunnlag: null, datastatus: 'utilgjengelig', aarsak: '', rader: [] },
    ])).toBe('utilgjengelig')
  })

  it('valget tas per stasjonsmåned, ikke per kjede', () => {
    const { perNoekkel } = velgGrunnlagPerNoekkel([...fase2, ...fase1], (r) => `${r.stasjon_id}|${r.periode}`)
    expect(perNoekkel.get(`${L}|2026-04-01`)!.grunnlag).toBe('gruppe')
    expect(perNoekkel.get(`${D}|2026-04-01`)!.grunnlag).toBe('produkt')
  })
})
