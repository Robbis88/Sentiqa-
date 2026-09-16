// Hvem er personen bak nummeret på en Basis Export-rad?
//
// =====================================================================
// DETTE ER A1-PORTEN. `lonn/identitet.ts` STÅR URØRT.
//
// `koble()` i `lonn/identitet.ts` er den gamle broa, og den har ett
// kallsted: `arbeidssted.ts`, som bærer målingen på −0,402 % over fem
// kontrollmåneder. Å endre kontrakten der er en motorendring, ikke en
// identitetsendring, og den hører til B2d.
//
// Derfor er dette en NY port ved siden av, ikke en omskriving. De to
// deler `NUMMERBRO` — den håndholdte tabellen skal finnes ett sted — og
// ingenting annet.
//
// ---------------------------------------------------------------------
// TRE AKSER, OG DE BLANDES IKKE
//
// Denne fila svarer på ÉN ting: hvem. Ikke hva personen koster, ikke om
// personen kan timeprises, ikke om måneden er komplett.
//
// Særlig gjelder det fastlønn. `koble()` tar imot `fastlonnede` og
// returnerer `{ status: 'fastlonn' }` — altså en klassifisering på
// identitetsaksen. Det er feil sted: FASTLØNN ER IKKE EN IDENTITET.
//
// Konsekvensen er konkret. `ansatt_avtale` er nøklet
// `(stasjon_id, ansatt_nr)` og er sparsom — målt i produksjon 2026-09-16
// finnes 18 rader, bare på to av fem stasjoner, og 8 av dem har
// `lonnsform = null`. Fikk den avgjøre først, ville en avtalerad kunne
// gjort en person med MOTSTRIDENDE identitet til «håndtert» før noen
// hadde spurt om det i det hele tatt.
//
// 1018 skal gjennom navnevetoet FØRST. Prisbarheten kommer i B2b, og
// bare for en identitet som allerede er sikker.
//
// ---------------------------------------------------------------------
// NAVNET ER ET VETO, ALDRI EN NØKKEL
//
// MÅLT over 27 lønnsgrunnlag og 8 Basis Export-filer: registernavnet og
// Basis-navnet for samme (nummer, måned) deler minst ett navneledd i
// ALLE tilfeller unntatt ett.
//
//     1018, juli 2026
//     register   Bønes,  Marietta Iacovou,  239,33
//     Basis      Varden, Andre Fjørstad,    54,50 timer
//
// Uten vetoet prises Andres 54,5 timer med Mariettas sats — omtrent
// 13 000 kroner på feil person, i et resultat som melder seg selv som
// komplett. Feilpriset er usynlig; uprisbar er det ikke.
//
// Regelen er ENSRETTET. Felles navneledd er ikke bevis for at det er
// samme person — det er fravær av motbevis. To personer med samme
// etternavn deler et ledd, og det skal fortsatt ikke koble dem. Nummeret
// foreslår; navnet kan nekte.
//
// Derfor brukes navnet heller ALDRI til å velge mellom to kandidater.
// Gjorde vi det, ville det vært en positiv nøkkel med et annet navn.
//
// ---------------------------------------------------------------------
// ET MANGLENDE NAVN ER FRAVÆR, IKKE MOTSTRID
//
// Samme lærdom som betalingsfrekvensen i B1: der talte første utgave en
// BLANK verdi som en variant, og hver eneste person i hver eneste fil
// ble en konflikt. En tom streng er ikke en påstand om noe annet.
//
// Har en av sidene ingen brukbare navneledd, kan vetoet ikke slå til.
// =====================================================================

import { NUMMERBRO } from '@/lib/lonn/identitet'

/** En rad i månedens `lonnsregister`, uansett hvilken stasjon den kom fra. */
export type Registerkandidat = {
  ansattNr: string
  navn: string
  /** Stasjonen hvis FIL bar raden. Ikke `hovedlokasjon`, som er fritekst. */
  stasjonId: string
}

/** Raden fra `basisvakt` vi prøver å sette et navn på. */
export type Basisobservasjon = {
  ansattNr: string
  ansattNavn: string
}

export type Motstridsgrunn =
  /** Både nummeret selv og broas mål finnes. Broa er gal eller foreldet. */
  | 'bro'
  /** To registerrader på samme nummer, samme måned. To stasjoner, to svar. */
  | 'kollisjon'
  /** Registeret og Basis Export sier navn uten et eneste felles ledd. */
  | 'navn'

export type Identitet =
  | {
    status: 'koblet'
    lonnsnr: string
    /** Stasjonen registerraden kom fra. Avgjør senere om timene er innlånt. */
    registerStasjonId: string
    kilde: 'direkte' | 'bro'
  }
  | { status: 'ukoblet'; grunn: 'ukjent_nummer' }
  | {
    status: 'motstrid'
    grunn: Motstridsgrunn
    /** Skal kunne vises til et menneske uten at koden leses. */
    forklaring: string
    kandidater: Registerkandidat[]
  }

/**
 * Navneleddene som kan bære et veto.
 *
 * Diakritiske tegn foldes bort, og de norske bokstavene som IKKE
 * dekomponerer i NFD (ø, æ) mappes eksplisitt. Uten det ville
 * «Fjørstad» og «Fjorstad» vært to ulike ledd, og et veto ville slått
 * til på en skrivemåte.
 *
 * Ledd på ett tegn kastes. En mellominitial er ikke et navn, og et delt
 * «E» ville hindret et veto som skulle slått til.
 */
