import { describe, expect, it } from 'vitest'
import { erLonnsgrunnlagFil, gjenkjennLonnsgrunnlag, lesLonnsgrunnlag } from './lonnsgrunnlag'
import { erStemplingFil } from './stempling'
import { erLonnsartFil } from './lonnsart'

// Formen er hentet fra en ekte eksport (Laguneparken, august 2026, 158
// dagslinjer), men navnene er byttet ut. Lønn per navngitt person er
// personopplysninger og hører ikke hjemme i et repo.
const TOPP = [
  'Stemplingsnummer', 'Ansatt', 'Lønn', 'Betalingsfrekvens', 'Lokasjon',
  'Hovedlokasjon', 'Dato', 'Timer', 'Etterbetaling Ordinære timer (antall)',
  'Sykelønn', 'Matpenger',
  'Etterbetaling Tillegg hverdag 18-21 (antall)',
  'Etterbetaling Tillegg hverdag 21-24 (antall)',
  'Etterbetaling Tillegg hverdag 00-06 (antall)',
  'Etterbetaling Tillegg lørdag (antall)',
  'Etterbetaling Tillegg søndag 00-06 (antall)',
  'Etterbetaling Tillegg søndag 06-18 (antall)',
  'Etterbetaling Tillegg søndag 18-24 (antall)',
  'Fastlønn', '50% O.tidstillegg dag', 'O.tidstillegg dag 100% søn',
].map((x) => `"${x}"`).join(',')

/** En dagslinje. `felt` overstyrer kolonner på navn. */
const dag = (
  nr: string, navn: string, sats: string, dato: string,
  felt: Record<string, string> = {},
) => {
  const rad: Record<string, string> = {
    Stemplingsnummer: nr, Ansatt: navn, Lønn: sats, Betalingsfrekvens: sats,
    Lokasjon: 'St1 - Laguneparken', Hovedlokasjon: 'St1 - Laguneparken', Dato: dato,
    ...felt,
  }
  return TOPP.split(',')
    .map((k) => k.slice(1, -1))
    .map((k) => {
      const v = rad[k] ?? (k === 'Etterbetaling Ordinære timer (antall)' ? rad.Timer : '0')
      return /^[\d.]*$/.test(v ?? '') ? (v || '0') : `"${v}"`
    })
    .join(',')
}

const fil = (...rader: string[]) => [
  '" 1 august 2026  - 31 august 2026 ",,,"Generert av N N,  7 september 2026 10:51"',
  '',
  TOPP,
  // Delsummene. Leses de med, tredobles timene.
  ',,,,"St1 - Laguneparken",,,16,16,0,0,0,0,0,0,0,0,0,0,0,0',
  '11058,"Olav N",260.46,Time,,"St1 - Laguneparken",,16,16,0,0,0,0,0,0,0,0,0,0,0,0',
  '11058,"Olav N",260.46,Time,"St1 - Laguneparken","St1 - Laguneparken",,16,16,0,0,0,0,0,0,0,0,0,0,0,0',
  ...rader,
].join('\n')

