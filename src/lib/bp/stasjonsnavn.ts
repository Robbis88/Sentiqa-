// =====================================================================
// Å KOBLE ST1s STASJONSNAVN TIL VÅRE
//
// Delingsfila skriver «SHELL LAGUNEPARKEN». Basen har «St1 Laguneparken».
// Samme stasjon, to kjedenavn — St1 har byttet merke på flere av dem, og
// filene henger etter.
//
// «koble aldri på navn i stillhet» er husregelen, og den gjelder her:
// funksjonen kobler bare når koblingen er ENTYDIG, og den returnerer det
// den ikke fikk koblet slik at kallstedet kan si fra.
//
// ---------------------------------------------------------------------
// REGELEN, OG HVORFOR DEN ER SÅ SMAL
//
//   1. Eksakt treff på hele navnet.
//   2. Ellers: treff på navnet UTEN første ord, og bare hvis det er
//      entydig på begge sider.
//
// Første ord er kjedemerket («Shell», «St1»), og stedsnavnet er det som
// faktisk identifiserer stasjonen. Men to stasjoner kan hete det samme
// etter at merket er strippet — og da er et treff en gjetning. Derfor
// kreves entydighet begge veier: ett filnavn skal peke på én stasjon, og
// én stasjon skal treffes av ett filnavn.
//
// Ingen liste over merkenavn. En slik liste ville måttet vedlikeholdes
// per kjede, og den ville sett komplett ut lenge etter at den ikke var
// det.
// =====================================================================

export type Stasjonsnavn = { id: string; navn: string }

const normaliser = (s: string) => s.trim().toLowerCase().replace(/\s+/g, ' ')
const utenMerke = (s: string) => {
  const d = normaliser(s).split(' ')
  return d.length > 1 ? d.slice(1).join(' ') : d.join(' ')
}

/** Én oppslagstabell for navnene i en fil, og de som ikke lot seg koble. */
export function koblePaaNavn(
  stasjoner: Stasjonsnavn[],
  filnavn: string[],
): { kobling: Map<string, string>; ukoblet: string[] } {
  const eksakt = new Map<string, string[]>()
  const kort = new Map<string, string[]>()
  for (const s of stasjoner) {
    const e = normaliser(s.navn)
    const k = utenMerke(s.navn)
    eksakt.set(e, [...(eksakt.get(e) ?? []), s.id])
    kort.set(k, [...(kort.get(k) ?? []), s.id])
  }

  // Hvor mange filnavn peker på samme korte form? To gjør koblingen
  // tvetydig FRA filas side, og da skal ingen av dem kobles.
  const fraFila = new Map<string, number>()
  for (const n of filnavn) {
    const k = utenMerke(n)
    fraFila.set(k, (fraFila.get(k) ?? 0) + 1)
  }

  const kobling = new Map<string, string>()
  const ukoblet: string[] = []
  for (const n of filnavn) {
    const e = eksakt.get(normaliser(n))
    if (e?.length === 1) { kobling.set(normaliser(n), e[0]); continue }
    const k = utenMerke(n)
    const treff = kort.get(k)
    if (treff?.length === 1 && fraFila.get(k) === 1) {
      kobling.set(normaliser(n), treff[0])
      continue
    }
    ukoblet.push(n)
  }
  return { kobling, ukoblet }
}
