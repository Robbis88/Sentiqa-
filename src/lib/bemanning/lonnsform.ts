// =====================================================================
// Samme navn, to lønnsformer. Én glemt rad velter hele justeringen.
//
// En fast vakt legges inn per ukedag. Lone man–fre er fem rader, og hver
// av dem har sitt eget lønnsform-valg. Retter man Lone fra timelønn til
// fastlønn og glemmer fredagen, er det ingenting på skjermen som sier
// fra: fem rader, fire med «Fastlønn» og én med «Timelønn», sortert
// etter navn og ukedag som om alt var i orden.
//
// HVA DET KOSTER, BEGGE VEIER:
//
//   Én glemt «Timelønn» på en fastlønnet — timene i den raden trekkes
//   fra rammen selv om lønnen er fast. Stasjonen ser ut til å ha brukt
//   flere timer enn den gjorde.
//
//   Én glemt «Fastlønn» på en timelønnet — årsverket/12 legges IKKE
//   tilbake i rammen den måneden. Regelen i `lederdekning.ts` er «ingen
//   av dem er fastlønnet», og én rad er nok til å gjøre den usann.
//   141,25 timer forsvinner, uten at noe peker på hvorfor.
//
// NAVNET BRUKES TIL Å SPØRRE, ALDRI TIL Å KOBLE. `navn` er fritekst, og
// å koble ansatte på navn er den samme feilen som er gjort før — samme
// person ligger under ansatt_nr, ansatte.id og fritekst navn samtidig.
// Denne funksjonen kobler ingenting og retter ingenting. Den peker på to
// rader som ser ut til å være samme person og ber et menneske se etter.
// «Ola Nordmann» og «ola nordmann» er verdt å spørre om; er det to ulike
// personer, er svaret nei, og ingen skade er skjedd.
// =====================================================================

export type VaktRad = {
  navn: string | null
  timelonnet: boolean | null
  fra_time: number
  til_time: number
}

export type Lonnsformfunn = {
  /** Navnet slik det er skrevet i den første raden. */
  navn: string
  timelonnede: number
  fastlonnede: number
  /** Ukentlige timer i de radene som er i mindretall — det som står på spill. */
  timerIMindretall: number
  /** Hvilken form flertallet har. Sier hvilken vei rettingen sannsynlig går. */
  flertall: 'timelønn' | 'fastlønn'
}

/** Fritekst gjort sammenliknbar. Kun for å spørre, ikke for å koble. */
const noekkel = (navn: string) => navn.trim().toLowerCase().replace(/\s+/g, ' ')

/**
 * Navn som opptrer med begge lønnsformer.
 *
 * Rader uten navn hoppes over: da finnes det ikke noe å spørre om.
 * `timelonnet: null` regnes som fastlønn, slik resten av koden gjør
 * (`.filter((f) => f.timelonnet)`) — ellers ville vakten meldt funn på
 * rader den øvrige logikken behandler likt.
 */
export function blandetLonnsform(rader: VaktRad[]): Lonnsformfunn[] {
  const grupper = new Map<string, { navn: string; rader: VaktRad[] }>()
  for (const r of rader) {
    const n = (r.navn ?? '').trim()
    if (!n) continue
    const k = noekkel(n)
    if (!grupper.has(k)) grupper.set(k, { navn: n, rader: [] })
    grupper.get(k)!.rader.push(r)
  }

  const funn: Lonnsformfunn[] = []
  for (const { navn, rader: g } of grupper.values()) {
    const time = g.filter((r) => r.timelonnet === true)
    const fast = g.filter((r) => r.timelonnet !== true)
    if (!time.length || !fast.length) continue

    const mindretall = time.length <= fast.length ? time : fast
    funn.push({
      navn,
      timelonnede: time.length,
      fastlonnede: fast.length,
      timerIMindretall: mindretall.reduce((s, r) => s + (r.til_time - r.fra_time), 0),
      flertall: time.length > fast.length ? 'timelønn' : 'fastlønn',
    })
  }

  // Størst avvik først: den med flest timer på spill er den som haster.
  return funn.sort((a, b) => b.timerIMindretall - a.timerIMindretall)
}
