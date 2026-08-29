// =====================================================================
// Én måned, ett språk.
//
// FIRE SIDER SPURTE OM DEN SAMME MÅNEDEN PÅ TRE MÅTER, og to av dem
// mente noe helt annet med det samme ordet:
//
//   /bemanning   ?maned=3&ar=2026     to felt, tallet er 1–12
//   /lonn        ?maned=3&ar=2026     to felt, tallet er 1–12
//   /svinn       ?maned=2026-03-01    ett felt, verdien er en dato
//   /kasserer    ?maned=2026-03-01    ett felt, verdien er en dato
//
// Det er ikke bare stygt. `Number('2026-03-01')` er NaN, så en lenke fra
// /svinn limt inn på /lonn faller stille tilbake til standardmåneden —
// og viser trygt fram feil tall uten å si fra. Samme parameternavn,
// to betydninger, ingen feilmelding.
//
// **Nøkkelen er ISO, første i måneden: `2026-03-01`.** Den sorterer
// alfabetisk, den er entydig, og den er allerede halve systemet.
//
// ---------------------------------------------------------------------
// KILDEN BESTEMMER HVILKE MÅNEDER SOM FINNES
//
// Ikke denne fila, og ikke velgeren. `/svinn` kan bare tilby måneder det
// finnes svinn i; `/bemanning` planlegger framover og må kunne tilby en
// måned det ennå ikke finnes noe i. En felles liste ville løyet på minst
// én av dem.
//
// Derfor tar `Maanedsvelger` imot lista, og hver side lager sin egen —
// enten fra dataene (`maanederI`) eller fra kalenderen (`maanederRundt`).
// =====================================================================

/** `YYYY-MM-01`. Alltid den første i måneden. */
export type Maaned = string

// `\d{2}` ville godtatt «2026-13-01». Testen fant det: en maaned som
// ikke finnes gikk rett gjennom og ble baaret videre som om den var
// gyldig. Maanedsleddet er 01-12, ikke to sifre.
const ISO_MAANED = /^(\d{4})-(0[1-9]|1[0-2])-01$/
const ISO_KORT = /^(\d{4})-(0[1-9]|1[0-2])$/

export function erMaaned(s: unknown): s is Maaned {
  return typeof s === 'string' && ISO_MAANED.test(s)
}

/** `(2026, 3)` → `'2026-03-01'`. Måneden er 1–12, slik mennesker teller. */
export function maanedNokkel(ar: number, maned: number): Maaned {
  return `${String(ar).padStart(4, '0')}-${String(maned).padStart(2, '0')}-01`
}

/** `'2026-03-01'` → `{ ar: 2026, maned: 3 }`. Måneden er 1–12. */
export function delMaaned(m: Maaned): { ar: number; maned: number } {
  const t = ISO_MAANED.exec(m)
  if (!t) throw new Error(`Ikke en måned: ${m}`)
  return { ar: Number(t[1]), maned: Number(t[2]) }
}

/**
 * Måneden fra URL-en, eller standarden.
 *
 * TAR IMOT DEN GAMLE FORMEN OGSÅ. `?maned=3&ar=2026` har ligget i
 * bokmerker og delte lenker siden /bemanning og /lonn ble bygget. Å
 * bare slutte å forstå den ville gjort at en gammel lenke stille viste
 * en annen måned enn den lovet — og det er nøyaktig feilen denne fila
 * finnes for å fjerne.
 *
 * Rekkefølgen er med vilje: ISO først, så den gamle formen. Står begge
 * i samme URL, er ISO det noen skrev sist.
 */
