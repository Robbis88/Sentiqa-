import { describe, it, expect } from 'vitest'
import { lagPdf, filnavn, pdfTekst } from './pdf'
import { byggUkebrief } from './bygg'
import { skjemabilde } from './skjema'
import type { Ukedata } from './type'

// =====================================================================
// PDF-en feiler i RUNTIME, ikke i typecheck.
//
// `@react-pdf/renderer` godtar en `style` den ikke forstår helt til den
// skal tegne den, og en ugyldig `flexDirection` eller en manglende font
// blir en kastet exception midt i en nedlasting. Typecheck ser ingenting
// av det. Derfor rendres dokumentet her, med et brev som har alle deler
// i seg — det er den eneste maaten aa vite at ruta ikke svarer 500.
// =====================================================================

const DAGER = ['2026-08-24', '2026-08-25', '2026-08-26', '2026-08-27', '2026-08-28', '2026-08-29', '2026-08-30']

/** Et brev med ALLE deler: handlinger, begge bolker, ukedagsrad og
    «vet ikke». Rendrer den, rendrer de tynnere ogsaa. */
function fulltBrev() {
  const d: Ukedata = {
    stasjonNavn: '0603 Teststasjon',
    ukeMandag: '2026-08-24',
    omsetning: 300000,
    omsetningIfjor: 400000,
    bpUke: 380000,
    avdelinger: [
      { kode: '20', navn: 'Bakeri', omsetning: 10000, ifjor: 40000, vekstPst: -75 },
      { kode: '40', navn: 'Ferskmat', omsetning: 60000, ifjor: 20000, vekstPst: 200 },
    ],
    utsolgt: [{ navn: 'Kaffe & Kaker «stor»', taptKr: 12000, dager: 5 }],
    treff: null,
    timer: { brukt: 240, ukesramme: 200 },
    tilbakemeldinger: { antall: 3, ulest: 2, harAlvorlig: true },
    skjema: [skjemabilde({
      navn: 'Rutiner',
      poster: [{ opprettet: '2026-01-01T09:00:00Z', slettet: null }],
      utfortPerDato: new Map(DAGER.map((dag, i) => [dag, i === 6 ? 0 : 1])),
      ukeMandag: '2026-08-24',
    })],
    kritiskeNei: 1,
    hull: [{ kilde: 'Timesalg', dagerMangler: 2 }],
  }
  return byggUkebrief(d)
}

describe('ukebriefen som PDF', () => {
  it('rendrer et komplett brev til en gyldig PDF', async () => {
    const brief = fulltBrev()
    // Alle deler MAA vaere i brevet, ellers rendrer testen en tom side og
    // beviser ingenting - da er den en kanarifugl som ikke synger.
    expect(brief.handlinger.length).toBeGreaterThan(0)
    expect(brief.oppmerksomhet.length).toBeGreaterThan(0)
    expect(brief.bra.length).toBeGreaterThan(0)
    expect(brief.skjema.length).toBeGreaterThan(0)
    expect(brief.viIkkeVet.length).toBeGreaterThan(0)

    const pdf = await lagPdf(brief)
    expect(pdf.subarray(0, 5).toString('latin1')).toBe('%PDF-')
    expect(pdf.length).toBeGreaterThan(2000)
  }, 30000)

  // KANARIFUGL. Helvetica bruker WinAnsi og har ikke piler. react-pdf
  // kaster ikke - den tegner et ANNET tegn, og «↓ 22 %» ble til «" 22 %»
  // i den foerste PDF-en. Typecheck saa ingenting; det gjorde ingen test
  // heller, foer denne.
  it('bytter ut tegn Helvetica ikke kan kode', () => {
    expect(pdfTekst('↓ 22 %')).toBe('- 22 %')
    expect(pdfTekst('↑ 190 %')).toBe('+ 190 %')
    expect(pdfTekst('≈ 12 400 kr tapt')).toBe('ca. 12 400 kr tapt')
    expect(pdfTekst('− 73 600 kr')).toBe('- 73 600 kr')
  })

  it('lar tegn Helvetica FAKTISK kan kode staa i fred', () => {
    // æøå, tankestrek, midtprikk og anfoerselstegn finnes i WinAnsi. Ble
    // de erstattet ogsaa, ville brevet blitt fattigere uten grunn.
    const t = 'Bakevarer — 30 800 kr · «tomt i hylla» · Lørdag'
    expect(pdfTekst(t)).toBe(t)
  })

  it('gir et filnavn som skiller uker og stasjoner fra hverandre', () => {
    // En mappe med «ukebrief.pdf» tolv ganger er ikke et arkiv.
    expect(filnavn(fulltBrev())).toBe('ukebrief-uke-35-0603-Teststasjon.pdf')
  })
})
