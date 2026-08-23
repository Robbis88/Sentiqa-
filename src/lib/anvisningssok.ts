// =====================================================================
// Søk i anvisningsarkivet.
//
// PREMISSET: personalet søker på det de har i hånda, ikke på det arket
// heter. «ost» skal finne hornet med ost og skinke, selv om ordet «ost»
// ikke står i tittelen. Derfor stikkord ved siden av tittel og kategori.
//
// ALLE ORD MÅ TREFFE, ikke minst ett. «ost horn» skal gi hornet med ost
// — ikke alt som inneholder enten «ost» eller «horn». Det er forskjellen
// mellom et søk som føles presist og et som blir ubrukelig så snart
// arkivet passerer noen titalls ark.
//
// FILTRERES I NETTLESEREN, med vilje. Arkivet er lite — titalls til
// hundretalls rader — og lokal filtrering gir treff mens fingeren
// skriver, uten et nettverkskall per tastetrykk. Passerer arkivet noen
// tusen rader, hører søket hjemme i databasen.
//
// Ingen fuzzy matching, ingen stemming, ingen rangering. Delstreng over
// tre felt. Det holder når stikkordene er satt fornuftig — og det er
// forutsigbart, som er mer verdt enn smart når man står med hansker.
// =====================================================================

export type Anvisning = {
  id: string
  tittel: string
  kategori: string
  stikkord: string[]
  innhold: string | null
  fil_sti: string | null
  dato: string | null
  erstatter_dato: string | null
}

/**
 * Trimmet, små bokstaver, kollapsede mellomrom.
 *
 * Brukes både til søk og til duplikatsjekk, og det er med vilje samme
 * funksjon: to ark som er «like nok» for søket skal være like nok for
 * advarselen også.
 */
export function normaliser(s: string): string {
  return s.trim().toLowerCase().replace(/\s+/g, ' ')
}

/** Feltene et søk leter i, slått sammen én gang per rad. */
function hoystakk(a: Anvisning): string {
  return normaliser([a.tittel, a.kategori, a.stikkord.join(' ')].join(' '))
}

/**
 * Radene som treffer.
 *
 * TOM SØKETEKST GIR ALT, ikke ingenting. En tom skjerm med «søk for å
 * begynne» tvinger den som bare vil bla til å gjette et ord først.
 */
export function sok(rader: Anvisning[], tekst: string): Anvisning[] {
  const q = normaliser(tekst)
  if (!q) return rader
  const ord = q.split(' ')
  return rader.filter((a) => {
    const h = hoystakk(a)
    return ord.every((o) => h.includes(o))
  })
}

/** Stikkord fra fritekst: komma eller mellomrom, normalisert, uten duplikater. */
export function lesStikkord(raa: string): string[] {
  return [...new Set(
    raa.split(/[,;\n]+/).map((s) => normaliser(s)).filter(Boolean),
  )]
}

export type Duplikat = { id: string; tittel: string; grunn: 'tittel' | 'filnavn' }

/**
 * Finnes arket fra før?
 *
 * BLOKKERER IKKE, OG DET ER HELE POENGET. En ny versjon av samme ark har
 * som regel identisk tittel — og det er nettopp da man vil laste opp.
 * Advarselen finnes for at man skal se det, ikke for å bli stoppet.
 */
export function finnDuplikat(
  eksisterende: { id: string; tittel: string; original_filnavn: string | null }[],
  ny: { tittel: string; filnavn: string | null },
): Duplikat | null {
  const t = normaliser(ny.tittel)
  const f = ny.filnavn ? normaliser(ny.filnavn) : null

  for (const e of eksisterende) {
    if (normaliser(e.tittel) === t) return { id: e.id, tittel: e.tittel, grunn: 'tittel' }
  }
  if (f) {
    for (const e of eksisterende) {
      if (e.original_filnavn && normaliser(e.original_filnavn) === f) {
        return { id: e.id, tittel: e.tittel, grunn: 'filnavn' }
      }
    }
  }
  return null
}

// Grensene for opplasting. Validert FØR vi snakker med storage, så
// brukeren får en setning på norsk i stedet for en API-feil på engelsk.
export const MAKS_BYTES = 20 * 1024 * 1024
export const TILLATT_TYPE = 'application/pdf'

/** Feilteksten, eller null når fila kan lastes opp. */
export function sjekkFil(fil: { size: number; type: string; name: string }): string | null {
  if (fil.size === 0) return 'Fila er tom.'
  if (fil.size > MAKS_BYTES) {
    const mb = Math.round((fil.size / (1024 * 1024)) * 10) / 10
    return `Fila er ${String(mb).replace('.', ',')} MB. Grensen er 20 MB.`
  }
  // Nettleseren setter `type` av filendelsen og tar av og til feil. Vi
  // sjekker begge, så en riktig PDF med rar MIME-type slipper gjennom og
  // en omdøpt .docx ikke gjør det.
  const erPdf = fil.type === TILLATT_TYPE || /\.pdf$/i.test(fil.name)
  if (!erPdf) return 'Bare PDF kan lastes opp.'
  return null
}

/**
 * Nøkkelen i storage: `{retailer}/{tid}-{tilfeldig}.pdf`.
 *
 * ALDRI BRUKERENS EGET FILNAVN. Det gir kollisjoner når to laster opp
 * «horn.pdf», tegnsettproblemer på æøå, og stier andre kan gjette seg
 * til. Originalnavnet lagres i basen — det er der det gjør nytte, til
 * duplikatvarselet.
 */
export function lagFilsti(retailerId: string, tid: number, tilfeldig: string): string {
  return `${retailerId}/${tid}-${tilfeldig}.pdf`
}
