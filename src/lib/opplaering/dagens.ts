// =====================================================================
// Hvilken opplæring gjelder på denne stasjonen i dag?
//
// SKIFT-KALENDEREN ER UTLØSEREN. Nettbrettet spør ikke «finnes det
// opplæring?» — det spør «finnes det et skift i dag, på min stasjon, i
// en periode som ikke er fullført?». Det er hele koblingen mellom
// butikksjefens planlegging og det som dukker opp i butikken.
//
// Tre ledd, og alle tre må stemme:
//
//   dato        skiftet står på dagens dato
//   stasjon     perioden hører til stasjonen nettbrettet står på
//   fullført    perioden har ikke `fullfort_tid`
//
// Det siste er en av-bryter: markerer butikksjefen perioden som
// fullført, forsvinner sjekklista fra nettbrettet med én gang — også om
// det ligger flere skift igjen i kalenderen. Det er meningen. En
// opplæring som er erklært ferdig skal ikke fortsette å be om haker.
//
// ---------------------------------------------------------------------
// TIDENE FORTELLER, DE GJEMMER IKKE
//
// Et skift kan ha `start_tid` og `slutt_tid` — «29. august, 16–23». De
// vises som tekst, men de styrer ikke om lista er synlig.
//
// Grunnen er retningen på arbeidet: man haker av **etter** at noe er
// lært bort. En liste som forsvinner 23:00 forsvinner midt i jobben, og
// den siste oppgaven er som regel den som tok lengst tid. En liste som
// dukker opp først 16:00 hjelper heller ingen som forbereder seg.
//
// Skulle det vise seg at lista er i veien utenom timene, er tallene
// allerede der. Da er det en endring i visningen, ikke i modellen.
// =====================================================================

import { opplaeringSynlig, type Synlighet } from './synlig'

export type Skiftrad = {
  id: string
  periode_id: string
  dato: string
  start_tid: string | null
  slutt_tid: string | null
}

export type Perioderad = {
  id: string
  stasjon_id: string
  ansatt_navn: string
  /** Null for perioder opprettet foer `0171`. */
  ansatt_id?: string | null
  start_dato: string
  fullfort_tid: string | null
}

export type DagensOpplaering = {
  periodeId: string
  ansattNavn: string
  ansattId: string | null
  /** Klokkeslettene, ferdig formatert. Null når skiftet gjelder hele dagen. */
  tidsrom: string | null
  skiftId: string
  /**
   * Om lista skal vises NAA — hvem som står der, og hva klokka er.
   *
   * Raden blir med selv når den er skjult, og det er med vilje: en tom
   * skjerm uten forklaring ser ut som en ødelagt tablet. Nettbrettet
   * viser `forklaring()` i stedet. Se `synlig.ts`.
   */
  synlighet: Synlighet
}

/** `'16:00:00'` → `'16:00'`. Postgres `time` kommer med sekunder. */
export function klokkeslett(t: string | null): string | null {
  if (!t) return null
  const m = /^(\d{2}):(\d{2})/.exec(t)
  return m ? `${m[1]}:${m[2]}` : null
}

/** `'16:00'`–`'23:00'` → `'16:00–23:00'`. Null når én av dem mangler. */
export function tidsrom(start: string | null, slutt: string | null): string | null {
  const a = klokkeslett(start)
  const b = klokkeslett(slutt)
  // BEGGE ELLER INGEN. Databasen har en check-skranke på det samme, så
  // dette skal ikke kunne skje - men et halvt tidsrom vist som «16:00–»
  // ser ut som en feil i dataene og ikke som «hele dagen».
  return a && b ? `${a}–${b}` : null
}

/**
 * Opplæringene som skal vises på nettbrettet nå.
 *
 * STASJONEN FILTRERES HER OG I RLS. Denne funksjonen ser bare radene
 * databasen alt har sluppet gjennom — gjerdet står i policyen, ikke i
 * denne if-en. Filteret her finnes for at eieren, som ser flere
 * stasjoner, ikke skal få nabostasjonens opplæring på sitt nettbrett.
 */
export function dagensOpplaering(
  skift: Skiftrad[],
  perioder: Perioderad[],
  stasjonId: string | null,
  idag: string,
  /** Hvem som er identifisert med PIN, og hva klokka er i Oslo. Utelatt
      (desktop, tester av de tre gamle leddene) = ingen ny begrensning. */
  naa?: { aktivAnsattId: string | null; minutter: number },
): DagensOpplaering[] {
  const periodeFor = new Map(perioder.map((p) => [p.id, p]))

  return skift
    .filter((s) => s.dato === idag)
    .map((s) => ({ s, p: periodeFor.get(s.periode_id) }))
    .filter((x): x is { s: Skiftrad; p: Perioderad } => x.p != null)
    .filter((x) => x.p.fullfort_tid == null)
    .filter((x) => stasjonId == null || x.p.stasjon_id === stasjonId)
    .map((x) => ({
      periodeId: x.p.id,
      ansattNavn: x.p.ansatt_navn,
      ansattId: x.p.ansatt_id ?? null,
      synlighet: naa
        ? opplaeringSynlig({
          periodeAnsattId: x.p.ansatt_id ?? null,
          aktivAnsattId: naa.aktivAnsattId,
          startTid: x.s.start_tid,
          sluttTid: x.s.slutt_tid,
          naaMinutter: naa.minutter,
        })
        : { synlig: true as const },
      tidsrom: tidsrom(x.s.start_tid, x.s.slutt_tid),
      skiftId: x.s.id,
    }))
    // Samme rekkefølge hver gang. To opplæringer på samme dag er
    // sjeldent, men en liste som bytter rekkefølge mellom to lastinger
    // er vanskelig å stole på.
    .sort((a, b) => a.ansattNavn.localeCompare(b.ansattNavn, 'nb-NO'))
}

/**
 * Fremdrift for en periode.
 *
 * TELLEREN TELLER BARE AKTIVE OPPGAVER. Deaktiverer admin en oppgave
 * noen alt har huket av, ville en teller over alle rader gitt 21 av 20
 * — og en fremdrift over 100 % er ikke en fremdrift. Nevneren og
 * telleren må se på det samme utvalget.
 */
export function fremdrift(
  utfortOppgaveIder: Iterable<string>,
  aktiveOppgaveIder: Set<string>,
): { gjort: number; totalt: number; andel: number | null } {
  let gjort = 0
  for (const id of utfortOppgaveIder) if (aktiveOppgaveIder.has(id)) gjort++
  const totalt = aktiveOppgaveIder.size
  return {
    gjort,
    totalt,
    // Null, ikke 0, når det ikke finnes oppgaver. En andel av ingenting
    // er ikke null prosent.
    andel: totalt > 0 ? gjort / totalt : null,
  }
}
