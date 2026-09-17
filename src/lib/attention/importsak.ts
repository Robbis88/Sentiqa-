// =====================================================================
// HENDELSE, SAK, TILSTAND — TRE TING SOM SÅ LIKE UT
// =====================================================================
//
// Robert, 2026-09-17, om Dales forside: «12 ting å se på» der samme
// `export.csv (27).csv` sto flere ganger, ved siden av mulig utsolgt og
// treffsikkerhet.
//
// Målt i produksjon samme dag:
//
//   import_jobber   1 897 rader, 4 med status «feilet»
//   varsler           25 rader, fra 12 strukturelt ulike filer
//
// Tjuefem kort for fire problemer. Og `butikksjef-dashbord.tsx` gjorde
// én varselrad om til ett kort, så tallene traff forsiden direkte.
//
// ---------------------------------------------------------------------
// DE TRE BEGREPENE
// ---------------------------------------------------------------------
//
//   HENDELSE   ett importforsøk. `import_jobber`-raden. Skjedde.
//   SAK        det strukturelle problemet: én `raa_fil_id`.
//   TILSTAND   trenger saken handling NÅ?
//
// Før dette var de samme ting: hver hendelse ble et varsel, og hvert
// varsel ble et kort som aldri lukket seg.
//
// ---------------------------------------------------------------------
// TILSTANDEN LESES AV JOBBEN, IKKE AV VARSELET
// ---------------------------------------------------------------------
//
// `settFeil` (`import/kjerne.ts`) skriver varselet én gang og setter
// status. Går fila gjennom senere, endres STATUSEN — varselet blir
// liggende ulest. Et varsel har ingen livssyklus knyttet til at
// problemet forsvant.
//
// Derfor er `import_jobber` sannhetseier for tilstand. 4 feilede jobber
// mot 25 uleste varsler er ikke en motsigelse: det er forskjellen på
// hva som SKJEDDE og hva som ER.
//
// ---------------------------------------------------------------------
// HVA STATUSEN FAKTISK BEVISER
// ---------------------------------------------------------------------
//
// «Siste jobb står ikke som feilet» beviser at siste FORSØK ikke
// feilet. Den beviser IKKE at alle ønskede data er korrekte eller
// komplette — en import kan lykkes teknisk og likevel mangle en stasjon
// (`sentiqa-stasjon-mangler-i-fila`).
//
// Språket her holder seg derfor til forsøket. `tilstand` heter ikke
// `loest`, og teksten sier «siste forsøk feilet», aldri «dataene
// mangler».
//
// ---------------------------------------------------------------------
// GAMLE VARSLER ER HISTORIKK, IKKE SAKER
// ---------------------------------------------------------------------
//
// De 25 radene som lå der før 3C har ingen `noekkel`. De kan ikke
// knyttes til en fil uten å matche på tittelteksten — nøyaktig den
// gjetningen nøkkelen erstatter, og målingen viste at 133 filnavn dekker
// mer enn én fil (ett av dem åtte).
//
// De telles derfor ikke som saker. De er hendelser som skjedde, og de
// slettes ikke. Tilstanden leses av jobbene uansett, så ingen aktiv sak
// blir borte av det.
// =====================================================================

export type Importtilstand = 'aktiv' | 'ikke_aktiv'

/** Statusverdier som betyr at forsøket står som mislykket. */
const FEILET = new Set(['feilet'])

export type Jobbrad = {
  id: string
  raa_fil_id: string
  status: string
  stasjon_id: string | null
  feilmelding: string | null
  opprettet_tid: string
  raa_filer: { filnavn: string } | null
}

export type Importhendelse = {
  jobbId: string
  status: string
  tid: string
  feilmelding: string | null
}

