// =====================================================================
// Kasserertall: rate, ikke rangering.
//
// SIDA I DAG VISER ÉN DAG, I KRONER, SORTERT PÅ OMSETNING. Alle tre
// gjør det samme feilgrepet i hver sin retning:
//
//   én dag      en kasserer med én vakt og én retur ser lik ut som et
//               mønster som har vart i et halvår
//   kroner      den som selger tre ganger så mye har tre ganger så mye
//               retur, uten at noe er galt
//   omsetning   rangeringen svarer på «hvem selger mest», ikke på det
//               siden finnes for
//
// Derfor: **avvik per 100 bonger**, per måned, målt mot kassererens
// EGEN historikk. En rate gjør en stor og en liten kasserer
// sammenlignbare; egen historikk gjør at det som måles er en endring
// hos den samme personen, ikke en forskjell mellom to personer.
//
// ---------------------------------------------------------------------
// DENNE FILA RANGERER INGEN OG FLAGGER INGENTING
//
// Først var det en forsiktighetsregel. Etter at
// `supabase/tests/kasserer_fordeling.sql` ble kjørt mot produksjon
// 2026-08-24 er det en **måling**:
//
//   spredning INNI én kasserer   mot   spennet MELLOM kasserere
//   (maks−min, egen kr per 100)        (p50 → p90 av egne snitt)
//
//   Lone          1 623   >   1 379
//   Dale          2 525   >     980
//   Laguneparken    969   >     892
//   Varden        1 806   >   1 060
//   Bønes         2 057   >     462
//
// På hver eneste stasjon svinger den samme kassereren mer fra måned til
// måned enn kasserere flest gjør fra hverandre. **Støyen er større enn
// signalet.** En månedsrate kan derfor ikke skille personer — den
// skiller måneder. Å rangere på den ville vært å rangere tilfeldighet,
// og navnet øverst ville vært et navn systemet ikke har dekning for.
//
// Grensa som sto i siden — 2 % av omsetningen — ble målt i samme
// slengen: den ville felt **771 av 775** kasserermåneder. Det er ikke
// en streng grense, det er en konstant.
//
// Derfor: ingen score, ingen sortering på avvik, ingen dom. Tall, og et
// menneske som leser dem.
//
// ---------------------------------------------------------------------
// `kasserer_nr` ER EN FJERDE IDENTITET
//
// Ved siden av `ansatt_nr` (easy@work), `ansatte.id` (PIN) og fritekst
// navn. Den er ikke koblet til noen av dem, og skal ikke bli det her.
// `kasserer_navn` kommer fra samme rad og vises som en opplysning — det
// er ikke en nøkkel. To kan hete det samme, og folk gifter seg.
// =====================================================================

/** Én rad fra `v_kasserer_maaned`. */
export type Kassererrad = {
  stasjon_id: string
  kasserer_nr: string
  maned: string
  dager: number
  bonger: number
  omsetning_kr: number
  retur_kr: number
  retur_antall: number
  makulert_kr: number
  makulert_antall: number
  slettet_kr: number
  slettet_antall: number
  /** Hvor mange ulike navn nummeret har båret i perioden. */
  ulike_navn: number
  navn: string | null
}

export type Avvikstype = 'retur' | 'makulert' | 'slettet'

export type Maanedsrate = {
  maned: string
  bonger: number
  omsetning_kr: number
  avvikKr: number
  avvikAntall: number
  /** Kroner avvik per 100 bonger. Null når det ikke finnes bonger. */
  krPer100: number | null
  /** Antall avvik per 100 bonger. Null når det ikke finnes bonger. */
  antallPer100: number | null
  perType: Record<Avvikstype, { kr: number; antall: number }>
}

export type Kassererbilde = {
  stasjon_id: string
  nr: string
  navn: string | null
  /** Sant når nummeret har båret flere navn — da er navnet ikke en identitet. */
  navnEtvetydig: boolean
  system: boolean
  /** Nyeste måned først. */
  maaneder: Maanedsrate[]
  denne: Maanedsrate | null
  /** Snittet av kassererens EGNE tidligere måneder. Null uten historikk. */
  egetSnitt: number | null
  /** Denne måneden minus eget snitt. Null når én av dem mangler. */
  motEgetSnitt: number | null
  /** Antall egne måneder som ligger bak `egetSnitt`. */
  egneMaaneder: number
}

