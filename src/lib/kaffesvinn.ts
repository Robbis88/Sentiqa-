// =====================================================================
// «Dere har glemt å slå inn påfyllene.»
//
// Robert, 2026-08-23: «kan den nevne det til butikksjefer når vi laster
// opp regnskapet? Ser ut til dere har glemt å justere x antall
// kaffekopper påfyll — slå inn 2700 påfyll cappuccino for å nullstille
// svinn kaffe.»
//
// HVORFOR DETTE LAR SEG MÅLE I DET HELE TATT. En kaffeavtale koster
// 300 kr, og så henter kunden så mye han vil. Slår den ansatte inn
// koppen som gitt bort, havner den i kassa som en `PÅFYLL`-linje med
// antall > 0, omsetning 0 og NEGATIV brutto — altså kaffens kost.
// Kassatallet inneholder dermed alt som ER slått inn.
//
// Da er differansen mot regnskapet nettopp det som forsvant UTEN å bli
// slått inn. Uten utdelingene ligger kaffemarginen på 82–84 % på alle
// fem stasjonene: samme produkt, samme pris, samme margin. Hele spennet
// i budsjettet — 20 % på Bønes mot 70 % på Dale — er utdeling.
//
// VARSELET SIER ET ANTALL KOPPER, IKKE EN PROSENT. «11 % av
// kaffemarginen mangler» er sant og ubrukelig. «Slå inn 2 100 PÅFYLL
// CAFFE LATTE» er en handling noen kan gjøre i dag.
// =====================================================================

export type Kaffemaaling = {
  /** Kassa, MED utdelingene — de ligger der som negativ brutto. */
  kassaBruttoKr: number
  kassaOmsetningKr: number
  /** Kassa UTEN utdelingene. Differansen er kosten ved det som ble slått inn. */
  kassaBruttoUtenUtdelingKr: number
  regnskapBruttoKr: number
  regnskapOmsetningKr: number
  /** Måneder med både kassatall og avlagt regnskap. */
  maaneder: number
  /** Den mest utdelte varen, og hva lageret justeres med per kopp. */
  vanligste: { varenavn: string; krPerKopp: number } | null
}

export type Kaffevarsel = {
  type: string
  tittel: string
  tekst: string
  /** Til etterprøving og til testene. Vises ikke som tall alene. */
  usynligKr: number
  kopper: number | null
}

// Tersklene. Satt slik at vanlig svinn ikke utløser noe: søl, kanner som
// tømmes ved stengetid og feilslag ligger i det samme gapet, og de er
// ikke noe butikksjefen kan slå inn.
//
// BEGGE MÅ TIL. Prosenten alene ville meldt en liten stasjon med noen
// tusen kroner; kronene alene ville meldt en stor stasjon som ligger
// helt normalt an.
const PP_GRENSE = 5
const KR_GRENSE = 5_000

const kr = (n: number) => `${Math.round(n).toLocaleString('nb-NO')} kr`

/** Prosent av omsetningen, eller null når nevneren ikke gir et mål. */
function margin(brutto: number, omsetning: number): number | null {
  if (!(omsetning > 0)) return null
  // Et beløp større enn omsetningen er ikke en margin, det er en feil i
  // grunnlaget. Samme vakt som `v_bp_status_avdeling` bruker.
  if (Math.abs(brutto) > omsetning) return null
  return (brutto / omsetning) * 100
}

/**
 * Varselet, eller ingenting.
 *
 * NULL ER DET NORMALE. Fire av fem stasjoner slo ut i august 2026, og
 * det var riktig — men en stasjon som har orden skal ikke få noe, og en
 * som har FUNNET penger igjen ved tellingen skal heller ikke det. Da er
 * det ikke kopper som mangler.
 */
export function lagKaffevarsel(m: Kaffemaaling): Kaffevarsel | null {
  const kassa = margin(m.kassaBruttoKr, m.kassaOmsetningKr)
  const regnskap = margin(m.regnskapBruttoKr, m.regnskapOmsetningKr)
  if (kassa == null || regnskap == null) return null

  const pp = kassa - regnskap
  const usynligKr = m.regnskapOmsetningKr * (pp / 100)
  if (pp < PP_GRENSE || usynligKr < KR_GRENSE) return null

  // Kopper: kostnaden ved det som ER slått inn, delt på antall — altså
  // hva lageret justeres med per kopp. Utledet av dataene, ikke antatt.
  const kopper = m.vanligste && m.vanligste.krPerKopp > 0
    ? Math.round(usynligKr / m.vanligste.krPerKopp)
    : null

  // FORUTSETNINGEN STÅR I TEKSTEN. Antallet gjelder den varen som deles
  // ut oftest. Er det latte som ikke slås inn og cappuccino som telles,
  // blir antallet et annet — kronene er de samme.
  const handling = kopper != null && m.vanligste
    ? `Slå inn ${kopper.toLocaleString('nb-NO')} ${m.vanligste.varenavn} `
      + 'for å nullstille det.'
    : 'Slå inn påfyllene som er gitt bort, så forsvinner differansen.'

  return {
    type: 'kaffe_paafyll',
    tittel: 'Påfyll som ikke er slått inn',
    tekst:
      `${kr(usynligKr)} av kaffemarginen er borte uten spor over `
      + `${m.maaneder} ${m.maaneder === 1 ? 'måned' : 'måneder'}. `
      + `Kassen sier ${kassa.toFixed(1).replace('.', ',')} % etter alle `
      + `registrerte påfyll, tellingen sier `
      + `${regnskap.toFixed(1).replace('.', ',')} %. `
      + `${handling} `
      + 'Kaffe som gis bort på avtale koster like mye enten den slås inn '
      + 'eller ikke — slås den inn, vet dere hvorfor margen faller.',
    usynligKr,
    kopper,
  }
}

/**
 * Hvor mange kopper per avtalekunde per dag utdelingene svarer til.
 *
 * DEN KONTROLLEN SOM AVGJORDE SAKEN. Lone slo inn 0,36 kopper per
 * avtalekunde per dag — en kunde som betaler 300 kr og henter så lite
 * kjøper ikke noe fornuftig. De fire andre lå mellom 0,59 og 1,73.
 * Legger man til koppene som mangler, lander Lone på 1,31.
 *
 * Ikke i varselteksten: den skal si én ting. Men tallet hører til når
 * noen spør hvorfor vi tror på anslaget.
 */
export function kopperPerAvtaleDag(
  kopper: number, avtaler: number, dager: number,
): number | null {
  if (!(avtaler > 0) || !(dager > 0)) return null
  return Math.round((kopper / avtaler / dager) * 100) / 100
}