export function lesMaaned(
  sok: { maned?: string; ar?: string },
  standard: Maaned,
): Maaned {
  const m = sok.maned?.trim()

  if (erMaaned(m)) return m

  // `2026-03` uten dag — en rimelig skrivemåte å møte halvveis.
  if (m && ISO_KORT.test(m)) return `${m}-01`

  // Den gamle formen: 1–12 pluss et årstall ved siden av.
  const tall = Number(m)
  const ar = Number(sok.ar)
  if (Number.isInteger(tall) && tall >= 1 && tall <= 12
      && Number.isInteger(ar) && ar >= 1970 && ar <= 9999) {
    return maanedNokkel(ar, tall)
  }

  return standard
}

/** Måneden `dato` ligger i. Tar en `Date` eller `YYYY-MM-DD`. */
export function maanedenTil(dato: Date | string): Maaned {
  if (typeof dato === 'string') {
    const t = /^(\d{4})-(0[1-9]|1[0-2])-\d{2}$/.exec(dato)
    if (!t) throw new Error(`Ikke en dato: ${dato}`)
    return `${t[1]}-${t[2]}-01`
  }
  return maanedNokkel(dato.getUTCFullYear(), dato.getUTCMonth() + 1)
}

/** `n` måneder fram eller tilbake fra `m`. */
export function flyttMaaned(m: Maaned, n: number): Maaned {
  const { ar, maned } = delMaaned(m)
  const i = ar * 12 + (maned - 1) + n
  return maanedNokkel(Math.floor(i / 12), (i % 12) + 1)
}

/**
 * En liste måneder rundt `midt`, nyeste først.
 *
 * FOR SIDER SOM IKKE KAN LESE UTVALGET UT AV DATA. /bemanning planlegger
 * neste måned, og den måneden har per definisjon ingen rader ennå. Et
 * utvalg fra kalenderen er da riktigere enn et fra tabellen.
 */
export function maanederRundt(midt: Maaned, bakover: number, framover: number): Maaned[] {
  const ut: Maaned[] = []
  for (let i = framover; i >= -bakover; i--) ut.push(flyttMaaned(midt, i))
  return ut
}

/** Månedene som finnes i rader med et `maned`-felt, nyeste først. */
export function maanederI<T extends { maned: string }>(rader: T[]): Maaned[] {
  return [...new Set(rader.map((r) => r.maned))]
    .filter(erMaaned)
    .sort()
    .reverse()
}

// =====================================================================
// ÉN DAG, SAMME SPRÅK.
//
// `/salg` tok allerede imot `?dato=`, men validerte den med
// `/^\d{4}-\d{2}-\d{2}$/`. Det er nøyaktig samme form som `\d{2}` hadde
// på månedsleddet over — og den slapp `2026-13-45` rett gjennom. Der en
// ugyldig måned bare bar seg selv videre, KRASJER en ugyldig dag sida:
//
//   new Date('2026-13-45T12:00:00Z')  →  Invalid Date
//   .setUTCDate(NaN); .toISOString()  →  RangeError: Invalid time value
//
// En URL noen kunne skrevet feil ga en hvit side, ikke en dårlig dag.
// =====================================================================

/** `YYYY-MM-DD`. */
export type Dag = string

const ISO_DAG = /^\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$/

export function erDag(s: unknown): s is Dag {
  if (typeof s !== 'string' || !ISO_DAG.test(s)) return false
  // `2026-02-31` består regexen, men finnes ikke — og `new Date` ruller
  // den STILLE over til 3. mars. Da ville sida vist en annen dag enn
  // URL-en lovte, uten at noe sa fra. Rundturen er det som skiller de to.
  return new Date(`${s}T00:00:00Z`).toISOString().slice(0, 10) === s
}

/**
 * Dagen fra URL-en, eller standarden.
 *
 * Ingen gammel form å møte halvveis her: `?dato=` har alltid vært ISO.
 * Det er nettopp derfor den kunne valideres slurvete uten at noen merket
 * det — alle lenkene i produktet lager den selv.
 */
export function lesDag(sok: { dato?: string }, standard: Dag): Dag {
  const d = sok.dato?.trim()
  return erDag(d) ? d : standard
}