describe('lesLonnsgrunnlag', () => {
  it('leser dagslinjene og priser dem', () => {
    const r = lesLonnsgrunnlag(fil(
      dag('11058', 'Olav N', '260.46', '2026-08-24', { Timer: '8' }),
      dag('11058', 'Olav N', '260.46', '2026-08-25', { Timer: '8' }),
    ))
    expect(r.rapporttype).toBe('easyatwork_lonnsgrunnlag')
    expect(r.lokasjoner).toEqual(['St1 - Laguneparken'])
    expect(r.fraDato).toBe('2026-08-24')
    expect(r.tilDato).toBe('2026-08-25')
    expect(r.linjer).toHaveLength(2)
    expect(r.linjer[0].lonnsart).toBe('2')
    expect(r.linjer[0].lonnsartTekst).toBe('2 Timelønn')
    expect(r.linjer[0].timer).toBe(8)
    expect(r.linjer[0].belopKr).toBe(2083.68) // 8 × 260,46
  })

  // ===================================================================
  // DELSUMMENE ER FELLA
  //
  // Fila har fire nivåer i de samme kolonnene, og de tre øverste er
  // summer av det fjerde. Leses alt, blir 16 timer til 64. Det ville
  // ikke sett ut som en feil — det ville sett ut som en stasjon med
  // altfor høy bemanning, og lønnsandelen ville blitt firedoblet.
  // ===================================================================
  it('leser bare dagslinjer, aldri delsummene over dem', () => {
    const r = lesLonnsgrunnlag(fil(
      dag('11058', 'Olav N', '260.46', '2026-08-24', { Timer: '8' }),
      dag('11058', 'Olav N', '260.46', '2026-08-25', { Timer: '8' }),
    ))
    expect(r.linjer.reduce((s, l) => s + l.timer, 0)).toBe(16)
  })

  // `Etterbetaling Ordinære timer (antall)` er en KOPI av `Timer` — lik
  // på øret i alle 158 dagslinjene i august. Leses begge, dobles
  // timelønna, og lønnskosten ser ut som to skift der det var ett.
  it('leser ikke etterbetalingskopien av timekolonnen', () => {
    const r = lesLonnsgrunnlag(fil(dag('1', 'A B', '200', '2026-08-24', { Timer: '8' })))
    expect(r.linjer.filter((l) => l.lonnsart === '2')).toHaveLength(1)
  })

  it('gir hvert tillegg sin egen linje, med lønnsarteksportens etikett', () => {
    const r = lesLonnsgrunnlag(fil(dag('1', 'A B', '200', '2026-08-24', {
      Timer: '8',
      'Etterbetaling Tillegg hverdag 18-21 (antall)': '3',
      'Etterbetaling Tillegg søndag 18-24 (antall)': '2',
    })))
    const per = Object.fromEntries(r.linjer.map((l) => [l.lonnsartTekst, l.belopKr]))
    expect(per['2 Timelønn']).toBe(1600)
    expect(per['1429 Tillegg hverdag 18-21']).toBe(36) // 3 × 12
    expect(per['1435 Tillegg søndag 18-24']).toBe(57) // 2 × 28,50 — ikke 27,50
  })

  it('hopper over en kolonne som er null, i stedet for å skrive en nullinje', () => {
    const r = lesLonnsgrunnlag(fil(dag('1', 'A B', '200', '2026-08-24', { Timer: '8' })))
    expect(r.linjer).toHaveLength(1)
  })

  it('leser sykelønn som egen lønnsart, betalt med egen sats', () => {
    const r = lesLonnsgrunnlag(fil(dag('1', 'A B', '185.58', '2026-08-24', {
      Timer: '0', Sykelønn: '8',
    })))
    expect(r.linjer).toHaveLength(1)
    expect(r.linjer[0].lonnsartTekst).toBe('12 Sykelønn')
    expect(r.linjer[0].belopKr).toBe(1484.64)
  })

  // ===================================================================
  // EN KOLONNE VI IKKE PRISER ER ET FUNN, IKKE EN DETALJ
  //
  // Rapporten settes sammen av avhukede kolonner i easy@work. Ni av dem
  // sto tomme i august 2026 — matpenger, ansvarstillegg,
  // kjøregodtgjørelse, helligdagsgodtgjørelse, overtid for
  // fastlønnede, fastlønn og vasketillegg. Får én av dem en verdi, er
  // det en lønnsart vi ikke kan prise, og et beløp som stille ble
  // borte ser ut som en billig måned.
  // ===================================================================
  it('kaster når en ukjent kolonne bærer et tall', () => {
    expect(() => lesLonnsgrunnlag(fil(
      dag('1', 'A B', '200', '2026-08-24', { Timer: '8', Fastlønn: '42000' }),
    ))).toThrow(/Fastlønn/)
  })

  it('lar den samme kolonnen være i fred så lenge den er tom', () => {
    expect(() => lesLonnsgrunnlag(fil(
      dag('1', 'A B', '200', '2026-08-24', { Timer: '8', Fastlønn: '0' }),
    ))).not.toThrow()
  })

  it('kaster på en dato som ikke er ISO, i stedet for å hoppe over linja', () => {
    expect(() => lesLonnsgrunnlag(fil(
      dag('1', 'A B', '200', '24 aug 2026', { Timer: '8' }),
    ))).toThrow(/Ugyldig dato/)
  })

  it('kaster på en fil uten dagslinjer', () => {
    expect(() => lesLonnsgrunnlag(fil())).toThrow(/ingen dagslinjer/)
  })

  // KOLONNER SLÅS OPP PÅ NAVN. Rapporten er konfigurerbar; en kolonne
  // til flytter alt til høyre for den. En parser som teller fra venstre
  // ville lest tillegg som noe annet uten å si fra.
  it('finner kolonnene selv om rekkefølgen endres', () => {
    const bytt = (s: string) => s.replace(
      '"Etterbetaling Tillegg hverdag 18-21 (antall)","Etterbetaling Tillegg hverdag 21-24 (antall)"',
      '"Etterbetaling Tillegg hverdag 21-24 (antall)","Etterbetaling Tillegg hverdag 18-21 (antall)"',
    )
    const raa = fil(dag('1', 'A B', '200', '2026-08-24', {
      Timer: '8', 'Etterbetaling Tillegg hverdag 18-21 (antall)': '3',
    }))
    // Bytt om BÅDE toppraden og verdiene, slik easy@work ville gjort.
    const linjer = raa.split('\n')
    linjer[2] = bytt(linjer[2])
    const felt = linjer[linjer.length - 1].split(',')
    ;[felt[11], felt[12]] = [felt[12], felt[11]]
    linjer[linjer.length - 1] = felt.join(',')
    const r = lesLonnsgrunnlag(linjer.join('\n'))
    expect(r.linjer.find((l) => l.lonnsart === '1429')?.timer).toBe(3)
  })
})