function navneledd(navn: string): Set<string> {
  // `NFD` deler «é» i «e» + kombinerende aksent, og «å» i «a» + ring.
  // Aksentene fjernes ikke her — `[^a-z0-9]` under tar dem, sammen med
  // punktum og apostrof. En egen `[̀-ͯ]`-linje sto her først;
  // den var DØD, fordi strippingen gjorde nøyaktig det samme. En
  // injeksjon som slettet den ble grønn, og en linje som ikke kan feile
  // er samme form som en vakt som ikke ser.
  //
  // ø og æ må derimot mappes eksplisitt: de dekomponerer ikke i NFD, så
  // uten dette ville «Fjørstad» blitt «fjrstad» og et veto slått til på
  // en skrivemåte.
  const foldet = navn
    .toLowerCase()
    .normalize('NFD')
    .replace(/ø/g, 'o')
    .replace(/æ/g, 'ae')
  return new Set(
    foldet
      .split(/[\s\-,.]+/)
      .map((d) => d.replace(/[^a-z0-9]/g, ''))
      .filter((d) => d.length > 1),
  )
}

/**
 * Sier de to navnene POSITIVT imot hverandre?
 *
 * Bare når begge har brukbare ledd og ingen av dem er felles. Mangler
 * det ene navnet, vet vi ingenting — og det er noe annet enn å vite at
 * det er en annen person.
 */
export function navnSierImot(a: string, b: string): boolean {
  const x = navneledd(a)
  const y = navneledd(b)
  if (x.size === 0 || y.size === 0) return false
  for (const d of x) if (y.has(d)) return false
  return true
}

/**
 * Avgjør hvem en Basis Export-rad peker på.
 *
 * @param obs raden fra `basisvakt`, med nummeret og navnet Easy skrev
 * @param slaaOpp månedens registerrader for et nummer, på tvers av
 *   stasjoner. Lønnsgrunnlaget lister stasjonens EGNE ansatte, ikke alle
 *   som jobbet der — Carmen sto 79,82 timer på Bønes i juli 2026 og
 *   finnes bare i Lones fil. Uten kryssoppslaget ville hun vært ukoblet.
 *
 * INGEN GJETNING. Er svaret ikke entydig, sies det.
 */
export function avgjorIdentitet(
  obs: Basisobservasjon,
  slaaOpp: (ansattNr: string) => readonly Registerkandidat[],
): Identitet {
  const reint = obs.ansattNr.trim()
  const broNr = NUMMERBRO[reint]

  const direkte = slaaOpp(reint)
  const viaBro = broNr ? slaaOpp(broNr) : []

  // 1. TO VEIER INN ER IKKE ET VALG, DET ER ET FUNN.
  //
  // Sjekkes dette ikke FØR det direkte treffet tas, ville en gal bro
  // ligget og priset feil person i stillhet: broa ville aldri blitt
  // brukt, og derfor aldri blitt oppdaget som gal heller.
  if (direkte.length > 0 && viaBro.length > 0) {
    return {
      status: 'motstrid',
      grunn: 'bro',
      forklaring: `Både ${reint} og broas mål ${broNr} finnes i registeret for `
        + 'måneden. Da er broa gal eller foreldet, og vi kan ikke velge.',
      kandidater: [...direkte, ...viaBro],
    }
  }

  const valgte = direkte.length > 0 ? direkte : viaBro
  const kilde: 'direkte' | 'bro' = direkte.length > 0 ? 'direkte' : 'bro'

  // 2. Ingen av delene.
  if (valgte.length === 0) return { status: 'ukoblet', grunn: 'ukjent_nummer' }

  // 3. SAMME NUMMER, TO STASJONER, SAMME MÅNED.
  //
  // ALDRI OBSERVERT i de 27 lønnsgrunnlagene — og nettopp derfor skal
  // det rope. `register.ts` slår i dag sammen to slike rader når navn OG
  // sats er like, med den begrunnelsen at det da er én person på to
  // steder. Den regelen er aldri utløst av ekte data, altså er den en
  // antakelse med kode rundt seg. Her er svaret motstrid, uansett.
  //
  // Og navnet brukes IKKE til å bryte uavgjortheten. Å la det velge ville
  // gjort navnet til en positiv nøkkel, som er nøyaktig det det ikke er.
  if (valgte.length > 1) {
    return {
      status: 'motstrid',
      grunn: 'kollisjon',
      forklaring: `${reint} finnes i registeret for ${valgte.length} stasjoner `
        + 'samme måned. Et nummer er en kildereferanse, ikke en personidentitet.',
      kandidater: [...valgte],
    }
  }

  const kandidat = valgte[0]

  // 4. VETOET.
  if (navnSierImot(obs.ansattNavn, kandidat.navn)) {
    return {
      status: 'motstrid',
      grunn: 'navn',
      forklaring: `Basis Export kaller ${reint} «${obs.ansattNavn}», registeret `
        + `kaller ${kandidat.ansattNr} «${kandidat.navn}». Ingen felles navneledd. `
        + 'Nummeret foreslår, navnet nekter.',
      kandidater: [kandidat],
    }
  }

  return {
    status: 'koblet',
    lonnsnr: kandidat.ansattNr,
    registerStasjonId: kandidat.stasjonId,
    kilde,
  }
}
