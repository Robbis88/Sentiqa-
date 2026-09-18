// =====================================================================
// NAVN FINNER. EAN IDENTIFISERER.
// =====================================================================
//
// Brukeren skriver «Coca-Cola Zero». Motoren trenger en EAN. Mellom dem
// står denne fila, og den har én regel: den velger aldri stille.
//
// Målt i produksjon 2026-09-17 — fire ulike EAN kan naturlig forstås som
// «Coca-Cola uten sukker»:
//
//   5000112636840  «COCA-COLA UTEN SUKKE»   8 189 stk   0,5 L
//   5000112636871  «COCA-COLA UTEN SUKKE»     797       1,5 L
//   5000112637397  «COCA-COLA UTEN SUKKE»     688       0,33 L
//   5000112691719  «0,5 L COCA-COLA ZERO»     399       boks
//
// Å velge den mest solgte ville gitt riktig svar fire av fem ganger og
// feil svar uten at noen merket det. Spørsmålet koster ett sekund; det
// gale tallet koster tillit.
//
// ---------------------------------------------------------------------
// SAMME EAN HAR BÅRET FLERE NAVN
// ---------------------------------------------------------------------
//
// `5000112651881` har hett både «COCA-COLA UTEN SUKKE» og «0,5 L
// COCA-COLA ZERO». Et søk på det ene navnet må finne varen, og de to
// navnene må ikke bli to kandidater.
//
// Derfor grupperes kandidatene på EAN, og navnene samles som
// `navnHistorikk`. Identiteten er nøkkelen; navnet er et attributt.
//
// ---------------------------------------------------------------------
// SØKET ER ET FILTER, IKKE EN RANGERING
// ---------------------------------------------------------------------
//
// Fila sorterer kandidatene på volum, men bare for at et
// oppklaringsspørsmål skal lese naturlig. Sorteringen velger ingenting —
// `entydig` krever nøyaktig én kandidat, aldri «den øverste».
// =====================================================================

export type Varekandidat = {
  ean: string
  /** Nyeste navn. Til visning. */
  navn: string
  /** Alle navn varen har båret i vinduet. Ett navn er ikke en identitet. */
  navnHistorikk: string[]
  varegruppeKode: string | null
  varegruppeNavn: string | null
  avdelingNavn: string | null
  /** Solgt antall i vinduet. Sorteringsgrunnlag, ikke et valg. */
  volum: number
  /** Stasjonene varen faktisk har historikk på. */
  stasjoner: string[]
}

export type Varerad = {
  ean: string
  varenavn: string | null
  avdeling_kode?: string | null
  varegruppe_kode: string | null
  varegruppe_navn: string | null
  vareomrade_kode?: string | null
  vareomrade_navn?: string | null
  avdeling_navn: string | null
  antall: number | null
  dato: string
  stasjon_id: string
}

/** Normaliserer for SØK. Aldri for identitet. */
const norm = (s: string): string =>
  s.toLowerCase()
    // «Coca-Cola», «Coca Cola» og «cocacola» er samme søk.
    .replace(/[^a-z0-9æøå]+/g, '')
    .replace(/aa/g, 'å')

/** Bredt databasefilter. Resolveren gjør fortsatt det endelige valget.
 * Fire første tegn tåler kildekuttet, og % mellom tegn tåler tegnsetting.
 * å erstattes av % fordi søkenormaliseringen også godtar aa.
 */
export function sokefilter(soek: string): { ean: string } | { navn: string } | null {
  const s = soek.trim()
  if (/^\d{1,14}$/.test(s)) return { ean: s }
  const ord = s.split(/\s+/).map(norm).find(Boolean)
  if (!ord) return null
  return { navn: `%${[...ord.slice(0, 4)].map((t) => t === 'å' ? '%' : t).join('%')}%` }
}

/**
 * Alle ordene i søket må finnes i navnet.
 *
 * OG, IKKE ELLER. «cola zero» skal ikke treffe hver vare som inneholder
 * «cola» — da hadde oppklaringsspørsmålet fått tjuefem alternativer og
 * blitt ubrukelig.
 *
 * ---------------------------------------------------------------------
 * NAVNENE ER AVKORTET TIL 20 TEGN
 * ---------------------------------------------------------------------
 *
 * Målt i produksjon:
 *
 *   «COCA-COLA UTEN SUKKE»   20 tegn
 *   «0,5 L COCA-COLA ZERO»   20
 *   «MUFFINS MILK CHOCOLA»   20
 *
 * Kilden kutter. Brukeren skriver «uten sukker», og ordet finnes aldri —
 * siste ord i navnet er kappet midt i.
 *
 * DET ER BARE SISTE ORD SOM KAN VÆRE KAPPET, fordi kuttet skjer på
 * slutten av strengen. Derfor får bare det siste søkeordet lov til å
 * treffe som et prefiks av seg selv, og bare når navnet SLUTTER der.
 * Og HØYST TO TEGN kan mangle. Første utgave lot prefikset bli
 * vilkårlig kort, og da traff «sukkerfri» navnet «UTEN SUKKE» — et
 * annet ord, godtatt som en avkorting. Et kutt på 20 tegn tar sjelden
 * mer enn en stavelse av det siste ordet.
 *
 * Regelen er smal med vilje. Den gjør ikke søket uskarpt; den kjenner
 * igjen en kjent avkorting.
 */
const KAPPET_MINST = 4
const KAPPET_MAKS_BORTE = 2

function treffer(navn: string, ord: string[]): boolean {
  const n = norm(navn)
  return ord.every((o, i) => {
    if (n.includes(o)) return true
    if (i !== ord.length - 1 || o.length <= KAPPET_MINST) return false
    const nedre = Math.max(KAPPET_MINST, o.length - KAPPET_MAKS_BORTE)
    for (let k = o.length - 1; k >= nedre; k--) {
      if (n.endsWith(o.slice(0, k))) return true
    }
    return false
  })
}