// =====================================================================
// TRE EKSPORTER SOM IKKE MÅ TA HVERANDRES FILER
//
// Gjenkjenningen her er den løseste av de tre — to kolonnenavn — og
// prøves derfor sist. At de ikke overlapper er ikke noe å stole på i
// det stille: påstanden står her, begge veier.
// =====================================================================
describe('gjenkjenning', () => {
  const GRUNNLAG = fil(dag('1', 'A B', '200', '2026-08-24', { Timer: '8' }))
  const LONNSART = '"St1 - Dale","A B",1104238,"2026-08-03 00:00:00",,'
    + '"2026-08-03 10:00:00-2026-08-03 16:00:00","2 Timelønn",6.00,"1 542.00"'
  const BASIS = 'Forretningsdato,Stemplingsnummer,Ansatt,Type,Fra,Til\n'
    + '13 aug 2026,308,A B,Betalt tid,12:00,18:00'

  it('kjenner igjen lønnsgrunnlaget', () => {
    expect(erLonnsgrunnlagFil(GRUNNLAG)).toBe(true)
    expect(gjenkjennLonnsgrunnlag(GRUNNLAG)).toBe('easyatwork_lonnsgrunnlag')
  })

  it('tar ikke lønnsarteksporten', () => {
    expect(erLonnsgrunnlagFil(LONNSART)).toBe(false)
    expect(erLonnsartFil(GRUNNLAG)).toBe(false)
  })

  // BASIS EXPORT DELER `Stemplingsnummer` MED DENNE. Den skilles på at
  // Basis har `Forretningsdato` der denne har `Dato`, og den prøves
  // først. Begge halvdelene må holde.
  it('tar ikke Basis Export', () => {
    expect(erLonnsgrunnlagFil(BASIS)).toBe(false)
    expect(erStemplingFil(GRUNNLAG)).toBe(false)
    expect(erStemplingFil(BASIS)).toBe(true)
  })

  it('sier nei til noe som ikke er en av dem', () => {
    expect(erLonnsgrunnlagFil('a,b,c\n1,2,3')).toBe(false)
    expect(gjenkjennLonnsgrunnlag('')).toBe('ukjent')
  })
})