/**
 * Er dette kassa selv og ikke et menneske?
 *
 * FIRE NITALL ELLER FLERE, ikke ett. Første utgave sa `^9+$`, og den
 * var for grådig: sonden fant `nr=9` på Varden med 14 måneder,
 * 10 505 bonger, 1,47 mill i omsetning og 178 288 kr i avvik — nesten
 * en tiendedel av stasjonens samlede avvik. Regelen ville lagt alt det
 * i «system» og fjernet det fra bildet uten at noe sa fra.
 *
 * DET ER DEN FARLIGE RETNINGEN. Viser vi et systemnummer som om det var
 * en person, ser noen det og sier fra. Skjuler vi en person som om den
 * var et system, ser ingen noe — og tallet mangler for godt.
 *
 * `999999` finnes på alle fem stasjonene og bærer 18–35 % av alle
 * bonger. Det er ikke støy, det er en egen kanal, og den skal vises for
 * seg — ikke slettes og ikke blandes inn.
 */
export function erSystemnummer(nr: string): boolean {
  const n = nr.trim()
  if (n === '') return true
  if (!/^[0-9]+$/.test(n)) return true
  return /^9{4,}$/.test(n) || /^0+$/.test(n)
}

/**
 * Avvik per 100 bonger.
 *
 * REN MATEMATIKK, INGEN POLITIKK. Null bare når nevneren ikke finnes —
 * ikke når den er «for liten». Hvor lite grunnlag som er for lite er en
 * beslutning, og beslutninger hører ikke hjemme inne i en divisjon der
 * de blir usynlige. Se `nokGrunnlag`.
 */
export function per100(avvik: number, bonger: number): number | null {
  if (!Number.isFinite(bonger) || bonger <= 0) return null
  if (!Number.isFinite(avvik)) return null
  return (avvik / bonger) * 100
}

/**
 * MÅLT, IKKE VALGT — `kasserer_fordeling.sql` del 3, 2026-08-24.
 *
 * Under en viss mengde bonger er en rate matematisk gyldig og likevel
 * meningsløs: én retur på tjue bonger blir 5 per 100, og det sier mer
 * om at vakten var kort enn om kassereren.
 *
 * Fordelingen bestemte hvor grensa kunne ligge:
 *
 *   under 100 bonger   utelater  5–19 % av kasserermånedene
 *   under 500 bonger   utelater 20–61 %  — flertallet på tre stasjoner
 *
 * 100 tar bort de månedene ingen kan tolke, og lar resten stå. 500
 * ville tatt bort mer enn halve Dale og halve Bønes, og da måler siden
 * ikke lenger driften.
 */
export const MIN_BONGER = 100

export function nokGrunnlag(bonger: number, minst = MIN_BONGER): boolean {
  return Number.isFinite(bonger) && bonger >= minst
}

/** Summerer én rad til en månedsrate. */
export function raten(r: Kassererrad): Maanedsrate {
  const perType: Record<Avvikstype, { kr: number; antall: number }> = {
    retur: { kr: r.retur_kr, antall: r.retur_antall },
    makulert: { kr: r.makulert_kr, antall: r.makulert_antall },
    slettet: { kr: r.slettet_kr, antall: r.slettet_antall },
  }
  const avvikKr = r.retur_kr + r.makulert_kr + r.slettet_kr
  const avvikAntall = r.retur_antall + r.makulert_antall + r.slettet_antall
  return {
    maned: r.maned,
    bonger: r.bonger,
    omsetning_kr: r.omsetning_kr,
    avvikKr,
    avvikAntall,
    krPer100: per100(avvikKr, r.bonger),
    antallPer100: per100(avvikAntall, r.bonger),
    perType,
  }
}

/**
 * Samler radene for ett kassanummer til ett bilde.
 *
 * SNITTET ER KASSERERENS EGNE TIDLIGERE MÅNEDER, ikke de andres. Det er
 * hele forskjellen mellom «du har endret deg» og «du er verre enn
 * kollegaen din». Den første er en observasjon; den andre er en dom
 * over noe som like gjerne kan være hvilken vakt man går.
 *
 * MÅNEDER UTEN NOK GRUNNLAG TELLER IKKE I SNITTET. En måned med tolv
 * bonger ville trukket snittet dit tilfeldigheten peker.
 */
