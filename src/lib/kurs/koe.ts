// =====================================================================
// GODKJENNINGSKØEN — ÉN MÅNED OM GANGEN
// =====================================================================
//
// Køen viste alle utkast, i alle måneder, i én liste. 2026-09-14 sto det
// 30 utkast fordelt på sju måneder der, og det kostet:
//
//   14:54:59.626   Laguneparken   juli   sluppet
//   14:55:04.947   Varden         juli   sluppet
//   14:55:07.086   Lone           JUNI   sluppet     <- feil maaned
//
// Tre klikk på åtte sekunder. Mekanismen er ikke uoppmerksomhet: hver
// gang en plan slippes, flytter kortet seg fra «Venter på deg» til
// «Avgjort», og resten av lista rykker opp. Det tredje klikket traff
// samme sted på skjermen og en annen rad.
//
// Sandra fikk et brev for juni — en måned uten snapshot — der matkast,
// usynlig svinn og rangering alle sto som «ikke beregnet».
//
// ---------------------------------------------------------------------
// Å SKJULE ER IKKE DET SAMME SOM Å LØSE
// ---------------------------------------------------------------------
//
// Et filter som bare viser juli har byttet én feil mot en verre: sida
// sier selv at «et utkast ingen ser er en stasjon uten en plan — uten at
// noe sa fra». Derfor TELLER `delKoe` det den holder utenfor, og flaten
// er nødt til å si det. Antallet er ikke pynt; det er hele grunnen til
// at filteret kan forsvares.
//
// ---------------------------------------------------------------------
// HVORFOR NYESTE MÅNED, OG IKKE NYESTE MED UTKAST
// ---------------------------------------------------------------------
//
// Første utgave åpnet på nyeste måned MED UTKAST, med begrunnelsen at
// køen er en arbeidsflate. Den ble målt i produksjon 2026-09-14, rett
// etter deployen, og begrunnelsen holdt ikke:
//
//   juli          5 sluppet, 0 utkast     <- ferdigbehandlet samme dag
//   juni          5 utkast
//   januar–mai   25 utkast
//
// Regelen valgte JUNI. Sida ville dermed ledet med fem seks måneder
// gamle utkast under «Venter på deg», mens måneden som faktisk var
// gjort lå bak nedtrekkslista.
//
// **Regelen er riktig mens du jobber, og gal rett etter at du er
// ferdig** — som er nøyaktig når du åpner sida neste gang.
//
// Nå åpner den på nyeste måned som har en plan i det hele tatt. Da er
// det første bildet hvor kjeden STÅR, ikke hvor den henger etter:
//
//   Ingenting venter i juli 2026
//   30 eldre utkast venter i 6 andre måneder
//
// Sikkerheten forsvinner ikke med dette. De eldre utkastene telles
// fortsatt av `delKoe`, de er nåbare via velgeren, måneden navngis
// fortsatt ved Slipp og Avvis, og et klikk kan fortsatt ikke krysse en
// månedsgrense uten et aktivt valg.
// =====================================================================

/** `YYYY-MM-DD`, alltid den første i måneden. */
export type Koemaaned = string

/**
 * Det køen trenger å vite om en rad for å sorteres.
 *
 * Med vilje smalere enn `Planrad` i sida: delingen skal kunne testes
 * uten en plan, en ingress eller et snapshot.
 */
export type Koerad = { maaned: string; status: string }

/**
 * Datoen som `YYYY-MM-DD`.
 *
 * Supabase gir `date` som streng, men en `Date` kan snike seg inn via en
 * annen kallssti. `slice(0, 10)` på en ISO-timestamp gir samme svar.
 */
function dag(m: string): Koemaaned {
  return String(m).slice(0, 10)
}

/** Månedene køen kan vise, nyeste først. */
export function maanederIKoe(rader: Koerad[]): Koemaaned[] {
  return [...new Set(rader.map((r) => dag(r.maaned)))].sort().reverse()
}

/**
 * Måneden køen skal åpne på: den nyeste som har en plan.
 *
 * STATUS TELLER IKKE MED. En ferdigbehandlet måned er fortsatt den siste
 * måneden kjeden har tatt stilling til, og det er det første bildet
 * eieren skal møte — se begrunnelsen øverst. Utkast i eldre måneder
 * telles av `delKoe` og nås via velgeren.
 *
 * `null` når det ikke finnes rader, så sida kan vise en tomtilstand i
 * stedet for en velger uten valg.
 */
export function standardmaaned(rader: Koerad[]): Koemaaned | null {
  return maanederIKoe(rader)[0] ?? null
}

export type Koedeling<T extends Koerad> = {
  /** Utkast i den valgte måneden. Det eieren skal ta stilling til nå. */
  utkast: T[]
  /** Avgjorte planer i den valgte måneden. */
  avgjort: T[]
  /** Utkast i ANDRE måneder. Skal vises som et tall, aldri utelates. */
  skjulteUtkast: number
  /** Hvor mange andre måneder de ligger i. */
  skjulteMaaneder: number
}

/**
 * Deler køen på den valgte måneden, og teller det som holdes utenfor.
 *
 * `valgt === null` betyr at det ikke finnes rader i det hele tatt.
 * Da er alle listene tomme og begge tellerne null — ikke «alt er skjult».
 */
export function delKoe<T extends Koerad>(
  rader: T[],
  valgt: Koemaaned | null,
): Koedeling<T> {
  if (valgt === null) {
    return { utkast: [], avgjort: [], skjulteUtkast: 0, skjulteMaaneder: 0 }
  }

  const iMaaneden = rader.filter((r) => dag(r.maaned) === valgt)
  const utenfor = rader.filter(
    (r) => dag(r.maaned) !== valgt && r.status === 'utkast',
  )

  return {
    utkast: iMaaneden.filter((r) => r.status === 'utkast'),
    avgjort: iMaaneden.filter((r) => r.status !== 'utkast'),
    skjulteUtkast: utenfor.length,
    skjulteMaaneder: maanederIKoe(utenfor).length,
  }
}
