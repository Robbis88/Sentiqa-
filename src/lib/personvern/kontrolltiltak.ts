// =====================================================================
// Hva systemet registrerer om den enkelte — sagt til den det gjelder.
//
// Arbeidsmiljøloven § 9-2 andre ledd: de som omfattes av et kontrolltiltak
// skal ha informasjon om formålet, de praktiske konsekvensene og hvor
// lenge det varer. Plikten er ubetinget — den gjelder også der det ikke
// finnes tillitsvalgte å drøfte med.
//
// Teksten ligger her som DATA, ikke som avsnitt i en side, av to grunner.
// Den skal kunne versjoneres: endres den vesentlig, må folk se den på
// nytt, for en bekreftelse på en tekst som senere ble endret
// dokumenterer ingenting. Og den skal kunne leses av noen som ikke er
// programmerer, uten å lete i JSX.
//
// SKRIVEREGELEN: si det som er sant, også når det er ubehagelig. En side
// som pynter på hva som måles, er verre enn ingen side — da har dere
// både målt og villedet.
// =====================================================================

/** Bumpes ved hver VESENTLIG endring. Da må alle bekrefte på nytt. */
export const KONTROLLTILTAK_VERSJON = '2026-08-18'

export type Tiltak = {
  hva: string
  /** I klarspråk. Ikke «for å optimalisere driften». */
  hvorfor: string
  hvemSer: string
  hvorLenge: string
  /** Det folk ville blitt overrasket over. Utelates aldri fordi det er kjedelig. */
  merk?: string
}

export const TILTAK: Tiltak[] = [
  {
    hva: 'Når du stempler inn og ut',
    hvorfor: 'Timene blir til lønn, og til grunnlaget for hvor mange som '
      + 'settes opp på vakt framover.',
    hvemSer: 'Butikksjefen din og eier.',
    hvorLenge: 'Fem år. Lønnsgrunnlag er regnskapsdokumentasjon, og '
      + 'bokføringsloven krever at det oppbevares så lenge.',
  },
  {
    hva: 'Arbeidsavtalen din',
    hvorfor: 'Fødselsdato, stilling, stillingsprosent og timesats. '
      + 'Nødvendig for å skrive avtalen og betale riktig lønn.',
    hvemSer: 'Butikksjefen din og eier.',
    hvorLenge: 'Fem år etter at du sluttet.',
    merk: 'Vi lagrer fødselsdato, ikke fødselsnummer. Arbeidsavtalen '
      + 'trenger ikke personnummeret ditt.',
  },
  {
    hva: 'Rutiner, sjekkpunkt og IK-mat du utfører',
    hvorfor: 'Mattilsynet krever at det kan dokumenteres hvem som gjorde '
      + 'hva. Det er også slik du får æren for jobben du har gjort.',
    hvemSer: 'Butikksjefen din og eier. Ved tilsyn: Mattilsynet.',
    hvorLenge: 'Så lenge dokumentasjonskravet gjelder.',
    // Teksten er en opplysningsplikt, ikke pynt: den skal beskrive
    // hvordan det FAKTISK virker. Vakta startes med ansattnummer og
    // PIN fra korrekthetstrinnet — sto det bare «PIN-koden din», ville
    // notatet beskrevet en ordning som ikke lenger finnes.
    merk: 'Registreringene knyttes til ansattnummeret ditt, som du '
      + 'starter vakta med sammen med PIN-en din. Låner du dem bort, '
      + 'står du oppført for det den andre gjorde.',
  },
  {
    hva: 'Ferie og fravær',
    hvorfor: 'For å planlegge bemanningen. Er du borte, må vakten dekkes.',
    hvemSer: 'Butikksjefen din og eier.',
    hvorLenge: 'Fem år.',
    merk: 'Er årsaken sykdom, er det en helseopplysning. Den behandles '
      + 'strengere: bare butikksjef og eier kan lese den, og aldri '
      + 'kolleger.',
  },
  {
    hva: 'Puls-svar',
    hvorfor: 'For å se hvordan folk har det over tid.',
    hvemSer: 'Butikksjefen din og eier ser tallene og kommentarene, men ikke '
      + 'hvem som skrev hva. Koblingen finnes i basen, men er sperret for '
      + 'lesing — heller ikke via omveier.',
    hvorLenge: 'Så lenge runden er lagret.',
    merk: 'Vi kaller det ikke anonymt, for det ville vært et løfte vi ikke '
      + 'kan holde: er dere få på jobb, kan en kommentar være lett å kjenne '
      + 'igjen på innholdet uansett hva systemet gjør. Det systemet KAN '
      + 'love, er at ingen får slå opp hvem som skrev hva.',
  },
  {
    hva: 'Merker, skills-score og konkurranser',
    hvorfor: 'For å vise utvikling og gi anerkjennelse.',
    hvemSer: 'Butikksjefen din og eier. Noe vises også for kolleger.',
    hvorLenge: 'Så lenge du er ansatt.',
  },
]

export type Rettighet = { tittel: string; tekst: string }

export const RETTIGHETER: Rettighet[] = [
  {
    tittel: 'Se alt vi har om deg',
    tekst: 'Be butikksjefen om en utskrift. Du får en samlet oversikt over '
      + 'alt som er registrert — ikke et sammendrag.',
  },
  {
    tittel: 'Få rettet det som er feil',
    tekst: 'Er en stempling, en stillingsprosent eller en timesats feil, '
      + 'skal den rettes. Si fra til butikksjefen.',
  },
  {
    tittel: 'Få slettet det som ikke lenger trengs',
    tekst: 'Lønnsgrunnlag må ligge i fem år etter bokføringsloven og kan '
      + 'ikke slettes før. Annet slettes når det ikke lenger er nødvendig.',
  },
  {
    tittel: 'Klage',
    tekst: 'Mener du opplysningene brukes feil, kan du si fra til eier — '
      + 'og du kan klage til Datatilsynet.',
  },
]

/** Er bekreftelsen fortsatt gyldig, eller har teksten endret seg siden? */
export const maaBekrefte = (bekreftetVersjon: string | null) =>
  bekreftetVersjon !== KONTROLLTILTAK_VERSJON
