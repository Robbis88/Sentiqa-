// Å koble et navn fra et fremmed system til en stasjon hos oss.
//
// easy@work skriver «St1 - Bønes». Basen kan ha «Bønes», «St1 Bønes»,
// «Bønes (0084)» eller noe fjerde — navnene er tastet inn av mennesker i
// to systemer som aldri har snakket sammen. Filene har ikke butikknummer,
// så navnet er alt vi har.
//
// Reglene er rangert etter hvor sikre de er, og den første som treffer
// vinner. Er den siste tvetydig, matcher vi ikke i det hele tatt: en
// stasjons timeforbruk bokført på nabostasjonen er verre enn en importrad
// som sier at noe må ryddes.

const noekkel = (v: string) => v.toLowerCase().replace(/[^a-z0-9à-ÿ]/g, '')
const utenKjede = (v: string) => noekkel(v).replace(/^st1/, '')

export type Stasjonsnavn = { id: string; navn: string }

export function lagStasjonsmatcher(stasjoner: Stasjonsnavn[]) {
  const oppslag = new Map<string, string>()
  for (const s of stasjoner) {
    oppslag.set(noekkel(s.navn), s.id)
    const u = utenKjede(s.navn)
    // Bare hvis det blir noe igjen å kjenne igjen. En stasjon som het
    // «St1» ville ellers matchet alt.
    if (u.length >= 3 && !oppslag.has(u)) oppslag.set(u, s.id)
  }

  return (lokasjon: string): string | undefined => {
    if (!lokasjon.trim()) return undefined

    // 1) Samme navn, sett bort fra store bokstaver, bindestreker og mellomrom.
    const direkte = oppslag.get(noekkel(lokasjon)) ?? oppslag.get(utenKjede(lokasjon))
    if (direkte) return direkte

    // 2) Den ene inneholder den andre: «bønes» mot «bønes0084». Minst fire
    //    tegn, ellers ville «st1» og «as» tatt hverandre.
    const n = utenKjede(lokasjon)
    if (n.length < 4) return undefined
    const treff = [...oppslag.entries()].filter(
      ([k]) => k.length >= 4 && (k.includes(n) || n.includes(k)),
    )
    // Nøyaktig én stasjon. Peker det på to, er gjetningen verdiløs.
    const unike = new Set(treff.map(([, id]) => id))
    return unike.size === 1 ? treff[0][1] : undefined
  }
}