export function kandidater(rader: readonly Varerad[], soek: string): Varekandidat[] {
  const ord = soek.split(/\s+/).map(norm).filter((o) => o.length > 0)
  if (ord.length === 0) return []

  const per = new Map<string, {
    navn: Map<string, string> // navn -> siste dato
    vgk: string | null; vgn: string | null; avd: string | null
    volum: number; stasjoner: Set<string>
  }>()

  for (const r of rader) {
    const navn = (r.varenavn ?? '').trim()
    if (!navn || !treffer(navn, ord)) continue
    const v = per.get(r.ean) ?? {
      navn: new Map(), vgk: r.varegruppe_kode, vgn: r.varegruppe_navn,
      avd: r.avdeling_navn, volum: 0, stasjoner: new Set<string>(),
    }
    const sett = v.navn.get(navn)
    if (!sett || r.dato > sett) v.navn.set(navn, r.dato)
    v.volum += r.antall ?? 0
    v.stasjoner.add(r.stasjon_id)
    per.set(r.ean, v)
  }

  return [...per.entries()].map(([ean, v]) => {
    const sortert = [...v.navn.entries()].sort((a, b) => b[1].localeCompare(a[1]))
    return {
      ean,
      navn: sortert[0][0],
      navnHistorikk: sortert.map(([n]) => n),
      varegruppeKode: v.vgk,
      varegruppeNavn: v.vgn,
      avdelingNavn: v.avd,
      volum: v.volum,
      stasjoner: [...v.stasjoner],
    }
  }).sort((a, b) => b.volum - a.volum)
}

export type Oppslag =
  | { slag: 'entydig'; vare: Varekandidat }
  | { slag: 'flere'; kandidater: Varekandidat[] }
  | { slag: 'ingen' }

/**
 * Hva søket ga.
 *
 * `entydig` KREVER NØYAKTIG ÉN. Ikke «den mest solgte», ikke «den
 * beste treffprosenten». Er det flere, er det brukeren som vet hvilken
 * vare hen mente — ikke vi.
 *
 * En EAN oppgitt direkte går rett gjennom: da har kallstedet allerede
 * identiteten, og et navnesøk ville bare kunne ødelegge den.
 */
export function slaaOpp(rader: readonly Varerad[], soek: string): Oppslag {
  const reneSifre = soek.trim()
  if (/^\d{1,14}$/.test(reneSifre)) {
    const egne = rader.filter((r) => r.ean === reneSifre)
    if (egne.length === 0) return { slag: 'ingen' }
    // Bygget direkte, ikke gjennom navnesøket: identiteten er alt gitt,
    // og et navnefilter kunne bare kastet den bort.
    const navn = new Map<string, string>()
    let volum = 0
    const stasjoner = new Set<string>()
    for (const r of egne) {
      const n = (r.varenavn ?? '').trim()
      if (n) {
        const sett = navn.get(n)
        if (!sett || r.dato > sett) navn.set(n, r.dato)
      }
      volum += r.antall ?? 0
      stasjoner.add(r.stasjon_id)
    }
    const sortert = [...navn.entries()].sort((a, b) => b[1].localeCompare(a[1]))
    return {
      slag: 'entydig',
      vare: {
        ean: reneSifre,
        navn: sortert[0]?.[0] ?? reneSifre,
        navnHistorikk: sortert.map(([n]) => n),
        varegruppeKode: egne[0].varegruppe_kode,
        varegruppeNavn: egne[0].varegruppe_navn,
        avdelingNavn: egne[0].avdeling_navn,
        volum,
        stasjoner: [...stasjoner],
      },
    }
  }
  const k = kandidater(rader, soek)
  if (k.length === 0) return { slag: 'ingen' }
  if (k.length === 1) return { slag: 'entydig', vare: k[0] }
  return { slag: 'flere', kandidater: k }
}

/**
 * Oppklaringsspørsmålet, i butikkspråk.
 *
 * Varegruppen står med fordi det er den som skiller «0,5 L» fra
 * «1,5 L» når navnene er like — og de ER like: tre ulike EAN heter
 * «COCA-COLA UTEN SUKKE».
 */
export function spoersmaal(k: readonly Varekandidat[], maks = 6): string {
  const vist = k.slice(0, maks)
  const merkelapp = (v: Varekandidat) =>
    `«${v.navn}»${v.varegruppeNavn ? ` (${v.varegruppeNavn.trim()})` : ''}`

  // TO KANDIDATER KAN SE HELT LIKE UT.
  //
  // Målt i produksjon 2026-09-17: `5000112651881` og `5000112691719`
  // heter BEGGE «0,5 L COCA-COLA ZERO» og ligger begge i «BRUS MEDIUM
  // =0,4 - 0,6l». Et spørsmål med to identiske alternativer er ikke et
  // spørsmål — det er en blindvei.
  //
  // Kolliderer merkelappen, følger EAN med. Den er stygg å lese, og det
  // er bedre enn å be noen velge mellom to like ting.
  const antall = new Map<string, number>()
  for (const v of vist) antall.set(merkelapp(v), (antall.get(merkelapp(v)) ?? 0) + 1)

  const linjer = vist.map((v) => {
    const m = merkelapp(v)
    return (antall.get(m) ?? 0) > 1 ? `${m} [${v.ean}]` : m
  })
  const mer = k.length > vist.length ? ` — og ${k.length - vist.length} til` : ''
  return `Hvilken mener du: ${linjer.join(', ')}?${mer}`
}