export function byggKasserer(
  stasjonId: string,
  nr: string,
  rader: Kassererrad[],
  valgtMaaned: string,
  minst = MIN_BONGER,
): Kassererbilde {
  // NOEKKELEN ER PARET, IKKE NUMMERET. Kassanumrene starter paa nytt paa
  // hver stasjon, saa «101» finnes fem ganger i kjeden og er fem ulike
  // mennesker. Nokles det bare paa nummer, smelter de sammen til én rad
  // naar eieren ser hele kjeden - og den raden tilhoerer ingen.
  const mine = rader
    .filter((r) => r.stasjon_id === stasjonId && r.kasserer_nr === nr)
    .sort((a, b) => (a.maned < b.maned ? 1 : a.maned > b.maned ? -1 : 0))

  const maaneder = mine.map(raten)
  const denne = maaneder.find((m) => m.maned === valgtMaaned) ?? null

  // TIDLIGERE, IKKE ALLE. Ligger den valgte måneden i snittet den skal
  // sammenlignes med, sammenligner den delvis med seg selv - og et
  // avvik trekker sin egen målestokk etter seg.
  const tidligere = maaneder.filter(
    (m) => m.maned < valgtMaaned && m.krPer100 != null && nokGrunnlag(m.bonger, minst),
  )
  const egetSnitt = tidligere.length > 0
    ? tidligere.reduce((n, m) => n + (m.krPer100 as number), 0) / tidligere.length
    : null

  const sisteRad = mine[0]
  return {
    stasjon_id: stasjonId,
    nr,
    navn: sisteRad?.navn ?? null,
    navnEtvetydig: mine.some((r) => r.ulike_navn > 1),
    system: erSystemnummer(nr),
    maaneder,
    denne,
    egetSnitt,
    motEgetSnitt: denne?.krPer100 != null && egetSnitt != null
      ? denne.krPer100 - egetSnitt
      : null,
    egneMaaneder: tidligere.length,
  }
}

/**
 * Alle kassanumre i materialet, systemnumrene for seg.
 *
 * SORTERT PÅ NUMMER, IKKE PÅ AVVIK. En liste sortert synkende på avvik
 * er en mistenktliste, uansett hva kolonnen heter — den øverste raden
 * leses som en anklage av alle som ser den. Vil man finne den største,
 * kan man klikke på kolonnen; det er en handling brukeren gjør, ikke en
 * påstand systemet leverer.
 */
export function byggAlle(
  rader: Kassererrad[],
  valgtMaaned: string,
  minst = MIN_BONGER,
): { folk: Kassererbilde[]; system: Kassererbilde[] } {
  const par = [...new Set(rader.map((r) => `${r.stasjon_id} ${r.kasserer_nr}`))].sort()
  const alle = par.map((p) => {
    const [stasjonId, nr] = p.split(' ')
    return byggKasserer(stasjonId, nr, rader, valgtMaaned, minst)
  })
  return {
    folk: alle.filter((k) => !k.system),
    system: alle.filter((k) => k.system),
  }
}

/** Månedene som finnes i radene, nyeste først. */
export function maanederI(rader: Kassererrad[]): string[] {
  return [...new Set(rader.map((r) => r.maned))].sort().reverse()
}

/** Summen for en måned, på tvers av kassanumre. Systemnumre holdes utenfor. */
export function totaltFor(
  rader: Kassererrad[],
  maaned: string,
): { bonger: number; omsetning: number; avvikKr: number; avvikAntall: number;
     krPer100: number | null; systemKr: number } {
  let bonger = 0, omsetning = 0, avvikKr = 0, avvikAntall = 0, systemKr = 0
  for (const r of rader) {
    if (r.maned !== maaned) continue
    const a = r.retur_kr + r.makulert_kr + r.slettet_kr
    // SYSTEMKRONENE FORSVINNER IKKE, de står for seg. Kastes de ut i
    // stillhet, ser totalen lavere ut enn den er; blandes de inn, får
    // kassa skylda til en medarbeider.
    if (erSystemnummer(r.kasserer_nr)) { systemKr += a; continue }
    bonger += r.bonger
    omsetning += r.omsetning_kr
    avvikKr += a
    avvikAntall += r.retur_antall + r.makulert_antall + r.slettet_antall
  }
  return { bonger, omsetning, avvikKr, avvikAntall, krPer100: per100(avvikKr, bonger), systemKr }
}
