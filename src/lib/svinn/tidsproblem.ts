// =====================================================================
// Samme vare, motsatt feil.
//
// Systemet har to sider som hver for seg ser halve bildet:
//
//   /svinn    hvilke varer dere KASTER
//   /utsolgt  hvilke varer dere går TOM for
//
// Hver av dem gir et opplagt råd: kast mindre, eller lag mer. Rådene er
// motsatte, og begge er feil når de gjelder samme vare.
//
// En vare som BÅDE kastes og går tom er ikke et volumproblem. Dere lager
// nok — bare til feil tid. Baguettene som kastes 22:00 er de samme som
// mangler 07:30. Løsningen er å flytte produksjonen, ikke endre mengden,
// og ingen av de to sidene kan se det alene.
//
// Derfor bor dette i en egen modul: det er en tredje observasjon, ikke en
// utvidelse av noen av dem.
// =====================================================================

export type Svinnrad = {
  ean: string
  varenavn: string | null
  dato: string
  antall: number | null
  /** Nettopris totalt for raden — det varen kostet dere. */
  kr: number | null
}

/** Samme form som `UtsolgtHendelse` i src/lib/utsolgt.ts. */
export type Utsolgtrad = {
  ean: string
  varenavn: string
  fra: string
  til: string
  dager: number
  tapt_kr: number
}

export type Tidsproblem = {
  ean: string
  varenavn: string
  /** Dager varen ble kastet på. */
  svinnDager: number
  svinnAntall: number
  svinnKr: number
  /** Dager varen sto på null. */
  utsolgtDager: number
  utsolgtHendelser: number
  tapteKr: number
  /**
   * Hva feilen koster til sammen: det dere kastet pluss det dere ikke
   * fikk solgt. Begge er ekte penger, og de peker på samme årsak.
   */
  samletKr: number
  /** Én setning en butikksjef kan handle på. */
  melding: string
}

/**
 * Hvor mange dager som må til før det regnes som et mønster.
 *
 * Én kastedag og ett hull kan være uflaks — en levering som kom sent, en
 * buss med tredve ungdommer. To av hver er en vane.
 */
const MIN_SVINNDAGER = 2

export function finnTidsproblemer(
  svinn: Svinnrad[],
  utsolgt: Utsolgtrad[],
): Tidsproblem[] {
  const perVare = new Map<string, {
    varenavn: string
    dager: Set<string>
    antall: number
    kr: number
  }>()

  for (const s of svinn) {
    if (!s.ean) continue
    const v = perVare.get(s.ean)
      ?? { varenavn: s.varenavn ?? s.ean, dager: new Set<string>(), antall: 0, kr: 0 }
    if (s.varenavn && v.varenavn === s.ean) v.varenavn = s.varenavn
    v.dager.add(s.dato)
    // Kastet antall føres negativt i eksporten. Fortegnet er ikke poenget
    // — mengden er.
    v.antall += Math.abs(s.antall ?? 0)
    v.kr += Math.abs(s.kr ?? 0)
    perVare.set(s.ean, v)
  }

  const perUtsolgt = new Map<string, { navn: string; dager: number; n: number; tapt: number }>()
  for (const u of utsolgt) {
    const p = perUtsolgt.get(u.ean) ?? { navn: u.varenavn, dager: 0, n: 0, tapt: 0 }
    p.dager += u.dager
    p.n += 1
    p.tapt += u.tapt_kr
    perUtsolgt.set(u.ean, p)
  }

  const ut: Tidsproblem[] = []
  for (const [ean, s] of perVare) {
    const u = perUtsolgt.get(ean)
    // Begge deler kreves. Bare svinn er /svinn sin sak; bare hull er
    // /utsolgt sin. Det er overlappet som er nytt.
    if (!u) continue
    if (s.dager.size < MIN_SVINNDAGER) continue

    const samletKr = s.kr + u.tapt
    ut.push({
      ean,
      varenavn: s.varenavn || u.navn,
      svinnDager: s.dager.size,
      svinnAntall: Math.round(s.antall),
      svinnKr: Math.round(s.kr),
      utsolgtDager: u.dager,
      utsolgtHendelser: u.n,
      tapteKr: Math.round(u.tapt),
      samletKr: Math.round(samletKr),
      melding: `Kastet ${s.dager.size} dager og gikk tom ${u.dager}. `
        + 'Mengden er ikke feil — tidspunktet er. Prøv å flytte produksjonen '
        + 'framfor å endre hvor mye som lages.',
    })
  }

  // Dyrest først. Det er der en endring betyr mest.
  return ut.sort((a, b) => b.samletKr - a.samletKr)
}

/** Hva hele funnet koster til sammen. Til nivå 1 på siden. */
export const samletTap = (rader: Tidsproblem[]) =>
  rader.reduce((n, r) => n + r.samletKr, 0)
