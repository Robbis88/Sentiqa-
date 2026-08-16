// =====================================================================
// Fyll ut en .docx-mal uten å røre ordlyden.
//
// Arbeidsavtalene er Virkes maler, juridisk gjennomgått. Vi kan ikke
// skrive dem om til HTML og håpe formuleringene overlever — vi fyller ut
// originalen og lar alt annet stå.
//
// PROBLEMET: Word deler tekst i «runs» (<w:r>), og et felt kan bli
// splittet på tvers av flere. I malen for fast ansettelse står
// [stillingsprosent] helt i ett run, mens [Navn på arbeidstaker] er delt
// i tre. En enkel søk-og-erstatt treffer halvparten.
//
// LØSNINGEN: slå sammen bare de kjørene et felt faktisk spenner over, og
// behold formateringen til den første. Feltene er gråmarkerte i malene
// (highlight lightGray), så de ligger uansett i én stil — det er ikke
// noe å miste.
//
// Vi slår IKKE sammen hele avsnitt. Et avsnitt kan ha fet skrift midt
// inne, og den skal fortsatt være fet.
// =====================================================================

// Ikke merket server-only med vilje: modulen er ren, og fflate er 8 kB og
// virker begge steder. Da lar den seg teste. At den bare kalles fra
// serveren er en beslutning hos kallerne, ikke en teknisk begrensning her.
import { unzipSync, zipSync } from 'fflate'

const DOK = 'word/document.xml'

const tekstAv = (xml: string) => xml.replace(/<[^>]+>/g, '')

/** Alle [felt] i malen, i den rekkefølgen de står. */
export function finnFelter(docx: Uint8Array): string[] {
  const xml = new TextDecoder().decode(unzipSync(docx)[DOK])
  const flat = tekstAv(xml)
  const sett = new Set<string>()
  for (const m of flat.matchAll(/\[([^\]\[\n]{1,80}?)\]/g)) sett.add(m[1])
  return [...sett]
}

type Run = { start: number; slutt: number; tekstStart: number; tekstSlutt: number; tekst: string }

/** Alle <w:r>…</w:r> med posisjonen til innholdet i <w:t>. */
function finnRuns(xml: string): Run[] {
  const ut: Run[] = []
  const re = /<w:r(?:\s[^>]*)?>[\s\S]*?<\/w:r>/g
  for (const m of xml.matchAll(re)) {
    const start = m.index
    const slutt = start + m[0].length
    const t = /<w:t(?:\s[^>]*)?>([\s\S]*?)<\/w:t>/.exec(m[0])
    if (!t) continue
    const tekstStart = start + m[0].indexOf(t[1], t.index)
    ut.push({ start, slutt, tekstStart, tekstSlutt: tekstStart + t[1].length, tekst: t[1] })
  }
  return ut
}

/**
 * Bytter ut [felt] med verdier.
 *
 * Felt som ikke finnes i `verdier` står igjen som de er — en mal med
 * uutfylte klammer er lettere å oppdage enn en med tomme hull.
 */
export function fyllUt(docx: Uint8Array, verdier: Record<string, string>): Uint8Array {
  const filer = unzipSync(docx)
  let xml = new TextDecoder().decode(filer[DOK])

  // Én runde per felt. Feltene er få, og dokumentet er lite.
  for (const [navn, verdi] of Object.entries(verdier)) {
    const soek = `[${navn}]`
    for (;;) {
      const runs = finnRuns(xml)
      // Hvilke runs spenner søkestrengen over? Bygg opp teksten til vi
      // finner treffet, og noter hvilke runs som er med.
      let samlet = ''
      const kart: { run: number; fra: number }[] = []
      for (let i = 0; i < runs.length; i++) {
        kart.push({ run: i, fra: samlet.length })
        samlet += runs[i].tekst
      }
      const traff = samlet.indexOf(soek)
      if (traff < 0) break

      const slutt = traff + soek.length
      const forste = kart.filter((k) => k.fra <= traff).at(-1)!.run
      const siste = kart.filter((k) => k.fra < slutt).at(-1)!.run

      if (forste === siste) {
        // Feltet står helt i ett run — bytt bare teksten.
        const r = runs[forste]
        const ny = r.tekst.replace(soek, verdi)
        xml = xml.slice(0, r.tekstStart) + ny + xml.slice(r.tekstSlutt)
        continue
      }

      // Splittet. Legg hele den nye teksten i det FØRSTE runet — det er
      // det som bærer formateringen feltet har — og tøm de øvrige.
      const forFeltet = samlet.slice(kart[forste].fra, traff)
      const etterFeltet = samlet.slice(slutt, kart[siste].fra + runs[siste].tekst.length)
      const ny = forFeltet + verdi + etterFeltet

      // Bakfra, så posisjonene ikke forskyves underveis.
      for (let i = siste; i > forste; i--) {
        const r = runs[i]
        xml = xml.slice(0, r.tekstStart) + xml.slice(r.tekstSlutt)
      }
      const f = runs[forste]
      xml = xml.slice(0, f.tekstStart) + ny + xml.slice(f.tekstSlutt)
    }
  }

  filer[DOK] = new TextEncoder().encode(xml)
  return zipSync(filer, { level: 6 })
}

/** Ren tekst ut av dokumentet — til forhåndsvisning og til å teste med. */
export function docxTilTekst(docx: Uint8Array): string {
  const xml = new TextDecoder().decode(unzipSync(docx)[DOK])
  return tekstAv(xml.replace(/<\/w:p>/g, '\n'))
}