export type Importsak = {
  /** Identiteten. Fila, ikke filnavnet — se `3C`. */
  raaFilId: string
  /** Bare til visning. To filer kan hete det samme. */
  filnavn: string | null
  stasjonId: string | null
  /** Nyest først. Historikken, uavkortet. */
  hendelser: Importhendelse[]
  sisteStatus: string
  sisteTid: string
  /**
   * `aktiv` betyr at SISTE FORSØK står som feilet.
   *
   * Ikke at data mangler, og `ikke_aktiv` ikke at alt er riktig. Se
   * blokkkommentaren over.
   */
  tilstand: Importtilstand
}

/**
 * Samler importforsøk til saker.
 *
 * REKKEFØLGEN PÅ INNGANGEN BESTEMMER INGENTING. Hendelsene sorteres på
 * tid her, så en kallsted som glemmer `order` ikke stille gir feil
 * «siste status» — det er den formen for feil som ser ut som data.
 */
export function importsaker(jobber: readonly Jobbrad[]): Importsak[] {
  const per = new Map<string, Jobbrad[]>()
  for (const j of jobber) {
    if (!j.raa_fil_id) continue
    per.set(j.raa_fil_id, [...(per.get(j.raa_fil_id) ?? []), j])
  }

  const ut: Importsak[] = []
  for (const [raaFilId, rader] of per) {
    const sortert = [...rader].sort((a, b) => b.opprettet_tid.localeCompare(a.opprettet_tid))
    const siste = sortert[0]
    ut.push({
      raaFilId,
      filnavn: sortert.find((r) => r.raa_filer?.filnavn)?.raa_filer?.filnavn ?? null,
      stasjonId: siste.stasjon_id,
      hendelser: sortert.map((r) => ({
        jobbId: r.id, status: r.status, tid: r.opprettet_tid, feilmelding: r.feilmelding,
      })),
      sisteStatus: siste.status,
      sisteTid: siste.opprettet_tid,
      tilstand: FEILET.has(siste.status) ? 'aktiv' : 'ikke_aktiv',
    })
  }
  // Nyeste sak først. INGEN RANGERING — importsaker har ingen alvorsgrad
  // å sortere på, og en rekkefølge utledet av noe annet ville sett ut
  // som en prioritering.
  return ut.sort((a, b) => b.sisteTid.localeCompare(a.sisteTid))
}

export const aktive = (saker: readonly Importsak[]): Importsak[] =>
  saker.filter((s) => s.tilstand === 'aktiv')

/**
 * Setningen som står på kortet.
 *
 * BUTIKKSJEFSPRÅK. Forsiden skal ikke kreve at man vet hva en CSV-parser
 * eller en lønnsartmapping er. «Fem forsøk» er noe alle forstår;
 * «5 import_jobber med status feilet» er ikke.
 *
 * TALLET ER FORSØK, IKKE SAKER. Å skjule at det har skjedd flere ganger
 * ville vært den motsatte feilen av den vi retter.
 */
export function importtekst(saker: readonly Importsak[]): string | null {
  const a = aktive(saker)
  if (a.length === 0) return null
  const forsok = a.reduce((n, s) => n + s.hendelser.length, 0)
  const filer = a.length === 1 ? '1 fil' : `${a.length} filer`
  const ord = forsok === 1 ? '1 forsøk' : `${forsok} forsøk`
  return `Siste forsøk feilet · ${filer} · ${ord}`
}

// ---------------------------------------------------------------------
// HVA SOM ER DRIFT OG HVA SOM ER SYSTEM
// ---------------------------------------------------------------------
//
// Forsiden deles i to, men begge halvdeler hører til samme
// Attention-kontrakt: rangert på samme måte, med samme alvorsbegrep.
// Delingen er visuell, så en butikksjef ser med én gang om det er
// BUTIKKEN eller SENTIQA som trenger noe.
//
// Listen er over MERKER, ikke over tekst. Et merke settes av kallstedet
// og er en klassifisering; en tittel er en setning som endrer seg.
export const SYSTEMMERKER: ReadonlySet<string> = new Set(['Import', 'Systemet'])

export const erSystem = (merke: string): boolean => SYSTEMMERKER.has(merke)
