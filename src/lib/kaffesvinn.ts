// =====================================================================
// «Dere har glemt å slå inn påfyllene.»
//
// Robert, 2026-08-23: «kan den nevne det til butikksjefer når vi laster
// opp regnskapet? Ser ut til dere har glemt å justere x antall
// kaffekopper påfyll — slå inn 2700 påfyll cappuccino for å nullstille
// svinn kaffe.»
//
// REGELEN, og den er eksakt:
//
//   «Kaffelojalitet er der vi nedjusteres. Hvis kaffelojalitet er
//    −2000 kr og kaffe/te er 2000, så er det rett justert. Er kaffe/te
//    1000 kr, mangler det justering på 1000 kr.»
//
// En kaffeavtale koster 300 kr, og så henter kunden så mye han vil.
// Kaffen forsvinner fysisk fra lageret og gir manko på `13010 KAFFE`.
// Slår den ansatte inn utdelingen, gir den et tilsvarende overskudd på
// `13011 KAFFELOJALITET`. Balanserer de, er alt registrert.
//
// INGEN MELLOMREGNING. Første utgave utledet det samme av kassa minus
// telling: tre ledd som alle kunne bære en feil, og som krevde en
// antakelse om varemiks for å bli til et antall kopper. St1 har regnet
// det ut, og `v_kaffe_svinn` leser det.
//
// VARSELET SIER ET ANTALL KOPPER, IKKE EN SUM. «148 428 kr mangler» er
// sant og ubrukelig. «Slå inn 2 100 PÅFYLL CAFFE LATTE» er en handling
// noen kan gjøre i dag.
// =====================================================================

export type Kaffemaaling = {
  /** `13010 KAFFE`. Positiv = manko, altså kaffe som er borte. */
  kaffeKr: number
  /** `13011 KAFFELOJALITET`. Negativ = utdeling som ER slått inn. */
  lojalitetKr: number
  /** Summen over hele avdeling 130. Positiv = justering som mangler. */
  manglerKr: number
  /** Måneder med svinnrader i år. */
  maaneder: number
  /** Den mest utdelte varen, og hva lageret justeres med per kopp. */
  vanligste: { varenavn: string; krPerKopp: number } | null
}

export type Kaffevarsel = {
  type: string
  tittel: string
  tekst: string
  manglerKr: number
  kopper: number | null
}

// Tersklene. PROVISORISKE, og satt for å bli flyttet: de er valgt av
// syv måneders tall fra fem stasjoner, ikke av erfaring.
//
// BEGGE MÅ TIL. Kronene alene ville meldt en stor stasjon som ligger
// helt normalt an; andelen alene ville meldt en liten på noen hundre
// kroner. Robert: «de har alltid litt svinn på kaffe hver mnd» — søl,
// kanner som tømmes ved stengetid og feilslag ligger i det samme tallet
// og er ikke noe butikksjefen kan slå inn.
const KR_GRENSE = 5_000
const ANDEL_GRENSE = 15

const kr = (n: number) => `${Math.round(n).toLocaleString('nb-NO')} kr`

/**
 * Hvor stor del av utdelingen som ikke er slått inn.
 *
 * NULL NÅR DET IKKE ER REGISTRERT UTDELING I DET HELE TATT. Da finnes
 * ingen andel, og «100 %» ville vært et påfunn — ikke en måling.
 */
export function andelUjustert(manglerKr: number, lojalitetKr: number): number | null {
  if (!(lojalitetKr < 0)) return null
  return Math.round((manglerKr / -lojalitetKr) * 1000) / 10
}

/**
 * Varselet, eller ingenting.
 *
 * NULL ER DET NORMALE. En stasjon som har justert riktig skal ikke få
 * noe, og en som står i overskudd — mer talt enn ventet — skal heller
 * ikke det. Da er det ikke kopper som mangler.
 */
export function lagKaffevarsel(m: Kaffemaaling): Kaffevarsel | null {
  if (!(m.manglerKr > 0)) return null
  if (m.manglerKr < KR_GRENSE) return null

  const andel = andelUjustert(m.manglerKr, m.lojalitetKr)
  // Er det ikke slått inn ÉN utdeling, finnes ingen andel å måle mot —
  // men manko på kaffen står der like fullt, og da er kronegrensen nok.
  if (andel != null && andel < ANDEL_GRENSE) return null

  const kopper = m.vanligste && m.vanligste.krPerKopp > 0
    ? Math.round(m.manglerKr / m.vanligste.krPerKopp)
    : null

  // FORUTSETNINGEN STÅR I TEKSTEN. Antallet gjelder den varen som deles
  // ut oftest. Er det latte som ikke slås inn og medium som telles, blir
  // antallet et annet — kronene er de samme.
  const handling = kopper != null && m.vanligste
    ? `Slå inn ${kopper.toLocaleString('nb-NO')} ${m.vanligste.varenavn} `
      + 'for å nullstille det.'
    : 'Slå inn påfyllene som er gitt bort, så går det i null.'

  return {
    type: 'kaffe_paafyll',
    tittel: 'Påfyll som ikke er slått inn',
    tekst:
      `Kaffen mangler ${kr(m.manglerKr)} i justering hittil i år `
      + `(${m.maaneder} ${m.maaneder === 1 ? 'måned' : 'måneder'}). `
      + `Tellingen viser ${kr(m.kaffeKr)} i manko på kaffe, mens bare `
      + `${kr(-m.lojalitetKr)} er slått inn som gitt bort. `
      + `${handling} `
      + 'Kaffe på avtale koster like mye enten den slås inn eller ikke — '
      + 'slås den inn, vet dere hvorfor margen faller.',
    manglerKr: m.manglerKr,
    kopper,
  }
}
